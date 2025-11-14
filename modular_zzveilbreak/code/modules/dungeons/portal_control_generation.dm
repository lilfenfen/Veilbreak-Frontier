// modular_zzveilbreak/code/modules/dungeons/portal_control_generation.dm

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	switch(action)
		if("generate_new")
			if(!linked_portal)
				to_chat(user, span_warning("No portal linked! Use the linkup button first."))
				return TRUE

			if(!linked_portal.destination)
				to_chat(user, span_warning("Portal has no destination configured!"))
				return TRUE

			var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination

			if(generation_in_progress)
				to_chat(user, span_warning("Portal stabilization is already in progress!"))
				return TRUE

			if(cleanup_in_progress)
				to_chat(user, span_warning("Portal cleanup is still in progress!"))
				return TRUE

			if(veil_dest.generating)
				to_chat(user, span_warning("Portal stabilization is already in progress!"))
				return TRUE

			if(linked_portal.transport_active)
				to_chat(user, span_warning("Deactivate the current portal before generating a new destination!"))
				return TRUE

			if(!linked_portal.powered())
				to_chat(user, span_warning("Portal has no power! Check power connections."))
				return TRUE

			cached_portal_name = null

			generation_in_progress = TRUE
			start_generation_monitoring()
			force_ui_update()

			var/start_success = veil_dest.start_generation()

			if(!start_success)
				generation_in_progress = FALSE
				stop_generation_monitoring()
				force_ui_update()
				to_chat(user, span_danger("Portal stabilization failed to start due to an error."))
				return TRUE

			if(!veil_dest.generating)
				generation_in_progress = FALSE
				stop_generation_monitoring()
				force_ui_update()
				to_chat(user, span_warning("Portal stabilization failed to start."))
			else
				linked_portal.say("Initiating new portal stabilization...")
				register_generation_callbacks(veil_dest)
			. = TRUE

		if("linkup")
			try_to_linkup()
			force_ui_update()
			return TRUE

		if("deactivate")
			if(linked_portal?.target)
				if(istype(linked_portal.target, /datum/portal_destination/veilbreak))
					var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
					cleanup_portal_simple(veil_dest)
				linked_portal.deactivate()
				cached_portal_name = null

			force_ui_update()
			return TRUE

	return FALSE

/obj/machinery/computer/portal_control/proc/cleanup_portal_simple(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest || QDELETED(veil_dest))
		return

	if(!veil_dest.dungeon_z_level)
		return

	cleanup_in_progress = TRUE
	force_ui_update()

	var/turf/ejection_turf = null
	if(linked_portal && !QDELETED(linked_portal))
		ejection_turf = get_step(linked_portal, SOUTH)
		if(!ejection_turf)
			ejection_turf = get_turf(linked_portal)

	veil_dest.cleanup_z_level_completely(veil_dest.dungeon_z_level, ejection_turf)

	addtimer(CALLBACK(src, .proc/on_cleanup_completed), 5 SECONDS)
