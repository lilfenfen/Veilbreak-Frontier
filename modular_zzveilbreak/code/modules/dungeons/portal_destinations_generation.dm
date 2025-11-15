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
