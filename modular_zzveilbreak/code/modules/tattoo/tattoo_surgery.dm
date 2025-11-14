// modular_zzveilbreak/code/modules/tattoo/tattoo_surgery.dm
/datum/surgery/custom_tattoo_removal
	name = "Custom Tattoo Removal"
	steps = list(/datum/surgery_step/cauterize_custom_tattoo)
	possible_locs = list()
	surgery_flags = SURGERY_SELF_OPERABLE
	target_mobtypes = list(/mob/living/carbon/human)
	self_surgery_possible_locs = list()

/datum/surgery/custom_tattoo_removal/New(atom/surgery_target, surgery_location, surgery_bodypart)
	. = ..()
	if(GLOB.custom_tattooable_body_parts && length(GLOB.custom_tattooable_body_parts))
		src.possible_locs = GLOB.custom_tattooable_body_parts.Copy()
		src.self_surgery_possible_locs = GLOB.custom_tattooable_body_parts.Copy()

/datum/surgery/custom_tattoo_removal/can_start(mob/user, mob/living/patient)
	if(!..()) return FALSE
	if(!istype(patient, /mob/living/carbon/human)) return FALSE
	var/mob/living/carbon/human/H = patient
	if(!H.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[H] doesn't allow body modifications!"))
		return FALSE
	if(!is_custom_tattoo_bodypart_existing(H, user.zone_selected)) return FALSE
	if(!get_custom_tattoo_location_accessible(H, user.zone_selected))
		to_chat(user, span_warning("The body part is not accessible!"))
		return FALSE
	return length(H.get_custom_tattoos(user.zone_selected)) > 0

/datum/surgery_step/cauterize_custom_tattoo
	name = "cauterize custom tattoo"
	implements = list(
		/obj/item/cautery = 100,
		/obj/item/cigarette = 75,
		/obj/item/lighter = 50,
		TOOL_SCALPEL = 40,
		/obj/item/weldingtool = 25
	)
	time = 4 SECONDS
	var/datum/custom_tattoo/operated_tattoo

/datum/surgery_step/cauterize_custom_tattoo/tool_check(mob/user, obj/item/tool)
	switch(tool.type)
		if(/obj/item/weldingtool)
			var/obj/item/weldingtool/welder = tool
			if(!welder.isOn())
				to_chat(user, span_warning("You need to turn [tool] on first!"))
				return FALSE
		if(/obj/item/lighter)
			var/obj/item/lighter/lighter = tool
			if(!lighter.lit)
				to_chat(user, span_warning("You need to light [tool] first!"))
				return FALSE
		if(/obj/item/cigarette)
			var/obj/item/cigarette/cig = tool
			if(!cig.lit)
				to_chat(user, span_warning("You need to light [tool] first!"))
				return FALSE
	return TRUE

/datum/surgery_step/cauterize_custom_tattoo/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	var/mob/living/carbon/human/H = target
	if(!istype(H))
		to_chat(user, span_warning("This can only be performed on humans!"))
		return
	var/list/tattoos = H.get_custom_tattoos(target_zone)
	if(!length(tattoos))
		to_chat(user, span_warning("No custom tattoos found to remove!"))
		return
	var/datum/custom_tattoo/to_remove
	if(length(tattoos) == 1)
		to_remove = tattoos[1]
	else
		var/list/tattoo_choices = list()
		for(var/datum/custom_tattoo/T as anything in tattoos)
			tattoo_choices["[T.design] by [T.artist]"] = T
		var/choice = input(user, "Which tattoo would you like to remove?", "Custom Tattoo Removal") as null|anything in tattoo_choices
		to_remove = tattoo_choices[choice]
	if(!to_remove) return
	operated_tattoo = to_remove
	var/burn_message
	if(istype(tool, /obj/item/cautery))
		burn_message = "You begin carefully cauterizing the custom tattoo..."
	else if(istype(tool, /obj/item/cigarette))
		burn_message = "You begin carefully burning the custom tattoo with the cigarette..."
	else if(istype(tool, /obj/item/lighter))
		burn_message = "You begin burning the custom tattoo with the lighter..."
	else if(istype(tool, /obj/item/weldingtool))
		burn_message = "You begin aggressively burning away the custom tattoo with the welding tool..."
	else
		burn_message = "You begin scraping away the custom tattoo..."
	display_results(
		user,
		target,
		span_notice("[burn_message]"),
		span_notice("[user] begins removing a custom tattoo from [target]'s [get_custom_tattoo_body_part_description(target_zone)]."),
		span_notice("[user] begins working on [target]'s [get_custom_tattoo_body_part_description(target_zone)]."),
	)
	display_pain(target, "Your [get_custom_tattoo_body_part_description(target_zone)] burns with intense heat!")

/datum/surgery_step/cauterize_custom_tattoo/success(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	if(!operated_tattoo)
		to_chat(user, span_warning("There is no custom tattoo to remove!"))
		return FALSE
	var/mob/living/carbon/human/H = target
	if(!istype(H) || QDELETED(operated_tattoo) || !(operated_tattoo in H.custom_body_tattoos))
		to_chat(user, span_warning("The tattoo appears to have already been removed!"))
		return FALSE
	var/burn_damage = 5
	var/tool_message = "carefully"
	if(istype(tool, /obj/item/cautery))
		burn_damage = 8
		tool_message = "precisely with the cautery"
	else if(istype(tool, /obj/item/cigarette))
		burn_damage = 25
		tool_message = "carefully with the cigarette"
	else if(istype(tool, /obj/item/lighter))
		burn_damage = 25
		tool_message = "crudely with the lighter"
	else if(tool.tool_behaviour == TOOL_SCALPEL)
		burn_damage = 12
		tool_message = "inefficiently with the scalpel"
	else if(istype(tool, /obj/item/weldingtool))
		burn_damage = 35
		tool_message = "aggressively with the welding tool, causing severe burns"
	if(H.remove_custom_tattoo(operated_tattoo))
		display_results(
			user,
			target,
			span_notice("You successfully remove the custom tattoo [tool_message]."),
			span_notice("[user] successfully removes the custom tattoo from your [get_custom_tattoo_body_part_description(target_zone)] [tool_message]!"),
			span_notice("[user] successfully works on your [get_custom_tattoo_body_part_description(target_zone)]!"),
		)
		var/obj/item/bodypart/BP = H.get_bodypart(target_zone)
		if(BP)
			BP.receive_damage(burn = burn_damage)
			if(burn_damage >= 30)
				BP.check_wounding(60, WOUND_BURN, target_zone)
			else if(burn_damage >= 20)
				BP.check_wounding(40, WOUND_BURN, target_zone)
			else if(burn_damage >= 10)
				BP.check_wounding(25, WOUND_BURN, target_zone)
		log_combat(user, target, "removed a custom tattoo from", addition="TATTOO: [operated_tattoo.design] | TOOL: [tool.name]")
	else
		to_chat(user, span_warning("Failed to remove the custom tattoo!"))
	return ..()

/datum/surgery_step/cauterize_custom_tattoo/failure(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, fail_prob = 0)
	var/screwedmessage = ""
	switch(fail_prob)
		if(0 to 24)
			screwedmessage = " You almost had it, though."
		if(50 to 74)
			screwedmessage = " This is hard to get right in these conditions..."
		if(75 to 99)
			screwedmessage = " This is practically impossible in these conditions..."
	display_results(
		user,
		target,
		span_warning("You screw up![screwedmessage]"),
		span_warning("[user] screws up!"),
		span_notice("[user] finishes."),
	)
	var/obj/item/bodypart/BP = target.get_bodypart(target_zone)
	if(BP)
		var/failure_damage = 20
		if(istype(tool, /obj/item/weldingtool))
			failure_damage = 50
		else if(istype(tool, /obj/item/lighter))
			failure_damage = 35
		else if(istype(tool, /obj/item/cigarette))
			failure_damage = 25
		else if(istype(tool, /obj/item/cautery))
			failure_damage = 15
		BP.receive_damage(burn = failure_damage)
		BP.check_wounding(50, WOUND_BURN, target_zone)
	return FALSE
