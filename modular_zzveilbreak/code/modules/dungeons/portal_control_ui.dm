// modular_zzveilbreak/code/modules/dungeons/portal_control_ui.dm

/obj/machinery/computer/portal_control/ui_data(mob/user)
	var/list/data = list()

	data["portal_present"] = !!linked_portal && !QDELETED(linked_portal)
	data["portal_status"] = data["portal_present"] ? linked_portal.powered() : FALSE
	data["portal_active"] = data["portal_present"] ? (linked_portal.transport_active ? TRUE : FALSE) : FALSE

	// NEW: Add power failure state
	data["power_failure"] = data["portal_present"] ? (linked_portal.machine_stat & NOPOWER) : FALSE

	// Improved current target detection with better name handling
	if(data["portal_present"] && linked_portal.target && !QDELETED(linked_portal.target))
		var/target_name = linked_portal.target.name
		// Use cached name if available, otherwise use target name
		if(cached_portal_name)
			data["current_target"] = list("name" = cached_portal_name)
		else if(target_name && target_name != "0" && target_name != "")
			data["current_target"] = list("name" = target_name)
		else
			data["current_target"] = list("name" = "Quantum Pocket Space")
	else
		data["current_target"] = null

	data["generation_status"] = "idle"
	data["generation_progress"] = 0
	data["generation_in_progress"] = generation_in_progress
	data["cleanup_in_progress"] = cleanup_in_progress

	if(data["portal_present"] && linked_portal.destination && !QDELETED(linked_portal.destination))
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		if(veil_dest.generating && !generation_in_progress)
			generation_in_progress = TRUE
			start_generation_monitoring()

		data["generation_status"] = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		data["generation_progress"] = veil_dest.generation_progress

	// CRITICAL FIX: Update can_generate to be more strict
	data["can_generate"] = !generation_in_progress && !cleanup_in_progress && data["portal_present"] && linked_portal.destination && !data["portal_active"] && data["portal_status"] && !data["power_failure"] && (data["generation_status"] == "idle")

	// Better portal name handling - ensure we always have the correct name when portal is active
	data["portal_name"] = null
	if(data["portal_active"] || (linked_portal?.destination?.generated))
		// Always try to get the most current name
		if(linked_portal.target && istype(linked_portal.target, /datum/portal_destination/veilbreak))
			var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
			data["portal_name"] = get_portal_name(veil_dest)
			// Update cache if needed
			if(data["portal_name"] && data["portal_name"] != cached_portal_name)
				cached_portal_name = data["portal_name"]
		else if(cached_portal_name)
			data["portal_name"] = cached_portal_name

	return data

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	switch(action)
		if("generate_new")
			// CRITICAL FIX: Double-check generation state before proceeding
			if(generation_in_progress || cleanup_in_progress)
				to_chat(user, span_warning("Portal operation already in progress!"))
				return TRUE

			if(!linked_portal)
				to_chat(user, span_warning("No portal linked! Use the linkup button first."))
				return TRUE

			if(!linked_portal.destination)
				to_chat(user, span_warning("Portal has no destination configured!"))
				return TRUE

			var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination

			// CRITICAL FIX: Additional backend state validation
			if(veil_dest.generating || veil_dest.generated)
				to_chat(user, span_warning("Portal destination is already being generated or is active!"))
				return TRUE

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

			// CRITICAL FIX: Set generation_in_progress IMMEDIATELY to prevent multiple clicks
			generation_in_progress = TRUE
			cached_portal_name = null

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
