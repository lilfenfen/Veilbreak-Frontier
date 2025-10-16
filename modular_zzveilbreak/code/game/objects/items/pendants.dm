/obj/item/clothing/neck/aether_pendant
	name = "Aether Pendant"
	desc = "A mysterious pendant. Protects the user from harm."
	icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	worn_icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	post_init_icon_state = "aether_pendant"
	worn_icon_state = "aether_pendant"
	icon_state = "aether_pendant"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_NECK
	pixel_x = 4  // Offset towards neck (up)

	var/active = FALSE  // For active ability
	var/on_cooldown = FALSE
	var/cooldown_time = 20 SECONDS

/obj/item/clothing/neck/aether_pendant/Initialize()
	. = ..()
	// Removed action grant here

/obj/item/clothing/neck/aether_pendant/equipped(mob/user, slot)
	. = ..()
	if(slot == ITEM_SLOT_NECK)
		RegisterSignal(user, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damage))
		if(!locate(/datum/action/item_action/aether_activate) in user.actions)
			var/datum/action/item_action/aether_activate/action = new(src)
			action.Grant(user)

/obj/item/clothing/neck/aether_pendant/dropped(mob/user)
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

/datum/action/item_action/aether_activate/Trigger(trigger_flags)
	var/obj/item/clothing/neck/aether_pendant/pendant = target
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

/obj/item/clothing/neck/aether_pendant/proc/on_damage(datum/source, damage, damagetype, def_zone, blocked, forced)
	SIGNAL_HANDLER
	if(prob(1) || active)  // 1% chance or active
		damage = 0  // Nullify damage
		if(active)
			active = FALSE
			to_chat(source, span_notice("The void fully blocks the damage!"))
		else
			to_chat(source, span_notice("The void passively blocks the damage!"))

/obj/item/clothing/neck/aether_pendant/proc/end_cooldown()
	on_cooldown = FALSE
	if(ismob(loc))
		to_chat(loc, span_notice("The Aether Pendant is ready to use again."))

/obj/item/clothing/neck/aether_pendant/proc/deactivate()
	if(active)
		active = FALSE
		if(ismob(loc))
			to_chat(loc, span_warning("The Aether Pendant's activation fades."))

/obj/item/clothing/neck/aether_pendant/build_worn_icon(default_layer = 0, default_icon_file = null, isinhands = FALSE, femaleuniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null)
	var/mutable_appearance/result = ..()
	if(result && ishuman(loc))
		var/mob/living/carbon/human/H = loc
		var/scale = H.dna.features["body_size"] || 1
		result.transform = result.transform.Scale(scale)
	return result

/obj/item/clothing/neck/life_pendant
	name = "Life Pendant"
	desc = "A vibrant pendant that pulses with life energy. Heals the user."
	icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	worn_icon = 'modular_zzveilbreak/icons/item_icons/pendants.dmi'
	post_init_icon_state = "life_pendant"
	icon_state = "life_pendant"
	worn_icon_state = "life_pendant"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_NECK
	pixel_x = 4  // Offset towards neck (up)

	var/on_cooldown = FALSE
	var/cooldown_time = 35 SECONDS

/obj/item/clothing/neck/life_pendant/Initialize()
	. = ..()
	// Removed action grant here

/obj/item/clothing/neck/life_pendant/equipped(mob/user, slot)
	. = ..()
	if(slot == ITEM_SLOT_NECK)
		START_PROCESSING(SSobj, src)  // Start passive healing
		if(!locate(/datum/action/item_action/life_heal) in user.actions)
			var/datum/action/item_action/life_heal/action = new(src)
			action.Grant(user)

/obj/item/clothing/neck/life_pendant/dropped(mob/user)
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

/datum/action/item_action/life_heal/Trigger(trigger_flags)
	var/obj/item/clothing/neck/life_pendant/pendant = target
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
	addtimer(CALLBACK(pendant, PROC_REF(end_cooldown)), pendant.cooldown_time)

/obj/item/clothing/neck/life_pendant/process(seconds_per_tick)
	if(!ismob(loc))
		return
	var/mob/living/user = loc
	if(user.health < user.maxHealth)
		user.adjustBruteLoss(-0.5 * seconds_per_tick)  // Heal 1 per second, scaled by tick
		user.adjustFireLoss(-0.5 * seconds_per_tick)
		user.adjustToxLoss(-0.5 * seconds_per_tick)
		user.adjustOxyLoss(-0.5 * seconds_per_tick)

/obj/item/clothing/neck/life_pendant/proc/end_cooldown()
	on_cooldown = FALSE
	if(ismob(loc))
		to_chat(loc, span_notice("The Life Pendant is ready to use again."))

/obj/item/clothing/neck/life_pendant/build_worn_icon(default_layer = 0, default_icon_file = null, isinhands = FALSE, femaleuniform = NO_FEMALE_UNIFORM, override_state = null, override_file = null)
	var/mutable_appearance/result = ..()
	if(result && ishuman(loc))
		var/mob/living/carbon/human/H = loc
		var/scale = H.dna.features["body_size"] || 1
		result.transform = result.transform.Scale(scale)
	return result

