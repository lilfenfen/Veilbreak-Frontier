// modular_zzveilbreak/code/modules/dungeons/portal_control_generation.dm

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	switch(action)
		if("generate_new")
			log_portal_control("DUNGEON DEBUG: Generate button pressed by [key_name(user)] at [AREACOORD(src)]")

			if(!linked_portal)
				to_chat(user, span_warning("No portal linked! Use the linkup button first."))
				return TRUE

			if(!linked_portal.destination)
				to_chat(user, span_warning("Portal has no destination configured!"))
				return TRUE

			var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination

			// Enhanced checks to prevent generation conflicts
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

			log_portal_control("DUNGEON DEBUG: All checks passed, starting generation process")

			// Clear cached name when starting new generation
			cached_portal_name = null

			// Set states BEFORE starting generation - disable button immediately
			generation_in_progress = TRUE
			log_portal_control("DUNGEON DEBUG: Set generation_in_progress = TRUE")

			// Start generation progress monitoring
			start_generation_monitoring()
			log_portal_control("DUNGEON DEBUG: Started generation monitoring")

			// Force immediate UI update to disable button
			force_ui_update()
			log_portal_control("DUNGEON DEBUG: Forced UI update")

			// Start generation with proper error handling
			var/start_success = veil_dest.start_generation()

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
			try_to_linkup()
			force_ui_update()
			return TRUE

		if("deactivate")
			if(linked_portal?.target)
				if(istype(linked_portal.target, /datum/portal_destination/veilbreak))
					var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
					cleanup_portal_simple(veil_dest)
				linked_portal.deactivate()

				// Clear the cached name when deactivating
				cached_portal_name = null

			force_ui_update()
			return TRUE

	return FALSE

/// FORCEFUL CLEANUP - Eject all mobs with throwing force in front of portal
/obj/machinery/computer/portal_control/proc/cleanup_portal_simple(datum/portal_destination/veilbreak/veil_dest)
	log_portal_control("DUNGEON DEBUG: cleanup_portal_simple called")

	if(!veil_dest || QDELETED(veil_dest))
		log_portal_control("DUNGEON DEBUG: Cleanup failed - invalid destination")
		return

	if(!veil_dest.dungeon_z_level)
		log_portal_control("DUNGEON DEBUG: Cleanup failed - no portal Z-level")
		return

	log_portal_control("DUNGEON DEBUG: Starting FORCEFUL cleanup of portal Z-level [veil_dest.dungeon_z_level]")

	// Set cleanup in progress flag
	cleanup_in_progress = TRUE
	force_ui_update()

	// Get area in front of portal for ejection
	var/turf/ejection_turf = null
	if(linked_portal && !QDELETED(linked_portal))
		ejection_turf = get_step(linked_portal, SOUTH)
		if(!ejection_turf)
			ejection_turf = get_turf(linked_portal)
		log_portal_control("DUNGEON DEBUG: Using force ejection turf at [AREACOORD(ejection_turf)]")

	// Use the enhanced cleanup that ejects mobs with force and deletes everything
	veil_dest.cleanup_z_level_completely(veil_dest.dungeon_z_level, ejection_turf)
	log_portal_control("DUNGEON DEBUG: Called veil_dest.cleanup_z_level_completely() with force ejection")

	// Clear the flag after cleanup completes
	addtimer(CALLBACK(src, .proc/on_cleanup_completed), 5 SECONDS)
	log_portal_control("DUNGEON DEBUG: Scheduled cleanup completion timer")
