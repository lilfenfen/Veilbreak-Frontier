/// Tattoo Removal Surgery
/// Allows removal of tattoos through surgical means with various tools
/// Supports multiple tattoo locations and tool types with different success rates

/datum/surgery/tattoo_removal
	name = "Tattoo Removal"
	steps = list(/datum/surgery_step/cauterize_tattoo)
	possible_locs = list(
		BODY_ZONE_HEAD,
		BODY_ZONE_CHEST,
		BODY_ZONE_L_ARM,
		BODY_ZONE_R_ARM,
		BODY_ZONE_L_LEG,
		BODY_ZONE_R_LEG,
		BODY_ZONE_PRECISE_L_HAND,
		BODY_ZONE_PRECISE_R_HAND,
		BODY_ZONE_PRECISE_L_FOOT,
		BODY_ZONE_PRECISE_R_FOOT,
		BODY_ZONE_PRECISE_GROIN,
		ORGAN_SLOT_BELLY,
		ORGAN_SLOT_BUTT
	)
	self_surgery_possible_locs = list(
		BODY_ZONE_HEAD,
		BODY_ZONE_CHEST,
		BODY_ZONE_L_ARM,
		BODY_ZONE_R_ARM,
		BODY_ZONE_L_LEG,
		BODY_ZONE_R_LEG,
		BODY_ZONE_PRECISE_L_HAND,
		BODY_ZONE_PRECISE_R_HAND,
		BODY_ZONE_PRECISE_L_FOOT,
		BODY_ZONE_PRECISE_R_FOOT,
		BODY_ZONE_PRECISE_GROIN,
		ORGAN_SLOT_BELLY,
		ORGAN_SLOT_BUTT
	)
	surgery_flags = SURGERY_REQUIRE_RESTING | SURGERY_REQUIRE_LIMB | SURGERY_SELF_OPERABLE

/datum/surgery/tattoo_removal/can_start(mob/user, mob/living/patient)
	if(!..())
		return FALSE

	if(!istype(patient, /mob/living/carbon/human))
		return FALSE

	var/mob/living/carbon/human/H = patient

	if(user == H && self_surgery_possible_locs && !(user.zone_selected in self_surgery_possible_locs))
		to_chat(user, span_warning("You can't perform this surgery on that body part on yourself!"))
		return FALSE

	// Check if target allows bodywriting (for removal consent) using preferences
	if(!H.allows_bodywriting())
		to_chat(user, span_warning("[H] doesn't allow bodywriting modifications!"))
		return FALSE

	// Check if the selected zone exists (either as bodypart or organ)
	if(!body_part_exists(H, user.zone_selected))
		return FALSE

	// Check if there are tattoos to remove in the target zone
	return length(H.get_tattoos(user.zone_selected))

// ============================================================
// SURGERY STEP: CAUTERIZE TATTOO
// ============================================================

/datum/surgery_step/cauterize_tattoo
	name = "cauterize tattoo"
	implements = list(
		/obj/item/cautery = 100,
		/obj/item/cigarette = 75,
		/obj/item/lighter = 50,
		/obj/item/weldingtool = 125,
		TOOL_SCALPEL = 25
	)
	time = 4.5 SECONDS
	var/datum/tattoo/operated_tattoo

/datum/surgery_step/cauterize_tattoo/tool_check(mob/user, obj/item/tool)
	// Check if tools need to be activated first
	if(istype(tool, /obj/item/weldingtool))
		var/obj/item/weldingtool/welder = tool
		if(!welder.isOn())
			to_chat(user, span_warning("You need to turn [tool] on first!"))
			return FALSE

	else if(istype(tool, /obj/item/lighter))
		var/obj/item/lighter/lighter = tool
		if(!lighter.lit)
			to_chat(user, span_warning("You need to light [tool] first!"))
			return FALSE

	else if(istype(tool, /obj/item/cigarette))
		var/obj/item/cigarette/cig = tool
		if(!cig.lit)
			to_chat(user, span_warning("You need to light [tool] first!"))
			return FALSE

	return TRUE

/datum/surgery_step/cauterize_tattoo/preop(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery)
	if(!istype(target, /mob/living/carbon/human))
		return

	var/mob/living/carbon/human/H = target
	var/list/tattoos = H.get_tattoos(target_zone)

	// Safety check - ensure tattoos exist
	if(!length(tattoos))
		to_chat(user, span_warning("No tattoos found to remove!"))
		return

	if(user == H)
		to_chat(user, span_warning("Performing surgery on yourself is difficult and will take longer. Be careful!"))

	// Handle single vs multiple tattoo selection
	var/datum/tattoo/to_remove
	if(length(tattoos) == 1)
		to_remove = tattoos[1]
	else
		var/list/tattoo_choices = list()
		for(var/datum/tattoo/T as anything in tattoos)
			tattoo_choices["[T.design] by [T.artist]"] = T
		var/choice = input(user, "Which tattoo would you like to remove?", "Tattoo Removal") as null|anything in tattoo_choices
		to_remove = tattoo_choices[choice]

	if(!to_remove)
		return

	operated_tattoo = to_remove

	// Generate appropriate message based on tool and whether it's self-surgery
	var/burn_message
	if(user == H)
		if(istype(tool, /obj/item/cautery))
			burn_message = "You begin carefully cauterizing the tattoo from your own [parse_zone(target_zone)]..."
		else if(istype(tool, /obj/item/weldingtool))
			burn_message = "You begin burning away the tattoo from your own [parse_zone(target_zone)] with the welding tool..."
		else if(istype(tool, /obj/item/cigarette) || istype(tool, /obj/item/lighter))
			burn_message = "You begin carefully burning the tattoo from your own [parse_zone(target_zone)]..."
		else
			burn_message = "You begin scraping away the tattoo from your own [parse_zone(target_zone)]..."
	else
		if(istype(tool, /obj/item/cautery))
			burn_message = "You begin carefully cauterizing the tattoo from [target]'s [parse_zone(target_zone)]..."
		else if(istype(tool, /obj/item/weldingtool))
			burn_message = "You begin burning away the tattoo from [target]'s [parse_zone(target_zone)] with the welding tool..."
		else if(istype(tool, /obj/item/cigarette) || istype(tool, /obj/item/lighter))
			burn_message = "You begin carefully burning the tattoo from [target]'s [parse_zone(target_zone)]..."
		else
			burn_message = "You begin scraping away the tattoo from [target]'s [parse_zone(target_zone)]..."

	display_results(
		user,
		target,
		span_notice("[burn_message]"),
		span_notice("[user] begins removing a tattoo from [target == user ? "their own" : "[target]'s"] [parse_zone(target_zone)] with [tool]."),
		span_notice("[user] begins working on [target == user ? "their own" : "[target]'s"] [parse_zone(target_zone)] with [tool].")
	)

/datum/surgery_step/cauterize_tattoo/success(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = TRUE)
	if(!istype(target, /mob/living/carbon/human) || !operated_tattoo)
		return FALSE

	var/mob/living/carbon/human/H = target

	// Determine success chance based on tool quality
	var/success_chance = 100
	if(istype(tool, /obj/item/weldingtool))
		success_chance = 90  // Powerful but imprecise
	else if(istype(tool, /obj/item/cautery))
		success_chance = 95  // Medical grade tool
	else if(istype(tool, /obj/item/cigarette) || istype(tool, /obj/item/lighter))
		success_chance = 70  // Improvised tools
	else if(tool.tool_behaviour == TOOL_SCALPEL)
		success_chance = 60  // Not designed for this purpose

	if(!prob(success_chance))
		display_results(
			user,
			target,
			span_warning("You accidentally burn [target] badly while trying to remove the tattoo!"),
			span_userdanger("[user] accidentally burns you badly while trying to remove the tattoo!"),
			span_warning("[user] accidentally causes a bad burn on [target]'s [parse_zone(target_zone)]!")
		)
		var/obj/item/bodypart/BP = H.get_bodypart(target_zone)
		if(BP)
			BP.receive_damage(burn = 25)
		return TRUE

	if(H.remove_tattoo(operated_tattoo))
		var/success_message
		if(istype(tool, /obj/item/cautery))
			success_message = "You successfully cauterize away the tattoo."
		else if(istype(tool, /obj/item/weldingtool))
			success_message = "You successfully burn away the tattoo."
		else
			success_message = "You successfully remove the tattoo."

		display_results(
			user,
			target,
			span_notice("[success_message]"),
			span_notice("[user] successfully removes the tattoo from your [parse_zone(target_zone)]."),
			span_notice("[user] successfully works on your [parse_zone(target_zone)].")
		)

		var/obj/item/bodypart/BP = H.get_bodypart(target_zone)
		if(BP)
			BP.receive_damage(burn = 5)
		return TRUE
	else
		display_results(
			user,
			target,
			span_warning("You fail to remove the tattoo!"),
			span_warning("[user] fails to remove the tattoo from your [parse_zone(target_zone)]!"),
			span_warning("[user] fails to work on your [parse_zone(target_zone)]!")
		)
		return FALSE

/datum/surgery_step/cauterize_tattoo/failure(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, fail_prob = 0)
	var/obj/item/bodypart/BP = target.get_bodypart(target_zone)
	if(BP)
		BP.receive_damage(burn = 35)

	display_results(
		user,
		target,
		span_warning("You mess up the tattoo removal procedure, severely burning the area!"),
		span_userdanger("[user] messes up the tattoo removal procedure on your [parse_zone(target_zone)], causing severe burns!"),
		span_warning("[user] messes up the procedure on [target == user ? "their own" : "[target]'s"] [parse_zone(target_zone)], leaving it badly burned!")
	)

	return FALSE
