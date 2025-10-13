// modular_zzveilbreak/code/modules/mapping/async_map_loader.dm
// Async (non-blocking) map loader override for Veilbreak
// Author: Set Fox
// Purpose: Prevents lag spikes during dynamic TGM map loading

/datum/map_template/load(z_level = 1, x_offset = 1, y_offset = 1, allow_overwrite = TRUE)
	// Call the original loader to ensure the map is parsed and validated
	if(!loaded)
		..()
		if(!loaded)
			CRASH("Failed to load map template [src] during async load.")

	// If no tile data, abort cleanly
	if(!gridSets || !gridSets.len)
		world.log << "[src.name]: No gridSets found during async load."
		return FALSE

	var/total_tiles = gridSets.len
	var/tiles_placed = 0
	var/start_time = world.time

	world.log << "[src.name]: Beginning asynchronous map placement ([total_tiles] tiles)..."

	// Place tiles in manageable chunks per tick to avoid blocking
	for(var/i in 1 to total_tiles)
		var/list/entry = gridSets[i]
		if(!islist(entry))
			continue

		var/x = entry["x"] + x_offset
		var/y = entry["y"] + y_offset
		var/z = z_level

		// Call the original turf/object placement proc if available
		if(entry["typepath"])
			instantiate_tile(entry, x, y, z, allow_overwrite)
		else
			// fallback: support legacy loader data
			var/typepath = entry["turf"]
			if(typepath)
				new typepath(locate(x, y, z))

		tiles_placed++

		// Every N tiles, yield if we're eating too much tick time
		if(tiles_placed % 50 == 0)
			if(world.tick_usage > 70)
				stoplag() // yield control to next tick
			else
				sleep(0) // minimal pause

	// Log completion time
	var/duration = world.time - start_time
	world.log << "[src.name]: Async map load complete in [duration] ticks ([tiles_placed] tiles placed)."
	return TRUE

// Compatibility helper: safely instantiate a tile
/proc/instantiate_tile(list/entry, x, y, z, allow_overwrite)
	if(!entry || !entry["typepath"])
		return
	var/type/turf_type = entry["typepath"]
	var/atom/location = locate(x, y, z)
	if(!location)
		return
	if(allow_overwrite)
		qdel(location)
	new turf_type(location)
