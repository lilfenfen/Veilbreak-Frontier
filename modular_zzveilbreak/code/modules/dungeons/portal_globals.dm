// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

// Forward declarations
/datum/space_level
/datum/parsed_map

// Global list for portal destinations (separate from gateways)
GLOBAL_LIST_EMPTY(portal_destinations)

// Reusable Z-level for all portal dungeons (set on first generation)
GLOBAL_VAR(portal_dungeon_z_level)

// Helper proc for dungeon generator logging
/proc/log_dungeon(text, list/data)
	log_game("DUNGEON: [text]", data, LOG_GAME)

// Helper proc for portal machinery logging
/proc/log_portal(text, list/data)
	log_game("DUNGEON: PORTAL: [text]", data, LOG_GAME)

// Helper proc for portal control logging
/proc/log_portal_control(text)
	log_game("DUNGEON: CONTROL: [text]", list(), LOG_GAME)
