// modular_zzveilbreak/code/modules/dungeons/portal_destinations_cleanup.dm

// Completely clean a Z-level before reuse with background processing
/datum/portal_destination/veilbreak/proc/cleanup_z_level_completely(z_level)
	log_dungeon("Cleanup: Starting background cleanup of Z-level [z_level]")

	// Use background processing for cleanup
	cleanup_process = new /datum/background_process(CALLBACK(src, .proc/execute_cleanup_step, z_level), "portal_cleanup_[z_level]")
	cleanup_process.start()

	return TRUE // Return immediately, cleanup happens in background

/datum/portal_destination/veilbreak/proc/execute_cleanup_step(z_level)
	if(processing_disabled)
		log_dungeon("Cleanup: Cleanup step aborted - processing disabled")
		return BG_PROCESSING_FINISHED

	var/start_time = world.time
	var/max_processing_time = MAX_PROCESSING_TIME_PER_TICK
	var/processed_count = cleanup_process.metadata["cleanup_processed"] || 0

	log_dungeon("Cleanup: Executing step - processed so far: [processed_count]")

	// Process mobs in chunks
	for(var/mob/living/mob in GLOB.mob_living_list)
		if(mob.z != z_level)
			continue

		if(should_preserve_for_cleanup(mob))
			continue

		qdel(mob)
		processed_count++

		// Check if we've used our time budget for this tick
		if(world.time - start_time > max_processing_time)
			cleanup_process.metadata["cleanup_processed"] = processed_count
			log_dungeon("Cleanup: Yielding after [processed_count] mobs")
			return BG_PROCESSING_CONTINUE // Continue next tick

	// Process objects in chunks
	for(var/obj/object in world)
		if(object.z != z_level)
			continue

		if(should_preserve_object(object))
			continue

		qdel(object)
		processed_count++

		if(world.time - start_time > max_processing_time)
			cleanup_process.metadata["cleanup_processed"] = processed_count
			log_dungeon("Cleanup: Yielding after [processed_count] objects")
			return BG_PROCESSING_CONTINUE

	// Reset turfs to space in chunks
	var/turf_processed = cleanup_process.metadata["turf_processed"] || 0
	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(turf_processed > 0) // Skip already processed turfs
			turf_processed--
			continue

		if(istype(T, /turf/open/space/basic))
			continue

		T.ChangeTurf(/turf/open/space/basic, FALSE, FALSE)
		processed_count++

		if(world.time - start_time > max_processing_time)
			cleanup_process.metadata["cleanup_processed"] = processed_count
			cleanup_process.metadata["turf_processed"] = turf_processed + 1
			log_dungeon("Cleanup: Yielding after [processed_count] items")
			return BG_PROCESSING_CONTINUE

	// Cleanup complete
	log_dungeon("Cleanup: COMPLETE for Z-level [z_level] - processed [processed_count] items")
	cleanup_process = null
	return BG_PROCESSING_FINISHED

// FIXED: Improved cleanup with better mob handling
/datum/portal_destination/veilbreak/proc/cleanup_dungeon()
	if(cleanup_in_progress || processing_disabled)
		log_dungeon("Cleanup: Already in progress or disabled, skipping")
		return

	cleanup_in_progress = TRUE
	processing_disabled = TRUE

	if(!dungeon_z_level)
		log_dungeon("Cleanup: No Z-level to clean up")
		cleanup_in_progress = FALSE
		processing_disabled = FALSE
		return

	log_dungeon("Cleanup: Starting comprehensive cleanup for Z-level [dungeon_z_level]")

	// Stop any background processing first
	STOP_PROCESSING(SSobj, src)
	if(cleanup_process)
		cleanup_process.stop()
		cleanup_process = null
	if(init_process)
		init_process.stop()
		init_process = null
	if(load_process)
		load_process.stop()
		load_process = null

	// 1. Clean up all mobs and objects on the Z-level
	cleanup_z_level_contents(dungeon_z_level)

	// 2. Reset all turfs to space
	reset_z_level_to_space(dungeon_z_level)

	// 3. Clean up any remaining portal connections with safety checks
	if(connected_portal && !QDELETED(connected_portal) && connected_portal.target == src)
		connected_portal.target = null
		connected_portal.transport_active = FALSE
		connected_portal.update_appearance()
		log_dungeon("Cleanup: Disconnected station portal")

	// 4. Clean up any dungeon-side portal safely
	var/obj/machinery/portal/dungeon_portal = get_portal_from_gateway_location()
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

	// 5. Reset state - but keep the Z-level for reuse
	generated = FALSE
	generating = FALSE
	generation_progress = 0
	current_request_id = 0
	// Don't clear last_generation_data - we might want it for analytics

	// Re-enable processing after cleanup
	addtimer(CALLBACK(src, .proc/enable_processing), 2 SECONDS)

	log_dungeon("Cleanup: Cleanup complete for veilbreak destination")

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

/datum/portal_destination/veilbreak/proc/enable_processing()
	processing_disabled = FALSE
	cleanup_in_progress = FALSE
	log_dungeon("Cleanup: Processing re-enabled")

/datum/portal_destination/veilbreak/proc/cleanup_z_level_contents(z_level)
	log_dungeon("Cleanup: Cleaning up contents of Z-level [z_level]")

	var/mobs_cleaned = 0
	var/objects_cleaned = 0

	// Clean up all non-player mobs
	for(var/mob/living/mob in GLOB.mob_list)
		if(mob.z == z_level)
			// Skip players and player-related entities (they should have been dumped already)
			if(mob.ckey || mob.client || is_player_related_for_cleanup(mob))
				continue
			// Delete hostile/npc mobs
			qdel(mob)
			mobs_cleaned++

	// Clean up non-essential objects
	for(var/obj/object in world)
		if(object.z == z_level)
			// Skip important structures and player items
			if(should_preserve_object(object))
				continue
			qdel(object)
			objects_cleaned++

	log_dungeon("Cleanup: Cleaned up [mobs_cleaned] mobs and [objects_cleaned] objects from Z-level [z_level]")

/// Check if an object should be preserved during cleanup
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

/// Check if a mob is player-related for cleanup purposes
/datum/portal_destination/veilbreak/proc/is_player_related_for_cleanup(mob/living/mob)
	// Players with active connections
	if(mob.client)
		return TRUE
	// Players with ckeys (SSD)
	if(mob.ckey)
		return TRUE
	// Player corpses with minds
	if(mob.stat == DEAD && mob.mind)
		return TRUE
	// Cyborgs with players
	if(iscyborg(mob) && (mob.ckey || mob.mind))
		return TRUE
	return FALSE

// Check if an atom should be preserved during Z-level cleanup
/datum/portal_destination/veilbreak/proc/should_preserve_for_cleanup(atom/movable/AM)
	// Preserve players and player-related entities
	if(ismob(AM))
		var/mob/M = AM
		if(M.client || M.ckey)
			return TRUE
		if(M.mind)
			return TRUE

	// Preserve important portal infrastructure
	if(istype(AM, /obj/machinery/portal))
		return TRUE
	if(istype(AM, /obj/effect/portal_bumper))
		return TRUE

	// Preserve station-bound items and structures
	if(AM.resistance_flags & INDESTRUCTIBLE)
		return TRUE

	return FALSE

// ===== PORTAL CONNECTION SYSTEM =====
/datum/portal_destination/veilbreak/proc/ensure_portal_connection()
	if(!dungeon_z_level)
		log_dungeon("Connection: Cannot ensure connection - no Z-level assigned")
		return FALSE

	log_dungeon("Connection: Using pre-determined gateway location from JSON")

	// Get the portal at the exact gateway location from JSON
	var/obj/machinery/portal/found_portal = get_portal_from_gateway_location()

	if(found_portal)
		log_dungeon("Connection: Found portal at gateway location [AREACOORD(found_portal)]")
		return connect_to_existing_portal(found_portal)
	else
		log_dungeon("Connection: ERROR - No portal found at gateway location")
		return FALSE

/// Get portal from the pre-determined gateway location from JSON
/datum/portal_destination/veilbreak/proc/get_portal_from_gateway_location()
	if(!last_generation_data || !last_generation_data["metadata"])
		log_dungeon("Gateway: No generation data available")
		return null

	var/list/metadata = last_generation_data["metadata"]
	var/list/key_positions = metadata["key_positions"]

	if(!key_positions || !key_positions["gateway"])
		log_dungeon("Gateway: No gateway position in metadata")
		return null

	var/list/gateway_pos = key_positions["gateway"]
	var/gateway_x = gateway_pos["x"]
	var/gateway_y = gateway_pos["y"]

	if(!gateway_x || !gateway_y)
		log_dungeon("Gateway: Invalid gateway coordinates: x=[gateway_x], y=[gateway_y]")
		return null

	// Look for portal at the exact gateway location
	var/turf/gateway_turf = locate(gateway_x, gateway_y, dungeon_z_level)
	if(!gateway_turf)
		log_dungeon("Gateway: Invalid gateway turf at [gateway_x],[gateway_y],[dungeon_z_level]")
		return null

	var/obj/machinery/portal/found_portal = locate(/obj/machinery/portal) in gateway_turf
	if(found_portal)
		log_dungeon("Gateway: Found portal at pre-determined location [AREACOORD(found_portal)]")
		return found_portal

	log_dungeon("Gateway: No portal found at pre-determined gateway location [gateway_x],[gateway_y],[dungeon_z_level]")
	return null

/datum/portal_destination/veilbreak/proc/connect_to_existing_portal(obj/machinery/portal/dungeon_portal)
	if(!dungeon_portal || QDELETED(dungeon_portal))
		log_dungeon("Connection: Invalid dungeon portal")
		return FALSE

	log_dungeon("Connection: Connecting to existing portal at [AREACOORD(dungeon_portal)]")

	// Configure the found portal for dungeon use
	dungeon_portal.use_power = NO_POWER_USE
	dungeon_portal.portal_possible = TRUE

	// Ensure it has a bumper
	if(!dungeon_portal.bumper)
		dungeon_portal.generate_bumper()

	// Create return destination
	var/datum/portal_destination/simple/return_destination = new()
	return_destination.name = "Return to Station"
	return_destination.return_portal = connected_portal

	// Register return destination
	var/return_id = "veilbreak_return_[dungeon_z_level]_[world.time]"
	GLOB.portal_destinations[return_id] = return_destination
	log_dungeon("Connection: Registered return destination [return_id]")

	// Configure the dungeon portal to target the return destination
	dungeon_portal.target = return_destination
	dungeon_portal.transport_active = TRUE
	dungeon_portal.update_appearance()

	log_dungeon("Connection: Dungeon portal configured at [AREACOORD(dungeon_portal)]")

	// Configure the station portal to target this dungeon
	if(connected_portal && !QDELETED(connected_portal))
		connected_portal.target = src
		connected_portal.transport_active = TRUE
		connected_portal.update_appearance()

		log_dungeon("Connection: SUCCESS - Bidirectional connection established!")
		log_dungeon("Connection: Station -> Dungeon: [AREACOORD(connected_portal)]")
		log_dungeon("Connection: Dungeon -> Station: [AREACOORD(dungeon_portal)]")
		return TRUE

	log_dungeon("Connection: WARNING - No connected portal found for station side")
	return FALSE
