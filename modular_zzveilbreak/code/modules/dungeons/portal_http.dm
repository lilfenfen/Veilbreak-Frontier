// modular_zzveilbreak/code/modules/dungeons/portal_http.dm

/datum/http_dungeon_generator
	var/current_request_id = 0
	var/list/active_requests = list()

/datum/http_dungeon_generator/proc/generate_dungeon(datum/portal_destination/veilbreak/destination, width = 250, height = 250)
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

	active_requests["[request_id]_req"] = request
	active_requests["[request_id]_time"] = world.time

	return request_id

/datum/http_dungeon_generator/proc/check_request(request_id)
	var/datum/portal_destination/veilbreak/destination = active_requests["[request_id]"]
	if(!destination || QDELETED(destination))
		active_requests -= "[request_id]"
		active_requests -= "[request_id]_req"
		active_requests -= "[request_id]_time"
		return FALSE

	var/datum/http_request/request = active_requests["[request_id]_req"]
	if(!request || QDELETED(request))
		active_requests -= "[request_id]"
		active_requests -= "[request_id]_time"
		return FALSE

	if(!request.is_complete())
		var/start_time = active_requests["[request_id]_time"]
		if(world.time - start_time > DUNGEON_GENERATOR_TIMEOUT)
			destination.generation_failed("Request timeout after [DUNGEON_GENERATOR_TIMEOUT/10] seconds")
			active_requests -= "[request_id]"
			active_requests -= "[request_id]_req"
			active_requests -= "[request_id]_time"
			return FALSE
		return TRUE

	var/datum/http_response/response = request.into_response()

	if(response.errored || !response.body)
		destination.generation_failed("HTTP error: [response.error]")
	else
		var/list/data = json_decode(response.body)
		if(data && data["status"] == "success")
			destination.generation_complete(data)
		else
			destination.generation_failed(data?["message"] || "Unknown error from generator")

	active_requests -= "[request_id]"
	active_requests -= "[request_id]_req"
	active_requests -= "[request_id]_time"

	return FALSE
