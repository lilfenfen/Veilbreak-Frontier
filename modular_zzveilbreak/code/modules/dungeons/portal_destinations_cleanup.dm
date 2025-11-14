// modular_zzveilbreak/code/modules/dungeons/portal_destinations_cleanup.dm

/datum/portal_destination/veilbreak/proc/cleanup_z_level_completely(z_level, turf/ejection_turf = null)
	if(!z_level || z_level < 1 || z_level > world.maxz)
		return

	if(z_level != dungeon_z_level)
		return

	cleanup_in_progress = TRUE
	processing_disabled = TRUE

	STOP_PROCESSING(SSobj, src)

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

		if(isliving(mob))
			var/mob/living/living_mob = mob
			if(living_mob.faction == FACTION_VOID)
				should_delete = TRUE

		if(!should_delete && is_hostile_or_void(mob))
			should_delete = TRUE

		if(should_delete)
			qdel(mob)
			mobs_deleted++

		else if(ejection_turf && !QDELETED(ejection_turf))
			mob.forceMove(ejection_turf)

			var/throw_target = get_edge_target_turf(ejection_turf, pick(GLOB.cardinals))
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

			mobs_ejected++

		if((mobs_deleted + mobs_ejected) % 25 == 0)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/delete_all_content_optimized(z_level)
	var/areas_purged = 0
	var/ticks_checked = 0

	for(var/obj/object in world)
		if(object.z != z_level)
			continue

		if(istype(object, /turf/open/space) || istype(object, /turf/open/space/basic))
			continue

		qdel(object)
		ticks_checked++

		if(ticks_checked % 50 == 0)
			CHECK_TICK

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
	if(connected_portal && !QDELETED(connected_portal))
		if(connected_portal.target == src)
			connected_portal.target = null
			connected_portal.transport_active = FALSE
			connected_portal.update_appearance()

		for(var/key in GLOB.portal_destinations)
			var/datum/portal_destination/dest = GLOB.portal_destinations[key]
			if(istype(dest, /datum/portal_destination/simple))
				var/datum/portal_destination/simple/simple_dest = dest
				if(simple_dest.return_portal == connected_portal)
					GLOB.portal_destinations -= key
					break

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
