// modular_zzveilbreak/code/modules/mobs/void_mobs.dm

// Define constants first
#define HARD_CRIT 2
#define BB_VOID_SUMMON_COOLDOWN "void_summon_cooldown"
#define BB_VOID_HEAL_COOLDOWN "void_heal_cooldown"

// Define faction constants
#define FACTION_VOID "void"
#define FACTION_STATION "station"

// Base void mob type with common functionality
/mob/living/basic/void_creature
	name = "Void Creature"
	desc = "A creature from the void."
	faction = list(FACTION_VOID, "hostile")
	gender = NEUTER
	speak_emote = list("hums")
	response_help_continuous = "touches"
	response_help_simple = "touch"
	response_disarm_continuous = "pushes"
	response_disarm_simple = "push"
	response_harm_continuous = "hits"
	response_harm_simple = "hit"
	maxHealth = 50
	health = 50
	melee_damage_lower = 10
	melee_damage_upper = 15
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'modular_zzveilbreak/sound/weapons/voidling_attack.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	status_flags = CANPUSH
	obj_damage = 30
	movement_type = GROUND
	basic_mob_flags = DEL_ON_DEATH
	ai_controller = /datum/ai_controller/basic_controller/void

/mob/living/basic/void_creature/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/simple_flying)

/mob/living/basic/void_creature/proc/void_death(message, loot_table)
	if(QDELETED(src))
		return

	if(loot_table)
		var/loot = pick_loot_from_table(loot_table)
		if(loot)
			new loot(loc)
	if(message)
		visible_message(span_danger("[message]"))

	// Use the standard mob deletion instead of qdel to prevent bad del
	// The DEL_ON_DEATH flag will handle proper deletion
	death()

// Voidling - Basic melee attacker
/mob/living/basic/void_creature/voidling
	name = "Voidling"
	desc = "You struggle to comprehend the details of this creature, it keeps shifting and changing constantly."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "voidling"
	icon_living = "voidling"
	icon_dead = "voidling_dead"
	maxHealth = 30
	health = 30
	melee_damage_lower = 5
	melee_damage_upper = 9
	speed = 1
	ai_controller = /datum/ai_controller/basic_controller/void/voidling

/mob/living/basic/void_creature/voidling/Move()
	. = ..()
	if(.)
		flick("voidling_2", src)

/mob/living/basic/void_creature/voidling/death(gibbed)
	void_death("And the void reclaims.", voidling_loot_table)

// Consumed Pathfinder - Ranged attacker with summoning
/mob/living/basic/void_creature/consumed_pathfinder
	name = "Consumed Frontier"
	desc = "A Frontier just like you, consumed by the void."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "consumed"
	icon_living = "consumed"
	icon_dead = "consumed_dead"
	maxHealth = 100
	health = 100
	melee_damage_lower = 3
	melee_damage_upper = 10
	speed = 1
	ai_controller = /datum/ai_controller/basic_controller/void_pathfinder
	var/last_summon = 0

/mob/living/basic/void_creature/consumed_pathfinder/Initialize(mapload)
	. = ..()
	// Set up ranged attacks using the basic mob's built-in ranged system
	AddComponent(/datum/component/ranged_attacks, /obj/projectile/magic/voidbolt)

/mob/living/basic/void_creature/consumed_pathfinder/death(gibbed)
	void_death("[src] shatters into nothingness.", consumed_pathfinder_drops)

// Voidbug - Defensive tank
/mob/living/basic/void_creature/voidbug
	name = "Voidbug"
	desc = "A resilient bug-like creature from the void, tough but weak in offense."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_bug"
	icon_living = "void_bug"
	icon_dead = "void_bug_dead"
	maxHealth = 150
	health = 150
	melee_damage_lower = 2
	melee_damage_upper = 5
	speed = 1.1
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	ai_controller = /datum/ai_controller/basic_controller/void/voidbug
	var/block_chance = 30

/mob/living/basic/void_creature/voidbug/bullet_act(obj/projectile/P, def_zone, piercing_hit)
	if(prob(block_chance))
		visible_message(span_warning("[src] blocks the projectile!"))
		return BULLET_ACT_BLOCK
	. = ..()

/mob/living/basic/void_creature/voidbug/death(gibbed)
	void_death("[src] crumbles into void dust.", voidbug_loot_table)

// Void Healer - Support mob
/mob/living/basic/void_creature/void_healer
	name = "Void Healer"
	desc = "A benevolent void entity that heals its allies and flees from threats."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_healer"
	icon_living = "void_healer"
	icon_dead = "void_healer_dead"
	maxHealth = 50
	health = 50
	melee_damage_lower = 0
	melee_damage_upper = 0
	speed = 0.9
	attack_verb_continuous = "touches"
	attack_verb_simple = "touch"
	environment_smash = ENVIRONMENT_SMASH_NONE
	ai_controller = /datum/ai_controller/basic_controller/void_healer

/mob/living/basic/void_creature/void_healer/death(gibbed)
	void_death("[src] fades into nothingness.", void_healer_table)

// Projectile for Consumed Pathfinder
/obj/projectile/magic/voidbolt
	name = "void bolt"
	icon = 'modular_zzveilbreak/icons/item_icons/voidring.dmi'
	icon_state = "voidbolt"
	damage = 20
	damage_type = BURN
	range = 50
	speed = 0.2

// Basic void AI controller
/datum/ai_controller/basic_controller/void
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

// Targeting strategy for basic void creatures - FIXED VERSION
/datum/targeting_strategy/basic
	/// Range we can attack from
	var/range = 1

/datum/targeting_strategy/basic/can_attack(mob/living/owner, atom/target, vision_range)
	if(!ismob(target))
		return FALSE

	var/mob/target_mob = target
	// Don't target dead mobs or ghosts
	if(target_mob.stat == DEAD || isobserver(target_mob))
		return FALSE

	// Don't target our own faction - FIXED: Use proper faction checking
	if(compare_factions(owner, target_mob))
		return FALSE

	if(get_dist(owner, target) > range)
		return FALSE

	return TRUE

// Helper proc for faction checking
/proc/compare_factions(mob/living/owner, mob/target)
	if(!owner.faction || !target.faction)
		return FALSE

	// Check if they share any factions (shouldn't attack if they do)
	for(var/faction in owner.faction)
		if(faction in target.faction)
			return TRUE
	return FALSE

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
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_VOID_SUMMON_COOLDOWN = 0,
		BB_BASIC_MOB_RETREAT_DISTANCE = 5,
		BB_BASIC_MOB_MINIMUM_DISTANCE = 3,
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
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_VOID_HEAL_COOLDOWN = 0,
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

/datum/ai_planning_subtree/void_pathfinder_summon/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/void_creature/consumed_pathfinder/pathfinder = controller.pawn
	if(!istype(pathfinder))
		return

	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!target)
		return

	// Check if we can summon
	if(world.time > controller.blackboard[BB_VOID_SUMMON_COOLDOWN])
		controller.queue_behavior(/datum/ai_behavior/void_summon, BB_BASIC_MOB_CURRENT_TARGET)
		return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/void_summon
	action_cooldown = 30 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT

/datum/ai_behavior/void_summon/setup(datum/ai_controller/controller, target_key)
	. = ..()
	var/mob/living/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	set_movement_target(controller, target)

/datum/ai_behavior/void_summon/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/basic/void_creature/consumed_pathfinder/pathfinder = controller.pawn
	if(!istype(pathfinder))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Summon a voidling
	var/mob/living/basic/void_creature/voidling/new_voidling = new(pathfinder.loc)
	new_voidling.faction = pathfinder.faction.Copy()

	// Set cooldown
	controller.set_blackboard_key(BB_VOID_SUMMON_COOLDOWN, world.time + 30 SECONDS)

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_planning_subtree/void_healer_heal

/datum/ai_planning_subtree/void_healer_heal/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/void_creature/void_healer/healer = controller.pawn
	if(!istype(healer))
		return

	// Check if we can heal
	if(world.time > controller.blackboard[BB_VOID_HEAL_COOLDOWN])
		controller.queue_behavior(/datum/ai_behavior/void_heal)
		return SUBTREE_RETURN_FINISH_PLANNING

/datum/ai_behavior/void_heal
	action_cooldown = 5 SECONDS

/datum/ai_behavior/void_heal/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/void_creature/void_healer/healer = controller.pawn
	if(!istype(healer))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Look for injured allies nearby
	for(var/mob/living/ally in view(7, healer))
		if(ally.faction != healer.faction || ally.health >= ally.maxHealth)
			continue

		// Heal the ally - use direct health adjustment
		ally.health = min(ally.health + 20, ally.maxHealth)
		controller.set_blackboard_key(BB_VOID_HEAL_COOLDOWN, world.time + 5 SECONDS)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
