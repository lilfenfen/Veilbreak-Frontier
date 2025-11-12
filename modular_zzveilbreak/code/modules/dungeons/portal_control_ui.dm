// modular_zzveilbreak/code/modules/dungeons/portal_control_ui.dm

/obj/machinery/computer/portal_control/ui_data(mob/user)
	log_portal_control("DUNGEON DEBUG: ui_data() called by [key_name(user)]")

	. = list()

	// Basic portal info
	.["portal_present"] = !!linked_portal
	.["portal_status"] = linked_portal ? linked_portal.powered() : FALSE
	.["portal_active"] = linked_portal?.transport_active ? TRUE : FALSE

	// FIX: Initialize current_target to empty list if none exists
	if(linked_portal?.target)
		.["current_target"] = linked_portal.target.get_ui_data()
	else
		.["current_target"] = list()

	// Generation status - FIX: Handle case where destination doesn't exist
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
	else
		// FIX: Handle case where destination doesn't exist yet
		generation_status = "error"
		can_generate = FALSE

	.["generation_status"] = generation_status
	.["generation_progress"] = generation_progress
	.["portal_name"] = cached_portal_name
	.["can_generate"] = can_generate
	.["generation_in_progress"] = generation_in_progress

	log_portal_control("DUNGEON DEBUG: UI Data - can_generate: [can_generate], generation_status: [generation_status], generation_in_progress: [generation_in_progress]")

	// Check if data has changed and update UI if needed
	check_and_update_ui(.)

	return .

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	log_portal_control("DUNGEON DEBUG: ui_act() called with action: [action]")
	log_portal_control("DUNGEON DEBUG: Action params: [json_encode(params)]")

	. = ..()
	if(.)
		log_portal_control("DUNGEON DEBUG: Action handled by parent, returning")
		return

	var/mob/user = usr

	switch(action)
		if("generate_new")
			log_portal_control("DUNGEON DEBUG: generate_new action received!")
			// DUNGEON DEBUG: Start comprehensive logging
			log_portal_control("DUNGEON DEBUG: Generate button pressed by [key_name(user)] at [AREACOORD(src)]")
			log_portal_control("DUNGEON DEBUG: linked_portal: [linked_portal ? "YES at [AREACOORD(linked_portal)]" : "NO"]")

			if(!linked_portal)
				to_chat(user, span_warning("No portal linked! Use the linkup button first."))
				log_portal_control("DUNGEON DEBUG: Generation failed - no linked portal")
				return TRUE

			if(!linked_portal.destination)
				to_chat(user, span_warning("Portal has no destination configured!"))
				log_portal_control("DUNGEON DEBUG: Generation failed - portal has no destination")
				return TRUE

			var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination

			// DUNGEON DEBUG: Log current state
			log_portal_control("DUNGEON DEBUG: Portal destination state:")
			log_portal_control("DUNGEON DEBUG: - generating: [veil_dest.generating]")
			log_portal_control("DUNGEON DEBUG: - generated: [veil_dest.generated]")
			log_portal_control("DUNGEON DEBUG: - progress: [veil_dest.generation_progress]")
			log_portal_control("DUNGEON DEBUG: - dungeon_z_level: [veil_dest.dungeon_z_level]")
			log_portal_control("DUNGEON DEBUG: - processing_disabled: [veil_dest.processing_disabled]")

			// Enhanced checks to prevent generation conflicts
			if(generation_in_progress)
				to_chat(user, span_warning("Portal stabilization is already in progress!"))
				log_portal_control("DUNGEON DEBUG: Generation blocked - generation_in_progress is TRUE")
				return TRUE

			if(veil_dest.generating)
				to_chat(user, span_warning("Portal stabilization is already in progress!"))
				log_portal_control("DUNGEON DEBUG: Generation blocked - veil_dest.generating is TRUE")
				return TRUE

			if(linked_portal.transport_active)
				to_chat(user, span_warning("Deactivate the current portal before generating a new destination!"))
				log_portal_control("DUNGEON DEBUG: Generation blocked - portal is active")
				return TRUE

			log_portal_control("DUNGEON DEBUG: All checks passed, starting generation process")

			// Clear cached name when starting new generation
			cached_portal_name = null

			// FIXED: Set states BEFORE starting generation - disable button immediately
			generation_in_progress = TRUE
			log_portal_control("DUNGEON DEBUG: Set generation_in_progress = TRUE")

			// Start generation progress monitoring
			start_generation_monitoring()
			log_portal_control("DUNGEON DEBUG: Started generation monitoring")

			// Force immediate UI update to disable button
			force_ui_update()
			log_portal_control("DUNGEON DEBUG: Forced UI update")

			// DUNGEON DEBUG: Before calling start_generation
			log_portal_control("DUNGEON DEBUG: Calling veil_dest.start_generation()...")

			// Start generation with proper error handling
			var/start_success = veil_dest.start_generation()

			// DUNGEON DEBUG: After calling start_generation
			log_portal_control("DUNGEON DEBUG: start_generation() returned: [start_success]")
			log_portal_control("DUNGEON DEBUG: veil_dest.generating is now: [veil_dest.generating]")
			log_portal_control("DUNGEON DEBUG: veil_dest.current_request_id: [veil_dest.current_request_id]")

			if(!start_success)
				log_portal_control("DUNGEON DEBUG: Generation failed to start - start_success is FALSE")
				generation_in_progress = FALSE
				stop_generation_monitoring()
				force_ui_update()
				to_chat(user, span_danger("Portal stabilization failed to start due to an error."))
				return TRUE

			if(!veil_dest.generating)
				// Generation failed to start properly
				log_portal_control("DUNGEON DEBUG: Generation failed - veil_dest.generating is still FALSE after start_generation()")
				generation_in_progress = FALSE
				stop_generation_monitoring()
				force_ui_update()
				to_chat(user, span_warning("Portal stabilization failed to start."))
			else
				linked_portal.say("Initiating new portal stabilization...")
				log_portal_control("DUNGEON DEBUG: Generation started successfully!")

				// Register for generation completion callbacks
				register_generation_callbacks(veil_dest)
				log_portal_control("DUNGEON DEBUG: Registered generation callbacks")
			. = TRUE

		if("linkup")
			log_portal_control("DUNGEON DEBUG: linkup action received")
			log_portal_control("UI: [key_name(user)] attempted linkup at [AREACOORD(src)]")
			try_to_linkup()
			if(linked_portal)
				log_portal_control("UI: Successfully linked to portal at [AREACOORD(linked_portal)]")
			// Force UI update after linkup
			force_ui_update()
			. = TRUE
		if("deactivate")
			log_portal_control("DUNGEON DEBUG: deactivate action received")
			if(linked_portal?.target)
				log_portal_control("UI: [key_name(user)] deactivating portal from [linked_portal.target.name] at [AREACOORD(src)]")
				if(istype(linked_portal.target, /datum/portal_destination/veilbreak))
					var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
					cleanup_portal_simple(veil_dest)
				linked_portal.deactivate()
			// Force UI update after deactivation
			force_ui_update()
			. = TRUE

	log_portal_control("DUNGEON DEBUG: ui_act() returning: [.]")
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
