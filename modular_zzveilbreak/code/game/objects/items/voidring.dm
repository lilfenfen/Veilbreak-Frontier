/obj/item/clothing/gloves/ring/voidring
	name = "Void Ring"
	desc = "A ring pulsing with void energy, automatically retaliating against threats."
	greyscale_config = /datum/greyscale_config/voidring
	greyscale_colors = "#c9a2e7#2700ff#fa00b9"
	var/active = FALSE
	var/timer_id
	var/list/item_faction = list()

/obj/item/clothing/gloves/ring/voidring/equipped(mob/user, slot)
	. = ..()
	if(slot == ITEM_SLOT_GLOVES)
		active = TRUE
		item_faction = user.faction.Copy()
		timer_id = addtimer(CALLBACK(src, PROC_REF(fire_bolt)), 10 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/obj/item/clothing/gloves/ring/voidring/dropped(mob/user)
	. = ..()
	active = FALSE
	item_faction = list()
	if(timer_id)
		deltimer(timer_id)
		timer_id = null

/obj/item/clothing/gloves/ring/voidring/proc/fire_bolt()
	if(!active || !ismob(loc))
		return
	var/mob/user = loc
	var/list/targets = list()
	for(var/mob/living/L in view(7, user))
		if(!length(L.faction & item_faction) && !L.stat)
			targets += L
	if(!length(targets))
		return
	var/mob/living/target = pick(targets)

	// Direct projectile firing without preparePixelProjectile
	var/obj/projectile/magic/voidbolt/bolt = new(get_turf(user))
	bolt.original = target
	bolt.firer = user
	bolt.yo = target.y - user.y
	bolt.xo = target.x - user.x
	bolt.fire()

/obj/item/clothing/gloves/ring/voidring/build_worn_icon(default_layer = 0, default_icon_file = null, isinhands = FALSE, femaleuniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null)
	var/mutable_appearance/result = ..()
	if(result && ishuman(loc))
		var/mob/living/carbon/human/H = loc
		var/scale = (H.dna.features["body_size"] || 1) * 0.2  // Make rings smaller
		result.transform = result.transform.Scale(scale)
	return result
