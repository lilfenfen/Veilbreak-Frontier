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
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 50

	ai_controller = /datum/ai_controller/basic_controller/voidling

/mob/living/simple_animal/hostile/Voidling/New()
	. = ..()
	faction |= FACTION_HOSTILE

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
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 30
	ranged = 1
	var/last_summon = 0
	projectiletype = /obj/projectile/magic/voidbolt

	ai_controller = /datum/ai_controller/basic_controller/void_pathfinder

/mob/living/simple_animal/hostile/Consumed_Pathfinder/New()
	. = ..()
	faction |= FACTION_HOSTILE

/mob/living/simple_animal/hostile/Consumed_Pathfinder/Life()
	. = ..()
	if(target && world.time > last_summon + 10 SECONDS)
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
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = FALSE
	var/block_chance = 30
	var/last_pack_call = 0

	ai_controller = /datum/ai_controller/basic_controller/voidbug

/mob/living/simple_animal/hostile/Voidbug/New()
	. = ..()
	faction |= FACTION_HOSTILE

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
	stat_attack = CONSCIOUS
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 70
	var/last_heal = 0

	ai_controller = /datum/ai_controller/basic_controller/void_healer

/mob/living/simple_animal/hostile/Void_Healer/New()
	. = ..()
	faction |= FACTION_HOSTILE

/mob/living/simple_animal/hostile/Void_Healer/death(gibbed)
	void_death("[src] fades into nothingness.", void_healer_table)
