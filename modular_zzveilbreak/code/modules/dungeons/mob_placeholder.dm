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
	// The actual spawning will be handled by the dungeon generation process
