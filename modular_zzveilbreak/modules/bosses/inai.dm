/mob/living/simple_animal/hostile/megafauna/inai
	name = "Inai"
	desc = "Spirit of the Void, enduring the mortal indignities of the coil."
	icon = 'modular_zzveilbreak/icons/bosses/inai_model.dmi'
	icon_state = "inai"
	pixel_x = -16
	pixel_y = -16
	bound_width = 32
	bound_height = 32
	maxHealth = 3000
	health = 3000
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	friendly_verb_continuous = "observes"
	friendly_verb_simple = "observe"
	melee_damage_lower = 10
	melee_damage_upper = 15
	attack_sound = 'modular_zzveilbreak/sound/weapons/inai_attack.ogg'
	speak_emote = list("says", "declares", "utters")
	speak_chance = 100
	faction = list("void")
	speed = 1.1
	rapid_melee = 1
	melee_queue_distance = 12
	del_on_death = TRUE
	environment_smash = 2
	armour_penetration = 40
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 40
	move_to_delay = 1.1
	loot = /obj/item/voidshard

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
		"I cannot let you live."
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
	// Abilities - define with default values
	var/ASTRAL_STEP_CD = 10 SECONDS
	var/RESONANT_WAVE_CD = 17 SECONDS
	var/channeling = FALSE  // Flag to prevent actions during channeling

	Initialize()
		. = ..()
		astral_step = new(src)
		resonant_wave = new(src)
		astral_step.Grant(src)
		resonant_wave.Grant(src)

		// Set cooldowns after actions are created
		if(astral_step)
			astral_step.cooldown_time = ASTRAL_STEP_CD
		if(resonant_wave)
			resonant_wave.cooldown_time = RESONANT_WAVE_CD

	Destroy()
		QDEL_NULL(astral_step)
		QDEL_NULL(resonant_wave)
		return ..()

	/mob/living/simple_animal/hostile/megafauna/inai/OpenFire()
		if(client)
			return

		if(target && get_dist(src, target) <= 11 && astral_step && astral_step.IsAvailable())
			astral_step.Activate(target)
		else if(resonant_wave && resonant_wave.IsAvailable() && !channeling)
			resonant_wave.Activate()

	// Life regeneration: 1 HP per tick when below max health and not dead
	/mob/living/simple_animal/hostile/megafauna/inai/Life()
		. = ..()
		if(channeling)
			return

		if(stat != DEAD && health < maxHealth)
			adjustBruteLoss(-1)
		// Spell casting logic
		if(stat != DEAD && target && prob(20))  // 20% chance per tick to attempt casting
			if(prob(50) && get_dist(src, target) <= 11 && astral_step && astral_step.IsAvailable())
				astral_step.Activate(target)
			else if(resonant_wave && resonant_wave.IsAvailable() && !channeling)
				resonant_wave.Activate()

	death(message)
		// Spawn loot before deletion
		var/loot = pick_loot_from_table(inai_drops)
		if(loot)
			new loot(loc)
		var/msg = pick(death_messages)
		visible_message("<span style='color:#8a2be2; font-style:italic; '>[msg]</span>")
		..()

// Astral Step ability
/datum/action/cooldown/mob_cooldown/astral_step
	name = "Astral Step"
	desc = "Teleport behind a target within 11 tiles and strike with extra damage."
	button_icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	button_icon_state = "astral_step"

	// Remove the New() proc that was causing null reference

/datum/action/cooldown/mob_cooldown/astral_step/Activate(atom/target)
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = owner
	if(!isliving(target) || get_dist(inai, target) > 11)
		return
	// Teleport behind target
	var/turf/target_turf = get_turf(target)
	var/dir_from_inai = get_dir(inai, target)
	var/turf/behind_turf = get_step(target_turf, dir_from_inai)
	var/turf/start_turf
	var/step_dir
	if(behind_turf && !behind_turf.density)
		start_turf = get_turf(inai)
		// Create visual effects
		step_dir = get_dir(start_turf, behind_turf)
		var/list/path = get_line(start_turf, behind_turf)
		for(var/i in 1 to length(path))
			var/turf/T = path[i]
			var/obj/effect/temp_visual/astral_step/effect
			if(i == 1)
				effect = new /obj/effect/temp_visual/astral_step/start(T)
			else if(i == length(path))
				effect = new /obj/effect/temp_visual/astral_step/end(T)
			else
				effect = new /obj/effect/temp_visual/astral_step/middle(T)
			effect.dir = step_dir
		inai.forceMove(behind_turf)
	// Mark effect on affected tiles
	if(start_turf && behind_turf)
		var/list/affected_turfs = get_line(start_turf, behind_turf)
		for(var/turf/T in affected_turfs)
			for(var/mob/living/L in T)
				if(L != inai && !(FACTION_VOID in L.faction))  // Exclude Inai and void faction mobs from the mark
					L.apply_status_effect(/datum/status_effect/astral_mark)
	var/msg = pick(inai.astral_messages)
	inai.visible_message("<span style='color:#8a2be2; font-style:italic; '>[msg]</span>")
	StartCooldown()

// Inai Wave ability
/datum/action/cooldown/mob_cooldown/inai_wave
	name = "Resonant Wave"
	desc = "Channel a wave that releases random waves, damaging along paths."
	button_icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	button_icon_state = "resonant_wave"

	// Remove the New() proc that was causing null reference

/datum/action/cooldown/mob_cooldown/inai_wave/Activate()
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = owner
	if(inai.stat)
		return
	inai.channeling = TRUE
	// Start channeling: stand still and don't attack for up to 6 seconds, releasing waves during
	inai.visible_message(span_danger("[inai] begins to channel a resonant wave..."))
	flick("inai_channeling", inai)
	var/channel_time = 12 SECONDS
	var/wave_interval = 1.5 SECONDS  // Release waves every 1.5 seconds
	var/elapsed = 0
	while(elapsed < channel_time)
		if(!do_after(inai, wave_interval, progress = TRUE))
			inai.visible_message(span_warning("[inai]'s channeling is interrupted!"))
			inai.channeling = FALSE  // Reset flag on interrupt
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
	inai.visible_message("<span style='color:#8a2be2; font-style:italic; '>[msg]</span>")
	inai.channeling = FALSE  // Reset flag
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
			if(!(FACTION_VOID in victim.faction))
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

/obj/effect/temp_visual/astral_step
	icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	duration = 1 SECONDS

/obj/effect/temp_visual/astral_step/start
	icon_state = "astral_step_start"

/obj/effect/temp_visual/astral_step/middle
	icon_state = "astral_step_middle"

/obj/effect/temp_visual/astral_step/end
	icon_state = "astral_step_end"

// Astral Mark status effect
/datum/status_effect/astral_mark
	id = "astral_mark"
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null
	duration = 1 SECONDS

/datum/status_effect/astral_mark/on_apply()
	. = ..()
	if(!isliving(owner))
		return FALSE
	var/mob/living/L = owner
	L.add_movespeed_modifier(/datum/movespeed_modifier/astral_mark)
	addtimer(CALLBACK(src, PROC_REF(explode)), 1 SECONDS)

/datum/status_effect/astral_mark/proc/explode()
	var/mob/living/L = owner
	if(!L)
		return
	L.remove_movespeed_modifier(/datum/movespeed_modifier/astral_mark)
	var/damage = 20
	var/damage_type = pick(BRUTE, BURN, TOX, OXY)
	L.apply_damage(damage, damage_type)
	var/obj/effect/temp_visual/astral_explosion/explosion = new(get_turf(L))
	explosion.dir = pick(GLOB.alldirs)
	qdel(src)

/datum/movespeed_modifier/astral_mark
	multiplicative_slowdown = 2  // Slow down by factor of 2 (speed halved)

/obj/effect/temp_visual/astral_explosion
	icon = 'modular_zzveilbreak/icons/bosses/inai.dmi'
	icon_state = "astral_explosion"
	duration = 1 SECONDS
