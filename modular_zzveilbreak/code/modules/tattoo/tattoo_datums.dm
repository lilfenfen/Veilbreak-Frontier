#define TATTOO_LAYER_UNDER 1
#define TATTOO_LAYER_NORMAL 2
#define TATTOO_LAYER_OVER 3

/datum/tattoo
    var/artist = "Unknown Artist" // Who applied the tattoo
    var/design = "" // The tattoo design/description
    var/body_part = BODY_ZONE_CHEST
    var/color = "#000000"
    var/date_applied = ""
    var/layer = TATTOO_LAYER_NORMAL

/datum/tattoo/New(artist, design, body_part, color, layer = TATTOO_LAYER_NORMAL)
    src.artist = sanitize_text(artist, "Unknown Artist")
    src.design = sanitize_text(design, "An intricate design")
    src.body_part = body_part
    src.color = sanitize_hexcolor(color, default = "#000000")
    src.layer = sanitize_integer(layer, 1, 3, 2)
    src.date_applied = time2text(world.realtime, "YYYY-MM-DD")

/datum/tattoo/proc/get_examine_text(mob/viewer, mob/living/carbon/human/victim)
	if(!is_visible(viewer, victim))
		world.log << "DEBUG: Tattoo not visible to viewer, no examine text"
		return ""

	// Make sure we have valid text
	var/display_design = design
	if(!display_design || display_design == "")
		display_design = "an intricate design"

	var/display_artist = artist
	if(!display_artist || display_artist == "")
		display_artist = "an unknown artist"

	// Use the enhanced body part descriptions
	var/body_part_description = get_specific_body_part_description(body_part)

	world.log << "DEBUG: Generating examine text for [display_design] on [body_part_description]"

	var/text = "<span style='color:[color]'>- [body_part_description]: \"[display_design]\" (by [display_artist])</span>"
	world.log << "DEBUG: Examine text: [text]"
	return text

/datum/tattoo/proc/is_visible(mob/viewer, mob/living/carbon/human/victim)
    if(!victim || !viewer)
        return FALSE

    if(get_dist(viewer, victim) > 7)
        return FALSE

    // Observers and non-humans can always see
    if(!ishuman(victim) || isobserver(viewer))
        return TRUE

    // Check if the body part is covered by clothing - APPLIES TO EVERYONE INCLUDING SELF
    return !is_hidden_by_clothes(victim, viewer)

/datum/tattoo/proc/is_hidden_by_clothes(mob/living/carbon/human/target_mob, mob/viewer)
	if(!target_mob)
		return TRUE

	world.log << "=== TATTOO VISIBILITY DEBUG ==="
	world.log << "DEBUG: Checking visibility for tattoo: [design] on [body_part]"
	world.log << "DEBUG: Target: [target_mob], Viewer: [viewer]"
	world.log << "DEBUG: Body part: [body_part]"

	// Special handling for external organ slots (tails, wings, etc.)
	if(body_part in list(ORGAN_SLOT_EXTERNAL_TAIL, ORGAN_SLOT_EXTERNAL_SPINES, ORGAN_SLOT_EXTERNAL_FRILLS,
						ORGAN_SLOT_EXTERNAL_HORNS, ORGAN_SLOT_EXTERNAL_WINGS, ORGAN_SLOT_WINGS))
		// These are usually always visible unless specifically covered by certain clothing
		var/obj/item/organ/organ = target_mob.get_organ_slot(body_part)
		if(!organ)
			world.log << "DEBUG: Organ not found for [body_part], returning hidden"
			return TRUE

		// Check for specific clothing that might cover these features
		if(target_mob.wear_suit)
			// Some suits might cover wings/tails specifically
			if(istype(target_mob.wear_suit, /obj/item/clothing/suit) && target_mob.wear_suit.flags_inv & HIDETAIL)
				if(body_part == ORGAN_SLOT_EXTERNAL_TAIL)
					world.log << "DEBUG: Tail hidden by suit with HIDETAIL flag"
					return TRUE
			// Check for spine covering
			if(target_mob.wear_suit.flags_inv & HIDEJUMPSUIT)
				if(body_part == ORGAN_SLOT_EXTERNAL_SPINES)
					world.log << "DEBUG: Spines hidden by suit with HIDEJUMPSUIT flag"
					return TRUE

		world.log << "DEBUG: External organ [body_part] is visible"
		return FALSE

	// Handle butt/stomach specifically since they're organ slots
	if(body_part == ORGAN_SLOT_BUTT)
		world.log << "DEBUG: Checking butt visibility"
		// Butt should be visible if not wearing pants/underwear that cover groin
		if(target_mob.w_uniform)
			var/covered = target_mob.w_uniform.body_parts_covered & GROIN
			world.log << "DEBUG: Uniform covers groin: [covered]"
			if(covered)
				return TRUE
		if(target_mob.wear_suit)
			var/covered = target_mob.wear_suit.body_parts_covered & GROIN
			world.log << "DEBUG: Suit covers groin: [covered]"
			if(covered)
				return TRUE
		// Check underwear too
		if(target_mob.w_underwear && !target_mob.underwear_hidden())
			var/covered = target_mob.w_underwear.body_parts_covered & GROIN
			world.log << "DEBUG: Underwear covers groin: [covered]"
			if(covered)
				return TRUE

		world.log << "DEBUG: Butt is visible"
		return FALSE

	if(body_part == ORGAN_SLOT_BELLY)
		world.log << "DEBUG: Checking stomach visibility"
		// Stomach should be visible if not wearing shirt that covers chest
		if(target_mob.w_uniform)
			var/covered = target_mob.w_uniform.body_parts_covered & CHEST
			world.log << "DEBUG: Uniform covers chest: [covered]"
			if(covered)
				return TRUE
		if(target_mob.wear_suit)
			var/covered = target_mob.wear_suit.body_parts_covered & CHEST
			world.log << "DEBUG: Suit covers chest: [covered]"
			if(covered)
				return TRUE
		// Check undershirt too
		if(target_mob.w_shirt && !target_mob.undershirt_hidden())
			var/covered = target_mob.w_shirt.body_parts_covered & CHEST
			world.log << "DEBUG: Shirt covers chest: [covered]"
			if(covered)
				return TRUE

		world.log << "DEBUG: Stomach is visible"
		return FALSE

	var/obj/item/bodypart/BP = target_mob.get_bodypart(body_part)
	if(!BP)
		// Check if it's an organ instead
		var/obj/item/organ/organ = target_mob.get_organ_slot(body_part)
		if(!organ)
			world.log << "DEBUG: No bodypart or organ found for [body_part], returning hidden"
			return TRUE

	var/check_flags = body_zone_to_flag(body_part)
	if(!check_flags)
		world.log << "DEBUG: No check flags for [body_part], assuming visible"
		return FALSE // If we can't map it to a flag, assume it's visible

	world.log << "DEBUG: Check flags for [body_part]: [check_flags]"

	// STRICT clothing check - NO EXCEPTIONS
	// Check all possible clothing layers

	// Outer suit coverage
	if(target_mob.wear_suit)
		world.log << "DEBUG: Checking wear_suit: [target_mob.wear_suit]"
		if(target_mob.wear_suit.body_parts_covered & check_flags)
			world.log << "DEBUG: Hidden by wear_suit body_parts_covered"
			return TRUE
		// Check if suit has flags that might cover the area
		if(target_mob.wear_suit.flags_inv & HIDEJUMPSUIT)
			if(check_flags & (CHEST|GROIN|ARMS|LEGS))
				world.log << "DEBUG: Hidden by wear_suit HIDEJUMPSUIT flag"
				return TRUE

	// Uniform coverage
	if(target_mob.w_uniform)
		world.log << "DEBUG: Checking w_uniform: [target_mob.w_uniform]"
		if(target_mob.w_uniform.body_parts_covered & check_flags)
			world.log << "DEBUG: Hidden by w_uniform body_parts_covered"
			return TRUE

	// Special cases for specific clothing types
	if(istype(target_mob.wear_suit, /obj/item/clothing/suit/toggle/labcoat/hospitalgown))
		world.log << "DEBUG: Hidden by hospital gown"
		return TRUE

	// Additional clothing layers (SPLURT EDIT compatibility)
	if(target_mob.w_shirt && !target_mob.undershirt_hidden())
		world.log << "DEBUG: Checking w_shirt: [target_mob.w_shirt]"
		if(target_mob.w_shirt.body_parts_covered & check_flags)
			world.log << "DEBUG: Hidden by w_shirt body_parts_covered"
			return TRUE

	if(target_mob.w_underwear && !target_mob.underwear_hidden())
		world.log << "DEBUG: Checking w_underwear: [target_mob.w_underwear]"
		if(target_mob.w_underwear.body_parts_covered & check_flags)
			world.log << "DEBUG: Hidden by w_underwear body_parts_covered"
			return TRUE

	// Gloves for hands
	if((check_flags & (HAND_LEFT|HAND_RIGHT)) && target_mob.gloves)
		world.log << "DEBUG: Hidden by gloves"
		return TRUE

	// Shoes for feet
	if((check_flags & (FOOT_LEFT|FOOT_RIGHT)) && target_mob.shoes)
		world.log << "DEBUG: Hidden by shoes"
		return TRUE

	// Headwear for head
	if((check_flags & HEAD) && target_mob.head)
		world.log << "DEBUG: Hidden by head"
		return TRUE

	world.log << "DEBUG: Tattoo is visible - no clothing covering [body_part]"
	return FALSE

/proc/body_zone_to_flag(body_zone)
    // Handle string organ slots first
    if(body_zone == ORGAN_SLOT_BELLY)
        return CHEST // Stomach is covered by chest clothing
    if(body_zone == ORGAN_SLOT_BUTT)
        return GROIN // Backside is covered by groin clothing

    // External organs are usually exposed
    if(body_zone in list(ORGAN_SLOT_EXTERNAL_TAIL, ORGAN_SLOT_EXTERNAL_SPINES, ORGAN_SLOT_EXTERNAL_FRILLS,
                        ORGAN_SLOT_EXTERNAL_HORNS, ORGAN_SLOT_EXTERNAL_WINGS, ORGAN_SLOT_WINGS))
        return null

    // Handle numeric body zones
    switch(body_zone)
        if(BODY_ZONE_HEAD) return HEAD
        if(BODY_ZONE_CHEST) return CHEST
        if(BODY_ZONE_L_ARM) return ARM_LEFT
        if(BODY_ZONE_R_ARM) return ARM_RIGHT
        if(BODY_ZONE_L_LEG) return LEG_LEFT
        if(BODY_ZONE_R_LEG) return LEG_RIGHT
        if(BODY_ZONE_PRECISE_L_HAND) return HAND_LEFT
        if(BODY_ZONE_PRECISE_R_HAND) return HAND_RIGHT
        if(BODY_ZONE_PRECISE_L_FOOT) return FOOT_LEFT
        if(BODY_ZONE_PRECISE_R_FOOT) return FOOT_RIGHT
        if(BODY_ZONE_PRECISE_GROIN) return GROIN
        else return null

/// Returns more specific descriptions for body parts
/proc/get_specific_body_part_description(body_zone)
    // Handle string organ slots
    if(body_zone == ORGAN_SLOT_BELLY)
        return "stomach"
    if(body_zone == ORGAN_SLOT_BUTT)
        return "backside"
    if(body_zone == ORGAN_SLOT_EXTERNAL_TAIL)
        return "tail"
    if(body_zone == ORGAN_SLOT_EXTERNAL_SPINES)
        return "spine ridge"
    if(body_zone == ORGAN_SLOT_EXTERNAL_FRILLS)
        return "head frills"
    if(body_zone == ORGAN_SLOT_EXTERNAL_HORNS)
        return "horns"
    if(body_zone == ORGAN_SLOT_EXTERNAL_WINGS)
        return "wings"
    if(body_zone == ORGAN_SLOT_WINGS)
        return "wing membranes"

    // Handle numeric body zones
    switch(body_zone)
        if(BODY_ZONE_HEAD) return "head"
        if(BODY_ZONE_CHEST) return "chest"
        if(BODY_ZONE_L_ARM) return "left arm"
        if(BODY_ZONE_R_ARM) return "right arm"
        if(BODY_ZONE_L_LEG) return "left leg"
        if(BODY_ZONE_R_LEG) return "right leg"
        if(BODY_ZONE_PRECISE_L_HAND) return "left hand"
        if(BODY_ZONE_PRECISE_R_HAND) return "right hand"
        if(BODY_ZONE_PRECISE_L_FOOT) return "left foot"
        if(BODY_ZONE_PRECISE_R_FOOT) return "right foot"
        if(BODY_ZONE_PRECISE_GROIN) return "groin area"
        else
            return get_body_zone_display_name(body_zone)

/// Converts body part strings to standardized organ slot defines
/// Converts body part strings to standardized organ slot defines
/proc/get_standardized_body_part(body_part_string)
    var/lower_part = lowertext(body_part_string)
    world.log << "DEBUG: Converting body part string: [body_part_string] -> [lower_part]"

    switch(lower_part)
        if("butt", "backside", "ass", "rear")
            world.log << "DEBUG: Converted to ORGAN_SLOT_BUTT: [ORGAN_SLOT_BUTT]"
            return ORGAN_SLOT_BUTT
        if("stomach", "belly")
            world.log << "DEBUG: Converted to ORGAN_SLOT_BELLY: [ORGAN_SLOT_BELLY]"
            return ORGAN_SLOT_BELLY
        if("tail")
            world.log << "DEBUG: Converted to ORGAN_SLOT_EXTERNAL_TAIL: [ORGAN_SLOT_EXTERNAL_TAIL]"
            return ORGAN_SLOT_EXTERNAL_TAIL
        if("spines", "spine ridge")
            world.log << "DEBUG: Converted to ORGAN_SLOT_EXTERNAL_SPINES: [ORGAN_SLOT_EXTERNAL_SPINES]"
            return ORGAN_SLOT_EXTERNAL_SPINES
        if("frills", "head frills")
            world.log << "DEBUG: Converted to ORGAN_SLOT_EXTERNAL_FRILLS: [ORGAN_SLOT_EXTERNAL_FRILLS]"
            return ORGAN_SLOT_EXTERNAL_FRILLS
        if("horns")
            world.log << "DEBUG: Converted to ORGAN_SLOT_EXTERNAL_HORNS: [ORGAN_SLOT_EXTERNAL_HORNS]"
            return ORGAN_SLOT_EXTERNAL_HORNS
        if("wings", "wing membranes")
            world.log << "DEBUG: Converted to ORGAN_SLOT_EXTERNAL_WINGS: [ORGAN_SLOT_EXTERNAL_WINGS]"
            return ORGAN_SLOT_EXTERNAL_WINGS
        else
            world.log << "DEBUG: No conversion found, returning original: [body_part_string]"
            return body_part_string
