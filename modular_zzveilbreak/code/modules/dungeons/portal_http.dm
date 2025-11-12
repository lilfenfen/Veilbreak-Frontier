// modular_zzveilbreak/code/modules/dungeons/portal_http.dm

// HTTP request manager for dungeon generation
/datum/http_dungeon_generator
	var/current_request_id = 0
	var/list/active_requests = list()

/datum/http_dungeon_generator/proc/generate_dungeon(datum/portal_destination/veilbreak/destination, width = 250, height = 250)
	log_dungeon("DUNGEON DEBUG: generate_dungeon() called with width=[width], height=[height]")
	log_dungeon("DUNGEON DEBUG: Current request_id: [current_request_id]")

	// Check if RUSTG HTTP is available
	var/datum/http_request/test_request = new()
	if(!test_request)
		log_dungeon("DUNGEON DEBUG: HTTP system not available - test_request is null")
		destination.generation_failed("HTTP system not available")
		return 0
	else
		log_dungeon("DUNGEON DEBUG: HTTP system available")

	var/request_id = ++current_request_id
	active_requests["[request_id]"] = destination
	log_dungeon("DUNGEON DEBUG: Stored destination in active_requests with key [request_id]")

	var/datum/http_request/request = new()
	var/url = "[DUNGEON_GENERATOR_URL][DUNGEON_GENERATE_ENDPOINT]?width=[width]&height=[height]&seed=[rand(1,1000000)]"

	log_dungeon("DUNGEON DEBUG: Prepared HTTP request to: [url]")

	request.prepare(RUSTG_HTTP_METHOD_GET, url, "", "")
	log_dungeon("DUNGEON DEBUG: Request prepared, beginning async...")
	request.begin_async()

	log_dungeon("DUNGEON DEBUG: HTTP request begun asynchronously")

	// Store the request data
	active_requests["[request_id]_req"] = request
	active_requests["[request_id]_time"] = world.time
	log_dungeon("DUNGEON DEBUG: Stored request data with time [world.time]")

	log_dungeon("DUNGEON DEBUG: Returning request_id: [request_id]")
	return request_id

/datum/http_dungeon_generator/proc/check_request(request_id)
	log_dungeon("DUNGEON DEBUG: check_request() called for request_id: [request_id]")
	log_dungeon("DUNGEON DEBUG: Active requests keys: [json_encode(active_requests)]")

	var/datum/portal_destination/veilbreak/destination = active_requests["[request_id]"]
	if(!destination || QDELETED(destination))
		log_dungeon("DUNGEON DEBUG: Request [request_id] - destination missing or deleted")
		active_requests -= "[request_id]"
		active_requests -= "[request_id]_req"
		active_requests -= "[request_id]_time"
		return FALSE // Not processing anymore

	var/datum/http_request/request = active_requests["[request_id]_req"]
	if(!request || QDELETED(request))
		log_dungeon("DUNGEON DEBUG: Request [request_id] - request object missing")
		active_requests -= "[request_id]"
		active_requests -= "[request_id]_time"
		return FALSE // Not processing anymore

	log_dungeon("DUNGEON DEBUG: Checking if request is complete...")
	if(!request.is_complete())
		log_dungeon("DUNGEON DEBUG: Request [request_id] - still processing")
		// Check for timeout
		var/start_time = active_requests["[request_id]_time"]
		if(world.time - start_time > DUNGEON_GENERATOR_TIMEOUT)
			log_dungeon("DUNGEON DEBUG: Request [request_id] - timeout after [DUNGEON_GENERATOR_TIMEOUT/10] seconds")
			destination.generation_failed("Request timeout after [DUNGEON_GENERATOR_TIMEOUT/10] seconds")
			active_requests -= "[request_id]"
			active_requests -= "[request_id]_req"
			active_requests -= "[request_id]_time"
			return FALSE // Not processing anymore
		log_dungeon("DUNGEON DEBUG: Request [request_id] - still within timeout, returning TRUE")
		return TRUE // Still processing

	log_dungeon("DUNGEON DEBUG: Request [request_id] - complete, getting response")
	var/datum/http_response/response = request.into_response()

	if(response.errored || !response.body)
		log_dungeon("DUNGEON DEBUG: Request [request_id] - error: [response.error]")
		destination.generation_failed("HTTP error: [response.error]")
	else
		log_dungeon("DUNGEON DEBUG: Request [request_id] - response received, body length: [length(response.body)]")
		var/list/data = json_decode(response.body)
		if(data && data["status"] == "success")
			log_dungeon("DUNGEON DEBUG: Request [request_id] - success, data received")
			destination.generation_complete(data)
		else
			log_dungeon("DUNGEON DEBUG: Request [request_id] - API error: [data?["message"] || "Unknown error"]")
			destination.generation_failed(data?["message"] || "Unknown error from generator")

	// Cleanup - request is complete
	log_dungeon("DUNGEON DEBUG: Cleaning up request [request_id]")
	active_requests -= "[request_id]"
	active_requests -= "[request_id]_req"
	active_requests -= "[request_id]_time"

	return FALSE // Not processing anymore
