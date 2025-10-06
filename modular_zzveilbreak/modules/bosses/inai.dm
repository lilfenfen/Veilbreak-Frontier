/mob/living/simple_animal/hostile/megafauna/inai
	name = "Inai"
	desc = "Spirit of the Void, enduring the mortal indignities of the coil."
	icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	icon_state = "inai"
	maxHealth = 3000
	health = 3000
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	friendly_verb_continuous = "observes"
	friendly_verb_simple = "observe"
	melee_damage_lower = 15
	melee_damage_upper = 25
	attack_sound = 'modular_zzveilbreak/sound/weapons/inai_attack.ogg'
	speak_emote = list("says", "declares", "utters")
	speak_chance = 50
	faction = list("hostile")
	speed = 0.8
	del_on_death = TRUE
	environment_smash = 2
	armour_penetration = 20
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 40
	move_to_delay = 1
	loot = list(/obj/item/voidshard)  // Fixed drop for now; can use table later

	// List of death messages
	var/list/death_messages = list(
		"This will open a dark path.",
		"The void beckons.",
		"Reality unravels.",
		"Your victory is impermanent."
	)

	// List of astral step messages
	var/list/astral_messages = list(
		"There's nowhere to run.",
		"I took a shortcut.",
		"Behind you.",
		"You're already too late.",
		"I'm everywhere and nowhere.",
		"A merry chase you lead."

	)

	// List of resonant pulse messages
	var/list/pulse_messages = list(
		"A field of nothing.",
		"Harm unseen.",
		"Null efforts.",
		"It isnt shadow that bathes me.",
		"Void Resonance."
	)

	var/datum/action/cooldown/mob_cooldown/astral_step/astral_step
	var/datum/action/cooldown/mob_cooldown/inai_wave/resonant_wave
	// Abilities
	var/ASTRAL_STEP_CD = 10 SECONDS
	var/RESONANT_WAVE_CD = 17 SECONDS

	Initialize()
		. = ..()
		astral_step = new(src)
		resonant_wave = new(src)
		astral_step.Grant(src)
		resonant_wave.Grant(src)
		ai_controller = new /datum/ai_controller/inai(src)

	Destroy()
		QDEL_NULL(astral_step)
		QDEL_NULL(resonant_wave)
		return ..()

	death(message)
		// Spawn loot before deletion
		var/loot = pick_loot_from_table(inai_drops)
		if(loot)
			new loot(loc)
		var/msg = pick(death_messages)
		visible_message("<span style='color:#8a2be2; font-style:italic;'>[msg]</span>")
		..()

// Astral Step ability
/datum/action/cooldown/mob_cooldown/astral_step
	name = "Astral Step"
	desc = "Teleport behind a target within 11 tiles and strike with extra damage."
	button_icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	button_icon_state = "astral_step"

/datum/action/cooldown/mob_cooldown/astral_step/New(Target)
	. = ..()
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = owner
	cooldown_time = inai.ASTRAL_STEP_CD

/datum/action/cooldown/mob_cooldown/astral_step/Activate(atom/target)
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = owner
	if(!isliving(target) || get_dist(inai, target) > 11)
		return
	// Teleport behind target
	var/turf/target_turf = get_turf(target)
	var/dir_to_inai = get_dir(target, inai)
	var/turf/behind_turf = get_step(target_turf, dir_to_inai)
	if(behind_turf && !behind_turf.density)
		inai.forceMove(behind_turf)
	// Attack with extra damage
	var/mob/living/victim = target
	var/extra_damage = 10
	var/damage_type = pick(BRUTE, BURN, TOX, OXY)  // Random damage type
	victim.apply_damage(extra_damage, damage_type)
	var/msg = pick(inai.astral_messages)
	inai.visible_message("<span style='color:#8a2be2; font-style:italic;'>[msg]</span>")
	StartCooldown()

// Inai Wave ability
/datum/action/cooldown/mob_cooldown/inai_wave
	name = "Resonant Wave"
	desc = "Channel a wave that releases random waves, damaging along paths."
	button_icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	button_icon_state = "resonant_wave"

/datum/action/cooldown/mob_cooldown/inai_wave/New(Target)
	. = ..()
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = owner
	cooldown_time = inai.RESONANT_WAVE_CD

/datum/action/cooldown/mob_cooldown/inai_wave/Activate()
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = owner
	if(inai.stat)
		return
	// Start channeling: stand still and don't attack for up to 6 seconds, releasing waves during
	inai.visible_message(span_danger("[inai] begins to channel a resonant wave..."))
	flick("inai_channeling", inai)
	var/channel_time = 12 SECONDS
	var/wave_interval = 1.5 SECONDS  // Release waves every 1.5 seconds
	var/elapsed = 0
	while(elapsed < channel_time)
		if(!do_after(inai, wave_interval, target = inai, progress = TRUE))
			inai.visible_message(span_warning("[inai]'s channeling is interrupted!"))
			return
		// Release 2-5 waves
		var/num_waves = rand(4, 6)
		for(var/w in 1 to num_waves)
			var/dir = pick(GLOB.alldirs)
			INVOKE_ASYNC(src, PROC_REF(fire_wave), inai, dir)
		elapsed += wave_interval
	// After channeling
	inai.visible_message(span_danger("[inai] finishes channeling the resonant wave!"))
	var/msg = pick(inai.pulse_messages)
	inai.visible_message("<span style='color:#8a2be2; font-style:italic;'>[msg]</span>")
	StartCooldown()

/datum/action/cooldown/mob_cooldown/inai_wave/proc/fire_wave(mob/living/simple_animal/hostile/megafauna/inai/inai, dir)
	var/turf/start_turf = get_turf(inai)
	for(var/i in 1 to 15)
		var/turf/current_turf = get_step(start_turf, dir)
		if(!current_turf || current_turf.density)
			break
		var/obj/effect/temp_visual/resonant_wave/wave = new(current_turf)
		wave.icon_state = "resonant_wave"  // Single state for all directions
		wave.dir = dir  // Set direction for animation
		for(var/mob/living/victim in current_turf)
			var/damage = 15
			var/damage_type = pick(BRUTE, BURN, TOX, OXY)
			victim.apply_damage(damage, damage_type)
		start_turf = current_turf
		sleep(0.8 SECONDS)  // Human-like speed: ~0.4 seconds per tile

// Temporary visual effect for the wave
/obj/effect/temp_visual/resonant_wave
	icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	icon_state = "resonant_wave"  // Single state
	duration = 0.8 SECONDS
