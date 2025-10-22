// modular_zzveilbreak/code/modules/dungeons/portal_debug.dm

/client/proc/create_test_portal()
	set name = "Create Test Portal"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	var/turf/T = get_turf(usr)
	if(!T)
		to_chat(usr, span_warning("Invalid location!"))
		return

	// Create portal without storing in variable to avoid unused var warning
	new /obj/machinery/portal(T)
	to_chat(usr, span_green("Created portal at [T.x],[T.y],[T.z]"))

	// Create control console nearby
	var/turf/console_turf = get_step(T, EAST)
	if(console_turf)
		new /obj/machinery/computer/portal_control(console_turf)
		to_chat(usr, span_green("Created control console next to portal."))

	message_admins("[key_name_admin(usr)] created a test portal at [ADMIN_VERBOSEJMP(T)]")
