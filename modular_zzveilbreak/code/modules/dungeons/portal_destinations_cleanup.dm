// modular_zzveilbreak/code/modules/dungeons/portal_destinations_cleanup.dm

/datum/portal_destination/veilbreak/proc/cleanup_z_level_completely(z_level, turf/ejection_turf = null, power_failure = FALSE)
	if(!z_level || z_level < 1 || z_level > world.maxz)
		return

	if(z_level != dungeon_z_level)
		return

	cleanup_in_progress = TRUE
	processing_disabled = TRUE

	STOP_PROCESSING(SSobj, src)

	// NEW: Different message for power failure
	if(power_failure)
		if(connected_portal && !QDELETED(connected_portal))
			connected_portal.say("Emergency shutdown: Power failure detected!")
	else
		if(connected_portal && !QDELETED(connected_portal))
			connected_portal.say("Initiating controlled shutdown...")

	handle_mobs_optimized(z_level, ejection_turf)
	CHECK_TICK

	delete_all_content_optimized(z_level)
	CHECK_TICK

	reset_z_level_to_space(z_level)
	CHECK_TICK

	cleanup_portal_connections()

	generated = FALSE
	generating = FALSE
	generation_progress = 0
	current_request_id = 0
	actual_dungeon_portal_location = null

	processing_disabled = FALSE
	cleanup_in_progress = FALSE

/datum/portal_destination/veilbreak/proc/handle_mobs_optimized(z_level, turf/ejection_turf)
	var/mobs_deleted = 0
	var/mobs_ejected = 0

	var/list/mobs_to_process = list()
	for(var/mob/M in world)
		if(M.z == z_level && !QDELETED(M))
			mobs_to_process += M

	for(var/mob/mob in mobs_to_process)
		if(QDELETED(mob))
			continue

		if(isobserver(mob))
			continue

		var/should_delete = FALSE
		var/should_eject = FALSE

		if(isliving(mob))
			var/mob/living/living_mob = mob

			// Remove from mobs subsystem processing to prevent errors during cleanup
			if(living_mob in GLOB.mob_living_list)
				GLOB.mob_living_list -= living_mob

			// UPDATED: Check for ALL our specific void creatures and megafauna
			if(is_our_void_mob(living_mob))
				should_delete = TRUE
			// Then check for void faction as backup
			else if(living_mob.faction == FACTION_VOID)
				should_delete = TRUE
			// Then check for other hostile mobs
			else if(is_hostile_mob(living_mob))
				should_delete = TRUE
			else
				// Only non-void, non-hostile mobs should be ejected
				should_eject = TRUE

		else
			// For non-living mobs, use simpler check
			if(is_hostile_or_void(mob))
				should_delete = TRUE
			else
				should_eject = TRUE

		if(should_delete)
			qdel(mob)
			mobs_deleted++
			if(mobs_deleted % 10 == 0)
				CHECK_TICK

		else if(should_eject && ejection_turf && !QDELETED(ejection_turf))
			// CRITICAL: Ensure we're ejecting to the STATION side portal, not the dungeon portal
			var/turf/actual_ejection_turf = find_station_ejection_turf()
			if(!actual_ejection_turf)
				actual_ejection_turf = ejection_turf // Fallback

			mob.forceMove(actual_ejection_turf)

			var/throw_target = get_edge_target_turf(actual_ejection_turf, pick(GLOB.cardinals))
			mob.throw_at(throw_target, 3, 2, spin = TRUE)

			if(isliving(mob))
				var/mob/living/living_mob = mob
				if(living_mob.stat == CONSCIOUS)
					living_mob.Stun(12 SECONDS)
					to_chat(living_mob, span_warning("The portal violently collapses! You're thrown clear!"))
					playsound(living_mob, 'sound/effects/bang.ogg', 60, TRUE)
				else
					living_mob.visible_message(span_notice("[living_mob] is thrown from a collapsing portal!"))
					playsound(living_mob, 'sound/effects/bang.ogg', 40, TRUE)

			// Add back to mobs subsystem processing if it's a living mob that was ejected
			if(isliving(mob) && !(mob in GLOB.mob_living_list))
				GLOB.mob_living_list += mob

			mobs_ejected++
			if(mobs_ejected % 10 == 0)
				CHECK_TICK

		else
			// If we get here and shouldn't delete but can't eject, just delete to be safe
			qdel(mob)
			mobs_deleted++

/datum/portal_destination/veilbreak/proc/is_our_void_mob(mob/living/mob)
	// UPDATED: Direct type checking for ALL our specific void creatures and megafauna
	if(istype(mob, /mob/living/basic/void_creature/void_healer))
		return TRUE
	if(istype(mob, /mob/living/basic/void_creature/voidbug))
		return TRUE
	if(istype(mob, /mob/living/basic/void_creature/consumed_pathfinder))
		return TRUE
	if(istype(mob, /mob/living/basic/void_creature/voidling))
		return TRUE
	if(istype(mob, /mob/living/simple_animal/hostile/megafauna/inai))
		return TRUE
	if(istype(mob, /mob/living/simple_animal/hostile/megafauna/melos_vecare))
		return TRUE

	// Also check parent types as fallback
	if(istype(mob, /mob/living/basic/void_creature))
		return TRUE

	// Check for void in name as additional safety
	if(findtext(lowertext(mob.name), "void"))
		return TRUE
	return FALSE

/datum/portal_destination/veilbreak/proc/is_hostile_mob(mob/living/mob)
	// Check if mob is naturally hostile
	if(istype(mob, /mob/living/simple_animal/hostile))
		return TRUE
	// Check AI behavior
	if(mob.ai_controller)
		var/datum/ai_controller/controller = mob.ai_controller
		if(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
			return TRUE
	// Check if mob has attacked anyone recently - simplified check
	if(mob.ckey && mob.client) // Player mobs - assume not hostile unless proven otherwise
		return FALSE
	// For non-player mobs, assume hostile if they're basic mobs without players
	if(istype(mob, /mob/living/basic) && !mob.ckey)
		return TRUE
	return FALSE

/datum/portal_destination/veilbreak/proc/is_hostile_or_void(mob/mob)
	// Combined check for non-living mobs
	if(isliving(mob))
		var/mob/living/living_mob = mob
		return is_our_void_mob(living_mob) || is_hostile_mob(living_mob)
	return FALSE

/datum/portal_destination/veilbreak/proc/find_station_ejection_turf()
	// Find the station-side portal for ejection
	if(connected_portal && !QDELETED(connected_portal))
		var/turf/station_turf = get_turf(connected_portal)
		if(station_turf)
			var/turf/ejection_turf = get_step(station_turf, SOUTH)
			if(!ejection_turf || !isfloorturf(ejection_turf))
				ejection_turf = station_turf
			return ejection_turf

	// Fallback: find any portal control console - use world iteration
	for(var/obj/machinery/computer/portal_control/console in world)
		if(console.linked_portal && !QDELETED(console.linked_portal))
			var/turf/console_turf = get_turf(console.linked_portal)
			if(console_turf)
				var/turf/ejection_turf = get_step(console_turf, SOUTH)
				if(!ejection_turf || !isfloorturf(ejection_turf))
					ejection_turf = console_turf
				return ejection_turf

	return null

/datum/portal_destination/veilbreak/proc/delete_all_content_optimized(z_level)
	var/areas_purged = 0
	var/ticks_checked = 0

	// First pass: delete all objects on the Z-level
	for(var/obj/object in world)
		if(object.z != z_level)
			continue

		// Skip space turfs and basic space
		if(istype(object, /turf/open/space) || istype(object, /turf/open/space/basic))
			continue

		// Skip mobs as they're handled separately
		if(ismob(object))
			continue

		// Skip portals as they're handled in cleanup_portal_connections
		if(istype(object, /obj/machinery/portal))
			continue

		qdel(object)
		ticks_checked++

		if(ticks_checked % 50 == 0)
			CHECK_TICK

	// Second pass: reset area power settings
	for(var/area/area in world)
		var/has_turfs_on_z = FALSE
		for(var/turf/T in area.contents)
			if(T.z == z_level)
				has_turfs_on_z = TRUE
				break

		if(has_turfs_on_z)
			area.power_equip = FALSE
			area.power_light = FALSE
			area.power_environ = FALSE
			area.always_unpowered = TRUE
			area.power_change()
			areas_purged++

		if(areas_purged % 10 == 0)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/reset_z_level_to_space(z_level)
	var/turfs_processed = 0
	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(!istype(T, /turf/open/space/basic))
			T.ChangeTurf(/turf/open/space/basic, FALSE, FALSE)
		turfs_processed++

		if(turfs_processed % 100 == 0)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/cleanup_portal_connections()
	// Clean up the station-side portal connection
	if(connected_portal && !QDELETED(connected_portal))
		if(connected_portal.target == src)
			connected_portal.target = null
			connected_portal.transport_active = FALSE
			connected_portal.update_appearance()

		// Clean up any simple return destinations pointing to this portal
		for(var/key in GLOB.portal_destinations)
			var/datum/portal_destination/dest = GLOB.portal_destinations[key]
			if(istype(dest, /datum/portal_destination/simple))
				var/datum/portal_destination/simple/simple_dest = dest
				if(simple_dest.return_portal == connected_portal)
					GLOB.portal_destinations -= key
					break

	// Clean up all portals on the dungeon Z-level
	var/portals_removed = 0
	for(var/turf/T in block(locate(1, 1, dungeon_z_level), locate(world.maxx, world.maxy, dungeon_z_level)))
		var/obj/machinery/portal/dungeon_portal = locate(/obj/machinery/portal) in T
		if(dungeon_portal && !QDELETED(dungeon_portal))
			if(dungeon_portal.target)
				dungeon_portal.target = null
				dungeon_portal.transport_active = FALSE

			QDEL_NULL(dungeon_portal)
			portals_removed++

			if(portals_removed % 10 == 0)
				CHECK_TICK

		if(portals_removed % 100 == 0)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/enable_processing()
	processing_disabled = FALSE
	cleanup_in_progress = FALSE
