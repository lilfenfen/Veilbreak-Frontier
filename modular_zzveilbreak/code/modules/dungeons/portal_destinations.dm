/**
 * Veilbreak Portal Destination - Dynamically generated dungeons
 */
/datum/portal_destination/veilbreak
	name = "Veilbreak Dungeon"
	wait = 0
	var/generated = FALSE
	var/generating = FALSE
	var/dungeon_seed = null
	var/dungeon_width = 80
	var/dungeon_height = 80
	var/dungeon_z_level = null
	var/dungeon_metadata = null
	var/obj/machinery/portal/connected_portal

/datum/portal_destination/veilbreak/New()
	. = ..()
	name = "Veilbreak Portal [rand(1000,9999)]"

/datum/portal_destination/veilbreak/is_available()
	return ..() && generated && !generating

/datum/portal_destination/veilbreak/get_available_reason()
	if(generating)
		return "Portal stabilizing... [rand(25,95)]%"
	if(!generated)
		return "Portal not initialized"
	return ..()

/datum/portal_destination/veilbreak/get_target_turf()
	if(!dungeon_z_level)
		return null

	// Use gateway position from metadata if available
	if(dungeon_metadata && dungeon_metadata["key_positions"] && dungeon_metadata["key_positions"]["gateway"])
		var/list/gateway_pos = dungeon_metadata["key_positions"]["gateway"]
		return locate(gateway_pos["x"], gateway_pos["y"], dungeon_z_level)

	// Fallback to center
	return locate(round(world.maxx * 0.5), round(world.maxy * 0.5), dungeon_z_level)

/datum/portal_destination/veilbreak/activate(obj/machinery/portal/activated)
	connected_portal = activated
	if(!generated && !generating)
		start_generation()

/datum/portal_destination/veilbreak/deactivate(obj/machinery/portal/deactivated)
	connected_portal = null

/datum/portal_destination/veilbreak/proc/start_generation()
	generating = TRUE
	generated = FALSE
	dungeon_seed = rand(1, 1000000)

	// Start async map generation
	INVOKE_ASYNC(src, PROC_REF(call_generator_api))

/datum/portal_destination/veilbreak/proc/call_generator_api()
	var/api_url = "[DUNGEON_GENERATOR_URL][DUNGEON_GENERATE_ENDPOINT]?width=[dungeon_width]&height=[dungeon_height]&seed=[dungeon_seed]&format=json"

	var/datum/http_request/request = new()
	request.prepare(RUSTG_HTTP_METHOD_GET, api_url, "", "")
	request.begin_async()

	// Monitor the request with adaptive polling
	INVOKE_ASYNC(src, PROC_REF(monitor_generation), request)

/datum/portal_destination/veilbreak/proc/monitor_generation(datum/http_request/request)
	var/start_time = world.time
	var/poll_interval = DUNGEON_GENERATOR_POLL_INTERVAL

	while(world.time - start_time < DUNGEON_GENERATOR_TIMEOUT)
		sleep(poll_interval)

		if(request.is_complete())
			handle_generator_response(request)
			return

		// Adaptive polling to reduce server load
		poll_interval = min(poll_interval * 1.5, 20)

	// Timeout handling
	generating = FALSE
	name = "Veilbreak Portal (Timeout)"
	if(connected_portal)
		connected_portal.say("Portal generation timed out. Please try again.")

/datum/portal_destination/veilbreak/proc/handle_generator_response(datum/http_request/request)
	var/datum/http_response/response = request.into_response()

	if(response.errored || !response.body)
		generating = FALSE
		name = "Veilbreak Portal (API Error)"
		if(connected_portal)
			connected_portal.say("Failed to contact dungeon generator.")
		return

	var/list/data
	try
		data = json_decode(response.body)
	catch
		generating = FALSE
		name = "Veilbreak Portal (Invalid Response)"
		if(connected_portal)
			connected_portal.say("Invalid response from generator.")
		return

	if(data["status"] == "success" && data["dmm_content"])
		load_generated_map(data)
		generating = FALSE
		generated = TRUE
		name = data["metadata"]?["map_name"] || "Veilbreak Dungeon"
		dungeon_metadata = data["metadata"]

		if(connected_portal)
			connected_portal.say("Portal to [name] is now stable.")
	else
		generating = FALSE
		name = "Veilbreak Portal (Generation Failed)"
		if(connected_portal)
			connected_portal.say("Dungeon generation failed: [data["message"] || "Unknown error"]")

/datum/portal_destination/veilbreak/proc/load_generated_map(list/generation_data)
	// Create a new z-level for the dungeon
	var/datum/map_template/veilbreak_dungeon/template = new(generation_data["dmm_content"])
	dungeon_z_level = template.load_new_z()

	// Store metadata for the portal to use
	if(connected_portal)
		connected_portal.generated_dungeon_data = generation_data["metadata"]


/datum/portal_destination/veilbreak/get_ui_data()
	. = list()
	.["ref"] = REF(src)
	.["name"] = name
	.["available"] = is_available()
	.["reason"] = get_available_reason()
	if(generating)
		.["timeout"] = 0.5 // Shows progress bar in UI
