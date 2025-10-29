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

	return .

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
			. = TRUE
		if("deactivate")
			if(linked_portal?.target)
				log_portal_control("Portal Control: [key_name(user)] deactivating portal from [linked_portal.target.name] at [AREACOORD(src)]")
				if(istype(linked_portal.target, /datum/portal_destination/veilbreak))
					var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
					cleanup_portal_with_corpse_dumping(veil_dest)
				linked_portal.deactivate()
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

				// Start generation - wrap in try/catch for safety
				var/start_success = FALSE
				try
					veil_dest.start_generation()
					start_success = TRUE
				catch(var/exception/e)
					log_portal_control("Portal Control: Exception during generation start: [e]")
					generation_in_progress = FALSE
					next_generate_attempt = 0
					to_chat(user, span_danger("Portal stabilization failed to start due to an error."))
					return TRUE

				if(!veil_dest.generating && start_success)
					// Generation failed to start properly
					generation_in_progress = FALSE
					next_generate_attempt = 0
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

/// Enhanced cleanup that dumps players safely before calling the destination's cleanup
/obj/machinery/computer/portal_control/proc/cleanup_portal_with_corpse_dumping(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest.dungeon_z_level)
		log_portal_control("Portal Control: No portal Z-level to clean up")
		return

	log_portal_control("Portal Control: Starting SAFE cleanup of portal Z-level [veil_dest.dungeon_z_level]")

	// SAFETY: Use the enhanced safe dumping
	dump_players_safely(veil_dest.dungeon_z_level)

	// Now call the destination's own cleanup proc
	veil_dest.cleanup_dungeon()

	// Remove the destination from global list
	for(var/key in GLOB.portal_destinations)
		if(GLOB.portal_destinations[key] == veil_dest)
			GLOB.portal_destinations -= key
			log_portal_control("Portal Control: Removed destination [key] from global list")
			break

// ===== GENERATION CALLBACK SYSTEM =====

/// Register callbacks with the destination to track generation completion
/obj/machinery/computer/portal_control/proc/register_generation_callbacks(datum/portal_destination/veilbreak/veil_dest)
	// Store a reference to this computer in the destination for callbacks
	veil_dest.connected_control_computer = src

/// Called when generation completes successfully
/obj/machinery/computer/portal_control/proc/on_generation_completed()
	generation_in_progress = FALSE
	log_portal_control("Portal Control: Portal generation completed successfully")

	// Provide user feedback
	if(linked_portal)
		linked_portal.say("Portal stabilization complete. Destination secured.")

/// Called when generation fails
/obj/machinery/computer/portal_control/proc/on_generation_failed(reason)
	generation_in_progress = FALSE
	log_portal_control("Portal Control: Portal generation failed - [reason]")

	// Provide user feedback
	if(linked_portal)
		linked_portal.say("Portal stabilization failed: [reason]")

// ===== PLAYER DETECTION AND SAFE DUMPING PROCS =====

/obj/machinery/computer/portal_control/proc/is_definitely_hostile(mob/living/mob)
	// Player-controlled entities are never hostile for dumping purposes
	if(mob.ckey || mob.client)
		return FALSE

	// Explicit hostile types
	if(istype(mob, /mob/living/simple_animal/hostile))
		return TRUE

	// Xenomorphs
	if(istype(mob, /mob/living/carbon/alien))
		return TRUE

	// NPC simple animals (most are hostile)
	if(istype(mob, /mob/living/simple_animal) && !mob.ckey)
		return TRUE

	// Mobs with hostile factions
	if(mob.faction && mob.faction != "neutral" && mob.faction != "player" && mob.faction != "silicon")
		return TRUE

	return FALSE

/// Enhanced dumping that provides better feedback for SSD players and borgs
/obj/machinery/computer/portal_control/proc/dump_players_safely(dungeon_z)
	if(!linked_portal)
		return

	var/turf/portal_turf = get_turf(linked_portal)
	if(!portal_turf)
		return

	log_portal_control("Portal Control: Starting simplified player dump from Z-level [dungeon_z]")

	var/dumped_count = 0
	var/skipped_hostiles = 0

	var/list/safe_turfs = get_safe_dump_turfs(portal_turf)

	if(!length(safe_turfs))
		log_portal_control("Portal Control: CRITICAL - No safe dump locations found!")
		return

	for(var/mob/living/mob in GLOB.mob_list)
		if(mob.z != dungeon_z)
			continue

		// Skip hostile mobs
		if(is_definitely_hostile(mob))
			skipped_hostiles++
			continue

		var/turf/dump_turf = pick(safe_turfs)
		if(dump_turf)
			mob.forceMove(dump_turf)

			// Handle all non-hostile mobs the same way
			if(mob.stat == CONSCIOUS)
				mob.Stun(3 SECONDS)
				to_chat(mob, span_warning("The portal destination collapses around you! You're ejected back to safety."))
				playsound(mob, 'sound/effects/empulse.ogg', 50, TRUE)
			else if(mob.stat == DEAD)
				mob.visible_message(span_notice("[mob] appears from a shimmering portal!"))
				playsound(mob, 'sound/effects/empulse.ogg', 30, TRUE)

			dumped_count++

	// Simplified feedback
	var/feedback_msg = "Portal destination collapse complete: [dumped_count] entities returned to safety."
	if(linked_portal)
		linked_portal.say(feedback_msg)
	log_portal_control("Portal Control: SIMPLIFIED DUMP COMPLETE - [feedback_msg] Hostiles skipped: [skipped_hostiles]")

/// Get safe turfs around the portal for dumping (avoid walls, space, hazards)
/obj/machinery/computer/portal_control/proc/get_safe_dump_turfs(turf/center_turf)
	var/list/safe_turfs = list()
	var/search_radius = 3

	// Search in expanding circles around the portal
	for(var/turf/T in range(search_radius, center_turf))
		// Skip the portal turf itself
		if(T == center_turf)
			continue

		// Check if turf is safe for dumping
		if(is_safe_dump_turf(T))
			safe_turfs += T

	// If no safe turfs found, try to find at least some open turfs
	if(!length(safe_turfs))
		for(var/turf/T in range(search_radius, center_turf))
			if(T == center_turf)
				continue
			if(istype(T, /turf/open) && !T.density)
				safe_turfs += T
				log_portal_control("Portal Control: Using fallback turf at [AREACOORD(T)]")

	return safe_turfs

/// Check if a turf is safe for dumping players/corpses
/obj/machinery/computer/portal_control/proc/is_safe_dump_turf(turf/T)
	// Must be open and not dense
	if(!istype(T, /turf/open) || T.density)
		return FALSE

	// Avoid space and lava
	if(istype(T, /turf/open/space) || istype(T, /turf/open/lava))
		return FALSE

	// Avoid chasms and other hazards
	if(istype(T, /turf/open/chasm))
		return FALSE

	// Avoid turfs with dangerous objects
	for(var/obj/O in T)
		if(O.density && !istype(O, /obj/structure/table) && !istype(O, /obj/structure/chair))
			return FALSE
		if(istype(O, /obj/machinery/porta_turret))
			return FALSE
		if(istype(O, /obj/structure/window) || istype(O, /obj/structure/grille))
			return FALSE

	return TRUE
