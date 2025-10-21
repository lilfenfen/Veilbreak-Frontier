/client/proc/test_dungeon_generator()
	set name = "Test Dungeon Generator"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	var/width = input(usr, "Dungeon Width (50-200)", "Width", 80) as num|null
	if(!width || width < 50 || width > 200)
		return

	var/height = input(usr, "Dungeon Height (50-200)", "Height", 80) as num|null
	if(!height || height < 50 || height > 200)
		return

	var/seed = input(usr, "Seed (leave empty for random)", "Seed") as num|null

	to_chat(usr, span_notice("Starting dungeon generation test..."))

	var/datum/portal_destination/veilbreak/test_dest = new()
	test_dest.dungeon_width = width
	test_dest.dungeon_height = height
	if(seed)
		test_dest.dungeon_seed = seed

	test_dest.start_generation()

	// Monitor progress
	var/start_time = world.time
	var/max_wait = 300 // 30 seconds

	to_chat(usr, span_notice("Generation started. Monitoring progress..."))

	INVOKE_ASYNC(src, PROC_REF(monitor_test_generation), test_dest, start_time, max_wait)

/client/proc/monitor_test_generation(datum/portal_destination/veilbreak/test_dest, start_time, max_wait)
	while(world.time - start_time < max_wait)
		sleep(10) // Check every second

		if(test_dest.generated)
			to_chat(usr, span_green("Dungeon generation successful!"))
			to_chat(usr, span_notice("Dungeon name: [test_dest.name]"))
			to_chat(usr, span_notice("Z-level: [test_dest.dungeon_z_level]"))
			if(test_dest.dungeon_metadata)
				to_chat(usr, span_notice("Rooms: [test_dest.dungeon_metadata["statistics"]?["rooms"] || "Unknown"]"))
				to_chat(usr, span_notice("Mobs: [test_dest.dungeon_metadata["statistics"]?["mobs"] || "Unknown"]"))
				to_chat(usr, span_notice("Containers: [test_dest.dungeon_metadata["statistics"]?["containers"] || "Unknown"]"))
			return
		else if(test_dest.generating)
			continue // Still generating
		else
			to_chat(usr, span_warning("Dungeon generation failed or was cancelled."))
			return

	// Timeout
	to_chat(usr, span_warning("Dungeon generation timed out after [max_wait/10] seconds."))

/client/proc/portal_system_status()
	set name = "Portal System Status"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	to_chat(usr, span_notice("=== Portal System Status ==="))
	to_chat(usr, span_notice("Total Portal Destinations: [length(GLOB.portal_destinations)]"))

	var/active_portals = 0
	var/generating_dungeons = 0
	var/ready_dungeons = 0

	for(var/datum/portal_destination/veilbreak/dest in GLOB.portal_destinations)
		if(dest.generating)
			generating_dungeons++
		else if(dest.generated)
			ready_dungeons++
		if(dest.connected_portal)
			active_portals++

	to_chat(usr, span_notice("Active Portals: [active_portals]"))
	to_chat(usr, span_notice("Generating Dungeons: [generating_dungeons]"))
	to_chat(usr, span_notice("Ready Dungeons: [ready_dungeons]"))

	// Test API connectivity
	to_chat(usr, span_notice("Testing API connectivity..."))

	var/datum/http_request/request = new()
	var/api_url = "[DUNGEON_GENERATOR_URL]/"
	request.prepare(RUSTG_HTTP_METHOD_GET, api_url, "", "")
	request.begin_async()

	sleep(10) // Brief wait for response

	if(request.is_complete())
		var/datum/http_response/response = request.into_response()
		if(!response.errored && response.status_code == 200)
			to_chat(usr, span_green("Dungeon Generator API: ONLINE"))
		else
			to_chat(usr, span_warning("Dungeon Generator API: OFFLINE (Error: [response.error])"))
	else
		to_chat(usr, span_warning("Dungeon Generator API: REQUEST TIMEOUT"))

/client/proc/create_test_portal()
	set name = "Create Test Portal"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	var/turf/T = get_turf(usr)
	if(!T)
		to_chat(usr, span_warning("Invalid location!"))
		return

	// Create portal
	var/obj/machinery/portal/new_portal = new(T)
	to_chat(usr, span_green("Created portal at [T.x],[T.y],[T.z]"))

	// Create control console nearby
	var/turf/console_turf = get_step(T, EAST)
	if(console_turf)
		new /obj/machinery/computer/portal_control(console_turf)
		to_chat(usr, span_green("Created control console next to portal."))

	message_admins("[key_name_admin(usr)] created a test portal at [ADMIN_VERBOSEJMP(T)]")
