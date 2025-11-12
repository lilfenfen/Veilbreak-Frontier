// modular_zzveilbreak/code/modules/dungeons/portal_machinery_processing.dm

/// Main processing - handles power state and destination availability
/obj/machinery/portal/process()
	if(is_dungeon_portal())
		handle_dungeon_portal_processing()
	else
		handle_station_portal_processing()

	// Ensure bumper exists when portal is active
	if(transport_active && !bumper)
		generate_bumper()

/// Processing logic for dungeon portals (always active, no power required)
/obj/machinery/portal/proc/handle_dungeon_portal_processing()
	portal_possible = TRUE
	if(target && !transport_active)
		transport_active = TRUE
		update_appearance()

/// Processing logic for station portals (power-dependent)
/obj/machinery/portal/proc/handle_station_portal_processing()
	// Check power state
	if((machine_stat & NOPOWER) && use_power)
		if(portal_possible)
			log_portal("Process: Lost power at [AREACOORD(src)]")
		portal_possible = FALSE
		if(target)
			deactivate()
		return

	// Check destination availability
	var/was_possible = portal_possible
	portal_possible = check_destination_availability()

	if(was_possible != portal_possible)
		log_portal("Process: Destination availability changed to [portal_possible] at [AREACOORD(src)]")
		update_appearance()

	// Auto-activate station portal when destination becomes available
	if(portal_possible && !target && !transport_active)
		activate_to_available_destination()

/// Check if any valid destinations are available
/obj/machinery/portal/proc/check_destination_availability()
	for(var/destination_key in GLOB.portal_destinations)
		var/datum/portal_destination/possible_destination = GLOB.portal_destinations[destination_key]
		if(!istype(possible_destination))
			log_portal("Availability: WARNING - Invalid destination found in global list: [destination_key]")
			continue
		if(valid_destination(possible_destination) && possible_destination.is_available())
			return TRUE
	return FALSE

/// Check if a destination is valid for this portal
/obj/machinery/portal/proc/valid_destination(datum/portal_destination/possible_destination)
	return possible_destination != destination

/// Auto-activate to first available destination
/obj/machinery/portal/proc/activate_to_available_destination()
	log_portal("Activate: Attempting auto-activation to available destination")
	for(var/destination_key in GLOB.portal_destinations)
		var/datum/portal_destination/possible_destination = GLOB.portal_destinations[destination_key]
		if(!istype(possible_destination))
			continue
		if(valid_destination(possible_destination) && possible_destination.is_available())
			log_portal("Activate: Found valid destination [possible_destination.name], activating")
			activate(possible_destination)
			break
