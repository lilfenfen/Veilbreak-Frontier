// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

// CORRECTED Forward declarations - only what we actually need
/datum/space_level
/datum/parsed_map

// Proc forward declarations
/proc/IS_LIST_OF_ATOMS(list/L)

#define DUNGEON_GENERATOR_URL "http://127.0.0.1:8000"
#define DUNGEON_GENERATE_ENDPOINT "/generate_dungeon"
#define DUNGEON_GENERATOR_TIMEOUT 300 // 30 seconds

// Global list for portal destinations (separate from gateways)
GLOBAL_LIST_EMPTY(portal_destinations)

// HTTP request manager for dungeon generation
/datum/http_dungeon_generator
	var/current_request_id = 0
	var/list/active_requests = list()

/datum/http_dungeon_generator/proc/generate_dungeon(datum/portal_destination/veilbreak/destination, width = 80, height = 80)
	// Check if RUSTG HTTP is available
	var/datum/http_request/test_request = new()
	if(!test_request)
		destination.generation_failed("HTTP system not available")
		return 0

	var/request_id = ++current_request_id
	active_requests["[request_id]"] = destination

	var/datum/http_request/request = new()
	var/url = "[DUNGEON_GENERATOR_URL][DUNGEON_GENERATE_ENDPOINT]?width=[width]&height=[height]&seed=[rand(1,1000000)]"

	log_game("Dungeon Generator: Starting HTTP request to [url]", LOG_CATEGORY_DEBUG_MAPPING)

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
GLOBAL_DATUM(dungeon_generator, /datum/http_dungeon_generator)

// Base portal destination type
/datum/portal_destination
	var/name = "Unknown Destination"
	var/wait = 0
	var/enabled = TRUE
	var/hidden = FALSE

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
	return

/datum/portal_destination/proc/deactivate(obj/machinery/portal/deactivated)
	return

/datum/portal_destination/proc/get_ui_data()
	. = list()
	.["ref"] = REF(src)
	.["name"] = name
	.["available"] = is_available()
	.["reason"] = get_available_reason()
	if(wait)
		.["timeout"] = max(1 - (wait - (world.time - SSticker.round_start_time)) / wait, 0)
	else
		.["timeout"] = 0

// Veilbreak-specific destination
/datum/portal_destination/veilbreak
	name = "Veilbreak Dungeon"
	var/generating = FALSE
	var/generated = FALSE
	var/dungeon_z_level = 0
	var/obj/machinery/portal/connected_portal
	var/last_generation_data = null
	var/current_request_id = 0
	var/generation_progress = 0
	var/last_progress_update = 0

// ADD THE MISSING PROCS FOR VEILBREAK DESTINATION
/datum/portal_destination/veilbreak/is_available()
	return ..() && generated && !generating

/datum/portal_destination/veilbreak/get_available_reason()
	if(generating)
		return "Dungeon generation in progress... [generation_progress]%"
	if(!generated)
		return "No dungeon generated yet"
	return ..()

/datum/portal_destination/veilbreak/get_target_turf()
	if(!dungeon_z_level || !last_generation_data)
		return null

	// Access metadata correctly from the nested structure
	var/list/metadata = last_generation_data["metadata"]
	if(metadata && metadata["key_positions"])
		var/list/key_positions = metadata["key_positions"]
		if(key_positions && key_positions["gateway"])
			var/list/gateway_pos = key_positions["gateway"]
			return locate(gateway_pos["x"], gateway_pos["y"], dungeon_z_level)

	// Fallback to center
	return locate(round(world.maxx/2), round(world.maxy/2), dungeon_z_level)

/datum/portal_destination/veilbreak/proc/start_generation()
	if(generating)
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

	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, 80, 80)

	if(!current_request_id)
		generation_failed("Failed to start generation request")
		return

	log_game("Dungeon Generator: Started generation request [current_request_id]", LOG_CATEGORY_DEBUG_MAPPING)

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

// ADD THE MISSING GENERATION PROCS
/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	generating = FALSE
	last_generation_data = data

	log_game("Dungeon Generator: Received successful generation response", LOG_CATEGORY_DEBUG_MAPPING)

	// Access dmm_content from top level
	if(data["dmm_content"])
		load_generated_dmm(data["dmm_content"], data["metadata"])
	else
		generation_failed("No DMM content in response")

/datum/portal_destination/veilbreak/proc/generation_failed(reason)
	generating = FALSE
	generated = FALSE
	generation_progress = 0

	log_game("Dungeon Generator: Generation failed - [reason]", LOG_CATEGORY_DEBUG_MAPPING)

	if(connected_portal)
		connected_portal.say("Dungeon generation failed: [reason]")
		connected_portal.generated_dungeon_data = null

// CORRECTED: Complete dungeon loading implementation
/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content, list/metadata)
	if(!dmm_content)
		return generation_failed("No DMM content provided")

	log_game("Dungeon Generator: Starting DMM content load for Veilbreak dungeon", LOG_CATEGORY_DEBUG_MAPPING)

	// Save original DMM for debugging
	text2file(dmm_content, "data/logs/dungeon_content_[world.time].dmm")

	// Verify mapping subsystem is ready
	if(!SSmapping.initialized)
		return generation_failed("Mapping subsystem not initialized")

	// Create new Z-level using mapping subsystem
	var/datum/space_level/dungeon_level = SSmapping.add_new_zlevel(
		name = "Veilbreak Dungeon [rand(1000,9999)]",
		traits = list(
			ZTRAIT_AWAY = TRUE,
			ZTRAIT_MINING = TRUE,
			ZTRAIT_BASETURF = /turf/open/space/basic
		),
		z_type = /datum/space_level
	)

	if(!dungeon_level)
		return generation_failed("Failed to create new Z-level")

	dungeon_z_level = dungeon_level.z_value
	log_game("Dungeon Generator: Created new dungeon at Z-level [dungeon_z_level]", LOG_CATEGORY_DEBUG_MAPPING)

	// Parse and load the DMM content
	var/datum/parsed_map/parsed = new(dmm_content)
	if(!parsed || !parsed.bounds)
		log_game("Dungeon Generator: Failed to parse DMM content - invalid format or null bounds", LOG_CATEGORY_DEBUG_MAPPING)
		return generation_failed("Failed to parse DMM content")

	log_game("Dungeon Generator: Parsed map with bounds [json_encode(parsed.bounds)]", LOG_CATEGORY_DEBUG_MAPPING)

	// Use SSair's map loading system if available
	if(SSair.initialized)
		SSair.StartLoadingMap()

	var/loaded_successfully = FALSE
	try
		loaded_successfully = parsed.load(
			z_offset = dungeon_z_level,
			no_changeturf = FALSE,
			place_on_top = FALSE,
			new_z = TRUE
		)
	catch(var/exception/e)
		log_game("Dungeon Generator: Exception during map load: [e]", LOG_CATEGORY_DEBUG_MAPPING)
		loaded_successfully = FALSE

	if(SSair.initialized)
		SSair.StopLoadingMap()

	if(!loaded_successfully)
		log_game("Dungeon Generator: Map loading failed at Z-level [dungeon_z_level]", LOG_CATEGORY_DEBUG_MAPPING)
		return generation_failed("Failed to load map into world")

	log_game("Dungeon Generator: Map loaded successfully at Z-level [dungeon_z_level]", LOG_CATEGORY_DEBUG_MAPPING)

	// Initialize all required subsystems
	initialize_dungeon_subsystems(dungeon_z_level)

	// Mark as complete
	generated = TRUE
	generation_progress = 100
	last_generation_data = metadata

	if(connected_portal)
		connected_portal.generated_dungeon_data = metadata
		connected_portal.say("Dungeon generation complete. Portal stabilized.")

	log_game("Dungeon Generator: Veilbreak dungeon fully initialized at Z-level [dungeon_z_level]", LOG_CATEGORY_DEBUG_MAPPING)
	return TRUE

// ADD THE MISSING SUBSYSTEM INITIALIZATION PROCS
/datum/portal_destination/veilbreak/proc/initialize_dungeon_subsystems(z_level)
	log_game("Dungeon Generator: Initializing subsystems for Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)

	// 1. Initialize lighting using area-based approach
	initialize_dungeon_lighting(z_level)

	// 2. Initialize atmospherics machinery and pipenets
	initialize_dungeon_atmospherics(z_level)

	log_game("Dungeon Generator: All subsystems initialized for Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)

/datum/portal_destination/veilbreak/proc/initialize_dungeon_lighting(z_level)
	if(!SSlighting || !SSlighting.initialized)
		log_game("Dungeon Generator: Lighting subsystem not available for Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)
		return

	log_game("Dungeon Generator: Initializing lighting for Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)

	var/lighting_objects_created = 0
	var/areas_processed = 0

	// Follow the exact same pattern as SSlighting.create_all_lighting_objects()
	for(var/area/area as anything in GLOB.areas)
		if(!area.static_lighting)
			continue

		areas_processed++
		var/list/zlevel_turfs = area.get_zlevel_turf_lists()

		// Safely check if this area has turfs on our Z-level
		if(!zlevel_turfs || !islist(zlevel_turfs) || !zlevel_turfs["[z_level]"])
			continue

		for(var/turf/area_turf as anything in zlevel_turfs["[z_level]"])
			if(area_turf.space_lit || area_turf.lighting_object)
				continue

			new /datum/lighting_object(area_turf)
			lighting_objects_created++

		CHECK_TICK

	log_game("Dungeon Generator: Created [lighting_objects_created] lighting objects across [areas_processed] areas on Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)

/datum/portal_destination/veilbreak/proc/initialize_dungeon_atmospherics(z_level)
	if(!SSair || !SSair.initialized)
		log_game("Dungeon Generator: Air subsystem not available for Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)
		return

	log_game("Dungeon Generator: Initializing atmospherics for Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)

	var/atmos_machines_initialized = 0
	var/list/atmos_machines = list()

	// Collect all atmos machinery on the new Z-level
	for(var/obj/machinery/atmospherics/AM as anything in SSair.atmos_machinery)
		if(AM.z == z_level)
			atmos_machines += AM
			atmos_machines_initialized++

	// Use SSair's template machinery setup if we found any machines
	if(length(atmos_machines))
		SSair.setup_template_machinery(atmos_machines)
		log_game("Dungeon Generator: Initialized [atmos_machines_initialized] atmos machines on Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)
	else
		log_game("Dungeon Generator: No atmos machines found on Z-level [z_level]", LOG_CATEGORY_DEBUG_MAPPING)

// ADD THE MISSING UTILITY PROCS
/datum/portal_destination/veilbreak/proc/cleanup_dungeon()
	if(dungeon_z_level && dungeon_z_level <= world.maxz)
		log_game("Dungeon at Z-level [dungeon_z_level] marked for cleanup", LOG_CATEGORY_DEBUG_MAPPING)
		// Note: In your system, Z-levels can't be easily removed
		// The dungeon will remain but portals won't target it

	dungeon_z_level = 0
	generated = FALSE
	last_generation_data = null

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
		log_game("Dungeon Generator: WARNING - Portal in invalid state (both generating and generated)", LOG_CATEGORY_DEBUG_MAPPING)
		return FALSE
	if(dungeon_z_level > world.maxz)
		log_game("Dungeon Generator: WARNING - Dungeon Z-level [dungeon_z_level] exceeds world maxz [world.maxz]", LOG_CATEGORY_DEBUG_MAPPING)
		return FALSE
	return TRUE
