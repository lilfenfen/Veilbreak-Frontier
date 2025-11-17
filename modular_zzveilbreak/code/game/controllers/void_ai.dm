// modular_zzveilbreak/code/datums/ai/void_ai.dm

// ===== BLACKBOARD KEYS =====
// Voidbug
#define BB_VOIDBUG_LAST_PACK_CALL "voidbug_last_pack_call"
#define COMSIG_MOB_ATTACKED "mob_attacked"
#define COMSIG_MOB_GIVE_TARGET "mob_give_target"

// Void Healer
#define BB_VOID_HEALER_LAST_HEAL "void_healer_last_heal"
#define BB_VOID_HEALER_CURRENT_TARGET "void_healer_current_target"
#define BB_VOID_HEALER_FLEE_TARGET "void_healer_flee_target"

// ===== BASE VOID CONTROLLER =====
/datum/ai_controller/basic_controller/void
	/// The range at which this AI will aggro onto targets.
	var/aggro_range = 8

	planning_subtrees = list(
		/datum/ai_planning_subtree/void_aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)
	ai_movement = /datum/ai_movement/basic_avoidance


/// Sets the attacker as the current target.
/datum/ai_controller/basic_controller/void/proc/on_attacked(datum/source, mob/attacker)
	SIGNAL_HANDLER
	if(attacker && !blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET)) //Don't switch targets if we already have one.
		var/mob/living/simple_animal/hostile/pawn_mob = pawn
		if(pawn_mob)
			pawn_mob.GiveTarget(attacker)

// ===== VOIDLING CONTROLLER (Basic attacker) =====
/datum/ai_controller/basic_controller/void/voidling
	aggro_range = 7
	planning_subtrees = list(
		/datum/ai_planning_subtree/void_aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)
	ai_movement = /datum/ai_movement/basic_avoidance

// ===== VOIDBUG CONTROLLER (Pack caller) =====
/datum/ai_controller/basic_controller/void/voidbug
	planning_subtrees = list(
		/datum/ai_planning_subtree/voidbug_pack_call,
		/datum/ai_planning_subtree/void_aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)
	ai_movement = /datum/ai_movement/basic_avoidance

// Voidbug calls nearby allies to attack its target
/datum/ai_planning_subtree/voidbug_pack_call
	var/pack_call_cooldown = 15 SECONDS

/datum/ai_planning_subtree/voidbug_pack_call/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(!controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	var/last_pack_call = controller.blackboard[BB_VOIDBUG_LAST_PACK_CALL] || 0
	if(world.time < last_pack_call + pack_call_cooldown)
		return

	controller.queue_behavior(/datum/ai_behavior/voidbug_call_pack, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/voidbug_call_pack
	action_cooldown = 15 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM

/datum/ai_behavior/voidbug_call_pack/setup(datum/ai_controller/controller, target_key)
	var/atom/target = controller.blackboard[target_key]
	if(!target)
		return FALSE
	return ..()

/datum/ai_behavior/voidbug_call_pack/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/living_pawn = controller.pawn
	var/atom/target = controller.blackboard[target_key]

	if(!target)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Alert nearby void faction members to attack the same target
	var/pack_called = FALSE
	for(var/mob/living/simple_animal/hostile/void_mob in view(7, living_pawn))
		if(void_mob.faction.Find(FACTION_VOID) && void_mob != living_pawn && !void_mob.ai_controller?.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
			void_mob.GiveTarget(target)
			pack_called = TRUE

	if(pack_called)
		living_pawn.visible_message(span_warning("[living_pawn] lets out a chittering call, rallying nearby void creatures!"))
		// Use existing sound or remove this line if no sound file exists
		// playsound(living_pawn, 'sound/creatures/voidbug_chitter.ogg', 50, TRUE)

	controller.blackboard[BB_VOIDBUG_LAST_PACK_CALL] = world.time
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

// ===== AGGRESSIVE FIND TARGET SUBTREE =====
/datum/ai_planning_subtree/void_aggressive_find_target
	/// Range to find targets
	var/target_range = 7

/datum/ai_planning_subtree/void_aggressive_find_target/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	var/mob/living/pawn_mob = controller.pawn
	if(!pawn_mob)
		return

	// Use controller's aggro range if available, otherwise use default
	var/aggro_range = target_range
	if(istype(controller, /datum/ai_controller/basic_controller/void))
		var/datum/ai_controller/basic_controller/void/void_controller = controller
		aggro_range = void_controller.aggro_range

	var/mob/living/target
	var/min_dist = INFINITY

	for(var/mob/living/L in view(aggro_range, pawn_mob))
		if(L.stat == DEAD)
			continue

		// Check if target is in same faction
		var/same_faction = FALSE
		for(var/faction in L.faction)
			if(faction in pawn_mob.faction)
				same_faction = TRUE
				break

		if(same_faction)
			continue

		var/dist = get_dist(pawn_mob, L)
		if(dist < min_dist)
			min_dist = dist
			target = L

	if(target)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
		return SUBTREE_RETURN_FINISH_PLANNING

// ===== VOID HEALER CONTROLLER (Support) =====
/datum/ai_controller/basic_controller/void_healer
	planning_subtrees = list(
		/datum/ai_planning_subtree/void_healer_heal_allies,
		/datum/ai_planning_subtree/void_healer_avoid_enemies,
		/datum/ai_planning_subtree/void_aggressive_find_target, // Can still find targets if needed
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)
	ai_movement = /datum/ai_movement/basic_avoidance

// Void healer prioritizes healing wounded allies
/datum/ai_planning_subtree/void_healer_heal_allies
	var/heal_cooldown = 5 SECONDS

/datum/ai_planning_subtree/void_healer_heal_allies/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/last_heal = controller.blackboard[BB_VOID_HEALER_LAST_HEAL] || 0
	if(world.time < last_heal + heal_cooldown)
		return

	// Find wounded allies
	var/mob/living/wounded_ally
	var/most_damaged_ratio = 0.3 // Only heal allies below 70% health

	var/mob/living/pawn_mob = controller.pawn
	if(!pawn_mob)
		return

	for(var/mob/living/ally in view(4, pawn_mob))
		// Check if ally is in same faction
		var/same_faction = FALSE
		for(var/faction in ally.faction)
			if(faction in pawn_mob.faction)
				same_faction = TRUE
				break

		if(same_faction && ally != pawn_mob && ally.health < ally.maxHealth)
			var/health_ratio = ally.health / ally.maxHealth
			if(health_ratio < most_damaged_ratio || (health_ratio < 0.7 && !wounded_ally))
				wounded_ally = ally
				most_damaged_ratio = health_ratio

	if(wounded_ally)
		controller.blackboard[BB_VOID_HEALER_CURRENT_TARGET] = wounded_ally
		controller.queue_behavior(/datum/ai_behavior/void_healer_heal, BB_VOID_HEALER_CURRENT_TARGET)
		return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/void_healer_heal
	action_cooldown = 5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM

/datum/ai_behavior/void_healer_heal/setup(datum/ai_controller/controller, target_key)
	var/mob/living/target = controller.blackboard[target_key]
	if(!target)
		return FALSE
	return ..()

/datum/ai_behavior/void_healer_heal/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/living_pawn = controller.pawn
	var/mob/living/target = controller.blackboard[target_key]

	if(!target || target.health >= target.maxHealth)
		controller.blackboard[BB_VOID_HEALER_CURRENT_TARGET] = null
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Heal the target
	target.adjustBruteLoss(-15)
	target.adjustFireLoss(-15)

	var/heal_message = pick("mends", "soothes", "repairs", "restores")
	living_pawn.visible_message(span_notice("[living_pawn] [heal_message] [target] with void energy."))
	// Use existing sound or remove this line if no sound file exists
	// playsound(living_pawn, 'sound/magic/void_heal.ogg', 30, TRUE)

	// Create simple visual effect
	var/obj/effect/temp_visual/heal_effect = new(get_turf(target))
	heal_effect.icon = 'modular_zzveilbreak/icons/mob/effects.dmi'
	heal_effect.icon_state = "heal"
	QDEL_IN(heal_effect, 1 SECONDS)

	controller.blackboard[BB_VOID_HEALER_LAST_HEAL] = world.time
	controller.blackboard[BB_VOID_HEALER_CURRENT_TARGET] = null
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

// Void healer avoids enemies
/datum/ai_planning_subtree/void_healer_avoid_enemies

/datum/ai_planning_subtree/void_healer_avoid_enemies/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/living_pawn = controller.pawn
	if(!living_pawn)
		return

	// Find closest enemy
	var/mob/living/closest_enemy
	var/closest_distance = 8 // Detection range

	for(var/mob/living/enemy in view(7, living_pawn))
		if(enemy.stat)
			continue

		// Check if enemy is NOT in same faction
		var/same_faction = FALSE
		for(var/faction in enemy.faction)
			if(faction in living_pawn.faction)
				same_faction = TRUE
				break

		if(!same_faction)
			var/distance = get_dist(living_pawn, enemy)
			if(distance < closest_distance)
				closest_enemy = enemy
				closest_distance = distance

	if(closest_enemy)
		controller.blackboard[BB_VOID_HEALER_FLEE_TARGET] = closest_enemy
		controller.queue_behavior(/datum/ai_behavior/void_healer_flee, BB_VOID_HEALER_FLEE_TARGET)
		return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/void_healer_flee
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT

/datum/ai_behavior/void_healer_flee/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/living_pawn = controller.pawn
	var/mob/living/enemy = controller.blackboard[target_key]

	if(!enemy)
		controller.blackboard[BB_VOID_HEALER_FLEE_TARGET] = null
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Move away from the enemy
	var/dir_away = get_dir(enemy, living_pawn)
	var/turf/escape_turf = get_step(living_pawn, dir_away)

	if(escape_turf && living_pawn.Move(escape_turf, dir_away))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	controller.blackboard[BB_VOID_HEALER_FLEE_TARGET] = null
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

// ===== CONSUMED PATHFINDER CONTROLLER (Brute tank) =====
/datum/ai_controller/basic_controller/void/consumed_pathfinder
	aggro_range = 10
	planning_subtrees = list(
		/datum/ai_planning_subtree/void_aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/void_pathfinder_pursue,
	)
	ai_movement = /datum/ai_movement/basic_avoidance

// Pathfinder aggressively pursues targets
/datum/ai_planning_subtree/void_pathfinder_pursue

/datum/ai_planning_subtree/void_pathfinder_pursue/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(!controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	controller.queue_behavior(/datum/ai_behavior/void_pathfinder_pursue, BB_BASIC_MOB_CURRENT_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/void_pathfinder_pursue
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT

/datum/ai_behavior/void_pathfinder_pursue/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/living_pawn = controller.pawn
	var/atom/target = controller.blackboard[target_key]

	if(!target)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Aggressively move toward target
	var/dir_to_target = get_dir(living_pawn, target)
	var/turf/approach_turf = get_step(living_pawn, dir_to_target)

	if(approach_turf && living_pawn.Move(approach_turf, dir_to_target))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

// ===== VISUAL EFFECTS =====
/obj/effect/temp_visual/heal_effect
	icon = 'modular_zzveilbreak/icons/mob/effects.dmi'
	icon_state = "heal"
	duration = 1 SECONDS
