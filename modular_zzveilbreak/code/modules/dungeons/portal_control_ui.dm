// modular_zzveilbreak/code/modules/dungeons/portal_control_ui.dm

/obj/machinery/computer/portal_control/ui_data(mob/user)
	var/list/data = list()

	// Basic portal info
	data["portal_present"] = !!linked_portal
	data["portal_status"] = linked_portal ? linked_portal.powered() : FALSE
	data["portal_active"] = linked_portal?.transport_active ? TRUE : FALSE

	// Current target
	if(linked_portal?.target)
		data["current_target"] = linked_portal.target.get_ui_data()
	else
		data["current_target"] = list()

	// Generation status - FIXED: Proper state management
	data["generation_in_progress"] = generation_in_progress

	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		data["generation_status"] = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		data["generation_progress"] = veil_dest.generation_progress

		// Can only generate if not currently doing anything
		data["can_generate"] = !generation_in_progress && !veil_dest.generating && !veil_dest.generated
	else
		data["generation_status"] = "error"
		data["can_generate"] = FALSE

	data["portal_name"] = cached_portal_name

	// Update last known state
	last_ui_data = data.Copy()

	return data

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

			// FIXED: Comprehensive state checks
			if(generation_in_progress || veil_dest.generating)
				to_chat(user, span_warning("Portal stabilization is already in progress!"))
				return TRUE

			if(linked_portal.transport_active)
				to_chat(user, span_warning("Deactivate the current portal before generating a new destination!"))
				return TRUE

			// FIXED: Set all states BEFORE starting generation
			generation_in_progress = TRUE
			cached_portal_name = null

			// Start monitoring
			start_generation_monitoring()

			// Force immediate UI update to disable button
			force_ui_update()

			// Start generation with error handling
			var/start_success = veil_dest.start_generation()

			if(!start_success || !veil_dest.generating)
				// Generation failed to start
				generation_in_progress = FALSE
				stop_generation_monitoring()
				force_ui_update()
				to_chat(user, span_danger("Portal stabilization failed to start."))
			else
				linked_portal.say("Initiating new portal stabilization...")
				register_generation_callbacks(veil_dest)

			return TRUE

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
			force_ui_update()
			return TRUE

	return FALSE

/// Check if UI data has changed and trigger update if needed
/obj/machinery/computer/portal_control/proc/check_and_update_ui(list/current_data)
	// If data is different from last known state, update UI
	if(!compare_ui_data(last_ui_data, current_data))
		last_ui_data = current_data.Copy()
		SStgui.update_uis(src)
		return TRUE
	return FALSE

/// Compare two UI data sets for significant changes
/obj/machinery/computer/portal_control/proc/compare_ui_data(list/old_data, list/new_data)
	if(!old_data || !new_data)
		return FALSE

	// Check key fields that should trigger updates
	var/check_fields = list(
		"portal_present",
		"portal_status",
		"portal_active",
		"generation_status",
		"generation_progress",
		"can_generate",
		"generation_in_progress",
		"portal_name"
	)

	for(var/field in check_fields)
		if(old_data[field] != new_data[field])
			return FALSE

	// Check current_target changes
	var/old_target = old_data["current_target"]
	var/new_target = new_data["current_target"]
	if((old_target && !new_target) || (!old_target && new_target))
		return FALSE
	if(old_target && new_target && old_target["name"] != new_target["name"])
		return FALSE

	return TRUE

/// Retrieve portal name from the destination data - called once when generation completes
/obj/machinery/computer/portal_control/proc/get_portal_name(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest || !veil_dest.generated)
		return generate_fallback_name()

	// FIXED: Use the map name directly from JSON metadata
	if(veil_dest.last_generation_data)
		var/list/metadata = veil_dest.last_generation_data["metadata"]
		if(metadata && metadata["map_name"])
			var/map_name = metadata["map_name"]
			log_portal_control("Portal Name: Using map name from JSON: [map_name]")
			return map_name

	// Fallback if no map name in metadata
	return generate_fallback_name()

/obj/machinery/computer/portal_control/proc/generate_fallback_name()
	return "Veilbreak Dungeon [rand(1000,9999)]"
