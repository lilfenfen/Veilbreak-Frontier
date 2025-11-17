// modular_zzveilbreak/code/modules/mobs/void_mobs.dm

// Define constants first
#define HARD_CRIT 2
#define BB_VOID_SUMMON_COOLDOWN "void_summon_cooldown"
#define BB_VOID_HEAL_COOLDOWN "void_heal_cooldown"
#define BB_VOID_TAUNT_COOLDOWN "void_taunt_cooldown"

// Define faction constants
#define FACTION_VOID "void"
#define FACTION_STATION "station"

// Base void mob type with proper AI integration
/mob/living/basic/void_creature
	name = "Void Creature"
	desc = "A creature from the void."
	faction = list(FACTION_VOID, FACTION_HOSTILE)
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

	// Ensure proper hostility
	faction = list(FACTION_VOID, FACTION_HOSTILE)

	// Force global registration for processing
	if(!(src in GLOB.basic_mobs))
		GLOB.basic_mobs += src

/mob/living/basic/void_creature/death(gibbed)
	. = ..()
	if(!.)
		return FALSE

	// Dust immediately and drop loot
	visible_message(span_danger("[src] collapses into void dust!"))

	// Drop loot before dusting
	if(!gibbed)
		drop_loot()

	// Dust the corpse
	dust(just_ash = FALSE, drop_items = FALSE)
	return TRUE

/mob/living/basic/void_creature/proc/drop_loot()
	// Override in child types
	return

// Voidling - Aggressive melee attacker
/mob/living/basic/void_creature/voidling
	name = "Voidling"
	desc = "You struggle to comprehend the details of this creature, it keeps shifting and changing constantly."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "voidling"
	icon_living = "voidling"
	icon_dead = "voidling_dead"
	maxHealth = 30
	health = 30
	melee_damage_lower = 8
	melee_damage_upper = 12
	speed = 0.8 // Faster than base
	ai_controller = /datum/ai_controller/basic_controller/void/voidling

/mob/living/basic/void_creature/voidling/Initialize(mapload)
	. = ..()
	// More aggressive stats
	melee_damage_lower = 8
	melee_damage_upper = 12
	speed = 0.8

/mob/living/basic/void_creature/voidling/Move()
	. = ..()
	if(.)
		flick("voidling_2", src)

/mob/living/basic/void_creature/voidling/drop_loot()
	var/loot = pick_loot_from_table(voidling_loot_table)
	if(loot)
		new loot(loc)

// Consumed Pathfinder - Vicious ranged attacker with strategic summoning
/mob/living/basic/void_creature/consumed_pathfinder
	name = "Consumed Frontier"
	desc = "A Frontier just like you, consumed by the void. It moves with unnatural purpose."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "consumed"
	icon_living = "consumed"
	icon_dead = "consumed_dead"
	maxHealth = 80
	health = 80
	melee_damage_lower = 5
	melee_damage_upper = 8
	speed = 1
	ai_controller = /datum/ai_controller/basic_controller/void_pathfinder
	var/last_summon = 0

/mob/living/basic/void_creature/consumed_pathfinder/Initialize(mapload)
	. = ..()
	// Set up ranged attacks
	AddComponent(/datum/component/ranged_attacks, /obj/projectile/magic/voidbolt)

/mob/living/basic/void_creature/consumed_pathfinder/drop_loot()
	var/loot = pick_loot_from_table(consumed_pathfinder_drops)
	if(loot)
		new loot(loc)

// Voidbug - Defensive tank that protects allies
/mob/living/basic/void_creature/voidbug
	name = "Voidbug"
	desc = "A resilient bug-like creature from the void, its chitinous plates deflect attacks with ease."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_bug"
	icon_living = "void_bug"
	icon_dead = "void_bug_dead"
	maxHealth = 200 // Much tankier
	health = 200
	melee_damage_lower = 4
	melee_damage_upper = 7
	speed = 1.3 // Slower but tougher
	attack_verb_continuous = "crushes"
	attack_verb_simple = "crush"
	ai_controller = /datum/ai_controller/basic_controller/void/voidbug
	var/block_chance = 40 // Higher block chance

/mob/living/basic/void_creature/voidbug/Initialize(mapload)
	. = ..()
	// Enhanced tank stats
	maxHealth = 200
	health = 200
	block_chance = 40

/mob/living/basic/void_creature/voidbug/bullet_act(obj/projectile/P, def_zone, piercing_hit)
	if(prob(block_chance) && !piercing_hit)
		visible_message(span_warning("[src]'s chitin deflects the projectile!"))
		playsound(src, 'sound/effects/magic/cosmic_energy.ogg', 50, TRUE)
		return BULLET_ACT_BLOCK
	return ..()

/mob/living/basic/void_creature/voidbug/drop_loot()
	var/loot = pick_loot_from_table(voidbug_loot_table)
	if(loot)
		new loot(loc)

// Void Healer - Support mob that prioritizes healing
/mob/living/basic/void_creature/void_healer
	name = "Void Healer"
	desc = "A benevolent void entity that mends its allies. It seems to pulse with restorative energy."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_healer"
	icon_living = "void_healer"
	icon_dead = "void_healer_dead"
	maxHealth = 40
	health = 40
	melee_damage_lower = 0
	melee_damage_upper = 0
	speed = 0.7 // Fast to escape
	attack_verb_continuous = "touches"
	attack_verb_simple = "touch"
	environment_smash = ENVIRONMENT_SMASH_NONE
	ai_controller = /datum/ai_controller/basic_controller/void_healer

/mob/living/basic/void_creature/void_healer/drop_loot()
	var/loot = pick_loot_from_table(void_healer_table)
	if(loot)
		new loot(loc)

// Enhanced Projectile for Consumed Pathfinder
/obj/projectile/magic/voidbolt
	name = "void bolt"
	icon = 'modular_zzveilbreak/icons/item_icons/voidring.dmi'
	icon_state = "voidbolt"
	damage = 25 // More damage
	damage_type = BURN
	range = 7 // Shorter range but more vicious
	speed = 0.3 // Faster projectile
	hitsound = 'sound/effects/magic/magic_missile.ogg'
	hitsound_wall = 'sound/effects/magic/magic_missile.ogg'

/obj/projectile/magic/voidbolt/on_hit(atom/target, blocked = FALSE)
	. = ..()
	if(iscarbon(target))
		var/mob/living/carbon/C = target
		C.adjust_stutter(4 SECONDS) // Disorienting effect

// Enhanced AI Controllers

// Base void AI - more aggressive
/datum/ai_controller/basic_controller/void
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_VISION_RANGE = 9, // Increased vision range
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

// More aggressive targeting strategy
/datum/targeting_strategy/basic
	var/attack_range = 9 // Use a different variable name

/datum/targeting_strategy/basic/can_attack(mob/living/owner, atom/target, vision_range)
	if(!ismob(target))
		return FALSE

	var/mob/target_mob = target
	if(target_mob.stat == DEAD || isobserver(target_mob))
		return FALSE

	// Don't target our own faction
	if(compare_factions(owner, target_mob))
		return FALSE

	// Use attack_range instead of range
	if(get_dist(owner, target) > min(vision_range, attack_range) + 2)
		return FALSE

	// Attack humans and silicons preferentially
	if(ishuman(target) || issilicon(target))
		return TRUE

	// Attack other mobs too
	return isliving(target)

// Helper proc for faction checking
/proc/compare_factions(mob/living/owner, mob/target)
	if(!owner.faction || !target.faction)
		return FALSE

	// Check if they share any factions (shouldn't attack if they do)
	for(var/faction in owner.faction)
		if(faction in target.faction)
			return TRUE
	return FALSE

// Voidling specific AI - hyper aggressive
/datum/ai_controller/basic_controller/void/voidling
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_VISION_RANGE = 10,
		BB_BASIC_MOB_IDLE_WALK_CHANCE = 80, // Very restless
	)

	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/voidling_swarm_behavior, // New swarm behavior
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

// Voidling swarm behavior - coordinate attacks
/datum/ai_planning_subtree/voidling_swarm_behavior
/datum/ai_planning_subtree/voidling_swarm_behavior/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/void_creature/voidling/ling = controller.pawn
	if(!istype(ling))
		return

	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!target)
		return

	// Count nearby voidlings
	var/swarm_count = 0
	for(var/mob/living/basic/void_creature/voidling/other in view(5, ling))
		if(other != ling && other.faction == ling.faction)
			swarm_count++

	// If we outnumber the target, be more aggressive
	if(swarm_count >= 2)
		ling.speed = 0.6 // Faster in swarms
		ling.melee_damage_upper = min(ling.melee_damage_upper + 2, 15) // Damage boost in swarms

// Voidbug specific AI - protective tank
/datum/ai_controller/basic_controller/void/voidbug
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_VISION_RANGE = 7,
		BB_VOID_TAUNT_COOLDOWN = 0,
	)

	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/voidbug_protective_behavior,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
	)

// Voidbug protective behavior - protect allies
/datum/ai_planning_subtree/voidbug_protective_behavior
/datum/ai_planning_subtree/voidbug_protective_behavior/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/void_creature/voidbug/bug = controller.pawn
	if(!istype(bug))
		return

	// Look for injured allies to protect
	for(var/mob/living/ally in view(7, bug))
		if(ally.faction == bug.faction && ally.health < ally.maxHealth * 0.4)
			var/mob/living/attacker = ally.ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
			if(attacker && isliving(attacker))
				// Protect our ally!
				controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] = attacker
				return SUBTREE_RETURN_FINISH_PLANNING

// Consumed Pathfinder AI - Strategic summoner
/datum/ai_controller/basic_controller/void_pathfinder
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_VISION_RANGE = 12, // Long range for kiting
		BB_VOID_SUMMON_COOLDOWN = 0,
		BB_RANGED_SKIRMISH_MIN_DISTANCE = 4, // Keep distance
		BB_RANGED_SKIRMISH_MAX_DISTANCE = 7,
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/void_pathfinder_strategic_summon,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree,
		/datum/ai_planning_subtree/ranged_skirmish, // Kiting behavior
	)

// Strategic summoning - only summon when advantageous
/datum/ai_planning_subtree/void_pathfinder_strategic_summon
/datum/ai_planning_subtree/void_pathfinder_strategic_summon/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/void_creature/consumed_pathfinder/pathfinder = controller.pawn
	if(!istype(pathfinder))
		return

	var/mob/living/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!target)
		return

	// Count existing voidlings
	var/voidling_count = 0
	for(var/mob/living/basic/void_creature/voidling/ling in view(9, pathfinder))
		if(ling.faction == pathfinder.faction)
			voidling_count++

	// Strategic summoning conditions
	var/should_summon = FALSE

	// Summon if we're outnumbered
	if(voidling_count < 2)
		should_summon = TRUE

	// Summon if target is strong (has armor, is human, etc)
	if(ishuman(target) || isliving(target) && target.health > 50)
		should_summon = TRUE

	// Summon if we're on cooldown and it's strategically good
	if(should_summon && world.time > controller.blackboard[BB_VOID_SUMMON_COOLDOWN])
		controller.queue_behavior(/datum/ai_behavior/void_summon, BB_BASIC_MOB_CURRENT_TARGET)
		return SUBTREE_RETURN_FINISH_PLANNING

// Void Healer AI - Smart support
/datum/ai_controller/basic_controller/void_healer
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_VISION_RANGE = 10,
		BB_VOID_HEAL_COOLDOWN = 0,
		BB_BASIC_MOB_FLEE_DISTANCE = 5, // Run away closer
	)

	ai_movement = /datum/ai_movement/basic_avoidance
	idle_behavior = /datum/idle_behavior/idle_random_walk
	planning_subtrees = list(
		/datum/ai_planning_subtree/target_retaliate,
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/void_healer_smart_heal, // Smarter healing
		/datum/ai_planning_subtree/flee_target, // Standard flee behavior
	)

// Smart healing - prioritize critical allies
/datum/ai_planning_subtree/void_healer_smart_heal
/datum/ai_planning_subtree/void_healer_smart_heal/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/void_creature/void_healer/healer = controller.pawn
	if(!istype(healer))
		return

	// Check if we can heal
	if(world.time <= controller.blackboard[BB_VOID_HEAL_COOLDOWN])
		return

	// Find the most injured ally
	var/mob/living/most_injured_ally = null
	var/lowest_health_percent = 1.0

	for(var/mob/living/ally in view(7, healer))
		if(ally.faction == healer.faction && ally.health > 0 && ally != healer)
			var/health_percent = ally.health / ally.maxHealth
			if(health_percent < lowest_health_percent)
				lowest_health_percent = health_percent
				most_injured_ally = ally

	// Heal if ally is below 70% health
	if(most_injured_ally && lowest_health_percent < 0.7)
		controller.queue_behavior(/datum/ai_behavior/void_heal)
		return SUBTREE_RETURN_FINISH_PLANNING

// Enhanced summon behavior
/datum/ai_behavior/void_summon
	action_cooldown = 25 SECONDS // Slightly faster summoning
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT

/datum/ai_behavior/void_summon/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/basic/void_creature/consumed_pathfinder/pathfinder = controller.pawn
	if(!istype(pathfinder))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Summon 1-2 voidlings
	var/summon_count = prob(30) ? 2 : 1

	for(var/i in 1 to summon_count)
		var/mob/living/basic/void_creature/voidling/new_voidling = new(pathfinder.loc)
		new_voidling.faction = pathfinder.faction.Copy()

		// Make summoned voidlings aggressive
		if(new_voidling.ai_controller)
			var/mob/living/target = controller.blackboard[target_key]
			if(target)
				new_voidling.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)

	// Set cooldown
	controller.set_blackboard_key(BB_VOID_SUMMON_COOLDOWN, world.time + action_cooldown)

	// Visual and sound feedback
	playsound(pathfinder, 'sound/effects/magic/summon_magic.ogg', 50, TRUE)
	pathfinder.visible_message(span_warning("[pathfinder] summons reinforcements from the void!"))

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

// Enhanced heal behavior
/datum/ai_behavior/void_heal
	action_cooldown = 4 SECONDS // Faster healing

/datum/ai_behavior/void_heal/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/basic/void_creature/void_healer/healer = controller.pawn
	if(!istype(healer))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Find the most injured ally
	var/mob/living/most_injured_ally = null
	var/lowest_health = INFINITY

	for(var/mob/living/ally in view(7, healer))
		if(ally.faction == healer.faction && ally.health > 0 && ally != healer)
			if(ally.health < lowest_health)
				lowest_health = ally.health
				most_injured_ally = ally

	if(!most_injured_ally)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Heal the ally
	var/heal_amount = 25
	most_injured_ally.heal_overall_damage(heal_amount, heal_amount)

	// Visual and sound feedback
	playsound(healer, 'sound/effects/magic/staff_healing.ogg', 50, TRUE)
	new /obj/effect/temp_visual/heal(most_injured_ally.loc, "#8A2BE2") // Purple heal effect

	healer.visible_message(span_green("[healer] pulses with violet energy, healing [most_injured_ally]!"))

	controller.set_blackboard_key(BB_VOID_HEAL_COOLDOWN, world.time + action_cooldown)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

// Visual effect for healing
/obj/effect/temp_visual/heal
	icon = 'icons/effects/effects.dmi'
	icon_state = "heal"
	duration = 1 SECONDS

/obj/effect/temp_visual/heal/Initialize(mapload, color)
	. = ..()
	if(color)
		add_atom_colour(color, FIXED_COLOUR_PRIORITY)
