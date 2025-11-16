// modular_zzveilbreak/code/modules/dungeons/portal_destinations_generation.dm

/datum/portal_destination/veilbreak/proc/start_generation()
	if(generating)
		return FALSE

	// Check subsystem readiness
	if(!subsystems_ready_for_portals())
		generation_failed("Subsystems not ready")
		return FALSE

	generating = TRUE
	generated = FALSE
	generation_progress = 0

	if(!GLOB.dungeon_generator)
		GLOB.dungeon_generator = new /datum/http_dungeon_generator()

	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, DUNGEON_WIDTH, DUNGEON_HEIGHT)

	if(!current_request_id)
		generating = FALSE
		generation_failed("Failed to start generation request")
		return FALSE

	START_PROCESSING(SSobj, src)
	return TRUE

/datum/portal_destination/veilbreak/process()
	if(processing_disabled)
		STOP_PROCESSING(SSobj, src)
		return

	if(!generating)
		STOP_PROCESSING(SSobj, src)
		return

	if(world.time - last_progress_update > 1 SECONDS)
		generation_progress = min(generation_progress + rand(5, 15), 90)
		last_progress_update = world.time

	if(current_request_id)
		var/still_processing = GLOB.dungeon_generator.check_request(current_request_id)
		if(!still_processing)
			STOP_PROCESSING(SSobj, src)
			generation_progress = 100
			return

	STOP_PROCESSING(SSobj, src)
	generation_failed("Generation process stuck in invalid state")

/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	generating = FALSE

	last_generation_data = data.Copy()

	// Ensure we have proper map_name data
	if(data["dmm_content"])
		load_generated_dmm(data["dmm_content"])
	else
		generation_failed("No DMM content in response")

	// Notify control computer immediately with the new data
	if(connected_control_computer && !QDELETED(connected_control_computer))
		connected_control_computer.on_generation_completed()
		// Also update the name immediately
		connected_control_computer.cached_portal_name = get_portal_name_from_data(data)
		connected_control_computer.force_ui_update()

/datum/portal_destination/veilbreak/proc/get_portal_name_from_data(list/data)
	if(!data)
		return "Quantum Pocket Space"

	// Try to get map_name from metadata first
	if(data["metadata"] && data["metadata"]["map_name"])
		var/map_name = data["metadata"]["map_name"]
		if(map_name && map_name != "0" && map_name != "")
			return map_name

	// Try direct map_name
	if(data["map_name"])
		var/map_name = data["map_name"]
		if(map_name && map_name != "0" && map_name != "")
			return map_name

	return "Quantum Pocket Space"

/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content)
	if(!dmm_content)
		return generation_failed("No DMM content provided")

	if(!initialize_portal_z_level())
		return generation_failed("Failed to initialize portal Z-level")

	load_dmm_with_ticks(dmm_content)

/datum/portal_destination/veilbreak/proc/load_dmm_with_ticks(dmm_content)
	if(!dmm_content || length(dmm_content) < 100)
		generation_failed("Invalid map data received")
		return

	var/temp_filename = "data/dungeon_temp_[world.time]_[rand(1000,9999)].dmm"

	try
		text2file(dmm_content, temp_filename)
	catch
		generation_failed("Failed to write map data")
		return

	// Use the same map loading pattern as SSmapping
	SSatoms.map_loader_begin("dungeon_generator_[dungeon_z_level]")

	if(SSair.initialized)
		SSair.StartLoadingMap()

	var/loaded_successfully = FALSE
	var/error_message = "Unknown error"

	try
		var/datum/parsed_map/parsed = new(file(temp_filename))
		if(parsed && parsed.bounds)
			// Use the same parameters as SSmapping's LoadGroup
			loaded_successfully = parsed.load(1, 1, dungeon_z_level, no_changeturf = FALSE, place_on_top = FALSE, new_z = FALSE)
		else
			error_message = "Failed to parse map file - no bounds"
			loaded_successfully = FALSE
	catch(var/exception/e2)
		error_message = "Exception during map load: [e2]"
		loaded_successfully = FALSE

	if(SSair.initialized)
		SSair.StopLoadingMap()

	SSatoms.map_loader_stop("dungeon_generator_[dungeon_z_level]")

	fdel(temp_filename)

	if(!loaded_successfully)
		generation_failed("Failed to load map: [error_message]")
		return

	// CRITICAL: Wait for SSatoms to finish processing the new map
	addtimer(CALLBACK(src, .proc/finalize_dungeon_generation, dungeon_z_level), 1 SECONDS)

/datum/portal_destination/veilbreak/proc/finalize_dungeon_generation(z_level)
	// CRITICAL: Initialize all atoms on the new Z-level
	initialize_atoms_on_z_level(z_level)
	CHECK_TICK

	// DEBUG: Check what's actually on the Z-level
	debug_z_level_contents(z_level)
	CHECK_TICK

	// STEP 1: Check for placeholders (map generator should have placed these)
	replace_map_mobs_with_placeholders(z_level)
	CHECK_TICK

	// STEP 2: Spawn properly initialized mobs from placeholders
	spawn_mobs_from_placeholders(z_level)
	CHECK_TICK

	// CRITICAL: Debug mob state AFTER spawning
	debug_mob_state("AFTER MOB SPAWNING", z_level)
	CHECK_TICK

	// CRITICAL: Force AI initialization for all basic mobs
	force_ai_initialization_fixed(z_level)
	CHECK_TICK

	// CRITICAL: Debug mob state AFTER AI initialization
	debug_mob_state("AFTER AI INIT", z_level)
	CHECK_TICK

	// CRITICAL: Ensure mobs are hostile to players
	ensure_mob_hostility(z_level)
	CHECK_TICK

	// Initialize areas and power
	initialize_areas_and_power(z_level)
	CHECK_TICK

	// Initialize machinery
	initialize_machinery(z_level)
	CHECK_TICK

	// CRITICAL: Force SSair initialization
	force_air_initialization(z_level)
	CHECK_TICK

	// CRITICAL: Force SSlighting initialization
	force_lighting_initialization(z_level)
	CHECK_TICK

	// Initialize smoothing
	initialize_enhanced_smoothing(z_level)
	CHECK_TICK

	ensure_portal_connection()

	generated = TRUE

	// Debug mob state after all systems are initialized
	debug_mob_state("AFTER ALL SYSTEMS", z_level)
	CHECK_TICK

	// Final check to ensure AI systems are running
	addtimer(CALLBACK(src, .proc/final_ai_verification, z_level), 2 SECONDS)

	// Force one more AI activation pass after everything is settled
	addtimer(CALLBACK(src, .proc/final_ai_activation, z_level), 3 SECONDS)

/datum/portal_destination/veilbreak/proc/debug_z_level_contents(z_level)
	// Debug what's actually on the Z-level
	message_admins("DEBUG Z[z_level] CONTENTS: Starting comprehensive scan")

	var/total_turfs = 0
	var/total_objs = 0
	var/total_mobs = 0
	var/total_placeholders = 0
	var/other_objects = 0

	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		total_turfs++

		for(var/atom/A in T.contents)
			if(ismob(A))
				total_mobs++
				var/mob/M = A
				message_admins("DEBUG: Found mob [M.type] at ([T.x],[T.y],[T.z]) - AI: [M.ai_controller ? "YES" : "NO"]")
			else if(istype(A, /obj/effect/mob_placeholder))
				total_placeholders++
				var/obj/effect/mob_placeholder/P = A
				message_admins("DEBUG: Found placeholder at ([T.x],[T.y],[T.z]) - Type: [P.mob_type], Name: [P.name]")
			else if(isobj(A))
				total_objs++
				if(total_objs < 10) // Only log first few objects to avoid spam
					message_admins("DEBUG: Found object [A.type] at ([T.x],[T.y],[T.z])")
			else
				other_objects++

		if(total_turfs % 1000 == 0)
			CHECK_TICK

	message_admins("DEBUG Z[z_level] CONTENTS: Turfs: [total_turfs], Objects: [total_objs], Mobs: [total_mobs], Placeholders: [total_placeholders], Other: [other_objects]")

/datum/portal_destination/veilbreak/proc/debug_mob_state(stage, z_level)
	var/total_mobs = 0
	var/mobs_with_ai = 0
	var/mobs_with_controller = 0
	var/mobs_in_global = 0
	var/mobs_hostile = 0

	for(var/mob/living/basic/mob in world)
		if(mob.z != z_level)
			continue

		total_mobs++

		if(mob.ai_controller)
			mobs_with_controller++
			// Check if AI controller has pawn set
			if(mob.ai_controller.pawn == mob)
				mobs_with_ai++

		if(mob in GLOB.basic_mobs)
			mobs_in_global++

		// Check if mob is hostile
		if(mob.faction && ("hostile" in mob.faction))
			mobs_hostile++

		CHECK_TICK

	message_admins("DEBUG: [stage] on Z[z_level] - Mobs: [total_mobs], Controllers: [mobs_with_controller], AI Ready: [mobs_with_ai], Global: [mobs_in_global], Hostile: [mobs_hostile]")

	// Detailed debug for first few mobs
	if(total_mobs > 0)
		var/debug_count = 0
		for(var/mob/living/basic/mob in world)
			if(mob.z != z_level || debug_count >= 3)
				continue

			var/ai_status = "NO_CONTROLLER"
			if(mob.ai_controller)
				ai_status = mob.ai_controller.pawn == mob ? "ACTIVE" : "NO_PAWN"

			var/faction_status = mob.faction ? jointext(mob.faction, ",") : "NO_FACTION"
			var/global_status = (mob in GLOB.basic_mobs) ? "IN_GLOBAL" : "NOT_IN_GLOBAL"

			message_admins("DEBUG: Mob [mob.type] at ([mob.x],[mob.y],[mob.z]) - AI: [ai_status], Faction: [faction_status], Global: [global_status]")
			debug_count++

/datum/portal_destination/veilbreak/proc/replace_map_mobs_with_placeholders(z_level)
	// This function is no longer needed since the map generator already uses placeholders
	// Instead, we'll just verify that placeholders exist and prepare for spawning
	message_admins("PLACEHOLDER CHECK: Checking for mob placeholders on Z[z_level]")

	var/placeholders_found = 0

	for(var/obj/effect/mob_placeholder/placeholder in world)
		if(placeholder.z != z_level)
			continue
		placeholders_found++

	message_admins("PLACEHOLDER CHECK: Found [placeholders_found] mob placeholders on Z[z_level]")

/datum/portal_destination/veilbreak/proc/spawn_mobs_from_placeholders(z_level)
	// Spawn properly initialized mobs from placeholders
	message_admins("MOB SPAWNING: Starting mob spawning from placeholders for Z[z_level]")

	var/mobs_spawned = 0
	var/placeholders_processed = 0

	for(var/obj/effect/mob_placeholder/placeholder in world)
		if(placeholder.z != z_level)
			continue

		placeholders_processed++

		var/mob/living/basic/new_mob
		var/turf/spawn_turf = get_turf(placeholder)

		if(!spawn_turf)
			message_admins("MOB SPAWNING: WARNING - Invalid spawn turf for placeholder at ([placeholder.x],[placeholder.y],[placeholder.z])")
			continue

		// Determine which mob type to spawn
		if(placeholder.mob_type)
			// Use the stored mob type if available
			new_mob = new placeholder.mob_type(spawn_turf)
			message_admins("MOB SPAWNING: Spawned [placeholder.mob_type] at ([spawn_turf.x],[spawn_turf.y],[spawn_turf.z])")
		else
			// Fallback: try to determine mob type from placeholder name or other properties
			new_mob = determine_mob_type_from_placeholder(placeholder, spawn_turf)

		if(!new_mob)
			message_admins("MOB SPAWNING: FAILED to spawn mob from placeholder at ([spawn_turf.x],[spawn_turf.y],[spawn_turf.z])")
			continue

		// Apply stored properties
		if(placeholder.mob_faction)
			new_mob.faction = placeholder.mob_faction.Copy()

		if(placeholder.mob_name && placeholder.mob_name != "mob placeholder")
			new_mob.name = placeholder.mob_name

		// Ensure proper initialization for void creatures
		if(istype(new_mob, /mob/living/basic/void_creature))
			var/mob/living/basic/void_creature/void_mob = new_mob
			void_mob.ensure_hostility()

		mobs_spawned++

		// Delete the placeholder
		qdel(placeholder)

		if(placeholders_processed % 50 == 0)
			CHECK_TICK

	message_admins("MOB SPAWNING: Successfully spawned [mobs_spawned] mobs from [placeholders_processed] placeholders on Z[z_level]")

/datum/portal_destination/veilbreak/proc/determine_mob_type_from_placeholder(obj/effect/mob_placeholder/placeholder, turf/spawn_turf)
	// Try to determine mob type based on placeholder properties
	// This is a fallback if mob_type isn't set

	// Check if the placeholder has any identifying properties
	if(placeholder.name && placeholder.name != "mob placeholder")
		var/name_lower = lowertext(placeholder.name)
		switch(name_lower)
			if("void healer", "healer")
				return new /mob/living/basic/void_creature/void_healer(spawn_turf)
			if("voidbug", "bug")
				return new /mob/living/basic/void_creature/voidbug(spawn_turf)
			if("consumed pathfinder", "pathfinder")
				return new /mob/living/basic/void_creature/consumed_pathfinder(spawn_turf)
			if("voidling")
				return new /mob/living/basic/void_creature/voidling(spawn_turf)
			if("boss", "megafauna", "inai")
				return new /mob/living/simple_animal/hostile/megafauna/inai(spawn_turf)

	// Default fallback - spawn a random void mob
	return spawn_random_void_mob(spawn_turf)

/datum/portal_destination/veilbreak/proc/spawn_random_void_mob(turf/spawn_turf)
	// Fallback method to spawn a random void mob
	var/static/list/void_mob_types = list(
		/mob/living/basic/void_creature/void_healer = 1,
		/mob/living/basic/void_creature/voidbug = 2,
		/mob/living/basic/void_creature/consumed_pathfinder = 1,
		/mob/living/basic/void_creature/voidling = 3
	)

	// Manual weighted selection since pickweight doesn't exist
	var/total_weight = 0
	for(var/mob_type in void_mob_types)
		total_weight += void_mob_types[mob_type]

	var/selected_weight = rand(1, total_weight)
	var/current_weight = 0

	for(var/mob_type in void_mob_types)
		current_weight += void_mob_types[mob_type]
		if(selected_weight <= current_weight)
			return new mob_type(spawn_turf)

	// Fallback if something goes wrong
	return new /mob/living/basic/void_creature/voidling(spawn_turf)

/datum/portal_destination/veilbreak/proc/force_ai_initialization_fixed(z_level)
	// SIMPLE FIX: Just ensure pawns are set and clear targets for freshly spawned mobs
	var/pawns_verified = 0
	var/global_added = 0

	message_admins("DEBUG: Verifying AI for freshly spawned mobs on Z[z_level]")

	for(var/mob/living/basic/mob in world)
		if(mob.z != z_level)
			continue

		// Verify pawn is set
		if(mob.ai_controller)
			if(mob.ai_controller.pawn == mob)
				pawns_verified++
				// Clear targets to trigger behavior
				mob.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] = null
			else
				message_admins("DEBUG: WARNING - Pawn not set for [mob.type] at ([mob.x],[mob.y],[mob.z])")

		// Ensure mob is in the global processing list
		if(!(mob in GLOB.basic_mobs))
			GLOB.basic_mobs += mob
			global_added++

		if((pawns_verified + global_added) % 50 == 0)
			CHECK_TICK

	message_admins("DEBUG: AI verification on Z[z_level] - Pawns Verified: [pawns_verified], Global Added: [global_added]")

/datum/portal_destination/veilbreak/proc/final_ai_activation(z_level)
	// Final pass to activate AI behaviors
	var/ai_activated = 0
	var/targets_cleared = 0

	for(var/mob/living/basic/mob in world)
		if(mob.z != z_level)
			continue

		// Force AI to start processing by triggering a behavior selection
		if(mob.ai_controller && mob.ai_controller.pawn == mob)
			// Clear any stale targets and force re-evaluation
			mob.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] = null
			targets_cleared++

			ai_activated++

			// Debug the AI controller state
			var/controller_type = mob.ai_controller.type
			var/has_target = !isnull(mob.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET])
			var/pawn_set = mob.ai_controller.pawn == mob
			message_admins("DEBUG: AI Controller [controller_type] - Has Target: [has_target], Pawn Set: [pawn_set]")

		ai_activated++

		if(ai_activated % 25 == 0)
			CHECK_TICK

	message_admins("DEBUG: Final AI activation on Z[z_level] - Activated: [ai_activated], Targets Cleared: [targets_cleared]")

/datum/portal_destination/veilbreak/proc/ensure_mob_hostility(z_level)
	// Force all void creatures to be hostile to players
	var/hostile_mobs = 0
	var/faction_changes = 0

	for(var/mob/living/basic/void_creature/mob in world)
		if(mob.z != z_level)
			continue

		var/original_faction = mob.faction ? jointext(mob.faction, ",") : "NONE"

		// Ensure faction is properly set to be hostile to players
		if(!mob.faction)
			mob.faction = list(FACTION_VOID, "hostile")
			faction_changes++
		else if(FACTION_VOID in mob.faction)
			// Already has void faction, ensure hostile
			if(!("hostile" in mob.faction))
				mob.faction |= "hostile"
				faction_changes++
		else
			// Add both void and hostile factions
			mob.faction = list(FACTION_VOID, "hostile")
			faction_changes++

		// Force AI controller to re-evaluate targets
		if(mob.ai_controller)
			mob.ai_controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] = null
			hostile_mobs++

		var/new_faction = jointext(mob.faction, ",")
		if(original_faction != new_faction)
			message_admins("DEBUG: Faction change for [mob.type] - From: [original_faction] To: [new_faction]")

		CHECK_TICK

	message_admins("DEBUG: Mob hostility on Z[z_level] - Hostile: [hostile_mobs], Faction Changes: [faction_changes]")

/datum/portal_destination/veilbreak/proc/initialize_atoms_on_z_level(z_level)
	// CRITICAL: Force SSatoms to initialize all atoms on the new Z-level
	if(SSatoms.initialized)
		SSatoms.InitializeAtoms(Z_TURFS(z_level))

/datum/portal_destination/veilbreak/proc/force_air_initialization(z_level)
	if(!SSair || !SSair.initialized)
		return

	// Wait a moment for SSair to be ready
	addtimer(CALLBACK(src, .proc/actually_initialize_air, z_level), 2 SECONDS)

/datum/portal_destination/veilbreak/proc/actually_initialize_air(z_level)
	var/initialized_count = 0
	for(var/turf/open/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		// FIXED: Use return_air() instead of .air
		var/datum/gas_mixture/air = T.return_air()
		if(!air) // Only initialize if not already done
			T.Initalize_Atmos(0)
			T.immediate_calculate_adjacent_turfs()
		initialized_count++

		if(initialized_count % 50 == 0)
			CHECK_TICK

	// Activate some turfs to kickstart atmos
	var/activated_count = 0
	for(var/turf/open/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(!T.excited && !T.blocks_air)
			SSair.add_to_active(T)
			activated_count++
			if(activated_count >= 100) // Activate a good number of turfs
				break
		CHECK_TICK

/datum/portal_destination/veilbreak/proc/force_lighting_initialization(z_level)
	if(!SSlighting || !SSlighting.initialized)
		return

	// CRITICAL: Create lighting objects for all non-space turfs
	var/objects_created = 0
	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		if(!T.space_lit && !T.lighting_object)
			new /datum/lighting_object(T)
			objects_created++

		// Force lighting updates
		T.update_appearance()

		if(objects_created % 100 == 0)
			CHECK_TICK

	// CRITICAL: Force SSlighting to process the new Z-level
	SSlighting.create_all_lighting_objects()

/datum/portal_destination/veilbreak/proc/log_loaded_content(z_level)
	var/turf_count = 0
	var/obj_count = 0
	var/mob_count = 0
	var/area_count = 0

	for(var/turf/T in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		turf_count++
		if(turf_count % 1000 == 0)
			CHECK_TICK

	for(var/obj/O in world)
		if(O.z == z_level)
			obj_count++
		if(obj_count % 100 == 0)
			CHECK_TICK

	for(var/mob/M in world)
		if(M.z == z_level)
			mob_count++
		if(mob_count % 100 == 0)
			CHECK_TICK

	for(var/area/A in world)
		var/has_turfs = FALSE
		for(var/turf/T in A.contents)
			if(T.z == z_level)
				has_turfs = TRUE
				break
		if(has_turfs)
			area_count++
		if(area_count % 10 == 0)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/initialize_areas_and_power(z_level)
	for(var/area/area as anything in GLOB.areas)
		var/has_turfs_on_z = FALSE
		for(var/turf/T in area.contents)
			if(T.z == z_level)
				has_turfs_on_z = TRUE
				break

		if(has_turfs_on_z)
			area.power_equip = initial(area.power_equip)
			area.power_light = initial(area.power_light)
			area.power_environ = initial(area.power_environ)
			area.always_unpowered = initial(area.always_unpowered)
			area.power_change()
			area.update_icon()

		CHECK_TICK

/datum/portal_destination/veilbreak/proc/initialize_machinery(z_level)
	var/processed = 0
	for(var/obj/machinery/machine in world)
		if(machine.z != z_level)
			continue

		if(machine.use_power)
			machine.power_change()
		machine.update_icon()
		machine.update_appearance()

		processed++
		if(processed % 50 == 0)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/debug_wall_smoothing_configuration(z_level)
	for(var/turf/closed/wall/wall in world)
		if(wall.z != z_level)
			continue
		break

/datum/portal_destination/veilbreak/proc/force_wall_smoothing_setup(z_level)
	var/fixed_count = 0

	for(var/turf/closed/wall/wall in world)
		if(wall.z != z_level)
			continue

		if(!wall.base_icon_state)
			wall.base_icon_state = "wall"

		if(!(wall.smoothing_flags & SMOOTH_BITMASK))
			wall.smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER

		if(!wall.smoothing_groups)
			wall.smoothing_groups = list(
				SMOOTH_GROUP_CLOSED_TURFS = TRUE,
				SMOOTH_GROUP_WALLS = TRUE
			)

		if(!wall.canSmoothWith)
			wall.canSmoothWith = list(
				SMOOTH_GROUP_CLOSED_TURFS = TRUE,
				SMOOTH_GROUP_WALLS = TRUE
			)

		wall.smoothing_junction = 0
		wall.icon_state = "[wall.base_icon_state]-0"
		wall.icon = 'icons/turf/walls/wall.dmi'

		fixed_count++
		if(fixed_count % 50 == 0)
			CHECK_TICK

/datum/portal_destination/veilbreak/proc/initialize_enhanced_smoothing(z_level)
	if(!SSicon_smooth || !SSicon_smooth.initialized)
		return

	// Give it a moment to settle
	sleep(1)

	// Force smoothing for all walls on the Z-level
	var/direct_count = 0
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			wall.smooth_icon()
			direct_count++
			if(direct_count % 100 == 0)
				CHECK_TICK

	// Also queue smoothing
	var/queued_count = 0
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			QUEUE_SMOOTH(wall)
			queued_count++
			if(queued_count % 100 == 0)
				CHECK_TICK

	// Use the subsystem's smoothing
	smooth_zlevel(z_level, TRUE)

	// Verify and fix any remaining unsmoothed walls
	addtimer(CALLBACK(src, .proc/verify_and_finalize_smoothing, z_level), 2 SECONDS)

/datum/portal_destination/veilbreak/proc/verify_and_finalize_smoothing(z_level)
	var/unsmoothed_count = 0

	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			if(wall.icon_state == "wall-0")
				unsmoothed_count++

	if(unsmoothed_count > 0)
		emergency_wall_smoothing_fix(z_level)

/datum/portal_destination/veilbreak/proc/emergency_wall_smoothing_fix(z_level)
	var/fixed_count = 0
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level && wall.icon_state == "wall-0")
			var/new_junction = NONE

			for(var/dir in list(NORTH, SOUTH, EAST, WEST))
				var/turf/neighbor = get_step(wall, dir)
				if(neighbor && istype(neighbor, /turf/closed/wall))
					new_junction |= dir

			if(new_junction != NONE)
				wall.smoothing_junction = new_junction
				wall.icon_state = "wall-[new_junction]"
				fixed_count++

			if(fixed_count % 50 == 0)
				CHECK_TICK

/datum/portal_destination/veilbreak/proc/final_ai_verification(z_level)
	// Final pass to ensure all mobs have AI controllers
	var/mobs_with_ai = 0
	var/total_mobs = 0

	for(var/mob/living/basic/void_creature/mob in world)
		if(mob.z != z_level)
			continue

		total_mobs++

		if(mob.ai_controller)
			mobs_with_ai++

		CHECK_TICK

	// Debug info
	message_admins("DEBUG: Final AI verification - [mobs_with_ai]/[total_mobs] void creatures with AI controllers on Z-level [z_level]")

/datum/portal_destination/veilbreak/proc/initialize_dungeon_mobs(z_level)
	if(!SSmobs.initialized)
		return

	var/mobs_initialized = 0
	for(var/mob/living/basic/mob in world)
		if(mob.z != z_level)
			continue

		// Ensure AI controller is properly set up
		if(mob.ai_controller && !mob.ai_controller.pawn)
			mob.ai_controller.pawn = mob

		mobs_initialized++

		if(mobs_initialized % 25 == 0)
			CHECK_TICK
