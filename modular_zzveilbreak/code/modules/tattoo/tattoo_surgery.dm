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
		BODY_ZONE_R_LEG
	)
	// Allow self-surgery and don't require lying down for tattoo removal
	surgery_flags = SURGERY_SELF_OPERABLE
	target_mobtypes = list(/mob/living/carbon/human)
	// VENUS ADDITION - Self Surgery locations
	self_surgery_possible_locs = list(
		BODY_ZONE_HEAD,
		BODY_ZONE_CHEST,
		BODY_ZONE_L_ARM,
		BODY_ZONE_R_ARM,
		BODY_ZONE_L_LEG,
		BODY_ZONE_R_LEG
	)

/datum/surgery/tattoo_removal/New(atom/surgery_target, surgery_location, surgery_bodypart)
	. = ..()
	// If the global exists and is populated, use it instead of fallback
	if(GLOB.tattooable_body_parts && length(GLOB.tattooable_body_parts))
		src.possible_locs = GLOB.tattooable_body_parts.Copy()

/datum/surgery/tattoo_removal/can_start(mob/user, mob/living/patient)
	if(!..())
		return FALSE

	if(!istype(patient, /mob/living/carbon/human))
		return FALSE

	var/mob/living/carbon/human/H = patient

	// Check if target allows bodywriting (for removal consent) using CORRECT preference
	if(!H.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
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
		/obj/item/cautery = 100,           // Best tool - medical grade
		/obj/item/cigarette = 75,          // Controlled small flame
		/obj/item/lighter = 50,            // Open flame, less controlled
		TOOL_SCALPEL = 40,                 // Wrong tool for the job
		/obj/item/weldingtool = 25         // Worst tool - catastrophic damage
	)
	time = 4 SECONDS
	var/datum/tattoo/operated_tattoo

/datum/surgery_step/cauterize_tattoo/tool_check(mob/user, obj/item/tool)
	// Check if tools need to be activated first
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

/datum/surgery_step/cauterize_tattoo/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
	var/mob/living/carbon/human/H = target
	var/list/tattoos = H.get_tattoos(target_zone)

	// Safety check - ensure tattoos exist
	if(!length(tattoos))
		to_chat(user, span_warning("No tattoos found to remove!"))
		return

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

	// Generate appropriate message based on tool
	var/burn_message
	if(istype(tool, /obj/item/cautery))
		burn_message = "You begin carefully cauterizing the tattoo from [target]'s [target.parse_zone_with_bodypart(target_zone)]..."
	else if(istype(tool, /obj/item/cigarette))
		burn_message = "You begin carefully burning the tattoo from [target]'s [target.parse_zone_with_bodypart(target_zone)] with the cigarette..."
	else if(istype(tool, /obj/item/lighter))
		burn_message = "You begin burning the tattoo from [target]'s [target.parse_zone_with_bodypart(target_zone)] with the lighter..."
	else if(istype(tool, /obj/item/weldingtool))
		burn_message = "You begin aggressively burning away the tattoo from [target]'s [target.parse_zone_with_bodypart(target_zone)] with the welding tool..."
	else
		burn_message = "You begin scraping away the tattoo from [target]'s [target.parse_zone_with_bodypart(target_zone)]..."

	display_results(
		user,
		target,
		span_notice("[burn_message]"),
		span_notice("[user] begins removing a tattoo from [target]'s [target.parse_zone_with_bodypart(target_zone)] with [tool]."),
		span_notice("[user] begins working on [target]'s [target.parse_zone_with_bodypart(target_zone)] with [tool]."),
	)

	display_pain(target, "Your [target.parse_zone_with_bodypart(target_zone)] burns with intense heat!")

/datum/surgery_step/cauterize_tattoo/success(mob/living/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
	if(!operated_tattoo)
		to_chat(user, span_warning("There is no tattoo to remove!"))
		return FALSE

	var/mob/living/carbon/human/H = target

	// Calculate burn damage based on tool quality (best to worst)
	var/burn_damage = 5
	var/tool_message = "carefully"

	if(istype(tool, /obj/item/cautery))
		burn_damage = 8  // Best tool - medical grade precision
		tool_message = "precisely with the cautery"
	else if(istype(tool, /obj/item/cigarette))
		burn_damage = 15  // Controlled small flame
		tool_message = "carefully with the cigarette"
	else if(istype(tool, /obj/item/lighter))
		burn_damage = 25  // Open flame, less controlled
		tool_message = "crudely with the lighter"
	else if(tool.tool_behaviour == TOOL_SCALPEL)
		burn_damage = 12  // Wrong tool for burning
		tool_message = "inefficiently with the scalpel"
	else if(istype(tool, /obj/item/weldingtool))
		burn_damage = 35  // Worst tool - catastrophic damage
		tool_message = "aggressively with the welding tool, causing severe burns"

	// Attempt tattoo removal
	if(H.remove_tattoo(operated_tattoo))
		display_results(
			user,
			target,
			span_notice("You successfully remove the tattoo [tool_message]."),
			span_notice("[user] successfully removes the tattoo from your [target.parse_zone_with_bodypart(target_zone)] [tool_message]!"),
			span_notice("[user] successfully works on your [target.parse_zone_with_bodypart(target_zone)]!"),
		)

		// Apply burn damage
		var/obj/item/bodypart/BP = H.get_bodypart(target_zone)
		if(BP)
			BP.receive_damage(burn = burn_damage)
			// Check for burn wounds based on damage level
			if(burn_damage >= 30)
				BP.check_wounding(60, WOUND_BURN, target_zone) // Critical burn wound (welding tool)
			else if(burn_damage >= 20)
				BP.check_wounding(40, WOUND_BURN, target_zone) // Severe burn wound (lighter)
			else if(burn_damage >= 10)
				BP.check_wounding(25, WOUND_BURN, target_zone) // Moderate burn wound

		log_combat(user, target, "removed a tattoo from", addition="TATTOO: [operated_tattoo.design] | TOOL: [tool.name]")
	else
		to_chat(user, span_warning("Failed to remove the tattoo!"))

	return ..()

/datum/surgery_step/cauterize_tattoo/failure(mob/user, mob/living/target, target_zone, obj/item/tool, datum/surgery/surgery, fail_prob = 0)
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

	// Apply significant burn damage on failure, scaled by tool quality
	var/obj/item/bodypart/BP = target.get_bodypart(target_zone)
	if(BP)
		var/failure_damage = 20
		if(istype(tool, /obj/item/weldingtool))
			failure_damage = 50  // Catastrophic failure with welding tool
		else if(istype(tool, /obj/item/lighter))
			failure_damage = 35  // Bad failure with lighter
		else if(istype(tool, /obj/item/cigarette))
			failure_damage = 25  // Moderate failure with cigarette
		else if(istype(tool, /obj/item/cautery))
			failure_damage = 15  // Minor failure with cautery

		BP.receive_damage(burn = failure_damage)
		BP.check_wounding(50, WOUND_BURN, target_zone) // Force severe burn wound on failure

	return FALSE
