// modular_zzveilbreak/code/modules/dungeons/portal_control.dm

/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new dungeon destinations."
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
		ui = new(user, src, "PortalControl", name)  // This matches the TSX component name
		ui.open()
	log_portal_control("Portal Control: [key_name(user)] opened UI at [AREACOORD(src)]")
	return TRUE  // Added return value

/obj/machinery/computer/portal_control/ui_data(mob/user)
	. = list()

	// Basic portal info
	.["portal_present"] = !!linked_portal
	.["portal_status"] = linked_portal ? linked_portal.powered() : FALSE
	.["portal_active"] = linked_portal?.transport_active ? TRUE : FALSE

	// Current target info
	if(linked_portal?.target)
		.["current_target"] = linked_portal.target.get_ui_data()

	// Available destinations
	var/list/destinations = list()
	if(linked_portal)
		for(var/destination_key in GLOB.portal_destinations)
			var/datum/portal_destination/possible_destination = GLOB.portal_destinations[destination_key]
			if(!istype(possible_destination)) // Safety check
				continue
			if(!linked_portal.valid_destination(possible_destination))
				continue
			destinations += list(possible_destination.get_ui_data())
	.["destinations"] = destinations

	// Generation status and cooldown
	var/can_generate = FALSE
	var/generation_status = "idle"
	var/generation_progress = 0
	var/dungeon_data = null

	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		generation_status = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		generation_progress = veil_dest.generation_progress
		dungeon_data = linked_portal.generated_dungeon_data

		// Check if we can generate
		if(!generation_in_progress && !veil_dest.generating && world.time >= next_generate_attempt)
			can_generate = TRUE

	.["generation_status"] = generation_status
	.["generation_progress"] = generation_progress
	.["dungeon_data"] = dungeon_data
	.["can_generate"] = can_generate
	.["generation_cooldown"] = max(0, next_generate_attempt - world.time) / 10 // Convert to seconds for UI
	.["generate_cooldown"] = generate_cooldown
	.["generation_in_progress"] = generation_in_progress

	return .

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
		if("activate")
			var/destination_key = params["destination"]
			var/datum/portal_destination/D = GLOB.portal_destinations[destination_key]
			if(D)
				log_portal_control("Portal Control: [key_name(user)] activating portal to [D.name] at [AREACOORD(src)]")
				try_to_connect(D)
			. = TRUE
		if("deactivate")
			if(linked_portal?.target)
				log_portal_control("Portal Control: [key_name(user)] deactivating portal from [linked_portal.target.name] at [AREACOORD(src)]")
				// REFACTORED: Use the destination's own cleanup system
				if(istype(linked_portal.target, /datum/portal_destination/veilbreak))
					var/datum/portal_destination/veilbreak/veil_dest = linked_portal.target
					cleanup_dungeon_with_corpse_dumping(veil_dest)
				linked_portal.deactivate()
			. = TRUE
		if("generate_new")
			if(linked_portal?.destination)
				var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination

				// ENHANCED: Triple-check to prevent any generation conflicts
				if(generation_in_progress)
					to_chat(user, span_warning("Dungeon generation is already being processed!"))
					log_portal_control("Portal Control: Generation blocked - already in progress (local)")
					return TRUE

				if(veil_dest.generating)
					to_chat(user, span_warning("Dungeon generation is already in progress!"))
					log_portal_control("Portal Control: Generation blocked - already in progress (destination)")
					return TRUE

				if(world.time < next_generate_attempt)
					to_chat(user, span_warning("Please wait [round((next_generate_attempt - world.time) / 10)] seconds before generating another dungeon."))
					return TRUE

				log_portal_control("Portal Control: [key_name(user)] initiating new dungeon generation at [AREACOORD(src)]")

				// Set states BEFORE starting generation
				generation_in_progress = TRUE
				next_generate_attempt = world.time + (generate_cooldown * 10) // Set cooldown

				// Start generation - wrap in try/catch for safety
				var/start_success = FALSE
				try
					veil_dest.start_generation()
					start_success = TRUE
				catch(var/exception/e)
					log_portal_control("Portal Control: Exception during generation start: [e]")
					generation_in_progress = FALSE
					next_generate_attempt = 0 // Reset cooldown on failure
					to_chat(user, span_danger("Dungeon generation failed to start due to an error."))
					return TRUE

				if(!veil_dest.generating && start_success)
					// Generation failed to start properly
					generation_in_progress = FALSE
					next_generate_attempt = 0 // Reset cooldown on failure
					to_chat(user, span_warning("Dungeon generation failed to start."))
					log_portal_control("Portal Control: Generation failed to start properly")
				else
					linked_portal.say("Initiating new dungeon generation...")
					log_portal_control("Portal Control: Generation started successfully")

					// Register for generation completion callbacks
					register_generation_callbacks(veil_dest)
			else
				log_portal_control("Portal Control: [key_name(user)] attempted generation without valid portal destination")
				to_chat(user, span_warning("No valid portal destination configured!"))
			. = TRUE

	return TRUE

/obj/machinery/computer/portal_control/proc/try_to_linkup()
	linked_portal = locate(/obj/machinery/portal) in view(7, get_turf(src))

/obj/machinery/computer/portal_control/proc/try_to_connect(datum/portal_destination/D)
	if(!D || !linked_portal)
		log_portal_control("Portal Control: Connection failed - no destination or linked portal")
		return
	if(!D.is_available())
		log_portal_control("Portal Control: Connection failed - destination [D.name] not available: [D.get_available_reason()]")
		return
	if(linked_portal.target)
		log_portal_control("Portal Control: Connection failed - portal already active to [linked_portal.target.name]")
		return

	log_portal_control("Portal Control: Successfully connecting to [D.name]")
	linked_portal.activate(D)

/// Enhanced cleanup that dumps players safely before calling the destination's cleanup
/obj/machinery/computer/portal_control/proc/cleanup_dungeon_with_corpse_dumping(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest.dungeon_z_level)
		log_portal_control("Portal Control: No dungeon Z-level to clean up")
		return

	log_portal_control("Portal Control: Starting SAFE cleanup of dungeon Z-level [veil_dest.dungeon_z_level]")

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
	log_portal_control("Portal Control: Generation completed successfully")

	// Provide user feedback
	if(linked_portal)
		linked_portal.say("Dungeon generation complete. Portal stabilized.")

/// Called when generation fails
/obj/machinery/computer/portal_control/proc/on_generation_failed(reason)
	generation_in_progress = FALSE
	// Don't reset cooldown on failure - user should still wait before retry
	log_portal_control("Portal Control: Generation failed - [reason]")

	// Provide user feedback
	if(linked_portal)
		linked_portal.say("Dungeon generation failed: [reason]")

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

/obj/machinery/computer/portal_control/proc/is_player_related(mob/living/mob)
	// Quick exclusion for obvious hostiles first
	if(is_definitely_hostile(mob))
		return FALSE

	// 1. Active players with clients (most common case)
	if(mob.client && !isobserver(mob))
		return TRUE

	// 2. SSD Players - they have ckeys but no client
	if(mob.ckey && !mob.client && !isobserver(mob))
		return TRUE

	// 3. Player corpses (dead humans) - include SSD corpses
	if(ishuman(mob) && mob.stat == DEAD)
		// Extra safety: check if they ever had a player mind
		if(mob.mind || mob.ckey)
			return TRUE
		// If no mind/ckey, it might be a spawned corpse - be more careful
		return FALSE

	// 4. Cyborgs and AIs - include SSD borgs
	if(iscyborg(mob) || isAI(mob))
		// Borgs always have players if they have ckeys or minds
		if(mob.ckey || (mob.mind && mob.mind.key))
			return TRUE
		// Safety: exclude NPC borgs
		return FALSE

	// 5. Simple animals that are player-controlled (pets, etc.)
	if(isanimal(mob))
		// Only include if explicitly player-controlled
		if(mob.ckey || mob.client || (mob.mind && mob.mind.key))
			return TRUE
		// Exclude wild animals
		return FALSE

	// 6. Mobs with player minds (covers edge cases)
	if(mob.mind && mob.mind.key)
		return TRUE

	// 7. Final ckey check as safety net
	if(mob.ckey)
		return TRUE

	return FALSE

/// Get safe turfs around the portal for dumping (avoid walls, space, hazards)
/obj/machinery/computer/portal_control/proc/get_safe_dump_turfs(turf/center_turf)
	var/list/safe_turfs = list()
	var/search_radius = 3 // How far from portal to search

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
			to_chat(mob, span_warning("The dungeon collapses around you! You're ejected back to safety."))
			playsound(mob, 'sound/effects/empulse.ogg', 50, TRUE)
		else if(mob.stat == DEAD)
			mob.visible_message(span_notice("[mob] appears from a shimmering portal!"))
			playsound(mob, 'sound/effects/empulse.ogg', 30, TRUE)

		dumped_count++

	// Simplified feedback
	var/feedback_msg = "Dungeon collapse complete: [dumped_count] entities returned to safety."
	if(linked_portal)
		linked_portal.say(feedback_msg)
	log_portal_control("Portal Control: SIMPLIFIED DUMP COMPLETE - [feedback_msg] Hostiles skipped: [skipped_hostiles]")

// Debug verb to test player detection
/obj/machinery/computer/portal_control/verb/test_player_detection()
	set name = "Test Player Detection"
	set category = "Debug"
	set src in view(1)

	usr << "=== PLAYER DETECTION TEST ==="
	var/test_z = usr.z // Current Z-level for testing

	var/active_players = 0
	var/ssd_players = 0
	var/borgs = 0
	var/corpses = 0
	var/hostiles = 0
	var/unknown = 0

	for(var/mob/living/mob in GLOB.mob_list)
		if(mob.z != test_z)
			continue

		if(is_definitely_hostile(mob))
			hostiles++
			usr << "HOSTILE: [mob] ([mob.type])"
			continue

		if(!is_player_related(mob))
			unknown++
			usr << "UNKNOWN: [mob] ([mob.type]) - ckey: [mob.ckey], client: [mob.client], mind: [mob.mind]"
			continue

		// Categorize player-related mobs
		if(iscyborg(mob) || isAI(mob))
			borgs++
			usr << "BORG: [mob] ([mob.type]) - ckey: [mob.ckey]"
		else if(mob.ckey && !mob.client)
			ssd_players++
			usr << "SSD: [mob] ([mob.type]) - ckey: [mob.ckey]"
		else if(mob.client)
			active_players++
			usr << "ACTIVE: [mob] ([mob.type])"
		else if(mob.stat == DEAD)
			corpses++
			usr << "CORPSE: [mob] ([mob.type]) - mind: [mob.mind]"
		else
			unknown++
			usr << "PLAYER-RELATED: [mob] ([mob.type]) - ckey: [mob.ckey]"

	usr << "=== SUMMARY ==="
	usr << "Active Players: [active_players]"
	usr << "SSD Players: [ssd_players]"
	usr << "Cyborgs/AI: [borgs]"
	usr << "Corpses: [corpses]"
	usr << "Hostiles: [hostiles]"
	usr << "Unknown: [unknown]"
	usr << "Total on Z-level: [active_players + ssd_players + borgs + corpses + hostiles + unknown]"

// Debug verb for portal info
/obj/machinery/computer/portal_control/verb/debug_portal_info()
	set name = "Debug Portal Info"
	set category = "Debug"
	set src in view(1)

	usr << "=== PORTAL DEBUG INFO ==="
	usr << "Linked Portal: [linked_portal ? AREACOORD(linked_portal) : "NONE"]"
	usr << "Portal Powered: [linked_portal ? linked_portal.powered() : "N/A"]"
	usr << "Portal Possible: [linked_portal ? linked_portal.portal_possible : "N/A"]"
	usr << "Transport Active: [linked_portal ? linked_portal.transport_active : "N/A"]"
	usr << "Current Target: [linked_portal?.target ? linked_portal.target.name : "NONE"]"
	usr << "Generation In Progress: [generation_in_progress]"
	usr << "Next Generate Attempt: [next_generate_attempt] (current: [world.time])"

	usr << "=== GLOBAL DESTINATIONS ==="
	var/count = 0
	for(var/key in GLOB.portal_destinations)
		var/datum/portal_destination/D = GLOB.portal_destinations[key]
		usr << "[key]: [D.name] - Available: [D.is_available()] - Reason: [D.get_available_reason()]"
		count++
	usr << "Total Destinations: [count]"
