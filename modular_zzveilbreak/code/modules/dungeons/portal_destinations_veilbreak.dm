// modular_zzveilbreak/code/modules/dungeons/portal_destinations_veilbreak.dm

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

/// Get the gateway turf from JSON metadata with coordinate scaling
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

	// Scale coordinates from 100x100 map to BYOND's 255x255 coordinate system
	var/scaled_x = scale_coordinate(gateway_x, world.maxx)
	var/scaled_y = scale_coordinate(gateway_y, world.maxy)

	log_dungeon("Gateway: Scaled coordinates from [gateway_x],[gateway_y] to [scaled_x],[scaled_y]")

	if(scaled_x < 1 || scaled_x > world.maxx || scaled_y < 1 || scaled_y > world.maxy)
		log_dungeon("Gateway: Scaled gateway coordinates out of bounds: [scaled_x],[scaled_y]")
		return null

	var/turf/gateway_turf = locate(scaled_x, scaled_y, dungeon_z_level)
	if(!gateway_turf)
		log_dungeon("Gateway: Invalid gateway turf at [scaled_x],[scaled_y],[dungeon_z_level]")
		return null

	log_dungeon("Gateway: Using scaled gateway location at [AREACOORD(gateway_turf)]")
	return gateway_turf

/// Scale coordinate from 100x100 map to BYOND's coordinate system
/datum/portal_destination/veilbreak/proc/scale_coordinate(coord, max_coord)
	// The map generator uses a 100x100 coordinate system
	// BYOND uses 255x255 by default
	// Scale proportionally
	var/scaled = round((coord / 100) * max_coord)
	// Ensure we're within bounds
	return clamp(scaled, 1, max_coord)

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

	log_dungeon("Connection: Scanning entire Z-level [dungeon_z_level] for portal")

	// Get the first portal found anywhere on the Z-level
	var/obj/machinery/portal/found_portal = get_any_portal_on_z_level()

	if(found_portal)
		log_dungeon("Connection: Found portal at [AREACOORD(found_portal)]")
		return connect_to_existing_portal(found_portal)
	else
		log_dungeon("Connection: ERROR - No portal found on Z-level [dungeon_z_level]")
		return FALSE

/// Get any portal on the entire Z-level
/datum/portal_destination/veilbreak/proc/get_any_portal_on_z_level()
	log_dungeon("Gateway: Scanning entire Z-level [dungeon_z_level] for any portal")

	var/portals_found = 0
	var/obj/machinery/portal/first_portal = null

	// Scan every turf on the Z-level
	for(var/turf/T in block(locate(1, 1, dungeon_z_level), locate(world.maxx, world.maxy, dungeon_z_level)))
		var/obj/machinery/portal/found_portal = locate(/obj/machinery/portal) in T
		if(found_portal && !QDELETED(found_portal))
			portals_found++
			if(!first_portal)
				first_portal = found_portal
				log_dungeon("Gateway: Found first portal at [AREACOORD(found_portal)]")
			// Don't break - we want to count how many portals exist for logging
		CHECK_TICK

	log_dungeon("Gateway: Found [portals_found] total portals on Z-level [dungeon_z_level]")
	return first_portal

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

	// Create return destination that properly points to the station portal
	var/datum/portal_destination/simple/return_destination = new()
	return_destination.name = "Return to Station"

	// CRITICAL FIX: Ensure the return_portal is set to the actual station portal
	if(connected_portal && !QDELETED(connected_portal))
		return_destination.return_portal = connected_portal
		log_dungeon("Connection: Return destination points to station portal at [AREACOORD(connected_portal)]")
	else
		log_dungeon("Connection: ERROR - No connected portal found for return destination")
		return FALSE

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
