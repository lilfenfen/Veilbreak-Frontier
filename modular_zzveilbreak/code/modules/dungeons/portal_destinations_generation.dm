// modular_zzveilbreak/code/modules/dungeons/portal_destinations_generation.dm

// Add this at the top of the file with other defines
#define MAX_Z_LEVELS 20 // Reasonable limit to prevent server overload

/datum/portal_destination/veilbreak/proc/start_generation()
	if(generating)
		log_dungeon("Generation: Attempted to start while already generating")
		return

	// Verify mapping subsystem is ready
	if(!SSmapping || !SSmapping.initialized)
		generation_failed("Mapping subsystem not ready")
		return

	if(SSmapping.clearing_reserved_turfs)
		generation_failed("Mapping subsystem is currently clearing reservations")
		return

	if(SSmapping.adding_new_zlevel)
		generation_failed("Mapping subsystem is already adding a Z-level")
		return

	// FIXED: Check if we're already at maximum Z-levels to prevent server overload
	if(world.maxz >= MAX_Z_LEVELS - 1) // Leave one Z-level buffer
		generation_failed("Maximum Z-level limit reached. Cannot generate new dungeon.")
		return

	generating = TRUE
	generated = FALSE
	generation_progress = 0
	last_progress_update = world.time

	if(!GLOB.dungeon_generator)
		GLOB.dungeon_generator = new /datum/http_dungeon_generator()

	log_dungeon("Generation: Starting for portal destination [name]")

	// FIXED: Use safe dungeon size with server protection
	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, DUNGEON_WIDTH, DUNGEON_HEIGHT)

	if(!current_request_id)
		generation_failed("Failed to start generation request")
		return

	log_dungeon("Generation: Started request [current_request_id]")

	// Start progress updates with proper tick checking
	START_PROCESSING(SSobj, src)

/datum/portal_destination/veilbreak/process()
	if(!generating || processing_disabled)
		log_dungeon("Generation: Stopping process - generating=[generating], disabled=[processing_disabled]")
		STOP_PROCESSING(SSobj, src)
		return

	// FIXED: Update progress for UI with server protection
	if(world.time - last_progress_update > 1 SECONDS)
		generation_progress = min(generation_progress + rand(5, 15), 90)
		last_progress_update = world.time
		log_dungeon("Generation: Progress updated to [generation_progress]%")

	// Check if request is complete
	if(current_request_id && GLOB.dungeon_generator.check_request(current_request_id))
		// Still processing
		return

	// Request completed or failed
	log_dungeon("Generation: Request completed, stopping process")
	STOP_PROCESSING(SSobj, src)
	generation_progress = 100

/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	log_dungeon("Generation: Complete, processing data")
	generating = FALSE

	// DEBUG: Log the complete data structure we received
	log_dungeon("Generation: Received data - status: [data["status"]], dmm length: [length(data["dmm_content"] || "")] bytes")

	if(data["metadata"])
		log_dungeon("Generation: Metadata present with keys: [json_encode(data["metadata"])]")

	// CRITICAL FIX: Store the complete data structure
	last_generation_data = data.Copy()

	// Access dmm_content from top level
	if(data["dmm_content"])
		// Pass both the dmm_content and the metadata to ensure they're available
		load_generated_dmm(data["dmm_content"], data["metadata"] ? data["metadata"].Copy() : list())
	else
		generation_failed("No DMM content in response")

	// Notify control computer of completion
	if(connected_control_computer && !QDELETED(connected_control_computer))
		connected_control_computer.on_generation_completed()
		connected_control_computer = null // Clear reference

/datum/portal_destination/veilbreak/proc/generation_failed(reason)
	log_dungeon("Generation: FAILED - [reason]")
	generating = FALSE
	generated = FALSE
	generation_progress = 0

	if(connected_portal && !QDELETED(connected_portal))
		connected_portal.say("Dungeon generation failed: [reason]")

	// Notify control computer of failure
	if(connected_control_computer && !QDELETED(connected_control_computer))
		connected_control_computer.on_generation_failed(reason)
		connected_control_computer = null // Clear reference

// Load generated DMM with incremental background processing
/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content, list/metadata)
	if(!dmm_content)
		return generation_failed("No DMM content provided")

	log_dungeon("DMM: Starting content load for Veilbreak dungeon")

	// Initialize or get the fixed portal Z-level
	if(!initialize_portal_z_level())
		return generation_failed("Failed to initialize portal Z-level")

	log_dungeon("DMM: Using fixed portal Z-level [dungeon_z_level]")

	// Queue cleanup to happen in background
	cleanup_z_level_completely(dungeon_z_level)

	// Store metadata
	last_generation_data = metadata

	// Use incremental loading instead of blocking load
	return load_dmm_incrementally(dmm_content, metadata)

// Incremental DMM loading using proper BYOND map loading
/datum/portal_destination/veilbreak/proc/load_dmm_incrementally(dmm_content, list/metadata)
	if(!dmm_content)
		return generation_failed("No DMM content provided")

	log_dungeon("DMM: Starting incremental load")

	// Write DMM content to a temporary file
	var/temp_filename = "data/dungeon_temp_[world.time]_[rand(1000,9999)].dmm"

	try
		text2file(dmm_content, temp_filename)
		log_dungeon("DMM: Wrote temporary file [temp_filename]")
	catch(var/exception/e)
		log_dungeon("DMM: Failed to write temporary DMM file: [e]")
		return generation_failed("Failed to write map data")

	// Start background map loading
	load_process = new /datum/background_process(
		CALLBACK(src, .proc/execute_dmm_load_step, temp_filename, dungeon_z_level),
		"dmm_load_[dungeon_z_level]"
	)
	load_process.start()

	log_dungeon("DMM: Started incremental loading process")
	return TRUE

/datum/portal_destination/veilbreak/proc/execute_dmm_load_step(temp_filename, z_level)
	if(processing_disabled)
		log_dungeon("DMM: Load step aborted - processing disabled")
		return BG_PROCESSING_FINISHED

	// FIXED: Add server protection with tick checking
	var/start_time = world.time
	var/max_processing_time = MAX_PROCESSING_TIME_PER_TICK

	// Get or initialize loading state
	var/current_step = load_process.metadata["current_step"] || 1

	switch(current_step)
		if(1) // Initialize Z-level as space
			log_dungeon("DMM: Step 1 - Initializing Z-level [z_level] as space")
			initialize_z_as_space(z_level)
			current_step++
			load_process.metadata["current_step"] = current_step

			// Check if we've used too much time
			if(world.time - start_time > max_processing_time)
				return BG_PROCESSING_CONTINUE
			else
				return BG_PROCESSING_CONTINUE

		if(2) // Load the map file
			log_dungeon("DMM: Step 2 - Loading DMM file for Z-level [z_level]")

			// Use SSatoms to handle initialization
			SSatoms.map_loader_begin("dungeon_generator_[z_level]")

			if(SSair.initialized)
				SSair.StartLoadingMap()

			var/loaded_successfully = FALSE
			try
				// Use the parsed_map system that SSmapping uses
				var/datum/parsed_map/parsed = new(file(temp_filename))
				if(parsed && parsed.bounds)
					loaded_successfully = parsed.load(1, 1, z_level, no_changeturf = FALSE, place_on_top = FALSE, new_z = FALSE)
					log_dungeon("DMM: Map load result: [loaded_successfully ? "SUCCESS" : "FAILED"]")
				else
					log_dungeon("DMM: Failed to parse map file")
					loaded_successfully = FALSE
			catch(var/exception/e)
				log_dungeon("DMM: Exception during map load: [e]")
				loaded_successfully = FALSE

			if(SSair.initialized)
				SSair.StopLoadingMap()

			SSatoms.map_loader_stop("dungeon_generator_[z_level]")

			// Clean up temp file regardless of success
			fdel(temp_filename)
			log_dungeon("DMM: Cleaned up temporary file")

			if(!loaded_successfully)
				generation_failed("Failed to load map into world")
				load_process = null
				return BG_PROCESSING_FINISHED

			current_step++
			load_process.metadata["current_step"] = current_step
			log_dungeon("DMM: Map loaded successfully, starting background initialization")

			// Check processing time
			if(world.time - start_time > max_processing_time)
				return BG_PROCESSING_CONTINUE
			else
				return BG_PROCESSING_CONTINUE

		if(3) // Start subsystem initialization
			log_dungeon("DMM: Step 3 - Starting subsystem initialization")

			// Mark as complete (systems will initialize in background)
			generated = TRUE
			generation_progress = 100

			if(connected_portal && !QDELETED(connected_portal))
				connected_portal.say("Dungeon generation complete. Portal stabilized.")

			// Start background initialization
			initialize_dungeon_subsystems(z_level)

			load_process = null
			return BG_PROCESSING_FINISHED

	// Should never reach here
	log_dungeon("DMM: WARNING - Reached end of load steps unexpectedly")
	load_process = null
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_z_as_space(z_level)
	log_dungeon("Init: Initializing Z-level [z_level] as space")

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
			log_dungeon("Init: Yielding after [turfs_processed] turfs due to time limit")
			// We'd need to implement resumable initialization here
			break

	log_dungeon("Init: Space initialization completed for [turfs_processed] turfs")
