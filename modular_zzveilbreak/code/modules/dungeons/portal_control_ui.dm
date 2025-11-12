// modular_zzveilbreak/code/modules/dungeons/portal_control_ui.dm

/obj/machinery/computer/portal_control/ui_data(mob/user)
	. = list()

	// Basic portal info
	.["portal_present"] = !!linked_portal
	.["portal_status"] = linked_portal ? linked_portal.powered() : FALSE
	.["portal_active"] = linked_portal?.transport_active ? TRUE : FALSE

	// Current target info
	if(linked_portal?.target)
		.["current_target"] = linked_portal.target.get_ui_data()

	// Generation status and cooldown - FIXED: No cooldown, just disable button
	var/can_generate = FALSE
	var/generation_status = "idle"
	var/generation_progress = 0

	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		generation_status = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		generation_progress = veil_dest.generation_progress

		// FIXED: Can generate only if not currently generating and no generation in progress
		if(!generation_in_progress && !veil_dest.generating && !veil_dest.generated)
			can_generate = TRUE

	.["generation_status"] = generation_status
	.["generation_progress"] = generation_progress
	.["portal_name"] = cached_portal_name // FIXED: Use cached name that only updates once
	.["can_generate"] = can_generate
	.["generation_in_progress"] = generation_in_progress

	// Check if data has changed and update UI if needed
	check_and_update_ui(.)

	return .

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
		"portal_name" // FIXED: Include portal name in change detection
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

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	switch(action)
		if("linkup")
			log_portal_control("UI: [key_name(user)] attempted linkup at [AREACOORD(src)]")
			try_to_linkup()
			if(linked_portal)
				log_portal_control("UI: Successfully linked to portal at [AREACOORD(linked_portal)]")
			// Force UI update after linkup
			force_ui_update()
			. = TRUE
		if("deactivate")
			if(linked_portal?.target)
				log_portal_control("UI: [key_name(user)] deactivating portal from [linked_portal.target.name] at [AREACOORD(src)]")
				if(istype(linked_portal.target, /datum/portal_destination/veilbreak))
					var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
					cleanup_portal_simple(veil_dest)
				linked_portal.deactivate()
			// Force UI update after deactivation
			force_ui_update()
			. = TRUE

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
