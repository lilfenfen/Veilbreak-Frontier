/mob/living/simple_animal/hostile/megafauna/melos_vecare
	name = "Melos Vecare"
	desc = "A siren corrupted by the void, her song now weaves destruction and chaos."
	icon = 'modular_zzveilbreak/icons/bosses/melos.dmi'
	icon_state = "idle"
	icon_living = "idle"
	pixel_x = -16
	pixel_y = -16
	bound_width = 32
	bound_height = 32
	speak_chance = 0
	maxHealth = 3000
	health = 3000
	harm_intent_damage = 10
	melee_damage_lower = 7
	melee_damage_upper = 13
	attack_verb_continuous = "blasts"
	attack_verb_simple = "blast"
	attack_sound = 'modular_zzveilbreak/sound/weapons/voidling_attack.ogg'
	faction = list("void")
	environment_smash = ENVIRONMENT_SMASH_NONE
	stat_attack = CONSCIOUS
	robust_searching = TRUE
	del_on_death = TRUE
	dodging = FALSE
	var/ability_cooldown = 0
	var/spell_range = 12
	var/ability_uses_counter = 0
	var/lyric_index = 1
	anchored = TRUE

	var/list/death_messages = list(
		"Maybe in death, i'll find lover...",
		"I die alone.",
		"I will find my lover, not even death will stop me.")

	death(message)
		var/loot = pick_loot_from_table(melos_vecare_drops)
		if(loot)
			new loot(loc)
		var/msg = pick(death_messages)
		visible_message("<span style='color:#8a2be2; font-style:italic; '>[msg]</span>")
		..()


/mob/living/simple_animal/hostile/megafauna/melos_vecare/Life()
	if(world.time > ability_cooldown)
		var/has_target = FALSE
		for(var/mob/living/L in range(spell_range, src))
			if(L != src && !L.stat)
				if(!length(L.faction & faction)) // Check if the mob is not in the void faction
					has_target = TRUE
					break

		if(!has_target)
			return

		ability_uses_counter++
		if(ability_uses_counter % 3 == 0)
			if(lyric_index <= length(GLOB.melos_lyrics))
				var/lyric = GLOB.melos_lyrics[lyric_index]
				// Using a similar style to other void entities for consistency.
				visible_message("<span style='color:#8a2be2; font-style:italic;'>[src] sings, \"[lyric]\"</span>")
				flick("singing", src)
				lyric_index++

		ability_cooldown = world.time + 6 SECONDS
		var/ability = pick("push", "pull")
		for(var/mob/living/L in range(spell_range, src))
			if(L == src || (FACTION_VOID in L.faction))
				continue
			if(ability == "push")
				var/dir = get_dir(src, L)
				L.throw_at(get_edge_target_turf(L, dir), 5, 1)
				new /obj/effect/temp_visual/voidout(get_turf(L))
			else
				L.throw_at(src.loc, 5, 1)
				new /obj/effect/temp_visual/voidin(get_turf(L))
		// Mark tiles immediately after push/pull
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
	for(var/mob/living/L in T)
		if(L == src || (FACTION_VOID in L.faction))
			continue
		if(effect_type == "water")
			L.adjustBruteLoss(25)
			new /obj/effect/temp_visual/water_torrent(T)
		else
			L.adjustFireLoss(25)
			new /obj/effect/temp_visual/void_torrent(T)

/obj/effect/temp_visual/melos_mark
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "mark"
	duration = 1 SECONDS

/obj/effect/temp_visual/water_torrent
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "water"
	duration = 1.5 SECONDS

/obj/effect/temp_visual/void_torrent
	icon = 'modular_zzveilbreak/icons/bosses/melos_vecare.dmi'
	icon_state = "void"
	duration = 1.5 SECONDS
