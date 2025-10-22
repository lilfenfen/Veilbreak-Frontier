// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

// ADD THESE CONSTANTS AT THE TOP
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
	if(!test_request)
		destination.generation_failed("HTTP system not available")
		return 0

	var/request_id = ++current_request_id
	active_requests["[request_id]"] = destination

	var/datum/http_request/request = new()
	var/url = "[DUNGEON_GENERATOR_URL][DUNGEON_GENERATE_ENDPOINT]?width=[width]&height=[height]&seed=[rand(1,1000000)]"

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

	if(connected_portal)
		connected_portal.say("Dungeon generation failed: [reason]")
		connected_portal.generated_dungeon_data = null

/datum/portal_destination/veilbreak/proc/load_generated_map(list/generation_data)
	world.log << "=== LOAD_GENERATED_MAP DEBUG ==="
	world.log << "DMM content length: [length(generation_data["dmm_content"])]"

	var/dmm_content = generation_data["dmm_content"]
	if(!dmm_content)
		generation_failed("No map data received")
		return

	// Create new z-level
	dungeon_z_level = world.maxz + 1
	world.incrementMaxZ()
	world.log << "New z-level: [dungeon_z_level]"

	// Try ChangeTurf first (since it seems to be working for you)
	var/datum/parsed_map/parsed = null

	world.log << "Attempting to load with ChangeTurf..."
	parsed = load_map(
		dmm_content,
		z_offset = dungeon_z_level,
		measure_only = FALSE,
		no_changeturf = FALSE,  // Use ChangeTurf
		new_z = TRUE
	)

	// If ChangeTurf fails, try no_changeturf as fallback
	if(!parsed || !parsed.bounds)
		world.log << "ChangeTurf loading failed, trying no_changeturf fallback..."
		parsed = load_map(
			dmm_content,
			z_offset = dungeon_z_level,
			measure_only = FALSE,
			no_changeturf = TRUE,  // Avoid ChangeTurf
			new_z = TRUE
		)

	world.log << "Parsed result: [parsed ? "SUCCESS" : "FAILED"]"
	world.log << "Bounds: [parsed?.bounds]"

	if(!parsed || !parsed.bounds)
		generation_failed("Failed to load generated map")
		return

	world.log << "Map loaded successfully!"

	// Check if we need to fix red X issues
	check_and_fix_map_issues(dungeon_z_level, parsed.bounds)

	world.log << "Dungeon ready at z-level [dungeon_z_level]"

/datum/portal_destination/veilbreak/proc/check_and_fix_map_issues(z_level, list/bounds)
	world.log << "Checking for map issues on z-level [z_level]..."

	if(!bounds || bounds.len < 6)
		bounds = list(1, 1, world.maxx, world.maxy, z_level, z_level)

	// Sample a few turfs to check for red X issues
	var/red_x_count = 0
	var/sample_count = 0

	for(var/turf/T in block(locate(bounds[1], bounds[2], z_level), locate(min(bounds[3], bounds[1]+10), min(bounds[4], bounds[2]+10), z_level)))
		sample_count++
		if(T.icon_state == "" || T.icon_state == "redx" || !T.icon)
			red_x_count++

	world.log << "Found [red_x_count] red X issues in [sample_count] sample turfs"

	// If we found red X issues, fix them
	if(red_x_count > 0)
		world.log << "Fixing red X issues..."
		fix_red_x_issues(z_level, bounds)
	else
		world.log << "No red X issues found"

/datum/portal_destination/veilbreak/proc/fix_red_x_issues(z_level, list/bounds)
	if(!bounds || bounds.len < 6)
		bounds = list(1, 1, world.maxx, world.maxy, z_level, z_level)

	var/turf/start = locate(bounds[1], bounds[2], z_level)
	var/turf/end = locate(bounds[3], bounds[4], z_level)

	var/fixed_count = 0
	for(var/turf/T in block(start, end))
		// Check for red X indicators
		if(T.icon_state == "" || T.icon_state == "redx" || !T.icon)
			fixed_count++

			// Reset to proper values
			T.icon = initial(T.icon)
			T.icon_state = initial(T.icon_state)

			// Set common icon states
			if(istype(T, /turf/open/floor))
				T.icon_state = "floor"
			else if(istype(T, /turf/closed/wall))
				T.icon_state = "wall"
			else if(istype(T, /turf/open/space))
				T.icon_state = "default"

	world.log << "Fixed [fixed_count] turfs with red X issues"
