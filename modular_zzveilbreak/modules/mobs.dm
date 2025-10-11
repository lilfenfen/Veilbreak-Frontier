/mob/living/simple_animal/hostile/Voidling
	name = "Voidling"
	desc = "You struggle to comprehend the details of this creature, it keeps shifting and changing constantly."
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "voidling"
	icon_living = "voidling"
	speak_chance = 0
	turns_per_move = 5
	speed = 1
	maxHealth = 125
	health = 125
	harm_intent_damage = 10
	melee_damage_lower = 5
	melee_damage_upper = 15
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
		if(world.time > last_summon + 10 SECONDS)
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
	damage = 15
	damage_type = BURN
	range = 50
	speed = 0.2
	light_color = "#8a2be2"
