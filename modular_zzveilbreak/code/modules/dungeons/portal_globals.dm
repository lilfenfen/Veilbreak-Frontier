// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

/datum/space_level
/datum/parsed_map

GLOBAL_LIST_EMPTY(portal_destinations)
GLOBAL_VAR(portal_dungeon_z_level)

/proc/is_hostile_or_void(mob/living/mob)
	if(mob.stat == DEAD)
		return FALSE

	if(mob.faction == FACTION_VOID)
		return TRUE

	if(istype(mob, /mob/living/simple_animal/hostile))
		return TRUE

	if(istype(mob, /mob/living/carbon/alien))
		return TRUE

	if(istype(mob, /mob/living/simple_animal) && !mob.ckey)
		return TRUE

	return FALSE
