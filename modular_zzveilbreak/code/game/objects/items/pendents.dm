/obj/item/clothing/neck/petcollar/aether_pendant
	name = "Aether Pendant"
	desc = "A mysterious pendant. Protects the user from harm."
	icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	worn_icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	icon_state = "aether_pendant"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_NECK

	var/active = FALSE  // For active ability
	var/on_cooldown = FALSE
	var/cooldown_time = 20 SECONDS

/obj/item/clothing/neck/petcollar/aether_pendant/Initialize()
	. = ..()
	// Removed action grant here

/obj/item/clothing/neck/petcollar/aether_pendant/equipped(mob/user, slot)
	. = ..()
	if(slot == ITEM_SLOT_NECK)
		RegisterSignal(user, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damage))
		if(!locate(/datum/action/item_action/aether_activate) in user.actions)
			var/datum/action/item_action/aether_activate/action = new(src)
			action.Grant(user)

/obj/item/clothing/neck/petcollar/aether_pendant/dropped(mob/user)
	. = ..()
	UnregisterSignal(user, COMSIG_MOB_APPLY_DAMAGE)
	var/datum/action/item_action/aether_activate/action = locate() in user.actions
	if(action)
		action.Remove(user)

/datum/action/item_action/aether_activate
	name = "Activate Aether Shield"
	desc = "Activate the Aether Pendant's shield for 1.5 seconds. Blocks one instance of damage"
	button_icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	button_icon_state = "aether_pendant"

/datum/action/item_action/aether_activate/Trigger()
	var/obj/item/clothing/neck/petcollar/aether_pendant/pendant = target
	if(!pendant)
		return
	if(pendant.on_cooldown)
		to_chat(owner, span_warning("The pendant is on cooldown!"))
		return
	if(pendant.active)
		to_chat(owner, span_warning("The pendant is already active!"))
		return
	pendant.active = TRUE
	pendant.on_cooldown = TRUE
	to_chat(owner, span_notice("You activate the Aether Pendant, nullifying damage for the next 1.5 seconds."))
	addtimer(CALLBACK(pendant, "deactivate"), 1.5 SECONDS)
	addtimer(CALLBACK(pendant, "end_cooldown"), pendant.cooldown_time)

/obj/item/clothing/neck/petcollar/aether_pendant/proc/on_damage(datum/source, damage, damagetype, def_zone, blocked, forced)
	SIGNAL_HANDLER
	if(prob(1) || active)  // 1% chance or active
		damage = 0  // Nullify damage
		if(active)
			active = FALSE
			to_chat(source, span_notice("The void fully blocks the damage!"))
		else
			to_chat(source, span_notice("The void passively blocks the damage!"))

/obj/item/clothing/neck/petcollar/aether_pendant/attack_self(mob/user)
	if(on_cooldown)
		to_chat(user, span_warning("The pendant is on cooldown!"))
		return
	if(active)
		to_chat(user, span_warning("The pendant is already active!"))
		return
	active = TRUE
	on_cooldown = TRUE
	to_chat(user, span_notice("You activate the Aether Pendant, nullifying damage for the next 1.5 seconds."))
	addtimer(CALLBACK(src, PROC_REF(deactivate)), 1.5 SECONDS)  // Active for 1.5 seconds
	addtimer(CALLBACK(src, PROC_REF(end_cooldown)), cooldown_time)  // 20 second cooldown

/obj/item/clothing/neck/petcollar/aether_pendant/proc/end_cooldown()
	on_cooldown = FALSE
	if(ismob(loc))
		to_chat(loc, span_notice("The Aether Pendant is ready to use again."))

/obj/item/clothing/neck/petcollar/aether_pendant/proc/deactivate()
	if(active)
		active = FALSE
		if(ismob(loc))
			to_chat(loc, span_warning("The Aether Pendant's activation fades."))

/obj/item/clothing/neck/petcollar/life_pendant
	name = "Life Pendant"
	desc = "A vibrant pendant that pulses with life energy. Heals the user."
	icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	worn_icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	icon_state = "life_pendant"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_NECK

	var/on_cooldown = FALSE
	var/cooldown_time = 35 SECONDS

/obj/item/clothing/neck/petcollar/life_pendant/Initialize()
	. = ..()
	// Removed action grant here

/obj/item/clothing/neck/petcollar/life_pendant/equipped(mob/user, slot)
	. = ..()
	if(slot == ITEM_SLOT_NECK)
		START_PROCESSING(SSobj, src)  // Start passive healing
		if(!locate(/datum/action/item_action/life_heal) in user.actions)
			var/datum/action/item_action/life_heal/action = new(src)
			action.Grant(user)

/obj/item/clothing/neck/petcollar/life_pendant/dropped(mob/user)
	. = ..()
	STOP_PROCESSING(SSobj, src)  // Stop passive healing
	var/datum/action/item_action/life_heal/action = locate() in user.actions
	if(action)
		action.Remove(user)

/datum/action/item_action/life_heal
	name = "Life Heal"
	desc = "Heal nearby allies with the Life Pendant."
	button_icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	button_icon_state = "life_pendant"

/datum/action/item_action/life_heal/Trigger()
	var/obj/item/clothing/neck/petcollar/life_pendant/pendant = target
	if(!pendant)
		return
	if(pendant.on_cooldown)
		to_chat(owner, span_warning("The pendant is on cooldown!"))
		return
	pendant.on_cooldown = TRUE
	var/healed_total = 0
	for(var/mob/living/t in range(3, owner))
		if(healed_total >= 100)
			break
		var/heal_amount = min(20, 100 - healed_total)
		t.adjustBruteLoss(-heal_amount)
		t.adjustFireLoss(-heal_amount)
		t.adjustToxLoss(-heal_amount)
		t.adjustOxyLoss(-heal_amount)
		healed_total += heal_amount
	to_chat(owner, span_notice("The Life Pendant heals nearby allies!."))
	addtimer(CALLBACK(pendant, "end_cooldown"), pendant.cooldown_time)

/obj/item/clothing/neck/petcollar/life_pendant/process(seconds_per_tick)
	if(!ismob(loc))
		return
	var/mob/living/user = loc
	if(user.health < user.maxHealth)
		user.adjustBruteLoss(-0.5 * seconds_per_tick)  // Heal 1 per second, scaled by tick
		user.adjustFireLoss(-0.5 * seconds_per_tick)
		user.adjustToxLoss(-0.5 * seconds_per_tick)
		user.adjustOxyLoss(-0.5 * seconds_per_tick)

/obj/item/clothing/neck/petcollar/life_pendant/attack_self(mob/user)
	if(on_cooldown)
		to_chat(user, span_warning("The pendant is on cooldown!"))
		return
	on_cooldown = TRUE
	var/healed_total = 0
	for(var/mob/living/target in range(3, user))
		if(healed_total >= 100)
			break
		var/heal_amount = min(20, 100 - healed_total)
		target.adjustBruteLoss(-heal_amount)
		target.adjustFireLoss(-heal_amount)
		target.adjustToxLoss(-heal_amount)
		target.adjustOxyLoss(-heal_amount)
		healed_total += heal_amount
	to_chat(user, span_notice("The Life Pendant heals nearby allies!."))
	addtimer(CALLBACK(src, PROC_REF(end_cooldown)), cooldown_time)

/obj/item/clothing/neck/petcollar/life_pendant/proc/end_cooldown()
	on_cooldown = FALSE
	if(ismob(loc))
		to_chat(loc, span_notice("The Life Pendant is ready to use again."))

/obj/item/clothing/neck/petcollar/aether_pendant
    /**
     * Custom worn overlay generator with scaling support.
     * Works even if base petcollar doesn't define get_mob_overlay().
     */
    proc/get_mob_overlay(mob/living/carbon/human/H, slot)
        // Build a basic image for the worn pendant
        var/image/overlay = image(
            icon = worn_icon,
            icon_state = worn_icon_state || icon_state,
            layer = H.layer + 0.01 // slightly above body layer
        )

        if(!overlay)
            return null

        // Base shrink factor (fits neck region)
        var/base_scale = 0.6

        // Apply dynamic mob scaling if present
        var/scale_x = base_scale
        var/scale_y = base_scale
        if(istype(H.transform, /matrix))
            if(H.transform.a)
                scale_x *= H.transform.a
            if(H.transform.d)
                scale_y *= H.transform.d

        var/matrix/M = matrix()
        M.Scale(scale_x, scale_y)
        overlay.transform = M

        // Adjust positioning so it sits at the neck
        overlay.pixel_y -= 4
        overlay.appearance_flags = RESET_TRANSFORM | KEEP_TOGETHER

        return overlay



/obj/item/clothing/neck/petcollar/life_pendant
    proc/get_mob_overlay(mob/living/carbon/human/H, slot)
        var/image/overlay = image(
            icon = worn_icon,
            icon_state = worn_icon_state || icon_state,
            layer = H.layer + 0.01
        )

        if(!overlay)
            return null

        var/base_scale = 0.6
        var/scale_x = base_scale
        var/scale_y = base_scale
        if(istype(H.transform, /matrix))
            if(H.transform.a)
                scale_x *= H.transform.a
            if(H.transform.d)
                scale_y *= H.transform.d

        var/matrix/M = matrix()
        M.Scale(scale_x, scale_y)
        overlay.transform = M

        overlay.pixel_y -= 4
        overlay.appearance_flags = RESET_TRANSFORM | KEEP_TOGETHER

        return overlay
