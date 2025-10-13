// modular_zzveilbreak/modules/mapping/async_map_loader.dm
// Adaptive async map loader for Veilbreak
// Overrides /datum/map_template/load to provide non-blocking map loading
// Author: Set Fox (refactored for BYOND 516 compatibility)

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
	// You can add specific conditions here based on your needs
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
	return FALSE

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
				return path_candidate

	// Fallback: scan all text variables for file-like patterns
	for(var/var_name in vars)
		if(istext(vars[var_name]))
			var/path_candidate = vars[var_name]
			if(validate_file_path(path_candidate))
				return path_candidate

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

		try
			// Use the global cached map loading system
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
				world.log << "MAPLOADER: [src.name] - Async file load failed after [load_time] seconds"
				success = FALSE

		catch(var/exception/e)
			exception_message = e
			world.log << "MAPLOADER: [src.name] - Async file load exception: [e]"
			success = FALSE
		finally
			GLOB.async_map_operations -= operation_id
			on_async_load_complete(success, file_path, exception_message)

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
				return candidate

	// Scan all list variables for coordinate-like structures
	for(var/var_name in vars)
		if(islist(vars[var_name]) && length(vars[var_name]) > 0)
			var/list/candidate = vars[var_name]
			if(validate_coordinate_grid(candidate))
				return candidate

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

	spawn()
		var/start_time = world.time
		var/tiles_placed = process_coordinate_batch(
			coordinate_grid,
			x_offset, y_offset, z_offset,
			no_changeturf
		)

		var/duration = world.time - start_time
		world.log << "MAPLOADER: [src.name] - Async coordinate load completed - [tiles_placed]/[length(coordinate_grid)] tiles in [duration] ticks"

		GLOB.async_map_operations -= operation_id
		on_async_load_complete((tiles_placed > 0), "coordinate_grid")

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
				continue

			if(place_coordinate_entry(entry, x_offset, y_offset, z_offset, no_changeturf))
				processed++
			else
				failed++

			// Yield every 50 tiles to prevent blocking
			if((i % 50) == 0)
				CHECK_TICK

		tiles_placed += processed
		failed_placements += failed

		// Adaptive batch sizing based on tick usage
		batch_size = calculate_next_batch_size(batch_size)

		// Progress reporting
		if((tiles_placed % 2000) == 0)
			world.log << "MAPLOADER: [src.name] - Progress: [tiles_placed]/[total_tiles] ([round((tiles_placed/total_tiles)*100)]%)"

		stoplag()

	return tiles_placed

/// Calculate initial batch size based on map size
/datum/map_template/proc/initial_batch_size(total_tiles)
	if(total_tiles <= 1000)
		return 100
	else if(total_tiles <= 5000)
		return 200
	else
		return INITIAL_BATCH_SIZE

/// Process a segment of the coordinate grid
/datum/map_template/proc/process_coordinate_batch_segment(
	list/coordinate_grid,
	start_index,
	end_index,
	x_offset, y_offset, z_offset,
	no_changeturf
)
	var/processed = 0
	var/failed = 0

	for(var/i = start_index to end_index)
		if(i > length(coordinate_grid))
			break

		var/list/entry = coordinate_grid[i]
		if(!islist(entry))
			failed++
			continue

		if(place_coordinate_entry(entry, x_offset, y_offset, z_offset, no_changeturf))
			processed++
		else
			failed++

		// Yield every 50 tiles to prevent blocking
		if((i % 50) == 0)
			CHECK_TICK

	return list("processed" = processed, "failed" = failed)

/// Place a single coordinate entry in the world
/datum/map_template/proc/place_coordinate_entry(
	list/entry,
	x_offset, y_offset, z_offset,
	no_changeturf
)
	// Extract coordinates with offset application
	var/x = (entry["x"] || entry[1] || 1) + x_offset
	var/y = (entry["y"] || entry[2] || 1) + y_offset
	var/z = entry["z"] || entry[3] || z_offset

	// Validate coordinates
	if(!isnum(x) || !isnum(y) || !isnum(z))
		return FALSE

	// Extract and validate turf path
	var/turf_path = extract_turf_path(entry)
	if(!turf_path)
		return FALSE

	// Place the turf
	var/turf/target = locate(x, y, z)
	if(!target)
		return FALSE

	if(no_changeturf)
		new turf_path(target)
	else
		target.ChangeTurf(turf_path)

	// Place additional atoms if specified
	place_additional_atoms(entry, target)

	return TRUE

/// Extract and validate turf path from coordinate entry
/datum/map_template/proc/extract_turf_path(list/entry)
	var/turf_path_candidate = entry["turf_path"] || entry["turf"] || entry["typepath"]

	if(!turf_path_candidate)
		return null

	// Handle text paths
	if(istext(turf_path_candidate))
		turf_path_candidate = text2path(turf_path_candidate)

	// Validate it's a valid turf path
	if(!ispath(turf_path_candidate, /turf))
		return null

	return turf_path_candidate

/// Place additional atoms specified in the coordinate entry
/datum/map_template/proc/place_additional_atoms(list/entry, turf/target)
	var/list/additional_atoms = entry["atoms"] || entry["contents"]

	if(!islist(additional_atoms))
		return

	for(var/atom_path in additional_atoms)
		if(ispath(atom_path))
			new atom_path(target)
		else if(istext(atom_path))
			var/resolved_path = text2path(atom_path)
			if(ispath(resolved_path))
				new resolved_path(target)

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
/datum/map_template/proc/on_async_load_complete(success, load_source, exception_message = null)
	if(success)
		world.log << "MAPLOADER: [src.name] - Async load successful from [load_source]"
		// You can add custom post-load logic here
	else
		world.log << "MAPLOADER: [src.name] - Async load failed from [load_source]"
		if(exception_message)
			world.log << "MAPLOADER: Exception details: [exception_message]"
