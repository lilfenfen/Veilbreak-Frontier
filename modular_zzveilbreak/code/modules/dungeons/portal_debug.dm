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

// ===== DEBUG VERBS =====
/obj/machinery/portal/verb/debug_portal_state()
	set name = "Debug Portal State"
	set category = "Debug"
	set src in view(1)

	usr << "=== PORTAL STATE DEBUG ==="
	usr << "Location: [AREACOORD(src)]"
	usr << "Powered: [powered()]"
	usr << "Portal Possible: [portal_possible]"
	usr << "Transport Active: [transport_active]"
	usr << "Is Dungeon Portal: [is_dungeon_portal()]"
	usr << "Calibrated: [calibrated]"
	usr << "Bumper: [bumper ? "Present at [AREACOORD(bumper)]" : "None"]"

	if(target)
		usr << "Current Target: [target.name]"
		usr << "Target Available: [target.is_available()]"
		usr << "Target Reason: [target.get_available_reason()]"

	if(destination)
		usr << "Default Destination: [destination.name]"
		usr << "Destination Generated: [destination.generated]"
		usr << "Destination Generating: [destination.generating]"
		usr << "Dungeon Z-Level: [destination.dungeon_z_level]"

	usr << "=== DESTINATION COUNT ==="
	var/count = 0
	for(var/key in GLOB.portal_destinations)
		count++
	usr << "Total Global Destinations: [count]"

/obj/machinery/portal/verb/test_auto_activation()
	set name = "Test Auto Activation"
	set category = "Debug"
	set src in view(1)

	usr << "Testing auto-activation..."
	usr << "Portal Possible: [portal_possible]"
	usr << "Current Target: [target ? target.name : "None"]"
	usr << "Transport Active: [transport_active]"

	if(portal_possible && !target && !transport_active)
		usr << "Conditions met for auto-activation - attempting..."
		activate_to_available_destination()
	else
		usr << "Auto-activation conditions not met:"
		if(!portal_possible)
			usr << "- Portal not possible"
		if(target)
			usr << "- Already has target: [target.name]"
		if(transport_active)
			usr << "- Transport already active"

/obj/machinery/computer/portal_control/verb/debug_cleanup_state()
	set name = "Debug Cleanup State"
	set category = "Debug"
	set src in view(1)

	usr << "=== CLEANUP STATE DEBUG ==="
	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		usr << "Destination State:"
		usr << "- Generated: [veil_dest.generated]"
		usr << "- Generating: [veil_dest.generating]"
		usr << "- Cleanup In Progress: [veil_dest.cleanup_in_progress]"
		usr << "- Processing Disabled: [veil_dest.processing_disabled]"
		usr << "- Dungeon Z: [veil_dest.dungeon_z_level]"

		// Check for active processes
		usr << "Active Processes:"
		usr << "- Cleanup: [veil_dest.cleanup_process ? "YES" : "NO"]"
		usr << "- Init: [veil_dest.init_process ? "YES" : "NO"]"
		usr << "- Load: [veil_dest.load_process ? "YES" : "NO"]"

		// Check global destinations
		usr << "Global Destinations: [length(GLOB.portal_destinations)]"
	else
		usr << "No linked portal destination"

/obj/machinery/computer/portal_control/verb/force_cleanup()
	set name = "Force Cleanup"
	set category = "Debug"
	set src in view(1)

	usr << "Forcing cleanup..."
	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		cleanup_portal_simple(veil_dest)
		usr << "Cleanup initiated"
	else
		usr << "No destination to clean up"

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

	// Show the actual gateway location from JSON
	if(last_generation_data && last_generation_data["metadata"])
		var/list/metadata = last_generation_data["metadata"]
		var/list/key_positions = metadata["key_positions"]
		if(key_positions && key_positions["gateway"])
			var/list/gateway = key_positions["gateway"]
			usr << "Gateway location from JSON: [gateway["x"]],[gateway["y"]]"

			var/turf/gateway_turf = locate(gateway["x"], gateway["y"], dungeon_z_level)
			if(gateway_turf)
				usr << "Gateway turf: [AREACOORD(gateway_turf)]"

				var/obj/machinery/portal/found = locate(/obj/machinery/portal) in gateway_turf
				if(found)
					usr << "Portal found at gateway: [AREACOORD(found)]"
				else
					usr << "NO PORTAL found at gateway location!"
		else
			usr << "No gateway position in JSON metadata"

	usr << "=== END DEBUG ==="

/datum/portal_destination/veilbreak/verb/force_reconnect()
	set name = "Force Portal Reconnect"
	set category = "Debug"
	set src in view(1)

	usr << "Forcing portal reconnection..."
	var/result = ensure_portal_connection()
	usr << "Reconnection result: [result ? "SUCCESS" : "FAILED"]"
