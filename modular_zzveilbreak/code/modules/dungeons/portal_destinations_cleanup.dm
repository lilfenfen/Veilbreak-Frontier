// modular_zzveilbreak/code/modules/dungeons/portal_destinations_cleanup.dm

/datum/portal_destination/veilbreak/proc/cleanup_z_level_completely(z_level)
	// Validate Z-level before proceeding
	if(!z_level || z_level < 1 || z_level > world.maxz)
		log_dungeon("Cleanup: ERROR - Invalid Z-level [z_level]")
		return

	// Prevent re-entrancy
	if(cleanup_in_progress)
		log_dungeon("Cleanup: Already in progress, skipping")
		return

	log_dungeon("Cleanup: Starting cleanup of Z-level [z_level]")

	cleanup_in_progress = TRUE
	processing_disabled = TRUE

	// Stop any active processing
	STOP_PROCESSING(SSobj, src)

	// Clean up all mobs and objects
	cleanup_z_level_contents(z_level)
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

	// Re-enable processing
	processing_disabled = FALSE
	cleanup_in_progress = FALSE

	log_dungeon("Cleanup: Cleanup complete for reusable Z-level [z_level]")

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

	// Clean up any dungeon-side portal safely using the new scanning method
	var/obj/machinery/portal/dungeon_portal = get_any_portal_on_z_level()
	if(dungeon_portal && !QDELETED(dungeon_portal))
		// Find and remove the return destination safely
		if(dungeon_portal.target)
			for(var/key in GLOB.portal_destinations)
				var/datum/portal_destination/dest = GLOB.portal_destinations[key]
				if(dest == dungeon_portal.target)
					GLOB.portal_destinations -= key
					log_dungeon("Cleanup: Removed return destination [key]")
					break

		// Use a timer to safely delete the portal
		QDEL_NULL(dungeon_portal)
		log_dungeon("Cleanup: Queued dungeon portal for deletion")

/datum/portal_destination/veilbreak/proc/cleanup_z_level_contents(z_level)
	log_dungeon("Cleanup: Cleaning up contents of Z-level [z_level]")

	var/mobs_cleaned = 0
	var/objects_cleaned = 0

	// Clean up all non-player mobs
	for(var/mob/living/mob in GLOB.mob_list)
		if(mob.z == z_level)
			if(mob.ckey || mob.client)
				continue // Skip players
			qdel(mob)
			mobs_cleaned++
			if(mobs_cleaned % 20 == 0)
				CHECK_TICK

	// Clean up non-essential objects
	for(var/obj/object in world)
		if(object.z == z_level)
			if(should_preserve_object(object))
				continue
			qdel(object)
			objects_cleaned++
			if(objects_cleaned % 50 == 0)
				CHECK_TICK

	log_dungeon("Cleanup: Cleaned up [mobs_cleaned] mobs and [objects_cleaned] objects from Z-level [z_level]")

/datum/portal_destination/veilbreak/proc/should_preserve_object(obj/object)
	// Preserve important structures
	if(istype(object, /obj/structure))
		return TRUE
	if(istype(object, /obj/machinery))
		return TRUE
	if(istype(object, /obj/item))
		return TRUE
	// Preserve anything that might be player-owned
	if(object.resistance_flags & INDESTRUCTIBLE)
		return TRUE
	return FALSE

/datum/portal_destination/veilbreak/proc/enable_processing()
	processing_disabled = FALSE
	cleanup_in_progress = FALSE
	log_dungeon("Cleanup: Processing re-enabled")
