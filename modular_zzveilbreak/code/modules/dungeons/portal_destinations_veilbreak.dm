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
	/// Prevent multiple simultaneous cleanups
	var/cleanup_in_progress = FALSE
	/// Prevent processing during cleanup
	var/processing_disabled = FALSE

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
		log_dungeon("TargetTurf: No dungeon Z-level assigned")
		return null

	// Use the gateway location from JSON metadata
	var/turf/gateway_turf = get_gateway_turf_from_metadata()
	if(gateway_turf)
		log_dungeon("TargetTurf: Using gateway location from JSON at [AREACOORD(gateway_turf)]")
		return gateway_turf

	// Fallback to center if no gateway found
	log_dungeon("TargetTurf: No gateway location, using center as fallback")
	return locate(round(world.maxx/2), round(world.maxy/2), dungeon_z_level)

/// Get the gateway turf from JSON metadata
/datum/portal_destination/veilbreak/proc/get_gateway_turf_from_metadata()
	if(!last_generation_data || !islist(last_generation_data["metadata"]))
		log_dungeon("Gateway: No generation data available")
		return null

	var/list/metadata = last_generation_data["metadata"]
	if(!islist(metadata["key_positions"]) || !islist(metadata["key_positions"]["gateway"]))
		log_dungeon("Gateway: No gateway position in metadata")
		return null

	var/list/gateway_pos = metadata["key_positions"]["gateway"]
	var/gateway_x = gateway_pos["x"]
	var/gateway_y = gateway_pos["y"]

	// Validate coordinates are numbers
	if(!isnum(gateway_x) || !isnum(gateway_y))
		log_dungeon("Gateway: Invalid gateway coordinates: x=[gateway_x], y=[gateway_y]")
		return null

	if(gateway_x < 1 || gateway_x > world.maxx || gateway_y < 1 || gateway_y > world.maxy)
		log_dungeon("Gateway: Gateway coordinates out of bounds: [gateway_x],[gateway_y]")
		return null

	var/turf/gateway_turf = locate(gateway_x, gateway_y, dungeon_z_level)
	if(!gateway_turf)
		log_dungeon("Gateway: Invalid gateway turf at [gateway_x],[gateway_y],[dungeon_z_level]")
		return null

	log_dungeon("Gateway: Using pre-determined gateway location at [AREACOORD(gateway_turf)]")
	return gateway_turf

/// Initialize or get the reusable portal Z-level
/datum/portal_destination/veilbreak/proc/initialize_portal_z_level()
	log_dungeon("DUNGEON DEBUG: initialize_portal_z_level() called - current world.maxz: [world.maxz]")

	// If we already have a reusable Z-level, use it
	if(GLOB.portal_dungeon_z_level)
		dungeon_z_level = GLOB.portal_dungeon_z_level
		log_dungeon("ZLevel: Using existing reusable portal Z-level [dungeon_z_level]")
		return TRUE

	// First time - create a new Z-level
	log_dungeon("ZLevel: Creating new Z-level for portal dungeons")

	// Use SSmapping to add a new Z-level
	var/datum/space_level/new_level = SSmapping.add_new_zlevel("Portal Dungeon", list(ZTRAIT_AWAY = TRUE))
	if(!new_level)
		log_dungeon("ZLevel: ERROR - Failed to create new Z-level")
		return FALSE

	// Store the new Z-level NUMBER for reuse, not the datum
	GLOB.portal_dungeon_z_level = new_level.z_value
	dungeon_z_level = GLOB.portal_dungeon_z_level

	log_dungeon("ZLevel: SUCCESS - Created new reusable portal Z-level [dungeon_z_level]")
	return TRUE

/// Get dungeon statistics for UI display
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

/// Validate destination state
/datum/portal_destination/veilbreak/proc/validate_state()
	if(generating && generated)
		log_dungeon("State: WARNING - Portal in invalid state (both generating and generated)")
		return FALSE
	if(dungeon_z_level > world.maxz)
		log_dungeon("State: WARNING - Dungeon Z-level [dungeon_z_level] exceeds world maxz [world.maxz]")
		return FALSE
	return TRUE

/datum/portal_destination/veilbreak/proc/generation_failed(reason)
	log_dungeon("DUNGEON DEBUG: generation_failed() called with reason: [reason]")
	generating = FALSE
	generated = FALSE
	generation_progress = 0
	log_dungeon("DUNGEON DEBUG: Reset generation state")

	if(connected_portal && !QDELETED(connected_portal))
		log_dungeon("DUNGEON DEBUG: Notifying portal of failure")
		connected_portal.say("Dungeon generation failed: [reason]")

	// Notify control computer of failure
	if(connected_control_computer && !QDELETED(connected_control_computer))
		log_dungeon("DUNGEON DEBUG: Notifying control computer of failure")
		connected_control_computer.on_generation_failed(reason)
		connected_control_computer = null

/datum/portal_destination/veilbreak/proc/ensure_portal_connection()
	if(!dungeon_z_level)
		log_dungeon("Connection: Cannot ensure connection - no Z-level assigned")
		return FALSE

	log_dungeon("Connection: Using pre-determined gateway location from JSON")

	// Get the portal at the exact gateway location from JSON
	var/obj/machinery/portal/found_portal = get_portal_from_gateway_location()

	if(found_portal)
		log_dungeon("Connection: Found portal at gateway location [AREACOORD(found_portal)]")
		return connect_to_existing_portal(found_portal)
	else
		log_dungeon("Connection: ERROR - No portal found at gateway location")
		return FALSE

/// Get portal from the pre-determined gateway location from JSON with ±5 tile scanning
/datum/portal_destination/veilbreak/proc/get_portal_from_gateway_location()
	if(!last_generation_data || !last_generation_data["metadata"])
		log_dungeon("Gateway: No generation data available")
		return null

	var/list/metadata = last_generation_data["metadata"]
	var/list/key_positions = metadata["key_positions"]

	if(!key_positions || !key_positions["gateway"])
		log_dungeon("Gateway: No gateway position in metadata")
		return null

	var/list/gateway_pos = key_positions["gateway"]
	var/gateway_x = gateway_pos["x"]
	var/gateway_y = gateway_pos["y"]

	if(!gateway_x || !gateway_y)
		log_dungeon("Gateway: Invalid gateway coordinates: x=[gateway_x], y=[gateway_y]")
		return null

	// Look for portal at the exact gateway location first
	var/turf/gateway_turf = locate(gateway_x, gateway_y, dungeon_z_level)
	if(gateway_turf)
		var/obj/machinery/portal/found_portal = locate(/obj/machinery/portal) in gateway_turf
		if(found_portal)
			log_dungeon("Gateway: Found portal at exact location [AREACOORD(found_portal)]")
			return found_portal

	// If not found at exact location, scan ±5 tiles around
	log_dungeon("Gateway: No portal at exact location, scanning ±5 tiles around [gateway_x],[gateway_y]")

	var/scan_range = 5
	var/min_x = max(1, gateway_x - scan_range)
	var/max_x = min(world.maxx, gateway_x + scan_range)
	var/min_y = max(1, gateway_y - scan_range)
	var/max_y = min(world.maxy, gateway_y + scan_range)

	for(var/x = min_x to max_x)
		for(var/y = min_y to max_y)
			var/turf/check_turf = locate(x, y, dungeon_z_level)
			if(check_turf)
				var/obj/machinery/portal/found_portal = locate(/obj/machinery/portal) in check_turf
				if(found_portal)
					log_dungeon("Gateway: Found portal at scanned location [AREACOORD(found_portal)] (offset: [x-gateway_x],[y-gateway_y])")
					return found_portal
			CHECK_TICK

	log_dungeon("Gateway: No portal found in ±[scan_range] tile area around [gateway_x],[gateway_y],[dungeon_z_level]")
	return null

/datum/portal_destination/veilbreak/proc/connect_to_existing_portal(obj/machinery/portal/dungeon_portal)
	if(!dungeon_portal || QDELETED(dungeon_portal))
		log_dungeon("Connection: Invalid dungeon portal")
		return FALSE

	log_dungeon("Connection: Connecting to existing portal at [AREACOORD(dungeon_portal)]")

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
	log_dungeon("Connection: Registered return destination [return_id]")

	// Configure the dungeon portal to target the return destination
	dungeon_portal.target = return_destination
	dungeon_portal.transport_active = TRUE
	dungeon_portal.update_appearance()

	log_dungeon("Connection: Dungeon portal configured at [AREACOORD(dungeon_portal)]")

	// Configure the station portal to target this dungeon
	if(connected_portal && !QDELETED(connected_portal))
		connected_portal.target = src
		connected_portal.transport_active = TRUE
		connected_portal.update_appearance()

		log_dungeon("Connection: SUCCESS - Bidirectional connection established!")
		log_dungeon("Connection: Station -> Dungeon: [AREACOORD(connected_portal)]")
		log_dungeon("Connection: Dungeon -> Station: [AREACOORD(dungeon_portal)]")
		return TRUE

	log_dungeon("Connection: WARNING - No connected portal found for station side")
	return FALSE
