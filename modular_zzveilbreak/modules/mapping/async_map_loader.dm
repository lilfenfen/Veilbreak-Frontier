// modular_zzveilbreak/modules/mapping/async_map_loader.dm
// Adaptive async map loader for Veilbreak
// Overrides /datum/map_template/load to provide non-blocking map loading
// Author: Set Fox (refactored with enhanced error reporting)

// Define constants at the top to avoid undefined errors
#define ASYNC_THRESHOLD_TILES 500
#define MAX_PLACEMENT_FAILURES 50
#define INITIAL_BATCH_SIZE 200
#define MIN_BATCH_SIZE 25
#define MAX_BATCH_SIZE 1000

/// Global list to track async map loading operations
GLOBAL_LIST_EMPTY(async_map_operations)

/datum/map_template/load(
	x_offset = 0,
	y_offset = 0,
	z_offset = 0,
	crop_map = FALSE,
	no_changeturf = FALSE,
	x_lower = -INFINITY,
	x_upper = INFINITY,
	y_lower = -INFINITY,
	y_upper = INFINITY,
	z_lower = -INFINITY,
	z_upper = INFINITY,
	place_on_top = FALSE,
	new_z = FALSE
)
	// Call parent first to handle basic validation and setup
	var/datum/parsed_map/loaded_map = ..()
	if(!loaded_map)
		world.log << "MAPLOADER: [src.name] - Base load() failed or returned null."
		return FALSE

	// Check if this template should be loaded asynchronously
	if(!should_load_async())
		return loaded_map

	// Attempt async loading for supported map types
	var/async_result = attempt_async_load(
		loaded_map,
		x_offset, y_offset, z_offset,
		crop_map, no_changeturf,
		x_lower, x_upper, y_lower, y_upper, z_lower, z_upper,
		place_on_top, new_z
	)

	return async_result ? loaded_map : FALSE

/// Determine if this template should be loaded asynchronously
/datum/map_template/proc/should_load_async()
	// For now, always attempt async for templates that support it
	return TRUE

/// Main async loading logic
/datum/map_template/proc/attempt_async_load(
	datum/parsed_map/loaded_map,
	x_offset, y_offset, z_offset,
	crop_map, no_changeturf,
	x_lower, x_upper, y_lower, y_upper, z_lower, z_upper,
	place_on_top, new_z
)
	// Try file-based async loading first (most common case)
	var/file_path = detect_map_file_path()
	if(file_path)
		return start_file_async_load(
			file_path,
			x_offset, y_offset, z_offset,
			crop_map, no_changeturf,
			x_lower, x_upper, y_lower, y_upper, z_lower, z_upper,
			place_on_top, new_z
		)

	// Fall back to coordinate-based async loading
	var/list/coordinate_grid = detect_coordinate_grid()
	if(coordinate_grid)
		return start_coordinate_async_load(
			coordinate_grid,
			x_offset, y_offset, z_offset,
			no_changeturf
		)

	// No async method available
	world.log << "MAPLOADER: [src.name] - No async loading method available, falling back to sync."
	log_template_variables() // Log template vars for debugging
	return FALSE

/// Log template variables for debugging purposes
/datum/map_template/proc/log_template_variables()
	world.log << "MAPLOADER: [src.name] - Template variables dump:"
	for(var/var_name in vars)
		var/val = vars[var_name]
		if(islist(val))
			world.log << "  [var_name]: list with [length(val)] elements"
		else if(istext(val) || isnum(val))
			world.log << "  [var_name]: [val]"
		else if(ispath(val))
			world.log << "  [var_name]: [val] (path)"
		else
			world.log << "  [var_name]: [val] (unknown type)"

/// Detect and validate map file path from template variables
/datum/map_template/proc/detect_map_file_path()
	var/static/list/file_path_indicators = list(
		"original_path",
		"map_path",
		"source_file",
		"file_path",
		"dmm_file"
	)

	for(var/path_var in file_path_indicators)
		if(vars[path_var] && istext(vars[path_var]))
			var/path_candidate = vars[path_var]
			if(validate_file_path(path_candidate))
				world.log << "MAPLOADER: [src.name] - Found file path via [path_var]: [path_candidate]"
				return path_candidate

	// Fallback: scan all text variables for file-like patterns
	var/found_candidates = 0
	for(var/var_name in vars)
		if(istext(vars[var_name]))
			var/path_candidate = vars[var_name]
			if(validate_file_path(path_candidate))
				found_candidates++
				world.log << "MAPLOADER: [src.name] - Found candidate file path in [var_name]: [path_candidate]"

	if(found_candidates > 1)
		world.log << "MAPLOADER: [src.name] - Warning: Multiple file path candidates found, using first match"

	return null

/// Validate that a string looks like a valid map file path
/datum/map_template/proc/validate_file_path(path_string)
	if(!istext(path_string))
		return FALSE

	// Check for file extensions
	if(findtext(path_string, ".dmm") || findtext(path_string, ".tgm"))
		return TRUE

	// Check for common map directory patterns
	if(copytext(path_string, 1, 7) == "_maps/")
		return TRUE

	return FALSE

/// Start async file-based map loading
/datum/map_template/proc/start_file_async_load(
	file_path,
	x_offset, y_offset, z_offset,
	crop_map, no_changeturf,
	x_lower, x_upper, y_lower, y_upper, z_lower, z_upper,
	place_on_top, new_z
)
	world.log << "MAPLOADER: [src.name] - Starting async file load for '[file_path]'"

	var/operation_id = "map_async_[world.time]_[world.tick_usage]"
	GLOB.async_map_operations[operation_id] = TRUE

	spawn()
		var/start_time = world.timeofday

		// Use try-catch for BYOND 516 compatibility
		var/success = FALSE
		var/exception_message = null
		var/detailed_error = null

		try
			// Use the global cached map loading system
			world.log << "MAPLOADER: [src.name] - Calling load_map with params: x=[x_offset], y=[y_offset], z=[z_offset], crop=[crop_map]"

			var/datum/parsed_map/async_loaded_map = load_map(
				file_path,
				x_offset, y_offset, z_offset,
				crop_map,
				FALSE, // measure_only - always false for actual loading
				no_changeturf,
				x_lower, x_upper, y_lower, y_upper, z_lower, z_upper,
				place_on_top, new_z
			)

			var/load_time = (world.timeofday - start_time) / 10

			if(async_loaded_map)
				world.log << "MAPLOADER: [src.name] - Async file load completed in [load_time] seconds"
				success = TRUE
			else
				world.log << "MAPLOADER: [src.name] - Async file load failed after [load_time] seconds - load_map returned null"
				detailed_error = "load_map proc returned null - file may not exist or parsing failed"
				success = FALSE

		catch(var/exception/e)
			exception_message = "[e] on [e.file]:[e.line]"
			world.log << "MAPLOADER: [src.name] - Async file load exception: [exception_message]"
			detailed_error = "Exception during load_map: [exception_message]"
			success = FALSE

		// Cleanup that runs regardless of success or failure
		GLOB.async_map_operations -= operation_id
		on_async_load_complete(success, file_path, detailed_error || exception_message)

	return TRUE

/// Detect coordinate-based map grid in template variables
/datum/map_template/proc/detect_coordinate_grid()
	var/static/list/grid_indicators = list(
		"grid_models",
		"map_grid",
		"coordinate_grid",
		"tile_data"
	)

	for(var/grid_var in grid_indicators)
		if(vars[grid_var] && islist(vars[grid_var]) && length(vars[grid_var]) > 0)
			var/list/candidate = vars[grid_var]
			if(validate_coordinate_grid(candidate))
				world.log << "MAPLOADER: [src.name] - Found coordinate grid via [grid_var] with [length(candidate)] entries"
				return candidate

	// Scan all list variables for coordinate-like structures
	var/found_candidates = 0
	for(var/var_name in vars)
		if(islist(vars[var_name]) && length(vars[var_name]) > 0)
			var/list/candidate = vars[var_name]
			if(validate_coordinate_grid(candidate))
				found_candidates++
				world.log << "MAPLOADER: [src.name] - Found coordinate grid candidate in [var_name] with [length(candidate)] entries"

	if(found_candidates > 1)
		world.log << "MAPLOADER: [src.name] - Warning: Multiple coordinate grid candidates found, using first match"

	return null

/// Validate that a list appears to be a coordinate grid
/datum/map_template/proc/validate_coordinate_grid(list/grid_candidate)
	if(!islist(grid_candidate) || !length(grid_candidate))
		return FALSE

	var/first_entry = grid_candidate[1]
	if(!islist(first_entry))
		return FALSE

	// Check for common coordinate field names
	var/has_coords = ("x" in first_entry) || ("y" in first_entry)
	var/has_turf_data = ("turf" in first_entry) || ("turf_path" in first_entry) || ("typepath" in first_entry)

	return has_coords || has_turf_data

/// Start async coordinate-based map loading
/datum/map_template/proc/start_coordinate_async_load(
	list/coordinate_grid,
	x_offset, y_offset, z_offset,
	no_changeturf
)
	world.log << "MAPLOADER: [src.name] - Starting async coordinate load ([length(coordinate_grid)] tiles)"

	var/operation_id = "coord_async_[world.time]_[world.tick_usage]"
	GLOB.async_map_operations[operation_id] = TRUE

	// Capture total_tiles here so it's available in the spawn closure
	var/total_tiles = length(coordinate_grid)

	spawn()
		var/start_time = world.time
		var/tiles_placed = process_coordinate_batch(
			coordinate_grid,
			x_offset, y_offset, z_offset,
			no_changeturf
		)

		var/duration = world.time - start_time
		var/success_rate = total_tiles > 0 ? (tiles_placed / total_tiles) * 100 : 0

		world.log << "MAPLOADER: [src.name] - Async coordinate load completed - [tiles_placed]/[total_tiles] tiles ([success_rate]%) in [duration] ticks"

		GLOB.async_map_operations -= operation_id
		on_async_load_complete((tiles_placed > 0), "coordinate_grid", "Placed [tiles_placed] of [total_tiles] tiles ([success_rate]% success rate)")

	return TRUE

/// Process coordinate grid in batches with adaptive performance management
/datum/map_template/proc/process_coordinate_batch(
	list/coordinate_grid,
	x_offset, y_offset, z_offset,
	no_changeturf
)
	var/total_tiles = length(coordinate_grid)
	var/tiles_placed = 0
	var/batch_size = initial_batch_size(total_tiles)
	var/failed_placements = 0
	var/list/failure_stats = list(
		"invalid_coords" = 0,
		"invalid_path" = 0,
		"invalid_location" = 0,
		"placement_failed" = 0,
		"invalid_entry" = 0
	)

	world.log << "MAPLOADER: [src.name] - Processing [total_tiles] tiles with initial batch size [batch_size]"

	while(tiles_placed < total_tiles && failed_placements < MAX_PLACEMENT_FAILURES)
		var/processed = 0
		var/failed = 0

		var/start_index = tiles_placed + 1
		var/end_index = min(tiles_placed + batch_size, total_tiles)

		for(var/i = start_index to end_index)
			if(i > length(coordinate_grid))
				break

			var/list/entry = coordinate_grid[i]
			if(!islist(entry))
				failed++
				failure_stats["invalid_entry"]++
				if(failure_stats["invalid_entry"] <= 5) // Log first 5 invalid entries
					world.log << "MAPLOADER: [src.name] - Entry [i] is not a list: [json_encode(entry)]"
				continue

			var/placement_result = place_coordinate_entry(entry, x_offset, y_offset, z_offset, no_changeturf)
			if(placement_result["success"])
				processed++
			else
				failed++
				failure_stats[placement_result["error_type"]]++

				// Log detailed error for first few failures of each type
				if(failure_stats[placement_result["error_type"]] <= 3)
					world.log << "MAPLOADER: [src.name] - Entry [i] failed: [placement_result["error"]]"
					world.log << "MAPLOADER: [src.name] - Entry data: [json_encode(entry)]"

			// Yield every 50 tiles to prevent blocking
			if((i % 50) == 0)
				CHECK_TICK

		tiles_placed += processed
		failed_placements += failed

		// Adaptive batch sizing based on tick usage
		batch_size = calculate_next_batch_size(batch_size)

		// Progress reporting
		if((tiles_placed % 2000) == 0)
			var/percent_complete = total_tiles > 0 ? round((tiles_placed/total_tiles)*100) : 0
			world.log << "MAPLOADER: [src.name] - Progress: [tiles_placed]/[total_tiles] ([percent_complete]%) - Batch size: [batch_size]"

		stoplag()

	// Log failure statistics
	if(failed_placements > 0)
		world.log << "MAPLOADER: [src.name] - Placement failure summary:"
		for(var/error_type in failure_stats)
			if(failure_stats[error_type] > 0)
				world.log << "MAPLOADER: [src.name] -   [error_type]: [failure_stats[error_type]] failures"

	return tiles_placed

/// Calculate initial batch size based on map size
/datum/map_template/proc/initial_batch_size(total_tiles)
	if(total_tiles <= 1000)
		return 100
	else if(total_tiles <= 5000)
		return 200
	else
		return INITIAL_BATCH_SIZE

/// Place a single coordinate entry in the world and return detailed result
/datum/map_template/proc/place_coordinate_entry(
	list/entry,
	x_offset, y_offset, z_offset,
	no_changeturf
)
	// Extract coordinates with offset application
	var/x = (entry["x"] || entry[1] || 1) + x_offset
	var/y = (entry["y"] || entry[2] || 1) + y_offset
	var/z = entry["z"] || entry[3] || z_offset

	// Validate coordinates with detailed error reporting
	if(!isnum(x))
		return list("success" = FALSE, "error" = "X coordinate '[x]' is not a number", "error_type" = "invalid_coords")
	if(!isnum(y))
		return list("success" = FALSE, "error" = "Y coordinate '[y]' is not a number", "error_type" = "invalid_coords")
	if(!isnum(z))
		return list("success" = FALSE, "error" = "Z coordinate '[z]' is not a number", "error_type" = "invalid_coords")

	// Validate coordinate ranges
	if(x < 1 || x > world.maxx)
		return list("success" = FALSE, "error" = "X coordinate [x] out of world bounds (1-[world.maxx])", "error_type" = "invalid_coords")
	if(y < 1 || y > world.maxy)
		return list("success" = FALSE, "error" = "Y coordinate [y] out of world bounds (1-[world.maxy])", "error_type" = "invalid_coords")
	if(z < 1 || z > world.maxz)
		return list("success" = FALSE, "error" = "Z coordinate [z] out of world bounds (1-[world.maxz])", "error_type" = "invalid_coords")

	// Extract and validate turf path
	var/turf_path = extract_turf_path(entry)
	if(!turf_path)
		return list("success" = FALSE, "error" = "No valid turf path found in entry", "error_type" = "invalid_path")

	// Place the turf
	var/turf/target = locate(x, y, z)
	if(!target)
		return list("success" = FALSE, "error" = "Could not locate turf at coordinates ([x], [y], [z])", "error_type" = "invalid_location")

	// Attempt to place the turf
	try
		if(no_changeturf)
			var/atom/new_turf = new turf_path(target)
			if(!new_turf || !isturf(new_turf))
				return list("success" = FALSE, "error" = "Failed to create turf [turf_path] at ([x], [y], [z])", "error_type" = "placement_failed")
		else
			var/turf/new_turf = target.ChangeTurf(turf_path)
			if(!new_turf || !isturf(new_turf))
				return list("success" = FALSE, "error" = "ChangeTurf failed for [turf_path] at ([x], [y], [z])", "error_type" = "placement_failed")
	catch(var/exception/e)
		return list("success" = FALSE, "error" = "Exception during turf placement: [e] at [e.file]:[e.line]", "error_type" = "placement_failed")

	// Place additional atoms if specified
	var/atom_result = place_additional_atoms(entry, target)
	if(!atom_result["success"])
		return atom_result

	return list("success" = TRUE)

/// Extract and validate turf path from coordinate entry
/datum/map_template/proc/extract_turf_path(list/entry)
	var/turf_path_candidate = entry["turf_path"] || entry["turf"] || entry["typepath"]

	if(!turf_path_candidate)
		return null

	// Handle text paths
	if(istext(turf_path_candidate))
		turf_path_candidate = text2path(turf_path_candidate)
		if(!turf_path_candidate)
			return null

	// Validate it's a valid turf path
	if(!ispath(turf_path_candidate, /turf))
		return null

	return turf_path_candidate

/// Place additional atoms specified in the coordinate entry
/datum/map_template/proc/place_additional_atoms(list/entry, turf/target)
	var/list/additional_atoms = entry["atoms"] || entry["contents"]

	if(!islist(additional_atoms))
		return list("success" = TRUE)

	for(var/atom_path in additional_atoms)
		if(ispath(atom_path))
			try
				var/atom/new_atom = new atom_path(target)
				if(!new_atom)
					return list("success" = FALSE, "error" = "Failed to create atom [atom_path] at [target]", "error_type" = "placement_failed")
			catch(var/exception/e)
				return list("success" = FALSE, "error" = "Exception creating atom [atom_path]: [e] at [e.file]:[e.line]", "error_type" = "placement_failed")
		else if(istext(atom_path))
			var/resolved_path = text2path(atom_path)
			if(ispath(resolved_path))
				try
					var/atom/new_atom = new resolved_path(target)
					if(!new_atom)
						return list("success" = FALSE, "error" = "Failed to create atom [resolved_path] (from [atom_path]) at [target]", "error_type" = "placement_failed")
				catch(var/exception/e)
					return list("success" = FALSE, "error" = "Exception creating atom [resolved_path] (from [atom_path]): [e] at [e.file]:[e.line]", "error_type" = "placement_failed")
			else
				return list("success" = FALSE, "error" = "Could not resolve text path [atom_path] to valid type", "error_type" = "invalid_path")

	return list("success" = TRUE)

/// Calculate next batch size based on current performance
/datum/map_template/proc/calculate_next_batch_size(current_batch_size)
	var/current_tick_usage = world.tick_usage

	if(current_tick_usage > 85)
		return max(round(current_batch_size * 0.6), MIN_BATCH_SIZE)
	else if(current_tick_usage > 70)
		return max(round(current_batch_size * 0.8), MIN_BATCH_SIZE)
	else if(current_tick_usage < 50)
		return min(round(current_batch_size * 1.2), MAX_BATCH_SIZE)
	else if(current_tick_usage < 30)
		return min(round(current_batch_size * 1.4), MAX_BATCH_SIZE)
	else
		return current_batch_size

/// Callback for when async loading completes
/datum/map_template/proc/on_async_load_complete(success, load_source, detailed_error = null)
	if(success)
		world.log << "MAPLOADER: [src.name] - Async load successful from [load_source]"
	else
		world.log << "MAPLOADER: [src.name] - Async load FAILED from [load_source]"
		if(detailed_error)
			world.log << "MAPLOADER: [src.name] - Detailed error: [detailed_error]"
