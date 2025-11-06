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
    // Store the raw values first - we'll handle defaults only when truly needed
    src.artist = artist
    src.design = design
    src.body_part = body_part
    src.color = sanitize_hexcolor(color, default = "#000000")
    src.layer = sanitize_integer(layer, 1, 3, 2)
    src.date_applied = time2text(world.realtime, "YYYY-MM-DD")

    // DEBUG: Log the tattoo creation with actual values
    world.log << "DEBUG: Tattoo datum created - Artist: [src.artist], Design: [src.design], Body Part: [src.body_part]"

/datum/tattoo/proc/get_examine_text(mob/viewer, mob/living/carbon/human/victim)
	if(!is_visible(viewer, victim))
		return ""

	// Use the actual stored values - apply defaults only at display time if truly empty
	var/display_design = design
	var/display_artist = artist

	// Only use defaults if the stored values are truly empty after checking
	if(!display_design || trimtext(display_design) == "")
		display_design = "an intricate design"

	if(!display_artist || trimtext(display_artist) == "")
		display_artist = "an unknown artist"

	// Use the enhanced body part descriptions
	var/body_part_description = get_specific_body_part_description(body_part)

	var/text = "<span style='color:[color]'>- [body_part_description]: \"[display_design]\" (by [display_artist])</span>"
	return text

/datum/tattoo/proc/is_visible(mob/viewer, mob/living/carbon/human/victim)
    if(!victim || !viewer)
        return FALSE

    // Distance check - use reasonable distance for examination
    if(get_dist(viewer, victim) > 3)
        return FALSE

    // Observers and non-humans can always see
    if(!ishuman(victim) || isobserver(viewer))
        return TRUE

    // Self-examination always shows tattoos on exposed body parts
    if(victim == viewer)
        return get_location_accessible(victim, body_part)

    // For others, use the same accessibility logic as surgery
    return get_location_accessible(victim, body_part)

/// Returns more specific descriptions for body parts
/proc/get_specific_body_part_description(body_zone)
    // Handle string organ slots
    if(body_zone == ORGAN_SLOT_BELLY)
        return "stomach"
    if(body_zone == ORGAN_SLOT_BUTT)
        return "butt" // CHANGED: backside -> butt
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
            // For any custom body zones, format the text nicely
            var/formatted_name = replacetext(replacetext("[body_zone]", "BODY_ZONE_", ""), "_", " ")
            formatted_name = lowertext(formatted_name)
            formatted_name = capitalize(formatted_name)
            return formatted_name

/// Converts body part strings to standardized organ slot defines
/proc/get_standardized_body_part(body_part_string)
    var/lower_part = lowertext(body_part_string)
    world.log << "DEBUG: Converting body part string: [body_part_string] -> [lower_part]"

    switch(lower_part)
        if("butt")
            return ORGAN_SLOT_BUTT
        if("stomach", "belly")
            return ORGAN_SLOT_BELLY
        if("tail")
            return ORGAN_SLOT_EXTERNAL_TAIL
        if("spines", "spine ridge")
            return ORGAN_SLOT_EXTERNAL_SPINES
        if("frills", "head frills")
            return ORGAN_SLOT_EXTERNAL_FRILLS
        if("horns")
            return ORGAN_SLOT_EXTERNAL_HORNS
        if("wings", "wing membranes")
            return ORGAN_SLOT_EXTERNAL_WINGS
        else
            return body_part_string
