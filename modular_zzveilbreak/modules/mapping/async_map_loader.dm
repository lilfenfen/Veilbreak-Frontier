// Map format constants - same as in reader.dm
#define MAP_DMM "dmm"
#define MAP_TGM "tgm"
#define MAP_UNKNOWN "unknown"

// Other constants from reader.dm
#define SPACE_KEY "space"

// Modular overrides for async map loading with tick management

/// Override the main load proc to add tick management
/datum/parsed_map/load(x_offset = 0, y_offset = 0, z_offset = 0, crop_map = FALSE, no_changeturf = FALSE, x_lower = -INFINITY, x_upper = INFINITY, y_lower = -INFINITY, y_upper = INFINITY, z_lower = -INFINITY, z_upper = INFINITY, place_on_top = FALSE, new_z = FALSE)
	world.log << "## ASYNC_MAP_LOAD: Starting async map load from [original_path] at ([x_offset],[y_offset],[z_offset])"
	world.log << "## ASYNC_MAP_LOAD: Parameters - crop_map: [crop_map], no_changeturf: [no_changeturf], place_on_top: [place_on_top], new_z: [new_z]"

	// Call parent implementation but spread across ticks
	Master.StartLoadingMap()

	// Initialize async loading state
	var/async_loading = initialize_async_loading(x_offset, y_offset, z_offset, crop_map, no_changeturf, x_lower, x_upper, y_lower, y_upper, z_lower, z_upper, place_on_top, new_z)

	if(!async_loading)
		// Fall back to original sync loading
		world.log << "## ASYNC_MAP_LOAD_ERROR: Async loading initialization failed, falling back to sync loading"
		. = ..()
		Master.StopLoadingMap()
		return .

	world.log << "## ASYNC_MAP_LOAD: Async loading initialized successfully with [length(gridSets)] grid sets"

	// Start the async loading process
	var/result = execute_async_load()
	Master.StopLoadingMap()

	if(result)
		world.log << "## ASYNC_MAP_LOAD: Completed async map load successfully, bounds: [json_encode(bounds)]"
	else
		world.log << "## ASYNC_MAP_LOAD_ERROR: Async map load failed or was interrupted"

	return result

/// Initialize state for async loading
/datum/parsed_map/proc/initialize_async_loading(x_offset, y_offset, z_offset, crop_map, no_changeturf, x_lower, x_upper, y_lower, y_upper, z_lower, z_upper, place_on_top, new_z)
	world.log << "## ASYNC_MAP_LOAD: Initializing async loading state..."

	// Store loading parameters
	src.async_x_offset = x_offset
	src.async_y_offset = y_offset
	src.async_z_offset = z_offset
	src.async_crop_map = crop_map
	src.async_no_changeturf = no_changeturf
	src.async_place_on_top = place_on_top
	src.async_new_z = new_z

	// Initialize async state
	src.async_grid_index = 1
	src.async_line_index = 1
	src.async_x_pos = 0
	src.async_tiles_this_tick = 0
	src.async_max_tiles_per_tick = initial_max_tiles_per_tick()

	world.log << "## ASYNC_MAP_LOAD: Building model cache..."
	src.async_model_cache = build_cache(no_changeturf)
	if(!src.async_model_cache)
		world.log << "## ASYNC_MAP_LOAD_ERROR: Failed to build model cache"
		return FALSE

	src.async_space_key = src.async_model_cache[SPACE_KEY]
	src.async_loading = TRUE

	// Set up bounds for the new load
	src.bounds = list(1.#INF, 1.#INF, 1.#INF, -1.#INF, -1.#INF, -1.#INF)

	world.log << "## ASYNC_MAP_LOAD: Initialized with [length(async_model_cache)] model keys, space_key: [async_space_key]"
	world.log << "## ASYNC_MAP_LOAD: Initial tile budget: [async_max_tiles_per_tick] per tick"

	return TRUE

/// Get initial tile budget based on server performance
/datum/parsed_map/proc/initial_max_tiles_per_tick()
	// Start conservative, adjust based on server performance
	return 50

/// Main async loading execution
/datum/parsed_map/proc/execute_async_load()
	// Tell ss atoms that we're doing maploading
	loading = TRUE
	SSatoms.map_loader_begin(REF(src))

	var/total_ticks = 0
	var/total_tiles = 0
	var/start_time = world.time

	world.log << "## ASYNC_MAP_LOAD: Beginning async load of [length(gridSets)] grid sets"

	// Process gridsets with tick management
	while(async_grid_index <= length(gridSets))
		total_ticks++

		// Log progress every 10 ticks
		if(total_ticks % 10 == 0)
			world.log << "## ASYNC_MAP_LOAD: Progress - grid [async_grid_index]/[length(gridSets)], tick [total_ticks], tiles this run: [total_tiles]"
			world.log << "## ASYNC_MAP_LOAD: Current tick usage: [world.tick_usage]%, budget: [async_max_tiles_per_tick] tiles/tick"

		var/continue_loading = process_current_gridset_async()

		if(!continue_loading)
			// We hit our tick limit, yield and continue next tick
			SSatoms.map_loader_stop(REF(src))
			stoplag()
			SSatoms.map_loader_begin(REF(src))
			async_tiles_this_tick = 0
			continue

	var/load_time = world.time - start_time
	world.log << "## ASYNC_MAP_LOAD: Grid processing completed in [load_time] ticks and [total_ticks] iterations"

	// Complete the loading process
	complete_async_loading()

	SSatoms.map_loader_stop(REF(src))
	loading = FALSE
	src.async_loading = FALSE

	return TRUE

/// Process current gridset with tick management
/datum/parsed_map/proc/process_current_gridset_async()
	var/datum/grid_set/gset = gridSets[async_grid_index]

	if(!gset)
		world.log << "## ASYNC_MAP_LOAD_ERROR: Grid set [async_grid_index] is null!"
		return FALSE

	var/list/gridLines = gset.gridLines
	var/line_len = src.line_len
	var/key_len = src.key_len

	if(!gridLines)
		world.log << "## ASYNC_MAP_LOAD_ERROR: Grid set [async_grid_index] has no gridLines!"
		return FALSE

	world.log << "## ASYNC_MAP_LOAD: Processing grid set [async_grid_index] at ([gset.xcrd],[gset.ycrd],[gset.zcrd]) with [length(gridLines)] lines"

	// Calculate actual coordinates
	var/true_xcrd = gset.xcrd + (async_x_offset - 1)
	var/ycrd = gset.ycrd + (async_y_offset - 1) - (async_line_index - 1)
	var/zcrd = gset.zcrd + (async_z_offset - 1)

	// Process remaining lines in this grid set
	for(var/i in async_line_index to length(gridLines))
		var/line = gridLines[i]

		if(!line)
			world.log << "## ASYNC_MAP_LOAD_WARNING: Line [i] in grid set [async_grid_index] is null, skipping"
			continue

		// Process characters in this line starting from where we left off
		for(var/tpos in (1 + async_x_pos) to line_len step key_len)
			// Check if we've processed enough tiles this tick
			if(async_tiles_this_tick >= async_max_tiles_per_tick)
				// Save our position for next tick
				async_line_index = i
				async_x_pos = tpos - 1
				world.log << "## ASYNC_MAP_LOAD: Tile budget reached at grid [async_grid_index], line [i], position [tpos]. Processed [async_tiles_this_tick] tiles this tick."
				return FALSE

			// Check current tick usage - yield if we're using too much
			if(world.tick_usage > 85)
				async_line_index = i
				async_x_pos = tpos - 1
				world.log << "## ASYNC_MAP_LOAD: High tick usage ([world.tick_usage]%) at grid [async_grid_index], line [i], position [tpos]. Yielding."
				return FALSE

			var/model_key = copytext(line, tpos, tpos + key_len)

			// Skip space keys to save processing
			if(model_key == async_space_key)
				async_tiles_this_tick++
				continue

			var/list/cache = async_model_cache[model_key]
			if(!cache)
				world.log << "## ASYNC_MAP_LOAD_ERROR: Undefined model key '[model_key]' at grid [async_grid_index], line [i], position [tpos]"
				CRASH("Undefined model key in DMM: [model_key]")

			// Calculate actual coordinate
			var/x_position = true_xcrd + ((tpos - 1) / key_len)
			var/turf/crds = locate(x_position, ycrd, zcrd)

			if(crds)
				// Build the coordinate using parent implementation
				build_coordinate(cache, crds, async_no_changeturf, async_place_on_top, async_new_z)

				// Update bounds
				update_bounds_async(x_position, ycrd, zcrd)
			else
				world.log << "## ASYNC_MAP_LOAD_WARNING: Could not locate turf at ([x_position], [ycrd], [zcrd])"

			async_tiles_this_tick++

		// Reset x position and move to next line
		async_x_pos = 0
		ycrd--

	world.log << "## ASYNC_MAP_LOAD: Completed grid set [async_grid_index]"

	// Move to next grid set
	async_grid_index++
	async_line_index = 1
	async_x_pos = 0

	// Adjust tile budget based on performance
	adjust_tile_budget_async()

	return TRUE

/// Update bounds during async loading
/datum/parsed_map/proc/update_bounds_async(x, y, z)
	var/list/bounds = src.bounds
	if(!bounds)
		world.log << "## ASYNC_MAP_LOAD_ERROR: Bounds list is null during update!"
		return

	bounds[MAP_MINX] = min(bounds[MAP_MINX], x)
	bounds[MAP_MINY] = min(bounds[MAP_MINY], y)
	bounds[MAP_MINZ] = min(bounds[MAP_MINZ], z)
	bounds[MAP_MAXX] = max(bounds[MAP_MAXX], x)
	bounds[MAP_MAXY] = max(bounds[MAP_MAXY], y)
	bounds[MAP_MAXZ] = max(bounds[MAP_MAXZ], z)

/// Adjust tile budget based on current performance
/datum/parsed_map/proc/adjust_tile_budget_async()
	var/current_tick_usage = world.tick_usage
	var/old_budget = async_max_tiles_per_tick

	if(current_tick_usage < 60)
		// We have headroom, increase budget
		async_max_tiles_per_tick = min(async_max_tiles_per_tick * 1.2, 200)
		world.log << "## ASYNC_MAP_LOAD: Increased tile budget from [old_budget] to [async_max_tiles_per_tick] (low usage: [current_tick_usage]%)"
	else if(current_tick_usage > 80)
		// We're using too much, decrease budget
		async_max_tiles_per_tick = max(async_max_tiles_per_tick * 0.8, 10)
		world.log << "## ASYNC_MAP_LOAD: Decreased tile budget from [old_budget] to [async_max_tiles_per_tick] (high usage: [current_tick_usage]%)"
	else
		world.log << "## ASYNC_MAP_LOAD: Maintaining tile budget at [async_max_tiles_per_tick] (usage: [current_tick_usage]%)"

/// Complete the async loading process
/datum/parsed_map/proc/complete_async_loading()
	world.log << "## ASYNC_MAP_LOAD: Starting post-load processing"

	// Handle post-load processing similar to original _load_impl

	if(async_new_z)
		world.log << "## ASYNC_MAP_LOAD: Building area turfs for new z-levels"
		for(var/z_index in bounds[MAP_MINZ] to bounds[MAP_MAXZ])
			SSmapping.build_area_turfs(z_index)

	if(!async_no_changeturf)
		world.log << "## ASYNC_MAP_LOAD: Calling AfterChange on loaded turfs"
		var/list/turfs = block(
			bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ],
			bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]
		)
		world.log << "## ASYNC_MAP_LOAD: Processing [length(turfs)] turfs for AfterChange"
		for(var/turf/T as anything in turfs)
			T.AfterChange(CHANGETURF_IGNORE_AIR)

	if(expanded_x || expanded_y)
		world.log << "## ASYNC_MAP_LOAD: Sending expanded bounds signal"
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPANDED_WORLD_BOUNDS, expanded_x, expanded_y)

	#ifdef TESTING
	if(turfsSkipped)
		testing("Skipped loading [turfsSkipped] default turfs")
	#endif

	world.log << "## ASYNC_MAP_LOAD: Post-load processing completed"

// Add async loading variables to the parsed_map datum
/datum/parsed_map
	// Async loading state
	var/async_loading = FALSE
	var/async_grid_index = 1
	var/async_line_index = 1
	var/async_x_pos = 0
	var/async_tiles_this_tick = 0
	var/async_max_tiles_per_tick = 50
	var/list/async_model_cache
	var/async_space_key

	// Async loading parameters
	var/async_x_offset
	var/async_y_offset
	var/async_z_offset
	var/async_crop_map
	var/async_no_changeturf
	var/async_place_on_top
	var/async_new_z


/// Override cache building to handle both TGM and DMM formats safely
/datum/parsed_map/build_cache(no_changeturf, bad_paths)
	world.log << "## ASYNC_MAP_LOAD: Building cache for format: [map_format]"

	if(modelCache && !bad_paths)
		return modelCache

	// Use the appropriate cache builder based on map format
	if(map_format == MAP_TGM)
		world.log << "## ASYNC_MAP_LOAD: Using TGM cache builder"
		return tgm_build_cache(no_changeturf, bad_paths)
	else
		world.log << "## ASYNC_MAP_LOAD: Using DMM cache builder"
		return dmm_build_cache(no_changeturf, bad_paths)

/// Fixed TGM cache building with proper error handling
/datum/parsed_map/tgm_build_cache(no_changeturf, bad_paths=null)
	if(modelCache && !bad_paths)
		return modelCache
	. = modelCache = list()
	var/list/grid_models = src.grid_models
	var/set_space = FALSE
	var/static/list/default_list = GLOB.map_model_default
	var/static/list/wrapped_default_list = list(default_list)

	var/path_to_init = ""
	var/list/current_attributes
	var/editing = FALSE

	world.log << "## TGM_CACHE: Building cache for [length(grid_models)] models"

	for(var/model_key in grid_models)
		world.log << "## TGM_CACHE: Processing model key '[model_key]'"

		var/list/lines = splittext(grid_models[model_key], "\n")
		var/list/members = list()
		var/list/members_attributes = list()

		for(var/line in lines)
			if(!line || length(line) == 0)
				world.log << "## TGM_CACHE_WARNING: Empty line in model [model_key]"
				continue

			var/last_char = length(line) > 0 ? line[length(line)] : ""

			switch(last_char)
				if(";") // Var edit
					if(!current_attributes)
						world.log << "## TGM_CACHE_WARNING: Var edit without active editing block in [model_key]: [line]"
						continue

					var_edits_tgm.Find(line)
					if(var_edits_tgm.group && length(var_edits_tgm.group) >= 3)
						var/value = parse_constant(var_edits_tgm.group[2])
						if(istext(value))
							value = apply_text_macros(value)
						current_attributes[var_edits_tgm.group[1]] = value
					continue

				if("{") // Start of edit block
					editing = TRUE
					current_attributes = list()
					members_attributes += list(current_attributes)
					path_to_init = copytext(line, 1, -1)

				if(",") // End of path
					if(editing)
						editing = FALSE
					else
						members_attributes += wrapped_default_list
						path_to_init = copytext(line, 1, -1)

				if("}") // End of edit block
					if(editing)
						editing = FALSE
					continue

				else // Path or area
					if(editing)
						var_edits_tgm.Find(line)
						if(var_edits_tgm.group && length(var_edits_tgm.group) >= 3)
							var/value = parse_constant(var_edits_tgm.group[2])
							if(istext(value))
								value = apply_text_macros(value)
							current_attributes[var_edits_tgm.group[1]] = value
						continue
					else
						members_attributes += wrapped_default_list
						path_to_init = line

			// Process the path if we have one
			if(path_to_init && path_to_init != "")
				var/atom_def = text2path(path_to_init)

				if(!ispath(atom_def, /atom))
					world.log << "## TGM_CACHE_WARNING: Invalid path '[path_to_init]' in model [model_key]"
					if(bad_paths)
						LAZYOR(bad_paths[path_to_init], model_key)
					// Remove the attributes we just added since the path is invalid
					if(length(members_attributes) > length(members))
						members_attributes.len = length(members)
					path_to_init = ""
					continue

				members += atom_def
				path_to_init = ""

		// Safety check - ensure lists are the same length
		if(length(members) != length(members_attributes))
			world.log << "## TGM_CACHE_ERROR: Mismatched list lengths in model [model_key]: members=[length(members)], attributes=[length(members_attributes)]"
			// Truncate the longer list to match the shorter one
			var/min_length = min(length(members), length(members_attributes))
			if(length(members) > min_length)
				members.len = min_length
			if(length(members_attributes) > min_length)
				members_attributes.len = min_length

		// Space key optimization
		if(!set_space && no_changeturf && length(members) == 2 && length(members_attributes) == 2)
			var/valid_space = TRUE
			if(members_attributes[1] != default_list || members_attributes[2] != default_list)
				valid_space = FALSE
			if(length(members) < 2 || members[2] != world.area || members[1] != world.turf)
				valid_space = FALSE

			if(valid_space)
				set_space = TRUE
				.[SPACE_KEY] = model_key
				world.log << "## TGM_CACHE: Set space key to '[model_key]'"
				continue

		.[model_key] = list(members, members_attributes)
		world.log << "## TGM_CACHE: Added model '[model_key]' with [length(members)] members"

	world.log << "## TGM_CACHE: Completed building cache with [length(.)] entries"
	return .

/// Fixed DMM cache building with proper error handling
/datum/parsed_map/dmm_build_cache(no_changeturf, bad_paths=null)
	if(modelCache && !bad_paths)
		return modelCache
	. = modelCache = list()
	var/list/grid_models = src.grid_models
	var/set_space = FALSE
	var/static/list/default_list = list(GLOB.map_model_default)

	world.log << "## DMM_CACHE: Building cache for [length(grid_models)] models"

	for(var/model_key in grid_models)
		world.log << "## DMM_CACHE: Processing model key '[model_key]'"

		var/list/members = list()
		var/list/members_attributes = list()
		var/model = grid_models[model_key]
		var/model_index = 1

		while(model_path.Find(model, model_index))
			var/variables_start = 0
			var/member_string = model_path.group[1]
			model_index = model_path.next

			// Check if this member has variables
			if(member_string[length(member_string)] == "}")
				variables_start = findtext(member_string, "{")

			var/path_text = trim(copytext(member_string, 1, variables_start))
			var/atom_def = text2path(path_text)

			if(!ispath(atom_def, /atom))
				world.log << "## DMM_CACHE_WARNING: Invalid path '[path_text]' in model [model_key]"
				if(bad_paths)
					LAZYOR(bad_paths[path_text], model_key)
				continue

			members += atom_def

			// Handle variables if present
			var/list/fields = default_list
			if(variables_start)
				member_string = copytext(member_string, variables_start + length(member_string[variables_start]), -length(copytext_char(member_string, -1)))
				fields = list(readlist(member_string, ";"))
				for(var/I in fields)
					var/value = fields[I]
					if(istext(value))
						fields[I] = apply_text_macros(value)

			members_attributes += fields

			// Prevent infinite loops
			if(model_index > length(model) * 2)
				world.log << "## DMM_CACHE_WARNING: Breaking potential infinite loop in model [model_key]"
				break

		// Space key optimization
		if(!set_space && no_changeturf && length(members) == 2 && length(members_attributes) == 2)
			var/valid_space = TRUE
			if(length(members_attributes[1]) != 0 || length(members_attributes[2]) != 0)
				valid_space = FALSE
			if(length(members) < 2 || members[2] != world.area || members[1] != world.turf)
				valid_space = FALSE

			if(valid_space)
				set_space = TRUE
				.[SPACE_KEY] = model_key
				world.log << "## DMM_CACHE: Set space key to '[model_key]'"
				continue

		.[model_key] = list(members, members_attributes)
		world.log << "## DMM_CACHE: Added model '[model_key]' with [length(members)] members"

	world.log << "## DMM_CACHE: Completed building cache with [length(.)] entries"
	return .




//Storing the adminverbs here for a moment

ADMIN_VERB(map_template_load_fen, R_DEBUG, "#Map Template - Place(NEW)", "Place a map template at your current location.", ADMIN_CATEGORY_DEBUG)
	var/datum/map_template/template
	var/map = tgui_input_list(user, "Choose a Map Template to place at your CURRENT LOCATION","Place Map Template", sort_list(SSmapping.map_templates))
	if(!map)
		return
	template = SSmapping.map_templates[map]

	var/turf/T = get_turf(user.mob)
	if(!T)
		return

	var/list/preview = list()
	var/center
	var/centeralert = tgui_alert(user,"Center Template.","Template Centering",list("Yes","No"))
	switch(centeralert)
		if("Yes")
			center = TRUE
		if("No")
			center = FALSE
		else
			return
	for(var/turf/place_on as anything in template.get_affected_turfs(T,centered = center))
		var/image/item = image('icons/turf/overlays.dmi', place_on,"greenOverlay")
		SET_PLANE(item, ABOVE_LIGHTING_PLANE, place_on)
		preview += item
	user.images += preview
	if(tgui_alert(user,"Confirm location.","Template Confirm",list("Yes","No")) == "Yes")
		// USE ASYNC LOADING INSTEAD OF template.load()
		if(template.cached_map)
			world.log << "## ASYNC_TEMPLATE_LOAD: Starting async template load [template.name] at [T]"
			var/success = template.cached_map.load(
				T.x - (center ? round(template.width/2) : 0),
				T.y - (center ? round(template.height/2) : 0),
				T.z,
				FALSE, // crop_map
				FALSE, // no_changeturf
				-INFINITY, // x_lower
				INFINITY,  // x_upper
				-INFINITY, // y_lower
				INFINITY,  // y_upper
				-INFINITY, // z_lower
				INFINITY,  // z_upper
				FALSE, // place_on_top
				FALSE  // new_z
			)

			if(success)
				var/affected = template.get_affected_turfs(T, centered = center)
				for(var/AT in affected)
					for(var/obj/docking_port/mobile/P in AT)
						if(istype(P, /obj/docking_port/mobile))
							template.post_load(P)
							break

				message_admins(span_adminnotice("[key_name_admin(user)] has placed a map template ([template.name]) at [ADMIN_COORDJMP(T)]"))
			else
				to_chat(user, "Failed to place map", confidential = TRUE)
		else
			to_chat(user, "Template has no cached map data", confidential = TRUE)
	user.images -= preview

ADMIN_VERB(map_template_upload_fen, R_DEBUG, "#Map Template - Upload (New)", "Upload a map template to the server.", ADMIN_CATEGORY_DEBUG)
	var/map = input(user, "Choose a Map Template to upload to template storage","Upload Map Template") as null|file
	if(!map)
		return
	if(!(copytext("[map]", -4) == ".dmm" || copytext("[map]", -4) == ".tgm"))
		to_chat(user, span_warning("Filename must end in '.dmm' or '.tgm': [map]"), confidential = TRUE)
		return

	world.log << "## ASYNC_TEMPLATE_UPLOAD: Starting async upload of [map]"

	var/datum/map_template/M
	switch(tgui_alert(user, "What kind of map is this?", "Map type", list("Normal", "Shuttle", "Cancel")))
		if("Normal")
			M = new /datum/map_template(map, "[map]", TRUE)
		if("Shuttle")
			M = new /datum/map_template/shuttle(map, "[map]", TRUE)
		else
			return

	world.log << "## ASYNC_TEMPLATE_UPLOAD: Template created, checking cached map..."

	// The template creation should have used your async parsed_map.New() override
	// but we add logging to verify
	if(!M.cached_map)
		to_chat(user, span_warning("Map template '[map]' failed to parse properly."), confidential = TRUE)
		world.log << "## ASYNC_TEMPLATE_UPLOAD_ERROR: Failed to parse map template [map]"
		return

	world.log << "## ASYNC_TEMPLATE_UPLOAD: Running validation on parsed map..."

	var/datum/map_report/report = M.cached_map.check_for_errors()
	var/report_link
	if(report)
		report.show_to(user)
		report_link = " - <a href='byond://?src=[REF(report)];[HrefToken(forceGlobal = TRUE)];show=1'>validation report</a>"
		to_chat(user, span_warning("Map template '[map]' <a href='byond://?src=[REF(report)];[HrefToken()];show=1'>failed validation</a>."), confidential = TRUE)
		if(report.loadable)
			var/response = tgui_alert(user, "The map failed validation, would you like to load it anyways?", "Map Errors", list("Cancel", "Upload Anyways"))
			if(response != "Upload Anyways")
				return
		else
			tgui_alert(user, "The map failed validation and cannot be loaded.", "Map Errors", list("Oh Darn"))
			return

	SSmapping.map_templates[M.name] = M
	message_admins(span_adminnotice("[key_name_admin(user)] has uploaded a map template '[map]' ([M.width]x[M.height])[report_link]."))
	to_chat(user, span_notice("Map template '[map]' ready to place ([M.width]x[M.height])"), confidential = TRUE)
