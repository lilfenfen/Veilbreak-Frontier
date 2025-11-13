// modular_zzveilbreak/code/modules/dungeons/portal_destinations_cleanup.dm

/datum/portal_destination/veilbreak/proc/cleanup_z_level_completely(z_level, turf/ejection_turf = null)
	// Validate Z-level before proceeding
	if(!z_level || z_level < 1 || z_level > world.maxz)
		log_dungeon("Cleanup: ERROR - Invalid Z-level [z_level]")
		return

	// Prevent re-entrancy
	if(cleanup_in_progress)
		log_dungeon("Cleanup: Already in progress, skipping")
		return

	log_dungeon("Cleanup: Starting complete cleanup of Z-level [z_level]")

	cleanup_in_progress = TRUE
	processing_disabled = TRUE

	// Stop any active processing
	STOP_PROCESSING(SSobj, src)

	// Eject all non-hostile mobs first with force
	eject_all_non_hostile_mobs_with_force(z_level, ejection_turf)
	CHECK_TICK

	// Delete everything that isn't space
	delete_non_space_content(z_level)
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

	log_dungeon("Cleanup: Complete cleanup finished for reusable Z-level [z_level]")

/// Eject all non-hostile mobs to specified turf with throwing force
/datum/portal_destination/veilbreak/proc/eject_all_non_hostile_mobs_with_force(z_level, turf/ejection_turf)
	log_dungeon("Cleanup: Ejecting non-hostile mobs from Z-level [z_level] with force")

	var/ejected_count = 0
	var/deleted_count = 0

	for(var/mob/living/mob in GLOB.mob_living_list)
		if(mob.z != z_level)
			continue

		// Skip hostile mobs and void faction
		if(is_hostile_or_void(mob))
			qdel(mob)
			deleted_count++
			continue

		// If we have an ejection turf, move mob there and throw them
		if(ejection_turf && !QDELETED(ejection_turf))
			// Move to ejection turf first
			mob.forceMove(ejection_turf)

			// Throw them with force in a random direction from the portal
			var/throw_target = get_edge_target_turf(ejection_turf, pick(GLOB.cardinals))
			mob.throw_at(throw_target, 3, 2, spin = TRUE)

			// Stun and message for conscious mobs
			if(mob.stat == CONSCIOUS)
				mob.Stun(2 SECONDS) // Shorter stun since they're being thrown
				to_chat(mob, span_warning("The portal violently collapses! You're thrown clear!"))
				playsound(mob, 'sound/effects/bang.ogg', 60, TRUE)
			else if(mob.stat == DEAD)
				mob.visible_message(span_notice("[mob] is thrown from a collapsing portal!"))
				playsound(mob, 'sound/effects/bang.ogg', 40, TRUE)

			ejected_count++
		else:
			// No ejection turf, just delete
			qdel(mob)
			deleted_count++

		if((ejected_count + deleted_count) % 20 == 0)
			CHECK_TICK

	log_dungeon("Cleanup: Force-ejected [ejected_count] and deleted [deleted_count] mobs from Z-level [z_level]")

/// Delete all objects, structures, and items that aren't space
/datum/portal_destination/veilbreak/proc/delete_non_space_content(z_level)
	log_dungeon("Cleanup: Deleting non-space content from Z-level [z_level]")

	var/objects_deleted = 0
	var/areas_purged = 0

	// Delete all objects
	for(var/obj/object in world)
		if(object.z != z_level)
			continue

		// Skip space and basic space turfs
		if(istype(object, /turf/open/space) || istype(object, /turf/open/space/basic))
			continue

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

	log_dungeon("Cleanup: Deleted [objects_deleted] objects and purged [areas_purged] areas from Z-level [z_level]")

/datum/portal_destination/veilbreak/proc/reset_z_level_to_space(z_level)
	log_dungeon("Cleanup: Resetting Z-level [z_level] to space")

	var/turfs_processed = 0
	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(!istype(T, /turf/open/space/basic))
			T.ChangeTurf(/turf/open/space/basic, FALSE, FALSE)
		turfs_processed++
		if(turfs_processed % 100 == 0)
			CHECK_TICK

	log_dungeon("Cleanup: Reset [turfs_processed] turfs to space")

/datum/portal_destination/veilbreak/proc/cleanup_portal_connections()
	log_dungeon("Cleanup: Cleaning up portal connections")

	// Clean up any remaining portal connections with safety checks
	if(connected_portal && !QDELETED(connected_portal) && connected_portal.target == src)
		connected_portal.target = null
		connected_portal.transport_active = FALSE
		connected_portal.update_appearance()
		log_dungeon("Cleanup: Disconnected station portal")

	// Clean up ALL portals on the dungeon Z-level
	var/portals_removed = 0
	for(var/turf/T in block(locate(1, 1, dungeon_z_level), locate(world.maxx, world.maxy, dungeon_z_level)))
		var/obj/machinery/portal/dungeon_portal = locate(/obj/machinery/portal) in T
		if(dungeon_portal && !QDELETED(dungeon_portal))
			// Find and remove the return destination safely
			if(dungeon_portal.target)
				for(var/key in GLOB.portal_destinations)
					var/datum/portal_destination/dest = GLOB.portal_destinations[key]
					if(dest == dungeon_portal.target)
						GLOB.portal_destinations -= key
						log_dungeon("Cleanup: Removed return destination [key]")
						break

			// Delete the portal
			QDEL_NULL(dungeon_portal)
			portals_removed++
			log_dungeon("Cleanup: Removed dungeon portal at [AREACOORD(T)]")

	log_dungeon("Cleanup: Removed [portals_removed] portals from Z-level [dungeon_z_level]")

/datum/portal_destination/veilbreak/proc/enable_processing()
	processing_disabled = FALSE
	cleanup_in_progress = FALSE
	log_dungeon("Cleanup: Processing re-enabled")
