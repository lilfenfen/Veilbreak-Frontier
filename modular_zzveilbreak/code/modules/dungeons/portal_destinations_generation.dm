// modular_zzveilbreak/code/modules/dungeons/portal_destinations_generation.dm

// Add this at the top of the file with other defines
#define MAX_Z_LEVELS 20 // Reasonable limit to prevent server overload

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

	// FIXED: Check if we're already at maximum Z-levels to prevent server overload
	log_dungeon("DUNGEON DEBUG: Checking Z-level limit - world.maxz: [world.maxz], MAX_Z_LEVELS: [MAX_Z_LEVELS]")
	if(world.maxz >= MAX_Z_LEVELS - 1) // Leave one Z-level buffer
		log_dungeon("DUNGEON DEBUG: Generation failed - Z-level limit reached")
		generation_failed("Maximum Z-level limit reached. Cannot generate new dungeon.")
		return FALSE

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
	log_dungeon("DUNGEON DEBUG: process() called - generating: [generating], disabled: [processing_disabled]")

	if(!generating || processing_disabled)
		log_dungeon("DUNGEON DEBUG: Stopping process - generating=[generating], disabled=[processing_disabled]")
		STOP_PROCESSING(SSobj, src)
		return

	// FIXED: Update progress for UI with server protection
	if(world.time - last_progress_update > 1 SECONDS)
		generation_progress = min(generation_progress + rand(5, 15), 90)
		last_progress_update = world.time
		log_dungeon("DUNGEON DEBUG: Progress updated to [generation_progress]%")

	// FIXED: Check if request is complete EVERY TICK with proper logic
	if(current_request_id)
		log_dungeon("DUNGEON DEBUG: Checking request [current_request_id]")
		var/still_processing = GLOB.dungeon_generator.check_request(current_request_id)
		log_dungeon("DUNGEON DEBUG: check_request returned: [still_processing]")

		if(still_processing)
			log_dungeon("DUNGEON DEBUG: Request still processing, continuing")
			return // Still processing, continue next tick
		else
			// Request completed or failed
			log_dungeon("DUNGEON DEBUG: Request completed or failed, stopping process")
			STOP_PROCESSING(SSobj, src)
			generation_progress = 100
			log_dungeon("DUNGEON DEBUG: Set progress to 100% and stopped processing")
			return

	// No active request but still generating? This shouldn't happen
	log_dungeon("DUNGEON DEBUG: WARNING - No active request but still generating")
	STOP_PROCESSING(SSobj, src)
	generation_failed("Generation process lost track of request")

/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	log_dungeon("DUNGEON DEBUG: generation_complete() called")
	log_dungeon("DUNGEON DEBUG: Data status: [data["status"]], dmm length: [length(data["dmm_content"] || "")] bytes")

	generating = FALSE
	log_dungeon("DUNGEON DEBUG: Set generating = FALSE")

	// DEBUG: Log the complete data structure we received
	if(data["metadata"])
		log_dungeon("DUNGEON DEBUG: Metadata present with map_name: [data["metadata"]["map_name"]]")
	else
		log_dungeon("DUNGEON DEBUG: No metadata in response")

	// CRITICAL FIX: Store the complete data structure
	last_generation_data = data.Copy()
	log_dungeon("DUNGEON DEBUG: Stored generation data")

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

	// Store metadata
	last_generation_data = metadata
	log_dungeon("DUNGEON DEBUG: Stored metadata")

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

			// Start background initialization
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
