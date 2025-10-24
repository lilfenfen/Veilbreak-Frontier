// modular_zzveilbreak/code/datums/ai/void_ai.dm

// --- Targeting Strategy ---
/**
 * /datum/targeting_strategy/void_faction_hostile
 *
 * A targeting strategy that considers any mob not in the "Void" faction as hostile.
 * Respects a configurable attack range from the controller's blackboard.
 */
/datum/targeting_strategy/void_faction_hostile
	name = "Void Faction Hostile Targeting"

/datum/targeting_strategy/void_faction_hostile/can_target(mob/living/user, mob/living/target)
	// Call parent for basic checks (e.g., target is alive, not self, not an observer)
	if(!..())
		return FALSE

	// Target is hostile if NOT in the "Void" faction
	if(target.faction.Find("Void"))
		return FALSE // Target is a void mob, not hostile to us

	// Check range from controller's blackboard
	var/datum/ai_controller/controller = user.ai_controller
	if(controller && controller.blackboard[BB_ATTACK_RANGE])
		var/attack_range = controller.blackboard[BB_ATTACK_RANGE]
		if(get_dist(user, target) > attack_range)
			return FALSE

	return TRUE

/datum/targeting_strategy/void_faction_hostile/find_target(mob/living/user)
	var/datum/ai_controller/controller = user.ai_controller
	var/attack_range = controller.blackboard[BB_ATTACK_RANGE] || 7 // Default range if not set

	var/mob/living/best_target = null
	var/min_dist = attack_range + 1

	// Search for targets within the defined attack range
	for(var/mob/living/M in view(attack_range, user))
		if(can_target(user, M)) // Use the custom can_target logic
			var/dist = get_dist(user, M)
			if(dist <= attack_range)
				if(!best_target || dist < min_dist) // Prioritize closer targets
					best_target = M
					min_dist = dist
	return best_target

// --- AI Controller ---
/**
 * /datum/ai_controller/basic_controller/void
 *
 * A basic AI controller for void-aligned mobs.
 * Prioritizes retaliation against attackers, then seeks out non-void mobs within range.
 */
/datum/ai_controller/basic_controller/void
	name = "Void Basic Controller"
	blackboard = list(
		BB_TARGETING_STRATEGY = new /datum/targeting_strategy/void_faction_hostile(),
		BB_ATTACK_RANGE = 7, // Default attack range for void mobs
		BB_RETALIATE_TARGET = null, // Stores a weakref to the mob that last damaged this mob
		BB_BASIC_MOB_CURRENT_TARGET = null, // The current primary target
	)
	planning_subtrees = list(
		/datum/ai_planning_subtree/void_retaliate, // Highest priority: retaliate against recent attackers
		/datum/ai_planning_subtree/void_find_and_attack, // Find and attack other enemies
	)
	ai_movement = /datum/ai_movement/jps // Use JPS for smarter pathfinding

/datum/ai_controller/basic_controller/void/Initialize(pawn)
	. = ..()
	// Register for the COMSIG_LIVING_DAMAGED signal to update BB_RETALIATE_TARGET
	RegisterSignal(pawn, COMSIG_LIVING_DAMAGED, PROC_REF(on_damaged))

/datum/ai_controller/basic_controller/void/Destroy()
	// Unregister the signal to prevent memory leaks
	UnregisterSignal(pawn, COMSIG_LIVING_DAMAGED)
	. = ..()

/datum/ai_controller/basic_controller/void/on_damaged(datum/source, mob/living/user, mob/living/target, damage, damage_type, def_zone, blocked, forced, spread_damage, wound_bonus, bare_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	if(target != pawn) // Ensure the damage was to this mob
		return

	// Only consider retaliation if the attacker is not a void faction member
	if(user && !user.faction.Find("Void"))
		blackboard[BB_RETALIATE_TARGET] = WEAKREF(user)
		plan_next_action() // Immediately try to re-evaluate plans to prioritize retaliation

// --- Planning Subtrees ---
/**
 * /datum/ai_planning_subtree/void_retaliate
 *
 * Attempts to target and attack the mob that last damaged this mob, if they are hostile.
 */
/datum/ai_planning_subtree/void_retaliate
	name = "Void Retaliate"

/datum/ai_planning_subtree/void_retaliate/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/weakref/weak_retaliate_target = controller.blackboard[BB_RETALIATE_TARGET]
	var/mob/living/retaliate_target = weak_retaliate_target?.resolve()

	// Check if the retaliate target is valid and hostile according to our strategy
	if(retaliate_target && !QDELETED(retaliate_target) && istype(controller.blackboard[BB_TARGETING_STRATEGY], /datum/targeting_strategy/void_faction_hostile))
		var/datum/targeting_strategy/void_faction_hostile/targeting_strategy = controller.blackboard[BB_TARGETING_STRATEGY]
		if(targeting_strategy.can_target(controller.pawn, retaliate_target))
			controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] = WEAKREF(retaliate_target)
			// Queue appropriate attack behavior (melee or ranged)
			if(controller.pawn.ranged)
				controller.queue_behavior(/datum/ai_behavior/basic_ranged_attack, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY)
			else
				controller.queue_behavior(/datum/ai_behavior/basic_melee_attack, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY)
			return SUBTREE_RETURN_FINISH_PLANNING // Prioritize retaliation over other actions

/**
 * /datum/ai_planning_subtree/void_find_and_attack
 *
 * Finds and attacks nearby hostile mobs if no other target is present.
 */
/datum/ai_planning_subtree/void_find_and_attack
	name = "Void Find and Attack"

/datum/ai_planning_subtree/void_find_and_attack/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/datum/weakref/weak_current_target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/mob/living/current_target = weak_current_target?.resolve()

	// If no current target or current target is invalid, find a new one
	if(!current_target || QDELETED(current_target) || !istype(controller.blackboard[BB_TARGETING_STRATEGY], /datum/targeting_strategy/void_faction_hostile) || !controller.blackboard[BB_TARGETING_STRATEGY].can_target(controller.pawn, current_target))
		var/mob/living/new_target = controller.blackboard[BB_TARGETING_STRATEGY].find_target(controller.pawn)
		if(new_target)
			controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] = WEAKREF(new_target)
			current_target = new_target

	if(current_target)
		// Queue appropriate attack behavior
		if(controller.pawn.ranged)
			controller.queue_behavior(/datum/ai_behavior/basic_ranged_attack, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY)
		else
			controller.queue_behavior(/datum/ai_behavior/basic_melee_attack, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY)
		return SUBTREE_RETURN_FINISH_PLANNING // Found a target and queued an attack, so finish planning

	// If no target found, the mob can perform idle actions like random wandering
	controller.queue_behavior(/datum/ai_behavior/idle_random_walk)
	return SUBTREE_RETURN_CONTINUE_PLANNING // Allow other idle behaviors if any


