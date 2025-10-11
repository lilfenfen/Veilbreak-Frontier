/obj/item/clothing/gloves/ring/voidring
	name = "Void Ring"
	desc = "A ring pulsing with void energy, automatically retaliating against threats."
	icon = 'modular_zzveilbreak/icons/item_icons/voidring.dmi'
	icon_state = "voidring"
	worn_icon = 'modular_zzveilbreak/icons/item_icons/voidring.dmi'
	worn_icon_state = "voidring"
	var/active = FALSE
	var/timer_id

/obj/item/clothing/gloves/ring/voidring/equipped(mob/user, slot)
	. = ..()
	if(slot == ITEM_SLOT_GLOVES)
		active = TRUE
		timer_id = addtimer(CALLBACK(src, PROC_REF(fire_bolt)), 10 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/obj/item/clothing/gloves/ring/voidring/dropped(mob/user)
	. = ..()
	active = FALSE
	if(timer_id)
		deltimer(timer_id)
		timer_id = null

/obj/item/clothing/gloves/ring/voidring/proc/fire_bolt()
	if(!active || !ismob(loc))
		return
	var/mob/user = loc
	var/list/targets = list()
	for(var/mob/living/L in view(7, user))
		if(L.faction != user.faction && !L.stat)
			targets += L
	if(!length(targets))
		return
	var/mob/living/target = pick(targets)
	var/obj/projectile/magic/voidbolt/bolt = new(get_turf(user))
	bolt.firer = user
	bolt.target = target
	bolt.angle = get_angle(user, target)
	bolt.fire()
