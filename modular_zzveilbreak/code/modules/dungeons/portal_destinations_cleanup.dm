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

// Initialize dungeon subsystems with proper tick checking
/datum/portal_destination/veilbreak/proc/initialize_dungeon_subsystems(z_level)
	log_dungeon("Subsystems: Starting background initialization for Z-level [z_level]")

	// Use background processing for initialization
	init_process = new /datum/background_process(CALLBACK(src, .proc/execute_init_step, z_level), "portal_init_[z_level]")
	init_process.start()

	return TRUE // Return immediately, initialization happens in background

/datum/portal_destination/veilbreak/proc/execute_init_step(z_level)
	if(processing_disabled)
		log_dungeon("Subsystems: Init step aborted - processing disabled")
		return BG_PROCESSING_FINISHED

	var/start_time = world.time
	var/max_processing_time = MAX_PROCESSING_TIME_PER_TICK
	var/current_step = init_process.metadata["current_step"] || 1

	log_dungeon("Subsystems: Executing step [current_step]")

	switch(current_step)
		if(1) // Initialize atoms
			var/result = initialize_dungeon_atoms_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(2) // Initialize areas
			var/result = initialize_dungeon_areas_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(3) // Initialize power
			var/result = initialize_dungeon_power_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(4) // Initialize lighting
			var/result = initialize_dungeon_lighting_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(5) // Initialize atmospherics
			var/result = initialize_dungeon_atmospherics_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(6) // Initialize machinery
			var/result = initialize_dungeon_machinery_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(7) // Safe smoothing initialization using SSicon_smooth
			log_dungeon("Subsystems: Starting safe smoothing initialization")
			safe_initialize_smoothing(z_level)
			current_step++
			init_process.metadata["current_step"] = current_step
			return BG_PROCESSING_CONTINUE

		if(8) // Visual updates (skip smoothing operations)
			var/result = force_immediate_visual_updates_incremental(z_level, start_time, max_processing_time)
			if(result == BG_PROCESSING_CONTINUE)
				return BG_PROCESSING_CONTINUE

	// Initialization complete
	log_dungeon("Subsystems: INITIALIZATION COMPLETE for Z-level [z_level]")

	// Ensure portal connection now that everything is ready
	ensure_portal_connection()

	init_process = null
	return BG_PROCESSING_FINISHED

// NEW: Safe smoothing initialization using SSicon_smooth subsystem
/datum/portal_destination/veilbreak/proc/safe_initialize_smoothing(z_level)
	log_dungeon("Smoothing: Starting safe smoothing initialization for Z-level [z_level]")

	if(!SSicon_smooth.initialized)
		log_dungeon("Smoothing: SSicon_smooth not initialized, skipping")
		return

	var/smoothed_count = 0
	var/skipped_count = 0

	// Process all atoms on the Z-level and safely add them to smoothing queue
	for(var/atom/A in world)
		if(A.z != z_level)
			continue

		// Skip atoms that are likely to cause smoothing errors
		if(should_skip_smoothing(A))
			skipped_count++
			continue

		// Only queue atoms that actually need smoothing
		if(A.smoothing_flags && !(A.smoothing_flags & SMOOTH_QUEUED))
			// FIXED: Remove try-catch since it's not properly structured in DM
			// Use the SSicon_smooth subsystem to queue the atom
			SSicon_smooth.add_to_queue(A)
			smoothed_count++

		CHECK_TICK

	log_dungeon("Smoothing: Completed - [smoothed_count] atoms queued, [skipped_count] skipped")

	// FIXED: Use proper SSicon_smooth method instead of undefined .wake()
	if(smoothed_count > 0 && SSicon_smooth.can_fire)
		log_dungeon("Smoothing: Smoothing subsystem will process queued atoms automatically")
		// SSicon_smooth will process automatically, no need to manually wake it

/datum/portal_destination/veilbreak/proc/should_skip_smoothing(atom/A)
	// Skip objects that are known to cause smoothing runtime errors
	if(istype(A, /obj/structure/alien/weeds))
		return TRUE

	// Skip atoms that aren't fully initialized
	if(!(A.flags_1 & INITIALIZED_1))
		return TRUE

	// Skip atoms without proper loc or z-level
	if(!A.loc || !A.z)
		return TRUE

	// Skip atoms that are queued for deletion
	if(QDELETED(A))
		return TRUE

	// Skip if the atom doesn't actually have smoothing flags set
	if(!A.smoothing_flags)
		return TRUE

	// Skip if atom is already in the smoothing queue
	if(A.smoothing_flags & SMOOTH_QUEUED)
		return TRUE

	return FALSE

// Incremental versions of initialization procs with proper tick checking
/datum/portal_destination/veilbreak/proc/initialize_dungeon_atoms_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["atom_index"] || 1
	var/list/atoms_to_initialize = init_process.metadata["atoms_list"]

	if(!atoms_to_initialize)
		// First call - build the list
		atoms_to_initialize = list()
		for(var/atom/A in world)
			if(A.z == z_level)
				atoms_to_initialize += A
		init_process.metadata["atoms_list"] = atoms_to_initialize
		init_process.metadata["atom_index"] = 1
		log_dungeon("Subsystems: Found [length(atoms_to_initialize)] atoms to initialize")
		return BG_PROCESSING_CONTINUE

	for(var/i = current_index to min(current_index + 50, length(atoms_to_initialize)))
		var/atom/A = atoms_to_initialize[i]
		if(!(A.flags_1 & INITIALIZED_1))
			SSatoms.InitAtom(A, FALSE, list(FALSE))

		if(world.time - start_time > max_time)
			init_process.metadata["atom_index"] = i + 1
			log_dungeon("Subsystems: Atom initialization yielding at index [i]")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Atom initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_areas_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["area_index"] || 1
	var/list/areas_to_process = init_process.metadata["areas_list"]

	if(!areas_to_process)
		areas_to_process = list()
		for(var/area/area as anything in GLOB.areas)
			var/has_turfs_on_z = FALSE
			for(var/turf/T in area.contents)
				if(T.z == z_level)
					has_turfs_on_z = TRUE
					break
			if(has_turfs_on_z)
				areas_to_process += area
		init_process.metadata["areas_list"] = areas_to_process
		init_process.metadata["area_index"] = 1
		log_dungeon("Subsystems: Found [length(areas_to_process)] areas to initialize")
		return BG_PROCESSING_CONTINUE

	for(var/i = current_index to min(current_index + 20, length(areas_to_process)))
		var/area/area = areas_to_process[i]
		area.power_equip = initial(area.power_equip)
		area.power_light = initial(area.power_light)
		area.power_environ = initial(area.power_environ)
		area.always_unpowered = initial(area.always_unpowered)
		area.power_change()
		area.update_icon()

		if(world.time - start_time > max_time)
			init_process.metadata["area_index"] = i + 1
			log_dungeon("Subsystems: Area initialization yielding at index [i]")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Area initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_power_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["power_index"] || 1

	// Initialize machinery power states
	for(var/obj/machinery/machine in world)
		if(machine.z != z_level)
			continue

		machine.power_change()

		if(world.time - start_time > max_time)
			init_process.metadata["power_index"] = current_index + 1
			log_dungeon("Subsystems: Power initialization yielding")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Power initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_lighting_incremental(z_level, start_time, max_time)
	if(!SSlighting || !SSlighting.initialized)
		log_dungeon("Subsystems: Lighting subsystem not available")
		return BG_PROCESSING_FINISHED

	var/current_x = init_process.metadata["lighting_x"] || 1
	var/current_y = init_process.metadata["lighting_y"] || 1

	for(var/x = current_x to world.maxx)
		for(var/y = current_y to world.maxy)
			var/turf/iter_turf = locate(x, y, z_level)
			if(!iter_turf.space_lit && !iter_turf.lighting_object)
				new /datum/lighting_object(iter_turf)

			if(world.time - start_time > max_time)
				init_process.metadata["lighting_x"] = x
				init_process.metadata["lighting_y"] = y + 1
				log_dungeon("Subsystems: Lighting initialization yielding at [x],[y]")
				return BG_PROCESSING_CONTINUE
		current_y = 1

	log_dungeon("Subsystems: Lighting initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_atmospherics_incremental(z_level, start_time, max_time)
	if(!SSair || !SSair.initialized)
		log_dungeon("Subsystems: Air subsystem not available")
		return BG_PROCESSING_FINISHED

	// Atmos machinery will be handled by SSair naturally
	log_dungeon("Subsystems: Atmospherics initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/initialize_dungeon_machinery_incremental(z_level, start_time, max_time)
	var/current_index = init_process.metadata["machinery_index"] || 1

	for(var/obj/machinery/machine in world)
		if(machine.z != z_level)
			continue

		if(machine.use_power)
			machine.power_change()
		machine.update_icon()
		machine.update_appearance()

		if(world.time - start_time > max_time)
			init_process.metadata["machinery_index"] = current_index + 1
			log_dungeon("Subsystems: Machinery initialization yielding")
			return BG_PROCESSING_CONTINUE

	log_dungeon("Subsystems: Machinery initialization completed")
	return BG_PROCESSING_FINISHED

/datum/portal_destination/veilbreak/proc/force_immediate_visual_updates_incremental(z_level, start_time, max_time)
	var/current_x = init_process.metadata["visual_x"] || 1
	var/current_y = init_process.metadata["visual_y"] || 1

	for(var/x = current_x to world.maxx)
		for(var/y = current_y to world.maxy)
			var/turf/iter_turf = locate(x, y, z_level)
			if(!istype(iter_turf, /obj/effect) && !istype(iter_turf, /obj/effect/decal))
				// Safe visual updates only - no smoothing operations
				iter_turf.update_icon()
				iter_turf.update_appearance()

			if(world.time - start_time > max_time)
				init_process.metadata["visual_x"] = x
				init_process.metadata["visual_y"] = y + 1
				log_dungeon("Subsystems: Visual updates yielding at [x],[y]")
				return BG_PROCESSING_CONTINUE
		current_y = 1

	log_dungeon("Subsystems: Visual updates completed")
	return BG_PROCESSING_FINISHED

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

// ===== CLEANUP AND UTILITY PROCS =====
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

	// 2. Clean up any remaining portal connections with safety checks
	if(connected_portal && !QDELETED(connected_portal) && connected_portal.target == src)
		connected_portal.target = null
		connected_portal.transport_active = FALSE
		connected_portal.update_appearance()
		log_dungeon("Cleanup: Disconnected station portal")

	// 3. Clean up any dungeon-side portal safely
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

	// 4. Reset state - but keep the Z-level for reuse
	generated = FALSE
	generating = FALSE
	// Don't clear last_generation_data - we might want it for analytics

	// Re-enable processing after cleanup
	addtimer(CALLBACK(src, .proc/enable_processing), 1 SECONDS)

	log_dungeon("Cleanup: Cleanup complete for veilbreak destination")

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
