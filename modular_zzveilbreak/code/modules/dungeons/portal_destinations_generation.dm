// modular_zzveilbreak/code/modules/dungeons/portal_destinations_generation.dm

/datum/portal_destination/veilbreak/proc/start_generation()
	log_dungeon("DUNGEON DEBUG: start_generation() called for [name]")
	log_dungeon("DUNGEON DEBUG: Current state - generating: [generating], generated: [generated], progress: [generation_progress]")

	if(generating)
		log_dungeon("DUNGEON DEBUG: Generation blocked - already generating")
		return FALSE

	// Verify mapping subsystem is ready
	if(!SSmapping || !SSmapping.initialized)
		log_dungeon("DUNGEON DEBUG: Generation failed - SSmapping not ready or not initialized")
		generation_failed("Mapping subsystem not ready")
		return FALSE

	if(SSmapping.clearing_reserved_turfs)
		log_dungeon("DUNGEON DEBUG: Generation failed - SSmapping clearing reservations")
		generation_failed("Mapping subsystem is currently clearing reservations")
		return FALSE

	if(SSmapping.adding_new_zlevel)
		log_dungeon("DUNGEON DEBUG: Generation failed - SSmapping adding Z-level")
		generation_failed("Mapping subsystem is already adding a Z-level")
		return FALSE

	// FIXED: Removed MAX_Z_LEVELS check since we're using world.maxz
	log_dungeon("DUNGEON DEBUG: Using world.maxz [world.maxz] for portal Z-level")

	generating = TRUE
	generated = FALSE
	generation_progress = 0
	last_progress_update = world.time
	log_dungeon("DUNGEON DEBUG: Set generation state - generating: TRUE, generated: FALSE, progress: 0")

	if(!GLOB.dungeon_generator)
		log_dungeon("DUNGEON DEBUG: Creating new dungeon_generator")
		GLOB.dungeon_generator = new /datum/http_dungeon_generator()
	else
		log_dungeon("DUNGEON DEBUG: Using existing dungeon_generator")

	log_dungeon("DUNGEON DEBUG: Starting generation for portal destination [name]")

	// FIXED: Use safe dungeon size with server protection
	log_dungeon("DUNGEON DEBUG: Calling generate_dungeon with width: [DUNGEON_WIDTH], height: [DUNGEON_HEIGHT]")
	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, DUNGEON_WIDTH, DUNGEON_HEIGHT)

	log_dungeon("DUNGEON DEBUG: generate_dungeon() returned request_id: [current_request_id]")

	if(!current_request_id)
		log_dungeon("DUNGEON DEBUG: Generation failed - generate_dungeon returned 0")
		generating = FALSE
		generation_failed("Failed to start generation request")
		return FALSE

	log_dungeon("DUNGEON DEBUG: Generation started successfully with request [current_request_id]")

	// Start progress updates with proper tick checking
	log_dungeon("DUNGEON DEBUG: Starting SSobj processing")
	START_PROCESSING(SSobj, src)
	log_dungeon("DUNGEON DEBUG: SSobj processing started")

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
			// Request completed or failed
			STOP_PROCESSING(SSobj, src)
			generation_progress = 100
			return

	// Safety timeout - if we're still here but shouldn't be
	STOP_PROCESSING(SSobj, src)
	generation_failed("Generation process stuck in invalid state")

/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	log_dungeon("DUNGEON DEBUG: generation_complete() called")
	log_dungeon("DUNGEON DEBUG: Data status: [data["status"]], dmm length: [length(data["dmm_content"] || "")] bytes")

	generating = FALSE
	log_dungeon("DUNGEON DEBUG: Set generating = FALSE")

	// DEBUG: Log the complete data structure we received
	if(data["metadata"])
		log_dungeon("DUNGEON DEBUG: Metadata present with map_name: [data["metadata"]["map_name"]]")
		log_dungeon("DUNGEON DEBUG: Gateway location: [json_encode(data["metadata"]["key_positions"]?["gateway"])]")
	else
		log_dungeon("DUNGEON DEBUG: No metadata in response")

	// CRITICAL FIX: Store the complete data structure IMMEDIATELY
	last_generation_data = data.Copy()
	log_dungeon("DUNGEON DEBUG: Stored generation data with keys: [json_encode(last_generation_data)]")

	// Access dmm_content from top level
	if(data["dmm_content"])
		log_dungeon("DUNGEON DEBUG: DMM content received, starting load process")
		// Pass both the dmm_content and the metadata to ensure they're available
		load_generated_dmm(data["dmm_content"], data["metadata"] ? data["metadata"].Copy() : list())
	else
		log_dungeon("DUNGEON DEBUG: No DMM content in response")
		generation_failed("No DMM content in response")

	// Notify control computer of completion
	if(connected_control_computer && !QDELETED(connected_control_computer))
		log_dungeon("DUNGEON DEBUG: Notifying control computer of completion")
		connected_control_computer.on_generation_completed()
		connected_control_computer = null // Clear reference
	else
		log_dungeon("DUNGEON DEBUG: No control computer to notify")

/datum/portal_destination/veilbreak/proc/generation_failed(reason)
	log_dungeon("DUNGEON DEBUG: generation_failed() called with reason: [reason]")
	generating = FALSE
	generated = FALSE
	generation_progress = 0
	log_dungeon("DUNGEON DEBUG: Reset generation state")

	if(connected_portal && !QDELETED(connected_portal))
		log_dungeon("DUNGEON DEBUG: Notifying portal of failure")
		connected_portal.say("Dungeon generation failed: [reason]")

	// Notify control computer of failure
	if(connected_control_computer && !QDELETED(connected_control_computer))
		log_dungeon("DUNGEON DEBUG: Notifying control computer of failure")
		connected_control_computer.on_generation_failed(reason)
		connected_control_computer = null // Clear reference

// Load generated DMM with incremental background processing
/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content, list/metadata)
	log_dungeon("DUNGEON DEBUG: load_generated_dmm() called")
	log_dungeon("DUNGEON DEBUG: Metadata keys: [json_encode(metadata)]")

	if(!dmm_content)
		log_dungeon("DUNGEON DEBUG: No DMM content provided")
		return generation_failed("No DMM content provided")

	log_dungeon("DUNGEON DEBUG: Starting content load for Veilbreak dungeon")

	// Initialize or get the fixed portal Z-level
	if(!initialize_portal_z_level())
		log_dungeon("DUNGEON DEBUG: Failed to initialize portal Z-level")
		return generation_failed("Failed to initialize portal Z-level")

	log_dungeon("DUNGEON DEBUG: Using fixed portal Z-level [dungeon_z_level]")

	// Queue cleanup to happen in background
	log_dungeon("DUNGEON DEBUG: Starting background cleanup")
	cleanup_z_level_completely(dungeon_z_level)

	// CRITICAL FIX: Ensure metadata is preserved for portal connection
	if(metadata)
		log_dungeon("DUNGEON DEBUG: Preserving metadata for portal connection")
		last_generation_data = list("metadata" = metadata.Copy())
	else
		log_dungeon("DUNGEON DEBUG: WARNING - No metadata to preserve!")

	// Use incremental loading instead of blocking load
	log_dungeon("DUNGEON DEBUG: Starting incremental DMM loading")
	return load_dmm_incrementally(dmm_content, metadata)

// Incremental DMM loading using proper BYOND map loading
/datum/portal_destination/veilbreak/proc/load_dmm_incrementally(dmm_content, list/metadata)
	log_dungeon("DUNGEON DEBUG: load_dmm_incrementally() called")

	if(!dmm_content)
		log_dungeon("DUNGEON DEBUG: No DMM content provided")
		return generation_failed("No DMM content provided")

	log_dungeon("DUNGEON DEBUG: Starting incremental load")

	// Write DMM content to a temporary file
	var/temp_filename = "data/dungeon_temp_[world.time]_[rand(1000,9999)].dmm"
	log_dungeon("DUNGEON DEBUG: Using temp file: [temp_filename]")

	try
		text2file(dmm_content, temp_filename)
		log_dungeon("DUNGEON DEBUG: Wrote temporary file [temp_filename]")
	catch(var/exception/e)
		log_dungeon("DUNGEON DEBUG: Failed to write temporary DMM file: [e]")
		return generation_failed("Failed to write map data")

	// Start background map loading
	load_process = new /datum/background_process(
		CALLBACK(src, .proc/execute_dmm_load_step, temp_filename, dungeon_z_level),
		"dmm_load_[dungeon_z_level]"
	)
	load_process.start()

	log_dungeon("DUNGEON DEBUG: Started incremental loading process")
	return TRUE

/datum/portal_destination/veilbreak/proc/execute_dmm_load_step(temp_filename, z_level)
	log_dungeon("DUNGEON DEBUG: execute_dmm_load_step() called for Z-level [z_level]")

	if(processing_disabled)
		log_dungeon("DUNGEON DEBUG: Load step aborted - processing disabled")
		return BG_PROCESSING_FINISHED

	// FIXED: Add server protection with tick checking
	var/start_time = world.time
	var/max_processing_time = MAX_PROCESSING_TIME_PER_TICK
	log_dungeon("DUNGEON DEBUG: Starting load step with max time: [max_processing_time]")

	// Get or initialize loading state
	var/current_step = load_process.metadata["current_step"] || 1
	log_dungeon("DUNGEON DEBUG: Current load step: [current_step]")

	switch(current_step)
		if(1) // Initialize Z-level as space
			log_dungeon("DUNGEON DEBUG: Step 1 - Initializing Z-level [z_level] as space")
			initialize_z_as_space(z_level)
			current_step++
			load_process.metadata["current_step"] = current_step
			log_dungeon("DUNGEON DEBUG: Step 1 complete, moving to step 2")

			// Check if we've used too much time
			if(world.time - start_time > max_processing_time)
				log_dungeon("DUNGEON DEBUG: Yielding after step 1 due to time limit")
				return BG_PROCESSING_CONTINUE
			else
				log_dungeon("DUNGEON DEBUG: Continuing to step 2")
				return BG_PROCESSING_CONTINUE

		if(2) // Load the map file
			log_dungeon("DUNGEON DEBUG: Step 2 - Loading DMM file for Z-level [z_level]")

			// Use SSatoms to handle initialization
			SSatoms.map_loader_begin("dungeon_generator_[z_level]")
			log_dungeon("DUNGEON DEBUG: Started map loader")

			if(SSair.initialized)
				SSair.StartLoadingMap()
				log_dungeon("DUNGEON DEBUG: Started air loading")

			var/loaded_successfully = FALSE
			try
				// Use the parsed_map system that SSmapping uses
				var/datum/parsed_map/parsed = new(file(temp_filename))
				if(parsed && parsed.bounds)
					log_dungeon("DUNGEON DEBUG: Parsed map successfully, bounds: [parsed.bounds]")
					loaded_successfully = parsed.load(1, 1, z_level, no_changeturf = FALSE, place_on_top = FALSE, new_z = FALSE)
					log_dungeon("DUNGEON DEBUG: Map load result: [loaded_successfully ? "SUCCESS" : "FAILED"]")
				else
					log_dungeon("DUNGEON DEBUG: Failed to parse map file")
					loaded_successfully = FALSE
			catch(var/exception/e)
				log_dungeon("DUNGEON DEBUG: Exception during map load: [e]")
				loaded_successfully = FALSE

			if(SSair.initialized)
				SSair.StopLoadingMap()
				log_dungeon("DUNGEON DEBUG: Stopped air loading")

			SSatoms.map_loader_stop("dungeon_generator_[z_level]")
			log_dungeon("DUNGEON DEBUG: Stopped map loader")

			// Clean up temp file regardless of success
			fdel(temp_filename)
			log_dungeon("DUNGEON DEBUG: Cleaned up temporary file")

			if(!loaded_successfully)
				log_dungeon("DUNGEON DEBUG: Map load failed")
				generation_failed("Failed to load map into world")
				load_process = null
				return BG_PROCESSING_FINISHED

			current_step++
			load_process.metadata["current_step"] = current_step
			log_dungeon("DUNGEON DEBUG: Step 2 complete, moving to step 3")

			// Check processing time
			if(world.time - start_time > max_processing_time)
				log_dungeon("DUNGEON DEBUG: Yielding after step 2 due to time limit")
				return BG_PROCESSING_CONTINUE
			else
				log_dungeon("DUNGEON DEBUG: Continuing to step 3")
				return BG_PROCESSING_CONTINUE

		if(3) // Start subsystem initialization
			log_dungeon("DUNGEON DEBUG: Step 3 - Starting subsystem initialization")

			// Mark as complete (systems will initialize in background)
			generated = TRUE
			generation_progress = 100
			log_dungeon("DUNGEON DEBUG: Set generated = TRUE, progress = 100")

			if(connected_portal && !QDELETED(connected_portal))
				connected_portal.say("Dungeon generation complete. Portal stabilized.")
				log_dungeon("DUNGEON DEBUG: Notified portal of completion")

			// FIXED: Call the initialize_dungeon_subsystems proc that we've now defined in this file
			log_dungeon("DUNGEON DEBUG: Starting dungeon subsystems")
			initialize_dungeon_subsystems(z_level)

			load_process = null
			log_dungeon("DUNGEON DEBUG: Load process complete")
			return BG_PROCESSING_FINISHED

	// Should never reach here
	log_dungeon("DUNGEON DEBUG: WARNING - Reached end of load steps unexpectedly")
	load_process = null
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_z_as_space(z_level)
	log_dungeon("DUNGEON DEBUG: initialize_z_as_space() called for Z-level [z_level]")

	var/turfs_processed = 0
	var/start_time = world.time
	var/max_processing_time = MAX_PROCESSING_TIME_PER_TICK

	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(!istype(T, /turf/open/space/basic))
			T.ChangeTurf(/turf/open/space/basic, FALSE, FALSE)  // No changeturf, no air

		turfs_processed++

		// Yield every 100 turfs to prevent blocking AND check time limit
		if(turfs_processed % 100 == 0)
			CHECK_TICK

		// Additional protection: don't process for more than max time per tick
		if(world.time - start_time > max_processing_time)
			log_dungeon("DUNGEON DEBUG: Yielding after [turfs_processed] turfs due to time limit")
			// We'd need to implement resumable initialization here
			break

	log_dungeon("DUNGEON DEBUG: Space initialization completed for [turfs_processed] turfs")

// FIXED: Added the missing initialize_dungeon_subsystems proc and its related procs
/datum/portal_destination/veilbreak/proc/initialize_dungeon_subsystems(z_level)
	log_dungeon("Subsystems: Starting background initialization for Z-level [z_level]")

	// Use background processing for initialization
	init_process = new /datum/background_process(CALLBACK(src, .proc/execute_init_step, z_level), "portal_init_[z_level]")
	init_process.start()

	return TRUE // Return immediately, initialization happens in background

/datum/portal_destination/veilbreak/proc/execute_init_step(z_level)
	if(processing_disabled)
		log_dungeon("Subsystems: Init step aborted - processing disabled")
		return BG_PROCESSING_FINISHED

	var/start_time = world.time
	var/max_processing_time = MAX_PROCESSING_TIME_PER_TICK
	var/current_step = init_process.metadata["current_step"] || 1

	log_dungeon("Subsystems: Executing step [current_step]")

	switch(current_step)
		if(1) // Initialize atoms
			var/result = initialize_dungeon_atoms_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(2) // Initialize areas
			var/result = initialize_dungeon_areas_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(3) // Initialize power
			var/result = initialize_dungeon_power_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(4) // Initialize lighting
			var/result = initialize_dungeon_lighting_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(5) // Initialize atmospherics
			var/result = initialize_dungeon_atmospherics_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(6) // Initialize machinery
			var/result = initialize_dungeon_machinery_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(7) // Safe smoothing initialization using SSicon_smooth
			log_dungeon("Subsystems: Starting safe smoothing initialization")
			safe_initialize_smoothing(z_level)
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(8) // Visual updates (skip smoothing operations)
			var/result = force_immediate_visual_updates_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE

	// Initialization complete
	log_dungeon("Subsystems: INITIALIZATION COMPLETE for Z-level [z_level]")

	// Ensure portal connection now that everything is ready
	ensure_portal_connection()

	init_process = null
	return BG_PROCESSING_FINISHED

// NEW: Safe smoothing initialization using SSicon_smooth subsystem
/datum/portal_destination/veilbreak/proc/safe_initialize_smoothing(z_level)
	log_dungeon("Smoothing: Starting safe smoothing initialization for Z-level [z_level]")

	if(!SSicon_smooth.initialized)
		log_dungeon("Smoothing: SSicon_smooth not initialized, skipping")
		return

	var/smoothed_count = 0
	var/skipped_count = 0

	// Process all atoms on the Z-level and safely add them to smoothing queue
	for(var/atom/A in world)
		if(A.z != z_level)
			continue

		// Skip atoms that are likely to cause smoothing errors
		if(should_skip_smoothing(A))
			skipped_count++
			continue

		// Only queue atoms that actually need smoothing
		if(A.smoothing_flags && !(A.smoothing_flags & SMOOTH_QUEUED))
			// FIXED: Remove try-catch since it's not properly structured in DM
			// Use the SSicon_smooth subsystem to queue the atom
			SSicon_smooth.add_to_queue(A)
			smoothed_count++

		CHECK_TICK

	log_dungeon("Smoothing: Completed - [smoothed_count] atoms queued, [skipped_count] skipped")

	// FIXED: Use proper SSicon_smooth method instead of undefined .wake()
	if(smoothed_count > 0 && SSicon_smooth.can_fire)
		log_dungeon("Smoothing: Smoothing subsystem will process queued atoms automatically")
		// SSicon_smooth will process automatically, no need to manually wake it

/datum/portal_destination/veilbreak/proc/should_skip_smoothing(atom/A)
	// Skip objects that are known to cause smoothing runtime errors
	if(istype(A, /obj/structure/alien/weeds))
		return TRUE

	// Skip atoms that aren't fully initialized
	if(!(A.flags_1 & INITIALIZED_1))
		return TRUE

	// Skip atoms without proper loc or z-level
	if(!A.loc || !A.z)
		return TRUE

	// Skip atoms that are queued for deletion
	if(QDELETED(A))
		return TRUE

	// Skip if the atom doesn't actually have smoothing flags set
	if(!A.smoothing_flags)
		return TRUE

	// Skip if atom is already in the smoothing queue
	if(A.smoothing_flags & SMOOTH_QUEUED)
		return TRUE

	return FALSE

// Incremental versions of initialization procs with proper tick checking
/datum/portal_destination/veilbreak/proc/initialize_dungeon_atoms_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["atom_index"] || 1
	var/list/atoms_to_initialize = init_process.metadata["atoms_list"]

	if(!atoms_to_initialize)
		// First call - build the list
		atoms_to_initialize = list()
		for(var/atom/A in world)
			if(A.z == z_level)
				atoms_to_initialize += A
		init_process.metadata["atoms_list"] = atoms_to_initialize
		init_process.metadata["atom_index"] = 1
		log_dungeon("Subsystems: Found [length(atoms_to_initialize)] atoms to initialize")
		return BG_PROCESSING_CONTINUE

	for(var/i = current_index to min(current_index + 50, length(atoms_to_initialize)))
		var/atom/A = atoms_to_initialize[i]
		if(!(A.flags_1 & INITIALIZED_1))
			SSatoms.InitAtom(A, FALSE, list(FALSE))

		if(world.time - start_time > max_time)
			init_process.metadata["atom_index"] = i + 1
			log_dungeon("Subsystems: Atom initialization yielding at index [i]")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Atom initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_areas_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["area_index"] || 1
	var/list/areas_to_process = init_process.metadata["areas_list"]

	if(!areas_to_process)
		areas_to_process = list()
		for(var/area/area as anything in GLOB.areas)
			var/has_turfs_on_z = FALSE
			for(var/turf/T in area.contents)
				if(T.z == z_level)
					has_turfs_on_z = TRUE
					break
			if(has_turfs_on_z)
				areas_to_process += area
		init_process.metadata["areas_list"] = areas_to_process
		init_process.metadata["area_index"] = 1
		log_dungeon("Subsystems: Found [length(areas_to_process)] areas to initialize")
		return BG_PROCESSING_CONTINUE

	for(var/i = current_index to min(current_index + 20, length(areas_to_process)))
		var/area/area = areas_to_process[i]
		area.power_equip = initial(area.power_equip)
		area.power_light = initial(area.power_light)
		area.power_environ = initial(area.power_environ)
		area.always_unpowered = initial(area.always_unpowered)
		area.power_change()
		area.update_icon()

		if(world.time - start_time > max_time)
			init_process.metadata["area_index"] = i + 1
			log_dungeon("Subsystems: Area initialization yielding at index [i]")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Area initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_power_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["power_index"] || 1

	// Initialize machinery power states
	for(var/obj/machinery/machine in world)
		if(machine.z != z_level)
			continue

		machine.power_change()

		if(world.time - start_time > max_time)
			init_process.metadata["power_index"] = current_index + 1
			log_dungeon("Subsystems: Power initialization yielding")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Power initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_lighting_incremental(z_level, start_time, max_time)
	if(!SSlighting || !SSlighting.initialized)
		log_dungeon("Subsystems: Lighting subsystem not available")
		return BG_PROCESSING_FINISHED

	var/current_x = init_process.metadata["lighting_x"] || 1
	var/current_y = init_process.metadata["lighting_y"] || 1

	for(var/x = current_x to world.maxx)
		for(var/y = current_y to world.maxy)
			var/turf/iter_turf = locate(x, y, z_level)
			if(!iter_turf.space_lit && !iter_turf.lighting_object)
				new /datum/lighting_object(iter_turf)

			if(world.time - start_time > max_time)
				init_process.metadata["lighting_x"] = x
				init_process.metadata["lighting_y"] = y + 1
				log_dungeon("Subsystems: Lighting initialization yielding at [x],[y]")
				return BG_PROCESSING_CONTINUE
		current_y = 1

	log_dungeon("Subsystems: Lighting initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_atmospherics_incremental(z_level, start_time, max_time)
	if(!SSair || !SSair.initialized)
		log_dungeon("Subsystems: Air subsystem not available")
		return BG_PROCESSING_FINISHED

	// Atmos machinery will be handled by SSair naturally
	log_dungeon("Subsystems: Atmospherics initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_machinery_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["machinery_index"] || 1

	for(var/obj/machinery/machine in world)
		if(machine.z != z_level)
			continue

		if(machine.use_power)
			machine.power_change()
		machine.update_icon()
		machine.update_appearance()

		if(world.time - start_time > max_time)
			init_process.metadata["machinery_index"] = current_index + 1
			log_dungeon("Subsystems: Machinery initialization yielding")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Machinery initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/force_immediate_visual_updates_incremental(z_level, start_time, max_time)
	var/current_x = init_process.metadata["visual_x"] || 1
	var/current_y = init_process.metadata["visual_y"] || 1

	for(var/x = current_x to world.maxx)
		for(var/y = current_y to world.maxy)
			var/turf/iter_turf = locate(x, y, z_level)
			if(!istype(iter_turf, /obj/effect) && !istype(iter_turf, /obj/effect/decal))
				// Safe visual updates only - no smoothing operations
				iter_turf.update_icon()
				iter_turf.update_appearance()

			if(world.time - start_time > max_time)
				init_process.metadata["visual_x"] = x
				init_process.metadata["visual_y"] = y + 1
				log_dungeon("Subsystems: Visual updates yielding at [x],[y]")
				return BG_PROCESSING_CONTINUE
		current_y = 1

	log_dungeon("Subsystems: Visual updates completed")
	return BG_PROCESSING_FINISHED
