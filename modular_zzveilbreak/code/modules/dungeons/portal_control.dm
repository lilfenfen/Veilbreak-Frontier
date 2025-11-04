// modular_zzveilbreak/code/modules/dungeons/portal_control.dm

/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new destinations beyond the veil."
	icon_screen = "gateway"
	icon_keyboard = "teleport_key"
	var/obj/machinery/portal/linked_portal
	/// Cooldown to prevent spam
	var/next_generate_attempt = 0
	/// Time between generate attempts in seconds
	var/generate_cooldown = 30
	/// Track if we're currently generating to prevent double-starts
	var/generation_in_progress = FALSE
	/// Last known UI data state for change detection
	var/list/last_ui_data = list()
	/// Timer for generation progress updates
	var/generation_progress_timer

// Helper proc for portal control logging
/proc/log_portal_control(text)
	log_game(text, list(), LOG_GAME)

/obj/machinery/computer/portal_control/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	try_to_linkup()

/obj/machinery/computer/portal_control/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PortalControl", name)
		ui.open()

	log_portal_control("Portal Control: [key_name(user)] opened UI at [AREACOORD(src)]")
	return TRUE

/obj/machinery/computer/portal_control/ui_data(mob/user)
	. = list()

	// Basic portal info
	.["portal_present"] = !!linked_portal
	.["portal_status"] = linked_portal ? linked_portal.powered() : FALSE
	.["portal_active"] = linked_portal?.transport_active ? TRUE : FALSE

	// Current target info
	if(linked_portal?.target)
		.["current_target"] = linked_portal.target.get_ui_data()

	// Generation status and cooldown
	var/can_generate = FALSE
	var/generation_status = "idle"
	var/generation_progress = 0
	var/portal_name = null

	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		generation_status = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		generation_progress = veil_dest.generation_progress

		// Get portal name from the destination data
		portal_name = get_portal_name(veil_dest)

		// Check if we can generate
		if(!generation_in_progress && !veil_dest.generating && world.time >= next_generate_attempt)
			can_generate = TRUE

	.["generation_status"] = generation_status
	.["generation_progress"] = generation_progress
	.["portal_name"] = portal_name
	.["can_generate"] = can_generate
	.["generation_cooldown"] = max(0, next_generate_attempt - world.time) / 10
	.["generate_cooldown"] = generate_cooldown
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
		"generation_cooldown",
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

/// Force a UI update (for when we know something important changed)
/obj/machinery/computer/portal_control/proc/force_ui_update()
	last_ui_data = list() // Force update by clearing last state
	SStgui.update_uis(src)

/// Start monitoring generation progress with periodic updates
/obj/machinery/computer/portal_control/proc/start_generation_monitoring()
	if(generation_progress_timer)
		deltimer(generation_progress_timer)

	// Update every 0.5 seconds during generation for progress bar
	generation_progress_timer = addtimer(CALLBACK(src, .proc/update_generation_progress), 0.5 SECONDS, TIMER_STOPPABLE)

/// Stop generation progress monitoring
/obj/machinery/computer/portal_control/proc/stop_generation_monitoring()
	if(generation_progress_timer)
		deltimer(generation_progress_timer)
		generation_progress_timer = null

/// Update generation progress (called during generation)
/obj/machinery/computer/portal_control/proc/update_generation_progress()
	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		if(veil_dest.generating)
			// Force UI update to show progress
			force_ui_update()
			// Continue monitoring
			start_generation_monitoring()
		else
			// Generation finished, do final update
			force_ui_update()
			stop_generation_monitoring()

/// Retrieve portal name from the destination data
/obj/machinery/computer/portal_control/proc/get_portal_name(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest || !veil_dest.generated)
		return null

	// Try to get stats from the destination first
	var/list/stats = veil_dest.get_dungeon_stats()
	if(stats && stats["name"])
		return stats["name"]

	// Try to get name from last generation data
	if(veil_dest.last_generation_data)
		var/list/metadata = veil_dest.last_generation_data["metadata"]
		if(metadata && metadata["map_name"])
			return metadata["map_name"]

	// Final fallback
	return generate_fallback_name()

/// Generate a fallback name when metadata isn't available
/obj/machinery/computer/portal_control/proc/generate_fallback_name()
	var/static/list/sector_prefixes = list(
		"Quantum", "Chrono", "Spatial", "Dimensional", "Void",
		"Celestial", "Astral", "Ethereal", "Cosmic", "Nebular"
	)
	var/static/list/sector_suffixes = list(
		"Realm", "Expanse", "Frontier", "Domain", "Territory",
		"Reach", "Void", "Sector", "Zone", "Dimension"
	)

	return "[pick(sector_prefixes)] [pick(sector_suffixes)]"

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	switch(action)
		if("linkup")
			log_portal_control("Portal Control: [key_name(user)] attempted linkup at [AREACOORD(src)]")
			try_to_linkup()
			if(linked_portal)
				log_portal_control("Portal Control: Successfully linked to portal at [AREACOORD(linked_portal)]")
			// Force UI update after linkup
			force_ui_update()
			. = TRUE
		if("deactivate")
			if(linked_portal?.target)
				log_portal_control("Portal Control: [key_name(user)] deactivating portal from [linked_portal.target.name] at [AREACOORD(src)]")
				if(istype(linked_portal.target, /datum/portal_destination/veilbreak))
					var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
					cleanup_portal_simple(veil_dest)
				linked_portal.deactivate()
			// Force UI update after deactivation
			force_ui_update()
			. = TRUE
		if("generate_new")
			if(linked_portal?.destination)
				var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination

				// Enhanced checks to prevent generation conflicts
				if(generation_in_progress)
					to_chat(user, span_warning("Portal stabilization is already in progress!"))
					log_portal_control("Portal Control: Generation blocked - already in progress (local)")
					return TRUE

				if(veil_dest.generating)
					to_chat(user, span_warning("Portal stabilization is already in progress!"))
					log_portal_control("Portal Control: Generation blocked - already in progress (destination)")
					return TRUE

				if(linked_portal.transport_active)
					to_chat(user, span_warning("Deactivate the current portal before generating a new destination!"))
					return TRUE

				if(world.time < next_generate_attempt)
					to_chat(user, span_warning("Please wait [round((next_generate_attempt - world.time) / 10)] seconds before generating another portal."))
					return TRUE

				log_portal_control("Portal Control: [key_name(user)] initiating new portal generation at [AREACOORD(src)]")

				// Set states BEFORE starting generation
				generation_in_progress = TRUE
				next_generate_attempt = world.time + (generate_cooldown * 10)

				// Start generation progress monitoring
				start_generation_monitoring()

				// Start generation - wrap in try/catch for safety
				var/start_success = FALSE
				try
					veil_dest.start_generation()
					start_success = TRUE
				catch(var/exception/e)
					log_portal_control("Portal Control: Exception during generation start: [e]")
					generation_in_progress = FALSE
					next_generate_attempt = 0
					stop_generation_monitoring()
					force_ui_update()
					to_chat(user, span_danger("Portal stabilization failed to start due to an error."))
					return TRUE

				if(!veil_dest.generating && start_success)
					// Generation failed to start properly
					generation_in_progress = FALSE
					next_generate_attempt = 0
					stop_generation_monitoring()
					force_ui_update()
					to_chat(user, span_warning("Portal stabilization failed to start."))
					log_portal_control("Portal Control: Generation failed to start properly")
				else
					linked_portal.say("Initiating new portal stabilization...")
					log_portal_control("Portal Control: Portal generation started successfully")

					// Register for generation completion callbacks
					register_generation_callbacks(veil_dest)
			else
				log_portal_control("Portal Control: [key_name(user)] attempted generation without valid portal destination")
				to_chat(user, span_warning("No valid portal destination configured!"))
			. = TRUE

	return TRUE

/obj/machinery/computer/portal_control/proc/try_to_linkup()
	linked_portal = locate(/obj/machinery/portal) in view(7, get_turf(src))

/// SIMPLIFIED CLEANUP - Eject all mobs except hostile or void faction
/obj/machinery/computer/portal_control/proc/cleanup_portal_simple(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest.dungeon_z_level)
		log_portal_control("Portal Control: No portal Z-level to clean up")
		return

	log_portal_control("Portal Control: Starting SIMPLIFIED cleanup of portal Z-level [veil_dest.dungeon_z_level]")

	// Use the new simple dumping
	dump_mobs_simple(veil_dest.dungeon_z_level)

	// Now call the destination's own cleanup proc
	veil_dest.cleanup_dungeon()

	// Remove the destination from global list
	for(var/key in GLOB.portal_destinations)
		if(GLOB.portal_destinations[key] == veil_dest)
			GLOB.portal_destinations -= key
			log_portal_control("Portal Control: Removed destination [key] from global list")
			break

// ===== SIMPLIFIED DUMPING SYSTEM =====

/// Dump only mobs - players, corpses, everything except hostile/void
/obj/machinery/computer/portal_control/proc/dump_mobs_simple(dungeon_z)
	if(!linked_portal)
		return

	var/turf/portal_turf = get_turf(linked_portal)
	if(!portal_turf)
		return

	log_portal_control("Portal Control: Starting MOB-ONLY dump from Z-level [dungeon_z]")

	var/dumped_count = 0
	var/skipped_count = 0

	// Get area around portal for dumping - simple 3x3 area
	var/list/dump_turfs = list()
	for(var/turf/T in range(1, portal_turf))
		if(T == portal_turf)
			continue
		if(istype(T, /turf/open))
			dump_turfs += T

	// Fallback if no turfs found
	if(!length(dump_turfs))
		dump_turfs += get_step(portal_turf, pick(NORTH, SOUTH, EAST, WEST))
		log_portal_control("Portal Control: Using fallback dump location")

	// Only process mobs
	for(var/mob/living/mob in GLOB.mob_living_list)
		if(mob.z != dungeon_z)
			continue

		// SIMPLE CHECK: Skip only hostile mobs or void faction
		if(is_hostile_or_void(mob))
			skipped_count++
			continue

		// All other mobs get dumped - players, corpses, animals, etc.
		var/turf/dump_turf = length(dump_turfs) ? pick(dump_turfs) : portal_turf
		if(dump_turf)
			mob.forceMove(dump_turf)

			// Stun and message for conscious mobs
			if(mob.stat == CONSCIOUS)
				mob.Stun(3 SECONDS)
				to_chat(mob, span_warning("The portal collapses! You're ejected back to the station."))
				playsound(mob, 'sound/effects/empulse.ogg', 50, TRUE)
			else if(mob.stat == DEAD)
				mob.visible_message(span_notice("[mob] appears from a collapsing portal!"))
				playsound(mob, 'sound/effects/empulse.ogg', 30, TRUE)

			dumped_count++

	var/feedback_msg = "Portal collapse: [dumped_count] mobs returned. [skipped_count] hostiles removed."
	if(linked_portal)
		linked_portal.say(feedback_msg)
	log_portal_control("Portal Control: MOB DUMP COMPLETE - [feedback_msg]")

/// Simple check: TRUE if hostile or void faction, FALSE otherwise (safe to eject)
/obj/machinery/computer/portal_control/proc/is_hostile_or_void(mob/living/mob)
	// Void faction always gets removed
	if(mob.faction == FACTION_VOID)
		return TRUE

	// Hostile simple animals
	if(istype(mob, /mob/living/simple_animal/hostile))
		return TRUE

	// Xenomorphs
	if(istype(mob, /mob/living/carbon/alien))
		return TRUE

	// If it has no client/ckey and is simple animal, assume hostile
	if(istype(mob, /mob/living/simple_animal) && !mob.ckey)
		return TRUE

	// Everything else is safe to eject - players, corpses, friendly animals, etc.
	return FALSE

// ===== GENERATION CALLBACK SYSTEM =====

/// Register callbacks with the destination to track generation completion
/obj/machinery/computer/portal_control/proc/register_generation_callbacks(datum/portal_destination/veilbreak/veil_dest)
	// Store a reference to this computer in the destination for callbacks
	veil_dest.connected_control_computer = src

/// Called when generation completes successfully
/obj/machinery/computer/portal_control/proc/on_generation_completed()
	generation_in_progress = FALSE
	log_portal_control("Portal Control: Portal generation completed successfully")

	// Stop monitoring and force final update
	stop_generation_monitoring()
	force_ui_update()

	// Provide user feedback
	if(linked_portal)
		linked_portal.say("Portal stabilization complete. Destination secured.")

/// Called when generation fails
/obj/machinery/computer/portal_control/proc/on_generation_failed(reason)
	generation_in_progress = FALSE
	log_portal_control("Portal Control: Portal generation failed - [reason]")

	// Stop monitoring and force final update
	stop_generation_monitoring()
	force_ui_update()

	// Provide user feedback
	if(linked_portal)
		linked_portal.say("Portal stabilization failed: [reason]")
