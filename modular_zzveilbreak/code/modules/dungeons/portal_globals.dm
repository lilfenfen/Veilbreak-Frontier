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

// Global helper to check if a mob is hostile (living hostile mobs only - corpses are NOT hostile)
/proc/is_hostile_or_void(mob/living/mob)
	// If mob is dead, it's not hostile (corpses get ejected)
	if(mob.stat == DEAD)
		return FALSE

	// Void faction always gets removed (if alive)
	if(mob.faction == FACTION_VOID)
		return TRUE

	// Hostile simple animals (only if alive)
	if(istype(mob, /mob/living/simple_animal/hostile))
		return TRUE

	// Xenomorphs (only if alive)
	if(istype(mob, /mob/living/carbon/alien))
		return TRUE

	// If it has no client/ckey and is simple animal, assume hostile (only if alive)
	if(istype(mob, /mob/living/simple_animal) && !mob.ckey)
		return TRUE

	// Everything else is safe to eject - players, corpses, friendly animals, borgs, etc.
	return FALSE
