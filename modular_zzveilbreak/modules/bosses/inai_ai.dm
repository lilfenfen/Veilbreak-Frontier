/datum/ai_controller/inai
	blackboard = list(
		BB_TARGET = null,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk

/datum/ai_controller/inai/process(seconds_per_tick)
	. = ..()
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = pawn
	if(!inai || inai.stat == DEAD)
		return

	// Get current target
	var/mob/living/target = inai.target

	// Try to use Astral Step if ready and target is valid
	var/datum/action/cooldown/mob_cooldown/astral_step/astral_action = locate() in inai.actions
	if(astral_action && astral_action.IsAvailable() && target && get_dist(inai, target) <= 11)
		astral_action.Activate(target)
		return

	// Try to use Resonant Wave if ready
	var/datum/action/cooldown/mob_cooldown/inai_wave/wave_action = locate() in inai.actions
	if(wave_action && wave_action.IsAvailable())
		wave_action.Activate()
		return
