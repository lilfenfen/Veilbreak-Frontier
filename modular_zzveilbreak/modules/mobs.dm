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
	faction = list("hostile")
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 50

	/datum/ai_controller/basic_controller/alien

	death(message)
		// Spawn loot before deletion
		var/loot = pick_loot_from_table(voidling_loot_table)
		if(loot)
			new loot(loc)
		visible_message(span_danger("And the void reclaims."))
		..()

	del_on_death = TRUE

/mob/living/simple_animal/hostile/Voidling/New()
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(qdel)), 30 SECONDS )

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
	faction = list("hostile")
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 30
	ranged = 1
	projectiletype = /obj/projectile/magic/voidbolt
	var/last_summon = 0

	/datum/ai_controller/basic_controller/alien

	Life()
		. = ..()
		if(target && world.time > last_summon + 10 SECONDS)
			last_summon = world.time
			var/mob/living/simple_animal/hostile/Voidling/new_voidling = new(loc)
			new_voidling.faction = faction.Copy()

	death(message)
		// Spawn loot before deletion
		var/loot = pick_loot_from_table(consumed_pathfinder_drops)
		if(loot)
			new loot(loc)
		visible_message(span_danger("[src] shatters into nothingness."))
		..()

	del_on_death = TRUE

/obj/projectile/magic/voidbolt
	name = "void bolt"
	icon = 'modular_zzveilbreak/icons/item_icons/voidring.dmi'
	icon_state = "voidbolt"
	damage = 20
	damage_type = BURN
	range = 50
	speed = 0.2
	var/atom/target

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
	faction = list("hostile")
	environment_smash = ENVIRONMENT_SMASH_STRUCTURES
	stat_attack = HARD_CRIT
	robust_searching = TRUE
	dodging = FALSE
	var/block_chance = 30

	/datum/ai_controller/basic_controller/alien

	take_damage(damage, damagetype, def_zone, blocked, forced, spread_damage, wound_bonus, bare_wound_bonus, sharpness, attack_direction, attacking_item)
		if(prob(block_chance))
			visible_message(span_warning("[src] blocks the attack!"))
			return
		. = ..()

	bullet_act(obj/projectile/P, def_zone, piercing_hit)
		if(prob(block_chance))
			visible_message(span_warning("[src] blocks the projectile!"))
			return BULLET_ACT_BLOCK
		. = ..()

	death(message)
		// Spawn loot before deletion
		var/loot = pick_loot_from_table(voidbug_loot_table)
		if(loot)
			new loot(loc)
		visible_message(span_danger("[src] crumbles into void dust."))
		..()

	del_on_death = TRUE

/mob/living/simple_animal/hostile/Void_Healer
	name = "Void Healer"
	desc = "A benevolent void entity that heals its allies and flees from threats."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_healer"
	icon_living = "void_healer"
	speak_chance = 0
	turns_per_move = 5
	speed = 0.9 // Faster to run away
	maxHealth = 50
	health = 50
	harm_intent_damage = 0
	melee_damage_lower = 0
	melee_damage_upper = 0
	attack_verb_continuous = "touches"
	attack_verb_simple = "touch"
	faction = list("hostile")
	environment_smash = ENVIRONMENT_SMASH_NONE
	stat_attack = CONSCIOUS
	robust_searching = TRUE
	dodging = TRUE
	dodge_prob = 70

	/datum/ai_controller/basic_controller/simple

	Life()
		. = ..()
		// Heal nearby allies
		for(var/mob/living/L in range(3, src))
			if(L.faction == faction && L.health < L.maxHealth)
				L.adjustBruteLoss(-5)
				visible_message(span_notice("[src] heals [L] with void energy."))
				break // Heal one per tick

		// Run away from enemies
		var/closest_enemy = null
		var/closest_dist = 10
		for(var/mob/living/hostile in view(7, src))
			if(hostile.faction != faction && !hostile.stat)
				var/dist = get_dist(src, hostile)
				if(dist < closest_dist)
					closest_dist = dist
					closest_enemy = hostile
		if(closest_enemy)
			var/dir_away = get_dir(closest_enemy, src)
			step(src, dir_away)

	death(message)
		var/loot = pick_loot_from_table(void_healer_table)
		if(loot)
			new loot(loc)
		visible_message(span_danger("[src] fades into nothingness."))
		..()

	del_on_death = TRUE



