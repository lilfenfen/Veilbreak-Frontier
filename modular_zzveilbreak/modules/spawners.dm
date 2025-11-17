/**
 * Contains mob spawners.
 */

#define MOB_PLACER_RANGE 16 // How far away to detect players.

/**
 * A simple, one-time use proximity spawner for void mobs.
 * When a player gets close, it spawns a random void mob and deletes itself.
 */
/obj/effect/random_mob_placer/void
	name = "void mob spawner"
	icon = 'modular_zzveilbreak/icons/mob/mobs.dmi'
	icon_state = "void_spawner"
	possible_mobs = list(
		/mob/living/basic/void_creature/voidling,
		/mob/living/basic/void_creature/consumed_pathfinder,
		/mob/living/basic/void_creature/voidbug,
		/mob/living/basic/void_creature/void_healer
	)

/obj/effect/random_mob_placer/void/Initialize(mapload)
	. = ..()
	for(var/turf/iterating_turf in range(MOB_PLACER_RANGE, src))
		RegisterSignal(iterating_turf, COMSIG_ATOM_ENTERED, PROC_REF(trigger))

/obj/effect/random_mob_placer/void/proc/trigger(datum/source, atom/movable/entered_atom)
	SIGNAL_HANDLER
	if(!isliving(entered_atom))
		return
	var/mob/living/entered_mob = entered_atom
	if(!entered_mob.client)
		return
	var/mob/picked_mob = pick(possible_mobs)
	new picked_mob(loc)
	qdel(src)

/**
 * A persistent, configurable mob spawner that acts like a nest.
 * It spawns mobs over time when players are near and can be temporarily destroyed.
 */
/obj/structure/mob_spawner/persistent
	name = "persistent mob spawner"
	desc = "A strange structure that seems to be spawning creatures."
	icon = 'modular_zzveilbreak/icons/obj/void_portal.dmi' // Generic icon, override in subtypes
	icon_state = "portal" // Generic icon state
	density = TRUE
	anchored = TRUE
	max_integrity = 150
	var/mob_type_to_spawn = /mob/living/basic/void_creature/voidling // The type of mob to spawn.
	var/max_mobs = 10 // The maximum number of controlled mobs active at once.
	var/trigger_range = 20 // How close a player needs to be to trigger spawning.
	var/spawn_cooldown = 20 SECONDS // Time between spawn checks.
	var/regenerate_time = 9000 MINUTES // Time to wait before respawning after being destroyed.
	var/retaliate_cooldown = 20 SECONDS // Cooldown for spawning a mob when attacked.
	var/list/spawn_faction = list("void") // Faction to assign to spawned mobs.
	var/list/spawned_mobs = list() // List of mobs this spawner controls.
	var/next_spawn_time = 0
	var/next_retaliate_time = 0

/obj/structure/mob_spawner/persistent/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/mob_spawner/persistent/Destroy()
	STOP_PROCESSING(SSobj, src)
	// When the nest is destroyed, it starts a timer to regenerate.
	new /obj/effect/mob_spawner_regenerator(loc, type, regenerate_time)
	return ..()

/obj/structure/mob_spawner/persistent/process()
	// Clean up dead/gone mobs from our list.
	for(var/mob/M in spawned_mobs)
		if(!M || M.stat == DEAD)
			spawned_mobs -= M

	// If we are at max capacity, do nothing.
	if(spawned_mobs.len >= max_mobs)
		return

	// If spawn cooldown is not ready, do nothing.
	if(world.time < next_spawn_time)
		return

	// Check for nearby players to trigger spawning.
	var/mob/living/target
	for(var/mob/living/L in range(trigger_range, src))
		if(L.client)
			target = L
			break

	if(target)
		spawn_mob(target)

/obj/structure/mob_spawner/persistent/attack_hand(mob/user)
	. = ..()
	if(.)
		handle_retaliation(user)

/obj/structure/mob_spawner/persistent/attackby(obj/item/I, mob/user, params)
	. = ..()
	if(.)
		handle_retaliation(user)

/obj/structure/mob_spawner/persistent/bullet_act(obj/projectile/P, def_zone)
	. = ..()
	if(.)
		handle_retaliation(P.firer)

/obj/structure/mob_spawner/persistent/proc/handle_retaliation(mob/attacker)
	if(!attacker || world.time < next_retaliate_time)
		return

	if(spawned_mobs.len < max_mobs)
		visible_message(span_warning("[src] shudders and releases a creature in defense!"))
		spawn_mob(attacker)
		next_retaliate_time = world.time + retaliate_cooldown

/obj/structure/mob_spawner/persistent/proc/spawn_mob(mob/target)
	if(!mob_type_to_spawn)
		return

	var/mob/living/new_mob = new mob_type_to_spawn(loc)
	new_mob.faction = spawn_faction.Copy()
	spawned_mobs += new_mob
	next_spawn_time = world.time + spawn_cooldown

	// Make the new mob aggressive towards the target that triggered the spawn.
	if(target && new_mob.ai_controller)
		new_mob.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)

	playsound(loc, 'sound/effects/magic/summon_magic.ogg', 50, TRUE)
	flick("spawn", src)

// This effect sits invisibly and respawns the nest after a delay.
/obj/effect/mob_spawner_regenerator
	name = "regenerating nest"
	var/spawner_type

/obj/effect/mob_spawner_regenerator/New(newloc, type_to_spawn, regen_time)
	..()
	loc = newloc
	spawner_type = type_to_spawn
	addtimer(CALLBACK(src, PROC_REF(regenerate)), regen_time)

/obj/effect/mob_spawner_regenerator/proc/regenerate()
	new spawner_type(loc)
	qdel(src)

