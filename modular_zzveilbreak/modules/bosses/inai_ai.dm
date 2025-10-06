/datum/ai_controller/inai
	blackboard = list(
		"target" = null,
	)
	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk

/datum/ai_controller/inai/process(seconds_per_tick)
	. = ..()
	var/mob/living/simple_animal/hostile/megafauna/inai/inai = pawn
	if(!inai || inai.stat == DEAD)
		return

	// Get current target
	var/mob/living/target = blackboard["target"]

	// Try to use Astral Step if ready and target is valid
	if(inai.astral_step && inai.astral_step.IsAvailable() && target && get_dist(inai, target) <= 11)
		inai.astral_step.Activate(target)
		return

	// Try to use Resonant Wave if ready
	if(inai.resonant_wave && inai.resonant_wave.IsAvailable())
		inai.resonant_wave.Activate()
		return
