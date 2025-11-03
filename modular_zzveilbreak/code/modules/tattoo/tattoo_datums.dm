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
    src.layer = clamp(layer, 1, 3)
    src.date_applied = time2text(world.realtime, "YYYY-MM-DD")

/datum/tattoo/proc/get_examine_text(mob/viewer, mob/living/carbon/human/victim)
    if(!is_visible(viewer, victim))
        return ""

    // Make sure we have valid text
    var/display_design = design
    if(!display_design || display_design == "")
        display_design = "an intricate design"

    var/display_artist = artist
    if(!display_artist || display_artist == "")
        display_artist = "an unknown artist"

    return "<span style='color:[color]'>- \"[display_design]\" (by [display_artist])</span>"

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

	var/obj/item/bodypart/BP = target_mob.get_bodypart(body_part)
	if(!BP)
		return TRUE

	var/check_flags = body_zone_to_flag(body_part)
	if(!check_flags)
		return FALSE // If we can't map it to a flag, assume it's visible

	// STRICT clothing check - NO EXCEPTIONS
	// Check all possible clothing layers

	// Outer suit coverage
	if(target_mob.wear_suit)
		if(target_mob.wear_suit.body_parts_covered & check_flags)
			return TRUE
		// Check if suit has flags that might cover the area
		if(target_mob.wear_suit.flags_inv & HIDEJUMPSUIT)
			if(check_flags & (CHEST|GROIN|ARMS|LEGS))
				return TRUE

	// Uniform coverage
	if(target_mob.w_uniform)
		if(target_mob.w_uniform.body_parts_covered & check_flags)
			return TRUE

	// Special cases for specific clothing types
	if(istype(target_mob.wear_suit, /obj/item/clothing/suit/toggle/labcoat/hospitalgown))
		return TRUE

	// Additional clothing layers (SPLURT EDIT compatibility)
	if(target_mob.w_shirt && !target_mob.undershirt_hidden())
		if(target_mob.w_shirt.body_parts_covered & check_flags)
			return TRUE

	if(target_mob.w_underwear && !target_mob.underwear_hidden())
		if(target_mob.w_underwear.body_parts_covered & check_flags)
			return TRUE

	// Gloves for hands
	if((check_flags & (HAND_LEFT|HAND_RIGHT)) && target_mob.gloves)
		return TRUE

	// Shoes for feet
	if((check_flags & (FOOT_LEFT|FOOT_RIGHT)) && target_mob.shoes)
		return TRUE

	// Headwear for head
	if((check_flags & HEAD) && target_mob.head)
		return TRUE

	return FALSE

/proc/body_zone_to_flag(body_zone)
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
