// modular_zzveilbreak/code/modules/dungeons/portal_destinations_cleanup.dm

/datum/portal_destination/veilbreak/proc/cleanup_z_level_completely(z_level, turf/ejection_turf = null)
	// Validate Z-level against our actual portal dungeon Z-level
	if(!z_level || z_level < 1 || z_level > world.maxz)
		log_dungeon("Cleanup: ERROR - Invalid Z-level [z_level]")
		return

	// CRITICAL FIX: Only clean up our assigned portal dungeon Z-level
	if(z_level != dungeon_z_level)
		log_dungeon("Cleanup: ERROR - Z-level [z_level] does not match portal dungeon Z-level [dungeon_z_level]")
		return

	log_dungeon("Cleanup: Starting complete cleanup of portal dungeon Z-level [z_level]")

	cleanup_in_progress = TRUE
	processing_disabled = TRUE

	// Stop any active processing
	STOP_PROCESSING(SSobj, src)

	// Handle ALL mobs according to the new rules
	handle_all_mobs(z_level, ejection_turf)
	CHECK_TICK

	// Delete ALL objects and structures (no exceptions)
	delete_all_content(z_level)
	CHECK_TICK

	// Reset all turfs to space
	reset_z_level_to_space(z_level)
	CHECK_TICK

	// Clean up portal connections
	cleanup_portal_connections()

	// Reset state (but keep the Z-level for reuse)
	generated = FALSE
	generating = FALSE
	generation_progress = 0
	current_request_id = 0
	actual_dungeon_portal_location = null

	// Re-enable processing
	processing_disabled = FALSE
	cleanup_in_progress = FALSE

	log_dungeon("Cleanup: Complete cleanup finished for portal dungeon Z-level [z_level]")

/// Handle ALL mobs according to the new rules: Delete FACTION_VOID and hostile mobs, eject everything else
/datum/portal_destination/veilbreak/proc/handle_all_mobs(z_level, turf/ejection_turf)
	log_dungeon("Cleanup: Handling ALL mobs from portal dungeon Z-level [z_level]")

	var/mobs_deleted = 0
	var/mobs_ejected = 0

	// Use both mob lists to ensure we catch everything
	var/list/all_mobs = list()
	all_mobs += GLOB.mob_list
	all_mobs += GLOB.mob_living_list

	// Remove duplicates
	var/list/unique_mobs = list()
	for(var/mob/mob in all_mobs)
		if(!mob || QDELETED(mob))
			continue
		unique_mobs[mob] = TRUE

	log_dungeon("Cleanup: Found [length(unique_mobs)] total mobs to process on portal dungeon Z-level [z_level]")

	for(var/mob/mob in unique_mobs)
		if(mob.z != z_level)
			continue

		log_dungeon("Cleanup: Processing mob [mob] at [AREACOORD(mob)] - type: [mob.type], mind: [mob.mind ? "YES" : "NO"], faction: [mob.faction]")

		// Skip observer mobs (ghosts, AI eyes, etc.) - they can phase through dimensions
		if(isobserver(mob))
			log_dungeon("Cleanup: Skipping observer mob [mob] - observers can phase through dimensions")
			continue

		// Check if this mob should be DELETED (FACTION_VOID or hostile)
		var/should_delete = FALSE

		// Check for FACTION_VOID (delete regardless of other factors)
		if(isfaction(mob, FACTION_VOID))
			log_dungeon("Cleanup: Marking mob [mob] for deletion - FACTION_VOID")
			should_delete = TRUE

		// Check if hostile (using the existing helper proc)
		else if(is_hostile_or_void(mob))
			log_dungeon("Cleanup: Marking mob [mob] for deletion - hostile")
			should_delete = TRUE

		// DELETE mobs that match the criteria
		if(should_delete)
			log_dungeon("Cleanup: Deleting mob [mob] at [AREACOORD(mob)]")
			qdel(mob)
			mobs_deleted++

		// EJECT all other mobs (only physical, non-observer mobs)
		else
			// If we have an ejection turf, move mob there and throw them
			if(ejection_turf && !QDELETED(ejection_turf))
				var/old_loc = AREACOORD(mob)
				mob.forceMove(ejection_turf)

				// Throw them with force in a random direction from the portal
				var/throw_target = get_edge_target_turf(ejection_turf, pick(GLOB.cardinals))
				mob.throw_at(throw_target, 3, 2, spin = TRUE)

				// Only stun and message living mobs
				if(isliving(mob))
					var/mob/living/living_mob = mob
					if(living_mob.stat == CONSCIOUS)
						living_mob.Stun(12 SECONDS)
						to_chat(living_mob, span_warning("The portal violently collapses! You're thrown clear!"))
						playsound(living_mob, 'sound/effects/bang.ogg', 60, TRUE)
					else
						living_mob.visible_message(span_notice("[living_mob] is thrown from a collapsing portal!"))
						playsound(living_mob, 'sound/effects/bang.ogg', 40, TRUE)
				else
					// Non-living mobs (shouldn't happen with our filters, but safety)
					mob.visible_message(span_notice("[mob] is thrown from a collapsing portal!"))

				log_dungeon("Cleanup: Ejected mob [mob] from [old_loc] to [AREACOORD(ejection_turf)]")
				mobs_ejected++
			else
				// No ejection turf, just delete (shouldn't happen but safety)
				log_dungeon("Cleanup: No ejection turf, deleting mob [mob]")
				qdel(mob)
				mobs_deleted++

		if((mobs_deleted + mobs_ejected) % 10 == 0)
			CHECK_TICK

	log_dungeon("Cleanup: Deleted [mobs_deleted] mobs and ejected [mobs_ejected] mobs from portal dungeon Z-level [z_level]")

/// Helper proc to check if a mob belongs to a specific faction
/datum/portal_destination/veilbreak/proc/isfaction(mob/mob, faction_to_check)
	if(!mob || !isliving(mob))
		return FALSE

	var/mob/living/living_mob = mob
	return living_mob.faction == faction_to_check

/// Delete ALL objects, structures, and items - complete cleanup
/datum/portal_destination/veilbreak/proc/delete_all_content(z_level)
	log_dungeon("Cleanup: Deleting ALL content from portal dungeon Z-level [z_level]")

	var/objects_deleted = 0
	var/areas_purged = 0

	// Delete ALL objects - no exceptions for indestructible items
	for(var/obj/object in world)
		if(object.z != z_level)
			continue

		// Skip space and basic space turfs (they'll be handled by turf reset)
		if(istype(object, /turf/open/space) || istype(object, /turf/open/space/basic))
			continue

		log_dungeon("Cleanup: Deleting object [object] at [AREACOORD(object)]")
		qdel(object)
		objects_deleted++

		if(objects_deleted % 50 == 0)
			CHECK_TICK

	// Clean up areas
	for(var/area/area in world)
		var/has_turfs_on_z = FALSE
		for(var/turf/T in area.contents)
			if(T.z == z_level)
				has_turfs_on_z = TRUE
				break

		if(has_turfs_on_z)
			// Reset area to default space state
			area.power_equip = FALSE
			area.power_light = FALSE
			area.power_environ = FALSE
			area.always_unpowered = TRUE
			area.power_change()
			areas_purged++

		CHECK_TICK

	log_dungeon("Cleanup: Deleted [objects_deleted] objects and purged [areas_purged] areas from portal dungeon Z-level [z_level]")

/datum/portal_destination/veilbreak/proc/reset_z_level_to_space(z_level)
	log_dungeon("Cleanup: Resetting portal dungeon Z-level [z_level] to space")

	var/turfs_processed = 0
	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(!istype(T, /turf/open/space/basic))
			T.ChangeTurf(/turf/open/space/basic, FALSE, FALSE)
		turfs_processed++
		if(turfs_processed % 100 == 0)
			CHECK_TICK

	log_dungeon("Cleanup: Reset [turfs_processed] turfs to space on portal dungeon Z-level [z_level]")

/datum/portal_destination/veilbreak/proc/cleanup_portal_connections()
	log_dungeon("Cleanup: Cleaning up portal connections for portal dungeon Z-level [dungeon_z_level]")

	// Clean up any remaining portal connections with safety checks
	if(connected_portal && !QDELETED(connected_portal))
		// Clear BOTH directions of the connection
		if(connected_portal.target == src)
			connected_portal.target = null
			connected_portal.transport_active = FALSE
			connected_portal.update_appearance()
			log_dungeon("Cleanup: Disconnected station portal from this destination")

		// Also clear the return destination if it exists
		for(var/key in GLOB.portal_destinations)
			var/datum/portal_destination/dest = GLOB.portal_destinations[key]
			if(istype(dest, /datum/portal_destination/simple))
				var/datum/portal_destination/simple/simple_dest = dest
				if(simple_dest.return_portal == connected_portal)
					GLOB.portal_destinations -= key
					log_dungeon("Cleanup: Removed return destination [key]")
					break

	// Clean up ALL portals on the portal dungeon Z-level
	var/portals_removed = 0
	for(var/turf/T in block(locate(1, 1, dungeon_z_level), locate(world.maxx, world.maxy, dungeon_z_level)))
		var/obj/machinery/portal/dungeon_portal = locate(/obj/machinery/portal) in T
		if(dungeon_portal && !QDELETED(dungeon_portal))
			// Clear the portal's target to prevent "Return to Station" lingering
			if(dungeon_portal.target)
				dungeon_portal.target = null
				dungeon_portal.transport_active = FALSE
				log_dungeon("Cleanup: Cleared target from dungeon portal at [AREACOORD(T)]")

			// Delete the portal
			QDEL_NULL(dungeon_portal)
			portals_removed++
			log_dungeon("Cleanup: Removed dungeon portal at [AREACOORD(T)]")

	log_dungeon("Cleanup: Removed [portals_removed] portals from portal dungeon Z-level [dungeon_z_level]")

/datum/portal_destination/veilbreak/proc/enable_processing()
	processing_disabled = FALSE
	cleanup_in_progress = FALSE
	log_dungeon("Cleanup: Processing re-enabled")
