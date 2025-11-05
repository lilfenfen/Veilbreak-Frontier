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

	var/text = "<span style='color:[color]'>- [body_part_description]: \"[display_design]\" (by [display_artist])</span>"
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
	if(!target_mob || !istype(target_mob))
		return TRUE

	// Use the existing surgery system's clothing check - THE CORRECT WAY
	return !get_location_accessible(target_mob, body_part)

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
/proc/get_standardized_body_part(body_part_string)
	var/lower_part = lowertext(body_part_string)

	switch(lower_part)
		if("butt", "backside", "ass", "rear")
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
