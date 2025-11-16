// modular_zzveilbreak/code/modules/dungeons/mob_placeholder.dm

/obj/effect/mob_placeholder
	name = "mob placeholder"
	desc = "A placeholder for a mob that will be properly initialized."
	icon = 'icons/effects/effects.dmi'
	icon_state = "sparkles"
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	// Storage for mob data
	var/mob_type
	var/list/mob_faction
	var/mob_name
	var/spawn_z_level

/obj/effect/mob_placeholder/Initialize(mapload)
	. = ..()

	// If mob_type isn't set, try to determine it from our name or other properties
	if(!mob_type)
		determine_mob_type_from_self()

/obj/effect/mob_placeholder/proc/determine_mob_type_from_self()
	// Try to determine mob type based on our own properties
	if(name && name != "mob placeholder")
		var/name_lower = lowertext(name)
		switch(name_lower)
			if("void healer", "healer")
				mob_type = /mob/living/basic/void_creature/void_healer
			if("voidbug", "bug")
				mob_type = /mob/living/basic/void_creature/voidbug
			if("consumed pathfinder", "pathfinder")
				mob_type = /mob/living/basic/void_creature/consumed_pathfinder
			if("voidling")
				mob_type = /mob/living/basic/void_creature/voidling
			if("boss", "megafauna", "inai")
				mob_type = /mob/living/simple_animal/hostile/megafauna/inai

	// If we still don't have a type, set a default
	if(!mob_type)
		mob_type = /mob/living/basic/void_creature/voidling
