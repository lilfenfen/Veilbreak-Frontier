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
			deactivate()
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
