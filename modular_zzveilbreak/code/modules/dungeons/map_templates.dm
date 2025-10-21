// modular_zzveilbreak/code/modules/dungeons/map_templates.dm

/**
 * Dynamic map template for Veilbreak dungeons
 */
/datum/map_template/veilbreak_dungeon
	var/tmp/dmm_text
	var/width = 80
	var/height = 80

/datum/map_template/veilbreak_dungeon/New(dmm_content)
	. = ..()
	name = "Veilbreak Dungeon [rand(1000,9999)]"
	dmm_text = dmm_content
	mappath = null // We're not using file paths

/datum/map_template/veilbreak_dungeon/preload()
	// Parse the DMM content to get actual dimensions
	var/dmm_suite/D = new()
	var/list/bounds = D.read_map(dmm_text, 1, 1, 1, cropMap = FALSE, measureOnly = TRUE)
	if(bounds)
		width = bounds[MAP_MAXX] || 80
		height = bounds[MAP_MAXY] || 80
	return TRUE

/datum/map_template/veilbreak_dungeon/load_new_z()
	// Load into a new z-level
	var/dmm_suite/D = new()
	var/z_level = world.maxz + 1

	// Reserve the new z-level
	world.incrementMaxZ()

	// Load the map with adaptive chunking to avoid tick consumption
	var/list/bounds = D.read_map(dmm_text, 1, 1, z_level, cropMap = FALSE, chunkSize = 5)

	if(!bounds)
		CRASH("Failed to load veilbreak dungeon map")

	return z_level
