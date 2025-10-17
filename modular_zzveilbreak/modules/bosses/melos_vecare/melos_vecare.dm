/mob/living/simple_animal/hostile/megafauna/melos_vecare
	name = "Melos Vecare"
	desc = "A siren corrupted by the void, her song now weaves destruction and chaos."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "melos_vecare"
	icon_living = "melos_vecare"
	pixel_x = -16
	pixel_y = -16
	bound_width = 64
	bound_height = 64
	speak_chance = 0
	turns_per_move = 0
	speed = 0
	maxHealth = 3000
	health = 3000
	harm_intent_damage = 0
	melee_damage_lower = 0
	melee_damage_upper = 0
	attack_verb_continuous = "sings"
	attack_verb_simple = "sing"
	attack_sound = 'modular_zzveilbreak/sound/weapons/voidling_attack.ogg'
	faction = list("Void")
	environment_smash = ENVIRONMENT_SMASH_NONE
	stat_attack = CONSCIOUS
	robust_searching = TRUE
	dodging = FALSE
	var/ability_cooldown = 0
	var/mark_cooldown = 0
	var/spell_range = 20
	loot = list(/obj/item/voidshard)

	anchored = TRUE

/mob/living/simple_animal/hostile/megafauna/melos_vecare/Life()
	. = ..()
	if(world.time > ability_cooldown)
		ability_cooldown = world.time + 3 SECONDS
		var/ability = pick("push", "pull")
		for(var/mob/living/L in range(spell_range, src))
			if(ability == "push")
				var/dir = get_dir(src, L)
				L.throw_at(get_edge_target_turf(L, dir), 5, 1)
				new /obj/effect/temp_visual/voidout(get_turf(L))
			else
				L.throw_at(src.loc, 5, 1)
				new /obj/effect/temp_visual/voidin(get_turf(L))

	if(world.time > mark_cooldown)
		mark_cooldown = world.time + 20 SECONDS
		melos_vecare_mark_tiles()

/mob/living/simple_animal/hostile/megafauna/melos_vecare/proc/melos_vecare_mark_tiles()
	var/list/tiles = list()
	for(var/turf/T in range(spell_range, src))
		if(isopenturf(T))
			tiles += T
	var/num_to_mark = round(length(tiles) * 0.4)
	for(var/i in 1 to num_to_mark)
		var/turf/T = pick(tiles)
		tiles -= T
		var/effect_type = pick("water", "void")
		new /obj/effect/temp_visual/melos_mark(T)
		addtimer(CALLBACK(src, PROC_REF(melos_vecare_apply_effect), T, effect_type), 1 SECONDS)

/mob/living/simple_animal/hostile/megafauna/melos_vecare/proc/melos_vecare_apply_effect(turf/T, effect_type)
	new /obj/effect/melos_damage(T, effect_type)

/obj/effect/temp_visual/melos_mark
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "mark"
	duration = 3 SECONDS

/obj/effect/temp_visual/water_effect
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "water"
	duration = 1 SECONDS

/obj/effect/temp_visual/void_effect
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "void"
	duration = 1 SECONDS

/obj/effect/melos_damage
	var/effect_type

/obj/effect/melos_damage/New(turf/T, type)
	. = ..()
	effect_type = type
	if(type == "water")
		new /obj/effect/temp_visual/water_torrent(T)
	else
		new /obj/effect/temp_visual/void_torrent(T)
	QDEL_IN(src, 1 SECONDS)

/obj/effect/melos_damage/Entered(atom/movable/AM)
	if(ismob(AM))
		var/mob/living/M = AM
		if(effect_type == "water")
			M.adjustBruteLoss(25)
		else
			M.adjustFireLoss(25)

/obj/effect/temp_visual/water_torrent
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "water"
	duration = 1 SECONDS

/obj/effect/temp_visual/void_torrent
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "void"
	duration = 1 SECONDS
