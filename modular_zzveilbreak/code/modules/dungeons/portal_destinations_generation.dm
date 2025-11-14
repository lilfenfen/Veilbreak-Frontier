// modular_zzveilbreak/code/modules/dungeons/portal_destinations_generation.dm

/datum/portal_destination/veilbreak/proc/start_generation()
	if(generating)
		return FALSE

	if(!SSmapping || !SSmapping.initialized)
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

	if(data["dmm_content"])
		load_generated_dmm(data["dmm_content"])
	else
		generation_failed("No DMM content in response")

	if(connected_control_computer && !QDELETED(connected_control_computer))
		connected_control_computer.on_generation_completed()
		connected_control_computer = null

/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content)
	if(!dmm_content)
		return generation_failed("No DMM content provided")

	if(!initialize_portal_z_level())
		return generation_failed("Failed to initialize portal Z-level")

	reset_z_level_to_space(dungeon_z_level)

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

	SSatoms.map_loader_begin("dungeon_generator_[dungeon_z_level]")

	if(SSair.initialized)
		SSair.StartLoadingMap()

	var/loaded_successfully = FALSE
	var/error_message = "Unknown error"

	try
		var/datum/parsed_map/parsed = new(file(temp_filename))
		if(parsed && parsed.bounds)
			loaded_successfully = parsed.load(1, 1, dungeon_z_level, no_changeturf = FALSE, place_on_top = TRUE, new_z = FALSE)
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

	initialize_dungeon_subsystems(dungeon_z_level)

/datum/portal_destination/veilbreak/proc/initialize_dungeon_subsystems(z_level)
	log_loaded_content(z_level)
	CHECK_TICK

	initialize_areas_and_power(z_level)
	CHECK_TICK

	initialize_machinery(z_level)
	CHECK_TICK

	initialize_lighting(z_level)
	CHECK_TICK

	debug_wall_smoothing_configuration(z_level)
	CHECK_TICK

	force_wall_smoothing_setup(z_level)
	CHECK_TICK

	initialize_enhanced_smoothing(z_level)
	CHECK_TICK

	ensure_portal_connection()

	generated = TRUE

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

/datum/portal_destination/veilbreak/proc/initialize_lighting(z_level)
	if(!SSlighting || !SSlighting.initialized)
		return

	for(var/x = 1 to world.maxx)
		for(var/y = 1 to world.maxy)
			var/turf/iter_turf = locate(x, y, z_level)
			if(!iter_turf.space_lit && !iter_turf.lighting_object)
				new /datum/lighting_object(iter_turf)
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

	sleep(1)

	var/direct_count = 0
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			wall.smooth_icon()
			direct_count++
			if(direct_count % 100 == 0)
				CHECK_TICK

	var/queued_count = 0
	for(var/turf/closed/wall/wall in world)
		if(wall.z == z_level)
			QUEUE_SMOOTH(wall)
			queued_count++
			if(queued_count % 100 == 0)
				CHECK_TICK

	smooth_zlevel(z_level, TRUE)

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
