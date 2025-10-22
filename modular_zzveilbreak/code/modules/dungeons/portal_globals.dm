// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

// Forward declarations to satisfy the compiler for types and procs defined elsewhere.
/datum/turf_reservation
/datum/map_loader
/datum/map_loader/proc/do_load(z_override)
/datum/map_loader/proc/get_bounds()
/datum/controller/subsystem/mapping
/datum/controller/subsystem/mapping/proc/get_next_z_level()
/datum/controller/subsystem/mapping/proc/prepare_new_z_level(z_level)
/datum/controller/subsystem/mapping/proc/free_z_level(datum/turf_reservation/reservation)
/datum/controller/subsystem/lighting
/datum/controller/subsystem/lighting/proc/init_lighting_for_z(z_level)
/datum/controller/subsystem/air
/datum/controller/subsystem/air/proc/init_new_z_level(z_level)

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

/datum/http_dungeon_generator/proc/generate_dungeon(datum/portal_destination/veilbreak/destination, width = 150, height = 150)
	// Check if RUSTG HTTP is available by trying to create a request
	var/datum/http_request/test_request = new()
	world.log << "DEBUG: Attempting to create HTTP request. test_request: [test_request]"
	if(!test_request)
		destination.generation_failed("HTTP system not available")
		return 0

	var/request_id = ++current_request_id
	active_requests["[request_id]"] = destination

	var/datum/http_request/request = new()
	var/url = "[DUNGEON_GENERATOR_URL][DUNGEON_GENERATE_ENDPOINT]?width=[width]&height=[height]&seed=[rand(1,1000000)]"
	world.log << "DEBUG: Dungeon generation URL: [url]"

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
			destination.generation_failed("Request timeout")
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
			destination.generation_failed(data?["message"] || "Unknown error")

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

	// FIXED: Access metadata correctly from the nested structure
	var/list/metadata = last_generation_data["metadata"]
	if(metadata && metadata["key_positions"])
		var/list/key_positions = metadata["key_positions"]
		if(key_positions && key_positions["gateway"])
			var/list/gateway_pos = key_positions["gateway"]
			return locate(gateway_pos["x"], gateway_pos["y"], dungeon_z_level)

	// Fallback to center
	return locate(world.maxx/2, world.maxy/2, dungeon_z_level)

/datum/portal_destination/veilbreak/proc/start_generation()
	if(generating)
		return

	generating = TRUE
	generated = FALSE
	generation_progress = 0
	last_progress_update = world.time

	if(!GLOB.dungeon_generator)
		GLOB.dungeon_generator = new /datum/http_dungeon_generator()

	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, 150, 150)

	if(!current_request_id)
		generation_failed("Failed to start generation request")
		return

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
	generated = TRUE
	last_generation_data = data

	// FIXED: Access dmm_content from top level, not nested
	if(data["dmm_content"])
		load_generated_map(data)
	else
		generation_failed("No map data in response")

	if(connected_portal)
		// FIXED: Access metadata correctly
		connected_portal.generated_dungeon_data = data["metadata"]
		connected_portal.say("Dungeon generation complete. Portal stabilized.")

	generation_progress = 100

/datum/portal_destination/veilbreak/proc/generation_failed(reason)
	generating = FALSE
	generated = FALSE
	generation_progress = 0

	log_admin("Dungeon generation failed: [reason]")

	if(connected_portal)
		connected_portal.say("Dungeon generation failed: [reason]")
		connected_portal.generated_dungeon_data = null

/datum/portal_destination/veilbreak/proc/load_generated_map(list/generation_data)
	var/dmm_content = generation_data["dmm_content"]
	if(!dmm_content)
		return generation_failed("No map data received")

	// Dynamically add a new z-level to the world and prepare it for use.
	// This is more reliable than trying to find a pre-existing empty one.
	world.maxz++
	dungeon_z_level = world.maxz
	SSmapping.prepare_new_z_level(dungeon_z_level)

	log_game("Dungeon Generator: Creating new dungeon at Z-level [dungeon_z_level].", LOG_CATEGORY_DEBUG_MAPPING)
	// Use the correct map loader that can handle raw DMM content from a string.
	var/datum/map_loader/dungeon_loader = new(list(dmm_content))

	var/list/loaded_atoms = dungeon_loader.do_load(z_override = dungeon_z_level)

	if(!IS_LIST_OF_ATOMS(loaded_atoms))
		log_game("Dungeon Generator: Failed to load map at Z-level [dungeon_z_level]. Map loader returned no atoms.", LOG_CATEGORY_DEBUG_MAPPING)
		dungeon_z_level = 0
		return generation_failed("Failed to load generated map into world.")


	// The map loader should handle initialization correctly, but if issues persist,
	// we can add a post-load fixup proc.
	// fix_red_x_issues(dungeon_z_level, loader.get_bounds())

	log_game("Dungeon Generator: Map loaded successfully at Z-level [dungeon_z_level].", LOG_CATEGORY_DEBUG_MAPPING)

	// Initialize lighting for the new Z-level
	if(SSlighting)
		SSlighting.init_lighting_for_z(dungeon_z_level)

	// Initialize atmos for the new Z-level
	if(SSair)
		SSair.init_new_z_level(dungeon_z_level)

	log_game("Dungeon Generator: Dungeon ready at z-level [dungeon_z_level]", LOG_CATEGORY_DEBUG_MAPPING)

/datum/portal_destination/veilbreak/proc/fix_red_x_issues(z_level, list/bounds)
	if(!bounds || bounds.len < 6)
		bounds = list(1, 1, world.maxx, world.maxy, z_level, z_level)

	var/turf/start = locate(bounds[1], bounds[2], z_level)
	var/turf/end = locate(bounds[3], bounds[4], z_level)

	var/fixed_count = 0
	for(var/turf/T in block(start, end))
		// Check for red X indicators
		if(initial(T.icon_state) == "redx") // Check the initial icon_state to be more robust
			fixed_count++
			// Re-running Initialize() on the turf often fixes visual issues
			// by re-applying overlays and other visual properties.
			T.Initialize()
			// Forcing a smooth queue can also help update neighbors.
			QUEUE_SMOOTH(T)

	log_game("Fixed [fixed_count] turfs with red X issues", LOG_CATEGORY_DEBUG_MAPPING)
