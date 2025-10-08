/datum/ai_controller/inai
	blackboard = list(
		BB_BASIC_MOB_CURRENT_TARGET = null,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk

/datum/ai_controller/inai/process(seconds_per_tick)
	. = ..()
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = pawn
	if(!inai || inai.stat == DEAD || inai.channeling)
		return

	// Get current target
	var/mob/living/target = blackboard[BB_BASIC_MOB_CURRENT_TARGET]

	// Try to use Astral Step if ready and target is valid
	if(inai.astral_step && inai.astral_step.IsAvailable() && target && get_dist(inai, target) <= 11)
		inai.astral_step.Activate(target)
		return

	// Try to use Resonant Wave if ready and no target
	if(inai.resonant_wave && inai.resonant_wave.IsAvailable() && !target)
		inai.resonant_wave.Activate()
		return
