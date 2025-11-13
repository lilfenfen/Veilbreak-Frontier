// modular_zzveilbreak/code/modules/dungeons/portal_destinations_generation.dm

/datum/portal_destination/veilbreak/proc/start_generation()
	log_dungeon("DUNGEON DEBUG: start_generation() called for [name]")

	if(generating)
		log_dungeon("DUNGEON DEBUG: Generation blocked - already generating")
		return FALSE

	// Verify mapping subsystem is ready
	if(!SSmapping || !SSmapping.initialized)
		log_dungeon("DUNGEON DEBUG: Generation failed - SSmapping not ready")
		return FALSE

	generating = TRUE
	generated = FALSE
	generation_progress = 0
	log_dungeon("DUNGEON DEBUG: Set generation state - generating: TRUE, generated: FALSE, progress: 0")

	if(!GLOB.dungeon_generator)
		GLOB.dungeon_generator = new /datum/http_dungeon_generator()

	log_dungeon("DUNGEON DEBUG: Starting generation for portal destination [name]")
	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, DUNGEON_WIDTH, DUNGEON_HEIGHT)

	if(!current_request_id)
		log_dungeon("DUNGEON DEBUG: Generation failed - generate_dungeon returned 0")
		generating = FALSE
		generation_failed("Failed to start generation request")
		return FALSE

	log_dungeon("DUNGEON DEBUG: Generation started successfully with request [current_request_id]")
	START_PROCESSING(SSobj, src)
	return TRUE

/datum/portal_destination/veilbreak/process()
	if(processing_disabled)
		STOP_PROCESSING(SSobj, src)
		return

	if(!generating)
		STOP_PROCESSING(SSobj, src)
		return

	// Update progress for UI
	if(world.time - last_progress_update > 1 SECONDS)
		generation_progress = min(generation_progress + rand(5, 15), 90)
		last_progress_update = world.time

	// Check if request is complete
	if(current_request_id)
		var/still_processing = GLOB.dungeon_generator.check_request(current_request_id)
		if(!still_processing)
			STOP_PROCESSING(SSobj, src)
			generation_progress = 100
			return

	// Safety timeout
	STOP_PROCESSING(SSobj, src)
	generation_failed("Generation process stuck in invalid state")

/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	log_dungeon("DUNGEON DEBUG: generation_complete() called")
	generating = FALSE

	// Store generation data
	last_generation_data = data.Copy()

	// Access dmm_content from top level
	if(data["dmm_content"])
		log_dungeon("DUNGEON DEBUG: DMM content received, starting load process")
		load_generated_dmm(data["dmm_content"])
	else
		log_dungeon("DUNGEON DEBUG: No DMM content in response")
		generation_failed("No DMM content in response")

	// Notify control computer
	if(connected_control_computer && !QDELETED(connected_control_computer))
		connected_control_computer.on_generation_completed()
		connected_control_computer = null

/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content)
	log_dungeon("DUNGEON DEBUG: load_generated_dmm() called")

	if(!dmm_content)
		log_dungeon("DUNGEON DEBUG: No DMM content provided")
		return generation_failed("No DMM content provided")

	// Initialize or get the reusable portal Z-level
	if(!initialize_portal_z_level())
		log_dungeon("DUNGEON DEBUG: Failed to initialize portal Z-level")
		return generation_failed("Failed to initialize portal Z-level")

	log_dungeon("DUNGEON DEBUG: Using reusable portal Z-level [dungeon_z_level]")

	// Load the DMM with tick balancing - NO CLEANUP NEEDED for fresh map
	load_dmm_with_ticks(dmm_content)

/datum/portal_destination/veilbreak/proc/load_dmm_with_ticks(dmm_content)
	log_dungeon("DUNGEON DEBUG: Starting tick-balanced DMM loading")

	// Validate DMM content first
	if(!dmm_content || length(dmm_content) < 100) // Basic sanity check
		log_dungeon("DUNGEON DEBUG: Invalid DMM content - too short or empty")
		generation_failed("Invalid map data received")
		return

	// Write DMM content to a temporary file
	var/temp_filename = "data/dungeon_temp_[world.time]_[rand(1000,9999)].dmm"

	try
		text2file(dmm_content, temp_filename)
		log_dungeon("DUNGEON DEBUG: Wrote temporary file [temp_filename]")
	catch(var/exception/e)
		log_dungeon("DUNGEON DEBUG: Failed to write temporary DMM file: [e]")
		generation_failed("Failed to write map data")
		return

	// Use SSatoms to handle initialization
	SSatoms.map_loader_begin("dungeon_generator_[dungeon_z_level]")

	if(SSair.initialized)
		SSair.StartLoadingMap()

	var/loaded_successfully = FALSE
	var/error_message = "Unknown error"

	try
		log_dungeon("DUNGEON DEBUG: Attempting to parse DMM file")
		var/datum/parsed_map/parsed = new(file(temp_filename))
		if(parsed && parsed.bounds)
			log_dungeon("DUNGEON DEBUG: Parsed map successfully, bounds: [parsed.bounds]")
			log_dungeon("DUNGEON DEBUG: Loading map to Z-level [dungeon_z_level]")
			loaded_successfully = parsed.load(1, 1, dungeon_z_level, no_changeturf = TRUE, place_on_top = FALSE, new_z = FALSE)
			log_dungeon("DUNGEON DEBUG: Map load result: [loaded_successfully ? "SUCCESS" : "FAILED"]")
		else
			error_message = "Failed to parse map file - no bounds"
			log_dungeon("DUNGEON DEBUG: [error_message]")
			loaded_successfully = FALSE
	catch(var/exception/e2)
		error_message = "Exception during map load: [e2]"
		log_dungeon("DUNGEON DEBUG: [error_message]")
		loaded_successfully = FALSE

	if(SSair.initialized)
		SSair.StopLoadingMap()

	SSatoms.map_loader_stop("dungeon_generator_[dungeon_z_level]")

	// Clean up temp file
	fdel(temp_filename)

	if(!loaded_successfully)
		log_dungeon("DUNGEON DEBUG: Map load failed: [error_message]")
		generation_failed("Failed to load map: [error_message]")
		return

	// Initialize subsystems with tick balancing
	initialize_dungeon_subsystems(dungeon_z_level)

/datum/portal_destination/veilbreak/proc/initialize_dungeon_subsystems(z_level)
	log_dungeon("Subsystems: Starting subsystem initialization for Z-level [z_level]")

	// Initialize areas and power with tick checks
	initialize_areas_and_power(z_level)
	CHECK_TICK

	// Initialize lighting
	initialize_lighting(z_level)
	CHECK_TICK

	// Initialize machinery states
	initialize_machinery(z_level)
	CHECK_TICK

	// Initialize ENHANCED wall and structure smoothing
	initialize_enhanced_smoothing(z_level)
	CHECK_TICK

	// Finalize portal connection
	ensure_portal_connection()

	// Mark as complete
	generated = TRUE
	log_dungeon("Subsystems: INITIALIZATION COMPLETE for Z-level [z_level]")

/datum/portal_destination/veilbreak/proc/initialize_areas_and_power(z_level)
	log_dungeon("Subsystems: Initializing areas and power")

	for(var/area/area as anything in GLOB.areas)
		var/has_turfs_on_z = FALSE
		for(var/turf/T in area.contents)
			if(T.z == z_level)
				has_turfs_on_z = TRUE
				break

		if(has_turfs_on_z)
			area.power_equip = initial(area.power_equip)
			area.power_light = initial(area.power_light)
			area.power_environ = initial(area.power_environ)
			area.always_unpowered = initial(area.always_unpowered)
			area.power_change()
			area.update_icon()

		CHECK_TICK

/datum/portal_destination/veilbreak/proc/initialize_lighting(z_level)
	log_dungeon("Subsystems: Initializing lighting")

	if(!SSlighting || !SSlighting.initialized)
		log_dungeon("Subsystems: Lighting subsystem not available")
		return

	for(var/x = 1 to world.maxx)
		for(var/y = 1 to world.maxy)
			var/turf/iter_turf = locate(x, y, z_level)
			if(!iter_turf.space_lit && !iter_turf.lighting_object)
				new /datum/lighting_object(iter_turf)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/initialize_machinery(z_level)
	log_dungeon("Subsystems: Initializing machinery")

	var/processed = 0
	for(var/obj/machinery/machine in world)
		if(machine.z != z_level)
			continue

		if(machine.use_power)
			machine.power_change()
		machine.update_icon()
		machine.update_appearance()

		processed++
		if(processed % 50 == 0)
			CHECK_TICK

	log_dungeon("Subsystems: Initialized [processed] machinery objects")

/// ENHANCED smoothing for walls and structures - using exact patterns from codebase
/datum/portal_destination/veilbreak/proc/initialize_enhanced_smoothing(z_level)
	log_dungeon("Smoothing: Starting ENHANCED wall and structure smoothing for Z-level [z_level]")

	if(!SSicon_smooth || !SSicon_smooth.initialized)
		log_dungeon("Smoothing: Smoothing subsystem not available")
		return

	var/smoothed_count = 0
	var/walls_fixed = 0

	// First, ensure all walls have proper smoothing flags and groups matching codebase patterns
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			// Match exact pattern from ice mineral wall example
			wall.smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER
			wall.smoothing_groups = list(SMOOTH_GROUP_CLOSED_TURFS, SMOOTH_GROUP_WALLS)
			wall.canSmoothWith = list(SMOOTH_GROUP_CLOSED_TURFS, SMOOTH_GROUP_WALLS)
			walls_fixed++
			CHECK_TICK

	// Also fix mineral walls using same pattern
	for(var/turf/closed/wall/mineral/mineral_wall in world)
		if(mineral_wall.z == z_level)
			mineral_wall.smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER
			mineral_wall.smoothing_groups = list(SMOOTH_GROUP_CLOSED_TURFS, SMOOTH_GROUP_MINERAL_WALLS)
			mineral_wall.canSmoothWith = list(SMOOTH_GROUP_CLOSED_TURFS, SMOOTH_GROUP_MINERAL_WALLS)
			walls_fixed++
			CHECK_TICK

	// Fix reinforced walls with same pattern
	for(var/turf/closed/wall/r_wall in world)
		if(r_wall.z == z_level && !istype(r_wall, /turf/closed/wall/mineral))
			r_wall.smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER
			r_wall.smoothing_groups = list(SMOOTH_GROUP_CLOSED_TURFS, SMOOTH_GROUP_WALLS)
			r_wall.canSmoothWith = list(SMOOTH_GROUP_CLOSED_TURFS, SMOOTH_GROUP_WALLS)
			walls_fixed++
			CHECK_TICK

	log_dungeon("Smoothing: Fixed smoothing flags for [walls_fixed] walls")

	// Now queue everything for smoothing
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			QUEUE_SMOOTH(wall)
			smoothed_count++
			if(smoothed_count % 50 == 0)
				CHECK_TICK

	// Queue all mineral walls
	for(var/turf/closed/wall/mineral/mineral_wall in world)
		if(mineral_wall.z == z_level)
			QUEUE_SMOOTH(mineral_wall)
			smoothed_count++
			if(smoothed_count % 50 == 0)
				CHECK_TICK

	// Queue all reinforced walls
	for(var/turf/closed/wall/r_wall in world)
		if(r_wall.z == z_level)
			QUEUE_SMOOTH(r_wall)
			smoothed_count++
			if(smoothed_count % 50 == 0)
				CHECK_TICK

	// Queue structures that support smoothing
	for(var/obj/structure/structure in world)
		if(structure.z == z_level && structure.smoothing_flags)
			QUEUE_SMOOTH(structure)
			smoothed_count++
			if(smoothed_count % 50 == 0)
				CHECK_TICK

	log_dungeon("Smoothing: Queued [smoothed_count] objects for ENHANCED smoothing on Z-level [z_level]")

	// Force an immediate smoothing update for the entire Z-level
	addtimer(CALLBACK(src, .proc/force_smoothing_update, z_level), 1 SECONDS)

/// Force a complete smoothing update for the Z-level
/datum/portal_destination/veilbreak/proc/force_smoothing_update(z_level)
	log_dungeon("Smoothing: Forcing complete smoothing update for Z-level [z_level]")

	// Force smooth all walls on the Z-level
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			wall.smooth_icon()
			CHECK_TICK

	// Force smooth all mineral walls
	for(var/turf/closed/wall/mineral/mineral_wall in world)
		if(mineral_wall.z == z_level)
			mineral_wall.smooth_icon()
			CHECK_TICK

	log_dungeon("Smoothing: Complete smoothing update finished for Z-level [z_level]")

/// Replace generated walls with proper SS13 wall types (optional fallback)
/datum/portal_destination/veilbreak/proc/replace_walls_with_proper_types(z_level)
	log_dungeon("Wall Replacement: Starting wall type replacement for Z-level [z_level]")

	var/walls_replaced = 0

	for(var/turf/closed/wall/wall in world)
		if(wall.z != z_level)
			continue

		// Skip if already a proper wall type
		if(istype(wall, /turf/closed/wall) && !istype(wall, /turf/closed/wall/mineral))
			continue

		var/turf/closed/wall/new_wall

		// Determine what type of wall to create based on appearance or other factors
		if(istype(wall, /turf/closed/wall/mineral))
			// Keep mineral walls but ensure they're proper types
			new_wall = wall.ChangeTurf(/turf/closed/wall/mineral/iron) // Default to iron
		else
			// Regular wall
			new_wall = wall.ChangeTurf(/turf/closed/wall)

		if(new_wall)
			walls_replaced++

		if(walls_replaced % 25 == 0)
			CHECK_TICK

	log_dungeon("Wall Replacement: Replaced [walls_replaced] walls with proper types")
