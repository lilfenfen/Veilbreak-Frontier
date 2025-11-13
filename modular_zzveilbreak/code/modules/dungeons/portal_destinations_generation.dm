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

	// CRITICAL: Clean the Z-level BEFORE loading new content
	log_dungeon("DUNGEON DEBUG: Pre-cleaning Z-level [dungeon_z_level] before loading new map")
	reset_z_level_to_space(dungeon_z_level)

	// Load the DMM with tick balancing
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

			// CRITICAL: Use place_on_top = TRUE to ensure content loads properly
			loaded_successfully = parsed.load(1, 1, dungeon_z_level, no_changeturf = FALSE, place_on_top = TRUE, new_z = FALSE)

			if(loaded_successfully)
				log_dungeon("DUNGEON DEBUG: Map load SUCCESS - loaded [parsed.bounds[1]]x[parsed.bounds[2]] area")
			else
				error_message = "Map loader returned false"
				log_dungeon("DUNGEON DEBUG: [error_message]")
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

	// CRITICAL: First, scan for and log what was actually loaded
	log_loaded_content(z_level)
	CHECK_TICK

	// Initialize areas and power with tick checks
	initialize_areas_and_power(z_level)
	CHECK_TICK

	// Initialize machinery states
	initialize_machinery(z_level)
	CHECK_TICK

	// Initialize lighting BEFORE smoothing
	initialize_lighting(z_level)
	CHECK_TICK

	// CRITICAL: Configure ALL walls for proper smoothing
	configure_all_walls_for_smoothing(z_level)
	CHECK_TICK

	// Initialize ENHANCED wall and structure smoothing LAST
	initialize_enhanced_smoothing(z_level)
	CHECK_TICK

	// CRITICAL: Ensure portal connection and log results
	var/connection_success = ensure_portal_connection()

	if(!connection_success)
		log_dungeon("Subsystems: WARNING - Failed to establish portal connection")
		// Don't fail generation entirely, but log the issue
	else
		log_dungeon("Subsystems: Portal connection established successfully")

	// Mark as complete
	generated = TRUE
	log_dungeon("Subsystems: INITIALIZATION COMPLETE for Z-level [z_level]")

/// CRITICAL: Log what content was actually loaded
/datum/portal_destination/veilbreak/proc/log_loaded_content(z_level)
	log_dungeon("Content Scan: Scanning loaded content on Z-level [z_level]")

	var/turf_count = 0
	var/obj_count = 0
	var/mob_count = 0
	var/area_count = 0
	var/portal_count = 0
	var/wall_count = 0
	var/other_wall_count = 0

	// Count turfs and walls
	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		turf_count++
		if(istype(T, /turf/closed/wall))
			wall_count++
		else if(istype(T, /turf/closed))
			other_wall_count++
		if(turf_count % 1000 == 0)
			CHECK_TICK

	// Count objects and mobs
	for(var/obj/O in world)
		if(O.z == z_level)
			obj_count++
			if(istype(O, /obj/machinery/portal))
				portal_count++
		if(obj_count % 100 == 0)
			CHECK_TICK

	for(var/mob/M in world)
		if(M.z == z_level)
			mob_count++
		if(mob_count % 100 == 0)
			CHECK_TICK

	// Count areas
	for(var/area/A in world)
		var/has_turfs = FALSE
		for(var/turf/T in A.contents)
			if(T.z == z_level)
				has_turfs = TRUE
				break
		if(has_turfs)
			area_count++
		if(area_count % 10 == 0)
			CHECK_TICK

	log_dungeon("Content Scan: Results - Turfs: [turf_count], Walls: [wall_count], Other Walls: [other_wall_count], Objects: [obj_count], Mobs: [mob_count], Areas: [area_count], Portals: [portal_count]")

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

/// CRITICAL: Configure ALL walls for proper smoothing
/datum/portal_destination/veilbreak/proc/configure_all_walls_for_smoothing(z_level)
	log_dungeon("Wall Config: Configuring ALL walls for smoothing on Z-level [z_level]")

	var/configured_count = 0
	var/regular_walls = 0
	var/mineral_walls = 0

	// Configure ALL regular walls
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			configure_regular_wall(wall)
			regular_walls++
			configured_count++
			if(configured_count % 50 == 0)
				CHECK_TICK

	// Configure ALL mineral walls
	for(var/turf/closed/mineral/mineral in world)
		if(mineral.z == z_level)
			configure_mineral_wall(mineral)
			mineral_walls++
			configured_count++
			if(configured_count % 50 == 0)
				CHECK_TICK

	log_dungeon("Wall Config: Configured [configured_count] total walls - Regular: [regular_walls], Mineral: [mineral_walls]")

/// Configure regular wall for smoothing
/datum/portal_destination/veilbreak/proc/configure_regular_wall(turf/closed/wall/wall)
	// Ensure base_icon_state is set
	if(!wall.base_icon_state)
		wall.base_icon_state = initial(wall.base_icon_state)

	// Ensure smoothing flags are set
	if(!(wall.smoothing_flags & SMOOTH_BITMASK))
		wall.smoothing_flags |= SMOOTH_BITMASK

	// Reset smoothing state to force recalculation
	wall.smoothing_junction = 0
	wall.icon_state = "[wall.base_icon_state]-0"

/// Configure mineral wall for smoothing
/datum/portal_destination/veilbreak/proc/configure_mineral_wall(turf/closed/mineral/mineral)
	// Ensure base_icon_state is set
	if(!mineral.base_icon_state)
		mineral.base_icon_state = initial(mineral.base_icon_state)

	// Ensure smoothing flags are set
	if(!(mineral.smoothing_flags & SMOOTH_BITMASK))
		mineral.smoothing_flags |= SMOOTH_BITMASK

	// Reset smoothing state to force recalculation
	mineral.smoothing_junction = 0
	mineral.icon_state = "[mineral.base_icon_state]-0"

/// ENHANCED smoothing for walls and structures
/datum/portal_destination/veilbreak/proc/initialize_enhanced_smoothing(z_level)
	log_dungeon("Smoothing: Starting ENHANCED wall and structure smoothing for Z-level [z_level]")

	if(!SSicon_smooth || !SSicon_smooth.initialized)
		log_dungeon("Smoothing: Smoothing subsystem not available")
		return

	// Wait a tick to ensure all walls are properly configured
	sleep(1)

	var/smoothed_count = 0

	// First pass: Queue ALL closed turfs for smoothing
	for(var/turf/closed/closed_turf in world)
		if(closed_turf.z == z_level && closed_turf.smoothing_flags)
			QUEUE_SMOOTH(closed_turf)
			smoothed_count++
			if(smoothed_count % 50 == 0)
				CHECK_TICK

	// Second pass: Queue structures that support smoothing
	for(var/obj/structure/structure in world)
		if(structure.z == z_level && structure.smoothing_flags)
			QUEUE_SMOOTH(structure)
			smoothed_count++
			if(smoothed_count % 50 == 0)
				CHECK_TICK

	log_dungeon("Smoothing: Queued [smoothed_count] objects for ENHANCED smoothing on Z-level [z_level]")

	// Force multiple passes to ensure everything smooths properly
	addtimer(CALLBACK(src, .proc/force_initial_smoothing, z_level), 1 SECONDS)
	addtimer(CALLBACK(src, .proc/force_complete_smoothing, z_level), 3 SECONDS)
	addtimer(CALLBACK(src, .proc/force_final_smoothing, z_level), 5 SECONDS)

/// Force initial smoothing pass
/datum/portal_destination/veilbreak/proc/force_initial_smoothing(z_level)
	log_dungeon("Smoothing: Forcing INITIAL smoothing update for Z-level [z_level]")

	// Use the global proc to smooth the entire Z-level (queued)
	smooth_zlevel(z_level, FALSE)

/// Force complete smoothing update for the Z-level
/datum/portal_destination/veilbreak/proc/force_complete_smoothing(z_level)
	log_dungeon("Smoothing: Forcing COMPLETE smoothing update for Z-level [z_level]")

	// Force immediate smoothing for any remaining walls
	smooth_zlevel(z_level, TRUE)

/// Force final smoothing pass
/datum/portal_destination/veilbreak/proc/force_final_smoothing(z_level)
	log_dungeon("Smoothing: Forcing FINAL smoothing update for Z-level [z_level]")

	// One more immediate pass to catch any stragglers
	smooth_zlevel(z_level, TRUE)

	// Force update all wall appearances
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			wall.update_appearance()

	log_dungeon("Smoothing: Complete smoothing forced for Z-level [z_level]")
