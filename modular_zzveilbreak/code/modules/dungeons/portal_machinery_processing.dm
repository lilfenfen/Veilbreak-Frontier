// modular_zzveilbreak/code/modules/dungeons/portal_machinery_processing.dm

/obj/machinery/portal/process()
	if(is_dungeon_portal())
		handle_dungeon_portal_processing()
	else
		handle_station_portal_processing()

	if(transport_active && !bumper)
		generate_bumper()

/obj/machinery/portal/proc/handle_dungeon_portal_processing()
	portal_possible = TRUE
	if(target && !transport_active)
		transport_active = TRUE
		update_appearance()

/obj/machinery/portal/proc/handle_station_portal_processing()
	if((machine_stat & NOPOWER) && use_power)
		portal_possible = FALSE
		if(target)
			// NEW: Trigger cleanup on power failure
			handle_power_failure_cleanup()
		return

	var/was_possible = portal_possible
	portal_possible = check_destination_availability()

	if(was_possible != portal_possible)
		update_appearance()

	if(portal_possible && !target && !transport_active)
		activate_to_available_destination()

/obj/machinery/portal/proc/check_destination_availability()
	for(var/destination_key in GLOB.portal_destinations)
		var/datum/portal_destination/possible_destination = GLOB.portal_destinations[destination_key]
		if(!istype(possible_destination))
			continue
		if(valid_destination(possible_destination) && possible_destination.is_available())
			return TRUE
	return FALSE

/obj/machinery/portal/proc/valid_destination(datum/portal_destination/possible_destination)
	return possible_destination != destination

/obj/machinery/portal/proc/activate_to_available_destination()
	for(var/destination_key in GLOB.portal_destinations)
		var/datum/portal_destination/possible_destination = GLOB.portal_destinations[destination_key]
		if(!istype(possible_destination))
			continue
		if(valid_destination(possible_destination) && possible_destination.is_available())
			activate(possible_destination)
			break

/obj/machinery/portal/proc/handle_power_failure_cleanup()
	if(!target || cleanup_in_progress)
		return

	cleanup_in_progress = TRUE

	// Notify anyone nearby
	visible_message(span_danger("[src] shuts down due to power failure! Initiating emergency cleanup..."))
	playsound(src, 'sound/machines/gateway/gateway_close.ogg', 100, TRUE)

	// If it's a veilbreak destination, trigger proper cleanup with power_failure flag
	if(istype(target, /datum/portal_destination/veilbreak))
		var/datum/portal_destination/veilbreak/veil_dest = target
		addtimer(CALLBACK(veil_dest, /datum/portal_destination/veilbreak.proc/cleanup_z_level_completely, veil_dest.dungeon_z_level, get_ejection_turf(), TRUE), 3 SECONDS)  // NEW: power_failure = TRUE

	// Deactivate the portal after a short delay
	addtimer(CALLBACK(src, .proc/deactivate_after_power_failure), 5 SECONDS)

/obj/machinery/portal/proc/deactivate_after_power_failure()
	deactivate()
	cleanup_in_progress = FALSE

/obj/machinery/portal/proc/get_ejection_turf()
	var/turf/primary_turf = get_step(src, SOUTH)
	if(!primary_turf)
		primary_turf = get_turf(src)
	return primary_turf
