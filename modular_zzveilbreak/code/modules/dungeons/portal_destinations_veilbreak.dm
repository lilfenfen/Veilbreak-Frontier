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
	var/obj/machinery/computer/portal_control/connected_control_computer
	var/cleanup_in_progress = FALSE
	var/processing_disabled = FALSE
	var/turf/actual_dungeon_portal_location = null

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
		return null

	if(actual_dungeon_portal_location && !QDELETED(actual_dungeon_portal_location))
		return actual_dungeon_portal_location

	return locate(round(world.maxx/2), round(world.maxy/2), dungeon_z_level)

/datum/portal_destination/veilbreak/proc/initialize_portal_z_level()
	if(GLOB.portal_dungeon_z_level)
		dungeon_z_level = GLOB.portal_dungeon_z_level
		return TRUE

	// Check if subsystems are ready
	if(!subsystems_ready_for_portals())
		return FALSE

	// CRITICAL: Use the mapping subsystem's proper method to add a new Z-level
	var/datum/space_level/new_level = SSmapping.add_new_zlevel("Portal Dungeon", list(ZTRAIT_AWAY = TRUE, ZTRAIT_MINING = TRUE))
	if(!new_level)
		return FALSE

	GLOB.portal_dungeon_z_level = new_level.z_value
	dungeon_z_level = GLOB.portal_dungeon_z_level

	// CRITICAL: Let the mapping subsystem fully initialize the Z-level
	SSmapping.manage_z_level(new_level, TRUE, TRUE) // filled_with_space = TRUE, contain_turfs = TRUE

	// Force area initialization for the new Z-level
	SSmapping.build_area_turfs(dungeon_z_level, TRUE)

	return TRUE

// REMOVED: generation_failed proc from this file since it's defined in portal_destinations_generation.dm

/datum/portal_destination/veilbreak/proc/ensure_portal_connection()
	if(!dungeon_z_level)
		return FALSE

	var/obj/machinery/portal/found_portal = get_any_portal_on_z_level()

	if(found_portal)
		actual_dungeon_portal_location = get_turf(found_portal)
		return connect_to_existing_portal(found_portal)
	else
		return create_fallback_portal()

/datum/portal_destination/veilbreak/proc/get_any_portal_on_z_level()
	var/obj/machinery/portal/first_portal = null

	for(var/turf/T in block(locate(1, 1, dungeon_z_level), locate(world.maxx, world.maxy, dungeon_z_level)))
		var/obj/machinery/portal/found_portal = locate(/obj/machinery/portal) in T
		if(found_portal && !QDELETED(found_portal))
			if(!first_portal)
				first_portal = found_portal
		CHECK_TICK

	return first_portal

/datum/portal_destination/veilbreak/proc/create_fallback_portal()
	var/turf/center_turf = locate(round(world.maxx/2), round(world.maxy/2), dungeon_z_level)

	if(!center_turf)
		return FALSE

	var/obj/machinery/portal/fallback_portal = new(center_turf)
	fallback_portal.use_power = NO_POWER_USE
	fallback_portal.portal_possible = TRUE
	fallback_portal.generate_bumper()

	actual_dungeon_portal_location = center_turf

	return connect_to_existing_portal(fallback_portal)

/datum/portal_destination/veilbreak/proc/connect_to_existing_portal(obj/machinery/portal/dungeon_portal)
	if(!dungeon_portal || QDELETED(dungeon_portal))
		return FALSE

	dungeon_portal.use_power = NO_POWER_USE
	dungeon_portal.portal_possible = TRUE

	if(!dungeon_portal.bumper)
		dungeon_portal.generate_bumper()

	var/datum/portal_destination/simple/return_destination = new()
	return_destination.name = "Return to Station"

	if(connected_portal && !QDELETED(connected_portal))
		return_destination.return_portal = connected_portal
	else
		return FALSE

	var/return_id = "veilbreak_return_[dungeon_z_level]_[world.time]"
	GLOB.portal_destinations[return_id] = return_destination

	dungeon_portal.target = return_destination
	dungeon_portal.transport_active = TRUE
	dungeon_portal.update_appearance()

	if(connected_portal && !QDELETED(connected_portal))
		connected_portal.target = src
		connected_portal.transport_active = TRUE
		connected_portal.update_appearance()

		return TRUE

	return FALSE
