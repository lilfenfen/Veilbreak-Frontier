// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

// CORRECTED Forward declarations - only what we actually need
/datum/space_level
/datum/parsed_map

// Proc forward declarations
/proc/IS_LIST_OF_ATOMS(list/L)

// Global list for portal destinations (separate from gateways)
GLOBAL_LIST_EMPTY(portal_destinations)

// Fixed Z-level for all portal dungeons (will be set to world.maxz)
GLOBAL_VAR(portal_dungeon_z_level)

// Helper proc for dungeon generator logging that's compatible with our log_game
/proc/log_dungeon(text)
	log_game(text, list(), LOG_GAME)

// HTTP request manager for dungeon generation
/datum/http_dungeon_generator
	var/current_request_id = 0
	var/list/active_requests = list()

/datum/http_dungeon_generator/proc/generate_dungeon(datum/portal_destination/veilbreak/destination, width = 250, height = 250)
	// Check if RUSTG HTTP is available
	var/datum/http_request/test_request = new()
	if(!test_request)
		destination.generation_failed("HTTP system not available")
		return 0

	var/request_id = ++current_request_id
	active_requests["[request_id]"] = destination

	var/datum/http_request/request = new()
	var/url = "[DUNGEON_GENERATOR_URL][DUNGEON_GENERATE_ENDPOINT]?width=[width]&height=[height]&seed=[rand(1,1000000)]"

	log_dungeon("Dungeon Generator: Starting HTTP request to [url]")

	request.prepare(RUSTG_HTTP_METHOD_GET, url, "", "")
	request.begin_async()

	// Store the request data
	active_requests["[request_id]_req"] = request
	active_requests["[request_id]_time"] = world.time

	return request_id

/datum/http_dungeon_generator/proc/check_request(request_id)
	var/datum/portal_destination/veilbreak/destination = active_requests["[request_id]"]
	if(!destination)
		return FALSE

	var/datum/http_request/request = active_requests["[request_id]_req"]
	if(!request)
		active_requests -= "[request_id]"
		return FALSE

	if(!request.is_complete())
		// Check for timeout
		var/start_time = active_requests["[request_id]_time"]
		if(world.time - start_time > DUNGEON_GENERATOR_TIMEOUT)
			destination.generation_failed("Request timeout after [DUNGEON_GENERATOR_TIMEOUT/10] seconds")
			active_requests -= "[request_id]"
			active_requests -= "[request_id]_req"
			active_requests -= "[request_id]_time"
			return FALSE
		return TRUE // Still processing

	var/datum/http_response/response = request.into_response()

	if(response.errored || !response.body)
		destination.generation_failed("HTTP error: [response.error]")
	else
		var/list/data = json_decode(response.body)
		if(data && data["status"] == "success")
			destination.generation_complete(data)
		else
			destination.generation_failed(data?["message"] || "Unknown error from generator")

	// Cleanup
	active_requests -= "[request_id]"
	active_requests -= "[request_id]_req"
	active_requests -= "[request_id]_time"

	return FALSE

// Global instance
GLOBAL_DATUM_INIT(dungeon_generator, /datum/http_dungeon_generator, new)

// Base portal destination type
/datum/portal_destination
	var/name = "Unknown Destination"
	var/wait = 0
	var/enabled = TRUE
	var/hidden = FALSE
	var/obj/machinery/portal/connected_portal

/datum/portal_destination/proc/is_available()
	return enabled && (world.time - SSticker.round_start_time >= wait)

/datum/portal_destination/proc/get_available_reason()
	. = "Unreachable"
	if(world.time - SSticker.round_start_time < wait)
		. = "Connection desynchronized. Recalibration in progress."

/datum/portal_destination/proc/incoming_pass_check(atom/movable/AM)
	return TRUE

/datum/portal_destination/proc/get_target_turf()
	CRASH("get_target_turf not implemented for this destination type")

/datum/portal_destination/proc/post_transfer(atom/movable/AM)
	if(ismob(AM))
		var/mob/M = AM
		if(M.client)
			M.client.move_delay = max(world.time + 5, M.client.move_delay)

/datum/portal_destination/proc/activate(obj/machinery/portal/activated)
	log_dungeon("Portal Destination: [name] activated by portal at [AREACOORD(activated)]")
	return

/datum/portal_destination/proc/deactivate(obj/machinery/portal/deactivated)
	return

/datum/portal_destination/proc/get_ui_data()
	. = list()
	.["name"] = name
	.["description"] = "Dimensional portal destination"
	.["key"] = get_global_key()
	.["available"] = is_available()
	.["available_reason"] = get_available_reason()
	if(wait)
		.["timeout"] = max(1 - (wait - (world.time - SSticker.round_start_time)) / wait, 0)
	else
		.["timeout"] = 0
	.["connected"] = !!connected_portal

// Veilbreak-specific destination
/datum/portal_destination/veilbreak
	name = "Veilbreak Dungeon"
	var/generating = FALSE
	var/generated = FALSE
	var/dungeon_z_level = 0
	var/last_generation_data = null
	var/current_request_id = 0
	var/generation_progress = 0
	var/last_progress_update = 0
	/// Reference to the control computer for callbacks
	var/obj/machinery/computer/portal_control/connected_control_computer
	/// Background processing for heavy operations
	var/datum/background_process/cleanup_process
	var/datum/background_process/init_process
	var/datum/background_process/load_process

/datum/portal_destination/veilbreak/is_available()
	return ..() && generated && !generating

/datum/portal_destination/veilbreak/get_available_reason()
	if(generating)
		return "Dungeon generation in progress... [generation_progress]%"
	if(!generated)
		return "No dungeon generated yet"
	return ..()

/datum/portal_destination/veilbreak/get_target_turf()
	if(!dungeon_z_level)
		return null

	// Just find any portal on the Z-level and use its location
	var/obj/machinery/portal/any_portal = scan_for_existing_portal()
	if(any_portal)
		log_dungeon("Dungeon Generator: Using portal at [AREACOORD(any_portal)] as target")
		return get_turf(any_portal)

	// Fallback to center if no portal found (shouldn't happen with our new system)
	log_dungeon("Dungeon Generator: No portal found, using center as fallback")
	return locate(round(world.maxx/2), round(world.maxy/2), dungeon_z_level)

/datum/portal_destination/veilbreak/proc/start_generation()
	if(generating)
		log_dungeon("Dungeon Generator: Attempted to start generation while already generating")
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

	generating = TRUE
	generated = FALSE
	generation_progress = 0
	last_progress_update = world.time

	if(!GLOB.dungeon_generator)
		GLOB.dungeon_generator = new /datum/http_dungeon_generator()

	log_dungeon("Dungeon Generator: Starting generation for portal destination [name]")
	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, 50, 50) // Reduced size for safety

	if(!current_request_id)
		generation_failed("Failed to start generation request")
		return

	log_dungeon("Dungeon Generator: Started generation request [current_request_id]")

	// Start progress updates
	START_PROCESSING(SSobj, src)

/datum/portal_destination/veilbreak/process()
	if(!generating)
		STOP_PROCESSING(SSobj, src)
		return

	// Update progress for UI
	if(world.time - last_progress_update > 1 SECONDS)
		generation_progress = min(generation_progress + rand(5, 15), 90)
		last_progress_update = world.time

	// Check if request is complete
	if(current_request_id && GLOB.dungeon_generator.check_request(current_request_id))
		// Still processing
		return

	// Request completed or failed
	STOP_PROCESSING(SSobj, src)
	generation_progress = 100

/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	generating = FALSE

	// DEBUG: Log the complete data structure we received
	log_dungeon("Dungeon Generator: Received complete data structure")
	log_dungeon("Dungeon Generator: Status: [data["status"]]")
	log_dungeon("Dungeon Generator: DMM content length: [length(data["dmm_content"] || "")] bytes")
	log_dungeon("Dungeon Generator: Metadata present: [data["metadata"] ? "YES" : "NO"]")

	if(data["metadata"])
		log_dungeon("Dungeon Generator: Metadata keys: [json_encode(data["metadata"])]")
		if(data["metadata"]["key_positions"])
			log_dungeon("Dungeon Generator: Key positions found: [json_encode(data["metadata"]["key_positions"])]")
			if(data["metadata"]["key_positions"]["gateway"])
				log_dungeon("Dungeon Generator: Gateway position: [json_encode(data["metadata"]["key_positions"]["gateway"])]")

	// CRITICAL FIX: Store the complete data structure
	last_generation_data = data.Copy()

	// Double-check storage worked
	log_dungeon("Dungeon Generator: Stored data verification - metadata: [last_generation_data["metadata"] ? "PRESENT" : "MISSING"]")
	if(last_generation_data["metadata"] && last_generation_data["metadata"]["key_positions"])
		log_dungeon("Dungeon Generator: Stored key positions: [json_encode(last_generation_data["metadata"]["key_positions"])]")

	// Access dmm_content from top level
	if(data["dmm_content"])
		// Pass both the dmm_content and the metadata to ensure they're available
		load_generated_dmm(data["dmm_content"], data["metadata"] ? data["metadata"].Copy() : list())
	else
		generation_failed("No DMM content in response")

	// NEW: Notify control computer of completion
	if(connected_control_computer)
		connected_control_computer.on_generation_completed()
		connected_control_computer = null // Clear reference

/datum/portal_destination/veilbreak/proc/generation_failed(reason)
	generating = FALSE
	generated = FALSE
	generation_progress = 0

	log_dungeon("Dungeon Generator: Generation failed - [reason]")

	if(connected_portal)
		connected_portal.say("Dungeon generation failed: [reason]")

	// NEW: Notify control computer of failure
	if(connected_control_computer)
		connected_control_computer.on_generation_failed(reason)
		connected_control_computer = null // Clear reference

// NEW: Initialize the fixed portal Z-level on first use
/datum/portal_destination/veilbreak/proc/initialize_portal_z_level()
	if(GLOB.portal_dungeon_z_level)
		dungeon_z_level = GLOB.portal_dungeon_z_level
		return TRUE

	// Use the highest existing Z-level
	if(world.maxz > 0)
		GLOB.portal_dungeon_z_level = world.maxz
		dungeon_z_level = GLOB.portal_dungeon_z_level
		log_dungeon("Dungeon Generator: Using existing Z-level [dungeon_z_level] for portal dungeons")
		return TRUE

	log_dungeon("Dungeon Generator: ERROR - No Z-levels available for portal dungeons")
	return FALSE

// MODIFIED: Load generated DMM with incremental background processing
/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content, list/metadata)
	if(!dmm_content)
		return generation_failed("No DMM content provided")

	log_dungeon("Dungeon Generator: Starting DMM content load for Veilbreak dungeon")

	// Initialize or get the fixed portal Z-level
	if(!initialize_portal_z_level())
		return generation_failed("Failed to initialize portal Z-level")

	log_dungeon("Dungeon Generator: Using fixed portal Z-level [dungeon_z_level]")

	// Queue cleanup to happen in background
	cleanup_z_level_completely(dungeon_z_level)

	// Store metadata
	last_generation_data = metadata

	// Use incremental loading instead of blocking load
	return load_dmm_incrementally(dmm_content, metadata)

// NEW: Incremental DMM loading using proper BYOND map loading
/datum/portal_destination/veilbreak/proc/load_dmm_incrementally(dmm_content, list/metadata)
	if(!dmm_content)
		return generation_failed("No DMM content provided")

	log_dungeon("Dungeon Generator: Starting INCREMENTAL DMM load")

	// Write DMM content to a temporary file
	var/temp_filename = "data/dungeon_temp_[world.time]_[rand(1000,9999)].dmm"

	try
		text2file(dmm_content, temp_filename)
	catch(var/exception/e)
		log_dungeon("Dungeon Generator: Failed to write temporary DMM file: [e]")
		return generation_failed("Failed to write map data")

	// Start background map loading
	load_process = new /datum/background_process(
		CALLBACK(src, .proc/execute_dmm_load_step, temp_filename, dungeon_z_level),
		"dmm_load_[dungeon_z_level]"
	)
	load_process.start()

	log_dungeon("Dungeon Generator: Started incremental DMM loading process")
	return TRUE

/datum/portal_destination/veilbreak/proc/execute_dmm_load_step(temp_filename, z_level)
	// Get or initialize loading state
	var/current_step = load_process.metadata["current_step"] || 1

	switch(current_step)
		if(1) // Initialize Z-level as space
			log_dungeon("Dungeon Generator: Step 1 - Initializing Z-level [z_level] as space")
			initialize_z_as_space(z_level)
			current_step++
			load_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(2) // Load the map file
			log_dungeon("Dungeon Generator: Step 2 - Loading DMM file for Z-level [z_level]")

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
				else
					log_dungeon("Dungeon Generator: Failed to parse map file")
					loaded_successfully = FALSE
			catch(var/exception/e)
				log_dungeon("Dungeon Generator: Exception during map load: [e]")
				loaded_successfully = FALSE

			if(SSair.initialized)
				SSair.StopLoadingMap()

			SSatoms.map_loader_stop("dungeon_generator_[z_level]")

			// Clean up temp file regardless of success
			fdel(temp_filename)

			if(!loaded_successfully)
				generation_failed("Failed to load map into world")
				load_process = null
				return BG_PROCESSING_FINISHED

			current_step++
			load_process.metadata["current_step"] = current_step
			log_dungeon("Dungeon Generator: Map loaded successfully, starting background initialization")
			return BG_PROCESSING_CONTINUE

		if(3) // Start subsystem initialization
			log_dungeon("Dungeon Generator: Step 3 - Starting subsystem initialization")

			// Mark as complete (systems will initialize in background)
			generated = TRUE
			generation_progress = 100

			if(connected_portal)
				connected_portal.say("Dungeon generation complete. Portal stabilized.")

			// Start background initialization
			initialize_dungeon_subsystems(z_level)

			load_process = null
			return BG_PROCESSING_FINISHED

	// Should never reach here
	load_process = null
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_z_as_space(z_level)
	log_dungeon("Dungeon Generator: Initializing Z-level [z_level] as space")

	var/turfs_processed = 0

	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(!istype(T, /turf/open/space/basic))
			T.ChangeTurf(/turf/open/space/basic, FALSE, FALSE)  // No changeturf, no air

		turfs_processed++

		// Yield every 100 turfs to prevent blocking
		if(turfs_processed % 100 == 0)
			CHECK_TICK

	log_dungeon("Dungeon Generator: Space initialization completed for [turfs_processed] turfs")

// NEW: Completely clean a Z-level before reuse with background processing
/datum/portal_destination/veilbreak/proc/cleanup_z_level_completely(z_level)
	log_dungeon("Dungeon Generator: Starting background cleanup of Z-level [z_level]")

	// Use background processing for cleanup
	cleanup_process = new /datum/background_process(CALLBACK(src, .proc/execute_cleanup_step, z_level), "portal_cleanup_[z_level]")
	cleanup_process.start()

	return TRUE // Return immediately, cleanup happens in background

/datum/portal_destination/veilbreak/proc/execute_cleanup_step(z_level)
	var/start_time = world.time
	var/max_processing_time = 0.5 SECONDS // Process for max 0.5 seconds per tick
	var/processed_count = cleanup_process.metadata["cleanup_processed"] || 0

	// Process mobs in chunks
	for(var/mob/living/mob in GLOB.mob_living_list)
		if(mob.z != z_level)
			continue

		if(should_preserve_for_cleanup(mob))
			continue

		qdel(mob)
		processed_count++

		// Check if we've used our time budget for this tick
		if(world.time - start_time > max_processing_time)
			cleanup_process.metadata["cleanup_processed"] = processed_count
			log_dungeon("Dungeon Generator: Cleanup yielding after [processed_count] mobs")
			return BG_PROCESSING_CONTINUE // Continue next tick

	// Process objects in chunks
	for(var/obj/object in world)
		if(object.z != z_level)
			continue

		if(should_preserve_object(object))
			continue

		qdel(object)
		processed_count++

		if(world.time - start_time > max_processing_time)
			cleanup_process.metadata["cleanup_processed"] = processed_count
			log_dungeon("Dungeon Generator: Cleanup yielding after [processed_count] objects")
			return BG_PROCESSING_CONTINUE

	// Reset turfs to space in chunks
	var/turf_processed = cleanup_process.metadata["turf_processed"] || 0
	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(turf_processed > 0) // Skip already processed turfs
			turf_processed--
			continue

		if(istype(T, /turf/open/space/basic))
			continue

		T.ChangeTurf(/turf/open/space/basic, FALSE, FALSE)
		processed_count++

		if(world.time - start_time > max_processing_time)
			cleanup_process.metadata["cleanup_processed"] = processed_count
			cleanup_process.metadata["turf_processed"] = turf_processed + 1
			log_dungeon("Dungeon Generator: Cleanup yielding after [processed_count] items")
			return BG_PROCESSING_CONTINUE

	// Cleanup complete
	log_dungeon("Dungeon Generator: Cleanup completed for Z-level [z_level] - processed [processed_count] items")
	cleanup_process = null
	return BG_PROCESSING_FINISHED

// MODIFIED: Initialize dungeon subsystems with proper tick checking
/datum/portal_destination/veilbreak/proc/initialize_dungeon_subsystems(z_level)
	log_dungeon("Dungeon Generator: Starting background subsystem initialization for Z-level [z_level]")

	// Use background processing for initialization
	init_process = new /datum/background_process(CALLBACK(src, .proc/execute_init_step, z_level), "portal_init_[z_level]")
	init_process.start()

	return TRUE // Return immediately, initialization happens in background

/datum/portal_destination/veilbreak/proc/execute_init_step(z_level)
	var/start_time = world.time
	var/max_processing_time = 0.5 SECONDS // Process for max 0.5 seconds per tick
	var/current_step = init_process.metadata["current_step"] || 1

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

		if(7) // Visual updates
			var/result = force_immediate_visual_updates_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE

	// Initialization complete
	log_dungeon("Dungeon Generator: Subsystem initialization completed for Z-level [z_level]")

	// Ensure portal connection now that everything is ready
	ensure_portal_connection()

	init_process = null
	return BG_PROCESSING_FINISHED

// NEW: Incremental versions of initialization procs with proper tick checking
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
		log_dungeon("Dungeon Generator: Found [length(atoms_to_initialize)] atoms to initialize")
		return BG_PROCESSING_CONTINUE

	for(var/i = current_index to min(current_index + 50, length(atoms_to_initialize)))
		var/atom/A = atoms_to_initialize[i]
		if(!(A.flags_1 & INITIALIZED_1))
			SSatoms.InitAtom(A, FALSE, list(FALSE))

		if(world.time - start_time > max_time)
			init_process.metadata["atom_index"] = i + 1
			log_dungeon("Dungeon Generator: Atom initialization yielding")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Dungeon Generator: Atom initialization completed")
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
			return BG_PROCESSING_CONTINUE

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
			return BG_PROCESSING_CONTINUE

	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_lighting_incremental(z_level, start_time, max_time)
	if(!SSlighting || !SSlighting.initialized)
		log_dungeon("Dungeon Generator: Lighting subsystem not available")
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
				return BG_PROCESSING_CONTINUE
		current_y = 1

	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_atmospherics_incremental(z_level, start_time, max_time)
	if(!SSair || !SSair.initialized)
		log_dungeon("Dungeon Generator: Air subsystem not available")
		return BG_PROCESSING_FINISHED

	// Atmos machinery will be handled by SSair naturally
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
			return BG_PROCESSING_CONTINUE

	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/force_immediate_visual_updates_incremental(z_level, start_time, max_time)
	var/current_x = init_process.metadata["visual_x"] || 1
	var/current_y = init_process.metadata["visual_y"] || 1

	for(var/x = current_x to world.maxx)
		for(var/y = current_y to world.maxy)
			var/turf/iter_turf = locate(x, y, z_level)
			if(!istype(iter_turf, /obj/effect) && !istype(iter_turf, /obj/effect/decal))
				iter_turf.update_icon()
				iter_turf.update_appearance()

			if(world.time - start_time > max_time)
				init_process.metadata["visual_x"] = x
				init_process.metadata["visual_y"] = y + 1
				return BG_PROCESSING_CONTINUE
		current_y = 1

	return BG_PROCESSING_FINISHED

// NEW: Check if an atom should be preserved during Z-level cleanup
/datum/portal_destination/veilbreak/proc/should_preserve_for_cleanup(atom/movable/AM)
	// Preserve players and player-related entities
	if(ismob(AM))
		var/mob/M = AM
		if(M.client || M.ckey)
			return TRUE
		if(M.mind)
			return TRUE

	// Preserve important portal infrastructure
	if(istype(AM, /obj/machinery/portal))
		return TRUE
	if(istype(AM, /obj/effect/portal_bumper))
		return TRUE

	// Preserve station-bound items and structures
	if(AM.resistance_flags & INDESTRUCTIBLE)
		return TRUE

	return FALSE

// ===== PORTAL CONNECTION SYSTEM =====
/datum/portal_destination/veilbreak/proc/ensure_portal_connection()
	if(!dungeon_z_level)
		log_dungeon("Dungeon Generator: Cannot ensure connection - no Z-level assigned")
		return FALSE

	log_dungeon("Dungeon Generator: Scanning Z-level [dungeon_z_level] for portals...")

	// Scan the entire Z-level for portal objects
	var/obj/machinery/portal/found_portal = scan_for_existing_portal()

	if(found_portal)
		log_dungeon("Dungeon Generator: Found existing portal at [AREACOORD(found_portal)]")
		return connect_to_existing_portal(found_portal)
	else
		log_dungeon("Dungeon Generator: No portal found in dungeon, creating optimal one")
		return create_and_connect_new_portal()

/datum/portal_destination/veilbreak/proc/scan_for_existing_portal()
	// Method 1: Direct search for portal machinery
	for(var/obj/machinery/portal/P in world)
		if(P.z == dungeon_z_level)
			log_dungeon("Dungeon Generator: Found portal at [AREACOORD(P)]")
			return P

	// Method 2: Search for portal bumpers (they indicate portal presence)
	for(var/obj/effect/portal_bumper/bumper in world)
		if(bumper.z == dungeon_z_level && bumper.parent_portal)
			log_dungeon("Dungeon Generator: Found portal via bumper at [AREACOORD(bumper.parent_portal)]")
			return bumper.parent_portal

	log_dungeon("Dungeon Generator: No portals found on Z-level [dungeon_z_level]")
	return null

/datum/portal_destination/veilbreak/proc/connect_to_existing_portal(obj/machinery/portal/dungeon_portal)
	if(!dungeon_portal)
		return FALSE

	log_dungeon("Dungeon Generator: Connecting to existing portal at [AREACOORD(dungeon_portal)]")

	// Configure the found portal for dungeon use
	dungeon_portal.use_power = NO_POWER_USE
	dungeon_portal.portal_possible = TRUE

	// Ensure it has a bumper
	if(!dungeon_portal.bumper)
		dungeon_portal.generate_bumper()

	// Create return destination
	var/datum/portal_destination/simple/return_destination = new()
	return_destination.name = "Return to Station"
	return_destination.return_portal = connected_portal

	// Register return destination
	var/return_id = "veilbreak_return_[dungeon_z_level]_[world.time]"
	GLOB.portal_destinations[return_id] = return_destination
	log_dungeon("Dungeon Generator: Registered return destination [return_id]")

	// Configure the dungeon portal to target the return destination
	dungeon_portal.target = return_destination
	dungeon_portal.transport_active = TRUE
	dungeon_portal.update_appearance()

	log_dungeon("Dungeon Generator: Dungeon portal configured at [AREACOORD(dungeon_portal)]")

	// Configure the station portal to target this dungeon
	if(connected_portal)
		connected_portal.target = src
		connected_portal.transport_active = TRUE
		connected_portal.update_appearance()

		log_dungeon("Dungeon Generator: SUCCESS - Bidirectional connection established!")
		log_dungeon("Dungeon Generator: Station -> Dungeon: [AREACOORD(connected_portal)]")
		log_dungeon("Dungeon Generator: Dungeon -> Station: [AREACOORD(dungeon_portal)]")
		return TRUE

	log_dungeon("Dungeon Generator: WARNING - No connected portal found for station side")
	return FALSE

/datum/portal_destination/veilbreak/proc/create_and_connect_new_portal()
	log_dungeon("Dungeon Generator: Creating new portal at optimal location")

	var/turf/optimal_turf = find_optimal_portal_location()
	if(!optimal_turf)
		log_dungeon("Dungeon Generator: ERROR - Could not find suitable location for portal")
		return FALSE

	// Create the portal
	var/obj/machinery/portal/dungeon_portal = new(optimal_turf)
	log_dungeon("Dungeon Generator: Created new portal at [AREACOORD(dungeon_portal)]")

	// Now connect it (reuse the same logic as for existing portals)
	return connect_to_existing_portal(dungeon_portal)

/datum/portal_destination/veilbreak/proc/find_optimal_portal_location()
	log_dungeon("Dungeon Generator: Searching for optimal portal location on Z-level [dungeon_z_level]")

	// Strategy: Look for open areas that are accessible and not blocked
	var/list/candidate_turfs = list()

	// First, scan the entire Z-level for good locations
	for(var/turf/T in block(locate(1, 1, dungeon_z_level), locate(world.maxx, world.maxy, dungeon_z_level)))
		if(is_good_portal_location(T))
			candidate_turfs += T
		CHECK_TICK

	log_dungeon("Dungeon Generator: Found [length(candidate_turfs)] candidate locations")

	if(!length(candidate_turfs))
		// Emergency fallback: any open turf
		for(var/turf/open/T in block(locate(1, 1, dungeon_z_level), locate(world.maxx, world.maxy, dungeon_z_level)))
			if(!T.density)
				log_dungeon("Dungeon Generator: Using emergency fallback location at [AREACOORD(T)]")
				return T
			CHECK_TICK
		return null

	// Score and select the best candidate
	var/turf/best_turf = candidate_turfs[1]
	var/best_score = rate_portal_location(best_turf)

	for(var/turf/candidate in candidate_turfs)
		var/score = rate_portal_location(candidate)
		if(score > best_score)
			best_turf = candidate
			best_score = score
		CHECK_TICK

	log_dungeon("Dungeon Generator: Selected optimal location at [AREACOORD(best_turf)] with score [best_score]")
	return best_turf

/datum/portal_destination/veilbreak/proc/is_good_portal_location(turf/T)
	if(!T)
		return FALSE
	if(!istype(T, /turf/open))
		return FALSE
	if(T.density)
		return FALSE
	if(locate(/obj/machinery/portal) in T)
		return FALSE
	// Avoid placing on top of important structures
	if(locate(/obj/structure) in T)
		return FALSE
	if(locate(/obj/machinery) in T)
		return FALSE

	// Check for reasonable clear space (at least 3x3 area)
	var/clear_tiles = 0
	for(var/turf/adjacent in range(1, T))
		if(istype(adjacent, /turf/open) && !adjacent.density)
			clear_tiles++

	return clear_tiles >= 5 // Need decent clearance

/datum/portal_destination/veilbreak/proc/rate_portal_location(turf/T)
	var/score = 0

	// Base score for being open
	if(istype(T, /turf/open))
		score += 10

	// Bonus for specific open types (floors better than space)
	if(istype(T, /turf/open/floor))
		score += 5

	// Check surrounding area for openness
	var/open_tiles = 0
	for(var/turf/adjacent in range(2, T))
		if(istype(adjacent, /turf/open) && !adjacent.density)
			open_tiles++

	score += min(open_tiles, 20) // Cap the openness bonus

	// Bonus for being near the center of the map
	var/distance_from_center = abs(T.x - round(world.maxx/2)) + abs(T.y - round(world.maxy/2))
	var/max_distance = round((world.maxx + world.maxy) / 2)
	var/center_bonus = round((1 - (distance_from_center / max_distance)) * 10)
	score += max(0, center_bonus)

	// Penalty for being near map edges
	if(T.x <= 3 || T.x >= world.maxx - 3 || T.y <= 3 || T.y >= world.maxy - 3)
		score -= 10

	return score

// ===== CLEANUP AND UTILITY PROCS =====
/datum/portal_destination/veilbreak/proc/cleanup_dungeon()
	if(!dungeon_z_level)
		log_dungeon("Dungeon Generator: No Z-level to clean up")
		return

	log_dungeon("Dungeon Generator: Starting comprehensive cleanup for Z-level [dungeon_z_level]")

	// 1. Clean up all mobs and objects on the Z-level (except players who were already dumped)
	cleanup_z_level_contents(dungeon_z_level)

	// 2. Clean up any remaining portal connections
	if(connected_portal && connected_portal.target == src)
		connected_portal.target = null
		connected_portal.transport_active = FALSE
		connected_portal.update_appearance()
		log_dungeon("Dungeon Generator: Disconnected station portal")

	// 3. Clean up any dungeon-side portal
	var/obj/machinery/portal/dungeon_portal = scan_for_existing_portal()
	if(dungeon_portal)
		// Find and remove the return destination
		if(dungeon_portal.target)
			for(var/key in GLOB.portal_destinations)
				if(GLOB.portal_destinations[key] == dungeon_portal.target)
					GLOB.portal_destinations -= key
					log_dungeon("Dungeon Generator: Removed return destination [key]")
					break
		// Queue the portal for deletion
		qdel(dungeon_portal)
		log_dungeon("Dungeon Generator: Queued dungeon portal for deletion")

	// 4. Reset state - but keep the Z-level for reuse
	generated = FALSE
	generating = FALSE
	last_generation_data = null

	log_dungeon("Dungeon Generator: Cleanup complete for veilbreak destination")

/datum/portal_destination/veilbreak/proc/get_dungeon_stats()
	if(!last_generation_data || !last_generation_data["metadata"])
		return null

	var/list/metadata = last_generation_data["metadata"]
	var/list/stats = list()

	stats["z_level"] = dungeon_z_level
	stats["name"] = metadata["map_name"]
	stats["technical_name"] = metadata["technical_name"]
	stats["seed"] = metadata["seed"]
	stats["dimensions"] = metadata["dimensions"]
	stats["statistics"] = metadata["statistics"]
	stats["generation_info"] = metadata["generation_info"]

	return stats

/datum/portal_destination/veilbreak/proc/validate_state()
	if(generating && generated)
		log_dungeon("Dungeon Generator: WARNING - Portal in invalid state (both generating and generated)")
		return FALSE
	if(dungeon_z_level > world.maxz)
		log_dungeon("Dungeon Generator: WARNING - Dungeon Z-level [dungeon_z_level] exceeds world maxz [world.maxz]")
		return FALSE
	return TRUE

// Simple destination that directly references a portal location
/datum/portal_destination/simple
	name = "Simple Destination"
	var/obj/machinery/portal/return_portal

/datum/portal_destination/simple/get_target_turf()
	if(return_portal)
		return get_turf(return_portal)
	return null

/datum/portal_destination/simple/is_available()
	return return_portal && !QDELETED(return_portal)

/datum/portal_destination/simple/get_available_reason()
	if(!return_portal || QDELETED(return_portal))
		return "Return portal not available"
	return "Available for return"

// ===== DEBUG VERBS =====
/datum/portal_destination/veilbreak/verb/debug_metadata()
	set name = "Debug Dungeon Metadata"
	set category = "Debug"
	set src in view(1)

	usr << "=== DUNGEON METADATA DEBUG ==="
	if(last_generation_data)
		usr << "Full generation data keys: [json_encode(last_generation_data)]"
		if(last_generation_data["metadata"])
			usr << "Metadata keys: [json_encode(last_generation_data["metadata"])]"
			var/list/metadata = last_generation_data["metadata"]
			if(metadata["key_positions"])
				usr << "Key positions: [json_encode(metadata["key_positions"])]"
			else
				usr << "No key_positions found in metadata"
		else
			usr << "No metadata found in generation data"
	else
		usr << "No generation data available"

/datum/portal_destination/veilbreak/verb/scan_and_debug_portals()
	set name = "Debug Portal Scan"
	set category = "Debug"
	set src in view(1)

	usr << "=== PORTAL SCAN DEBUG ==="
	usr << "Dungeon Z-level: [dungeon_z_level]"

	var/obj/machinery/portal/found = scan_for_existing_portal()
	if(found)
		usr << "Found portal at: [AREACOORD(found)]"
		usr << "Portal state: active=[found.transport_active], target=[found.target]"
	else
		usr << "No portals found in dungeon"

	// Test optimal location finding
	var/turf/test_turf = find_optimal_portal_location()
	if(test_turf)
		usr << "Optimal location: [AREACOORD(test_turf)] (score: [rate_portal_location(test_turf)])"
	else
		usr << "No optimal location found"

	usr << "=== END DEBUG ==="

/datum/portal_destination/veilbreak/verb/force_reconnect()
	set name = "Force Portal Reconnect"
	set category = "Debug"
	set src in view(1)

	usr << "Forcing portal reconnection..."
	var/result = ensure_portal_connection()
	usr << "Reconnection result: [result ? "SUCCESS" : "FAILED"]"

// ===== GLOBAL KEY PROC =====
/datum/portal_destination/proc/get_global_key()
	for(var/key in GLOB.portal_destinations)
		if(GLOB.portal_destinations[key] == src)
			return key
	return null


/datum/portal_destination/veilbreak/proc/cleanup_z_level_contents(z_level)
	log_dungeon("Dungeon Generator: Cleaning up contents of Z-level [z_level]")

	var/mobs_cleaned = 0
	var/objects_cleaned = 0

	// Clean up all non-player mobs
	for(var/mob/living/mob in GLOB.mob_list)
		if(mob.z == z_level)
			// Skip players and player-related entities (they should have been dumped already)
			if(mob.ckey || mob.client || is_player_related_for_cleanup(mob))
				continue
			// Delete hostile/npc mobs
			qdel(mob)
			mobs_cleaned++

	// Clean up non-essential objects
	for(var/obj/object in world)
		if(object.z == z_level)
			// Skip important structures and player items
			if(should_preserve_object(object))
				continue
			qdel(object)
			objects_cleaned++

	log_dungeon("Dungeon Generator: Cleaned up [mobs_cleaned] mobs and [objects_cleaned] objects from Z-level [z_level]")

/// Check if an object should be preserved during cleanup
/datum/portal_destination/veilbreak/proc/should_preserve_object(obj/object)
	// Preserve important structures
	if(istype(object, /obj/structure))
		return TRUE
	if(istype(object, /obj/machinery))
		return TRUE
	if(istype(object, /obj/item))
		return TRUE
	// Preserve anything that might be player-owned
	if(object.resistance_flags & INDESTRUCTIBLE)
		return TRUE
	return FALSE

/// Check if a mob is player-related for cleanup purposes
/datum/portal_destination/veilbreak/proc/is_player_related_for_cleanup(mob/living/mob)
	// Players with active connections
	if(mob.client)
		return TRUE
	// Players with ckeys (SSD)
	if(mob.ckey)
		return TRUE
	// Player corpses with minds
	if(mob.stat == DEAD && mob.mind)
		return TRUE
	// Cyborgs with players
	if(iscyborg(mob) && (mob.ckey || mob.mind))
		return TRUE
	return FALSE
