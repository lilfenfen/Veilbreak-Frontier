// Define constants first
#define HARD_CRIT 2
#define BB_VOID_SUMMON_COOLDOWN "void_summon_cooldown"
#define BB_VOID_HEAL_COOLDOWN "void_heal_cooldown"

/mob/living/simple_animal/hostile
	// Shared death proc for all void creatures
	proc/void_death(message, loot_table)
		if(loot_table)
			var/loot = pick_loot_from_table(loot_table)
			if(loot)
				new loot(loc)
		if(message)
			visible_message(span_danger("[message]"))
		qdel(src)

/mob/living/simple_animal/hostile/Voidling
	name = "Voidling"
	desc = "You struggle to comprehend the details of this creature, it keeps shifting and changing constantly."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "voidling"
	icon_living = "voidling"
	speak_chance = 0
	turns_per_move = 5
	speed = 1
	maxHealth = 30
	health = 30
	harm_intent_damage = 7
	melee_damage_lower = 5
	melee_damage_upper = 9
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = "modular_zzveilbreak/sound/weapons/voidling_attack.ogg"
	faction = list(FACTION_VOID)
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 50
	stat_attack = CONSCIOUS

	ai_controller = /datum/ai_controller/basic_controller/void/voidling

/mob/living/simple_animal/hostile/Voidling/Initialize(mapload)
	. = ..()
	// Ensure AI controller is properly initialized for map-spawned mobs
	if(mapload && ai_controller)
		ai_controller = new ai_controller(src)

/mob/living/simple_animal/hostile/Voidling/death(gibbed)
	void_death("And the void reclaims.", voidling_loot_table)

/mob/living/simple_animal/hostile/Voidling/Move()
	. = ..()
	if(.)
		flick("voidling_2", src)

/mob/living/simple_animal/hostile/Consumed_Pathfinder
	name = "Consumed Frontier"
	desc = "A Frontier just like you, consumed by the void."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "consumed"
	icon_living = "consumed"
	speak_chance = 0
	turns_per_move = 5
	speed = 1
	maxHealth = 100
	health = 100
	harm_intent_damage = 8
	melee_damage_lower = 3
	melee_damage_upper = 10
	attack_verb_continuous = "sends a bolt"
	attack_verb_simple = "bolts"
	attack_sound = "modular_zzveilbreak/sound/weapons/voidling_attack.ogg"
	faction = list(FACTION_VOID)
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 30
	ranged = 1
	var/last_summon = 0
	projectiletype = /obj/projectile/magic/voidbolt
	stat_attack = CONSCIOUS

	ai_controller = /datum/ai_controller/basic_controller/void_pathfinder

/mob/living/simple_animal/hostile/Consumed_Pathfinder/Initialize(mapload)
	. = ..()
	// Ensure AI controller is properly initialized for map-spawned mobs
	if(mapload && ai_controller)
		ai_controller = new ai_controller(src)

/mob/living/simple_animal/hostile/Consumed_Pathfinder/Life()
	. = ..()
	if(target && world.time > last_summon + 30 SECONDS)
		last_summon = world.time
		var/mob/living/simple_animal/hostile/Voidling/new_voidling = new(loc)
		new_voidling.faction = faction.Copy()

/mob/living/simple_animal/hostile/Consumed_Pathfinder/death(gibbed)
	void_death("[src] shatters into nothingness.", consumed_pathfinder_drops)

/obj/projectile/magic/voidbolt
	name = "void bolt"
	icon = 'modular_zzveilbreak/icons/item_icons/voidring.dmi'
	icon_state = "voidbolt"
	damage = 20
	damage_type = BURN
	range = 50
	speed = 0.2

/mob/living/simple_animal/hostile/Voidbug
	name = "Voidbug"
	desc = "A resilient bug-like creature from the void, tough but weak in offense."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_bug"
	icon_living = "void_bug"
	speak_chance = 0
	turns_per_move = 5
	speed = 1.1
	maxHealth = 150
	health = 150
	harm_intent_damage = 5
	melee_damage_lower = 2
	melee_damage_upper = 5
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	attack_sound = "modular_zzveilbreak/sound/weapons/voidling_attack.ogg"
	faction = list(FACTION_VOID)
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	robust_searching = TRUE
	dodging = FALSE
	var/block_chance = 30
	var/last_pack_call = 0
	stat_attack = CONSCIOUS

	ai_controller = /datum/ai_controller/basic_controller/void/voidbug

/mob/living/simple_animal/hostile/Voidbug/Initialize(mapload)
	. = ..()
	// Ensure AI controller is properly initialized for map-spawned mobs
	if(mapload && ai_controller)
		ai_controller = new ai_controller(src)

/mob/living/simple_animal/hostile/Voidbug/take_damage(damage, damagetype, def_zone, blocked, forced, spread_damage, wound_bonus, bare_wound_bonus, sharpness, attack_direction, attacking_item)
	if(prob(block_chance))
		visible_message(span_warning("[src] blocks the attack!"))
		return
	. = ..()

/mob/living/simple_animal/hostile/Voidbug/bullet_act(obj/projectile/P, def_zone, piercing_hit)
	if(prob(block_chance))
		visible_message(span_warning("[src] blocks the projectile!"))
		return BULLET_ACT_BLOCK
	. = ..()

/mob/living/simple_animal/hostile/Voidbug/death(gibbed)
	void_death("[src] crumbles into void dust.", voidbug_loot_table)

/mob/living/simple_animal/hostile/Void_Healer
	name = "Void Healer"
	desc = "A benevolent void entity that heals its allies and flees from threats."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_healer"
	icon_living = "void_healer"
	speak_chance = 0
	turns_per_move = 5
	speed = 0.9
	maxHealth = 50
	health = 50
	harm_intent_damage = 0
	melee_damage_lower = 0
	melee_damage_upper = 0
	attack_verb_continuous = "touches"
	attack_verb_simple = "touch"
	faction = list(FACTION_VOID)
	environment_smash = ENVIRONMENT_SMASH_NONE
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 70
	var/last_heal = 0
	stat_attack = CONSCIOUS

	ai_controller = /datum/ai_controller/basic_controller/void_healer

/mob/living/simple_animal/hostile/Void_Healer/Initialize(mapload)
	. = ..()
	// Ensure AI controller is properly initialized for map-spawned mobs
	if(mapload && ai_controller)
		ai_controller = new ai_controller(src)

/mob/living/simple_animal/hostile/Void_Healer/death(gibbed)
	void_death("[src] fades into nothingness.", void_healer_table)

// FIXED: Use standard targeting strategy instead of custom one
/datum/targeting_strategy/basic/void
	// This inherits from basic targeting strategy which already handles conscious targets

// Basic void AI controller
/datum/ai_controller/basic_controller/void
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/void,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

// Voidling specific AI - aggressive melee attacker
/datum/ai_controller/basic_controller/void/voidling
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

// Voidbug specific AI - defensive melee attacker
/datum/ai_controller/basic_controller/void/voidbug
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

// Consumed Pathfinder AI - ranged attacker with summoning
/datum/ai_controller/basic_controller/void_pathfinder
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/void,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/void_pathfinder_summon,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree,
	)

// Void Healer AI - flees and heals allies
/datum/ai_controller/basic_controller/void_healer
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic/void,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/void_healer_heal,
		/datum/ai_planning_subtree/flee_target,
	)

// Custom planning subtrees for void creatures
/datum/ai_planning_subtree/void_pathfinder_summon
	operational_datums = list(/datum/component/ai_target_timer)

/datum/ai_planning_subtree/void_pathfinder_summon/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/simple_animal/hostile/Consumed_Pathfinder/pathfinder = controller.pawn
	if(!istype(pathfinder))
		return

	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!target)
		return

	// Check if we can summon
	if(world.time > (controller.blackboard[BB_VOID_SUMMON_COOLDOWN] || 0))
		controller.queue_behavior(/datum/ai_behavior/void_summon, BB_BASIC_MOB_CURRENT_TARGET)
		return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/void_summon
	action_cooldown = 10 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT

/datum/ai_behavior/void_summon/setup(datum/ai_controller/controller, target_key)
	. = ..()
	var/mob/living/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	set_movement_target(controller, target)

/datum/ai_behavior/void_summon/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/simple_animal/hostile/Consumed_Pathfinder/pathfinder = controller.pawn
	if(!istype(pathfinder))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Summon a voidling
	var/mob/living/simple_animal/hostile/Voidling/new_voidling = new(pathfinder.loc)
	new_voidling.faction = pathfinder.faction.Copy()

	// Set cooldown
	controller.set_blackboard_key(BB_VOID_SUMMON_COOLDOWN, world.time + 10 SECONDS)

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_planning_subtree/void_healer_heal

/datum/ai_planning_subtree/void_healer_heal/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/simple_animal/hostile/Void_Healer/healer = controller.pawn
	if(!istype(healer))
		return

	// Check if we can heal
	if(world.time > (controller.blackboard[BB_VOID_HEAL_COOLDOWN] || 0))
		controller.queue_behavior(/datum/ai_behavior/void_heal)
		return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/void_heal
	action_cooldown = 5 SECONDS

/datum/ai_behavior/void_heal/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/simple_animal/hostile/Void_Healer/healer = controller.pawn
	if(!istype(healer))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Look for injured allies nearby
	for(var/mob/living/simple_animal/hostile/ally in view(7, healer))
		if(ally.faction != healer.faction || ally.health >= ally.maxHealth)
			continue

		// Heal the ally
		ally.adjustHealth(-20)
		controller.set_blackboard_key(BB_VOID_HEAL_COOLDOWN, world.time + 5 SECONDS)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
