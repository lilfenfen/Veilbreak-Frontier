/datum/tattoo
	var/artist = "Unknown Artist"
	var/design = ""
	var/body_part = BODY_ZONE_CHEST
	var/color = "#000000"
	var/date_applied = ""
	var/layer = TATTOO_LAYER_NORMAL
	var/is_signature = FALSE  // Whether this tattoo uses a signature as the artist name
	var/font = PEN_FONT       // Font used for the tattoo design

/datum/tattoo/New(artist, design, body_part, color, layer = TATTOO_LAYER_NORMAL, is_signature = FALSE, font = PEN_FONT)
	src.artist = artist || "Unknown Artist"
	src.design = design || "An intricate design"
	src.body_part = body_part || BODY_ZONE_CHEST
	src.color = sanitize_hexcolor(color, default = "#000000")
	src.layer = sanitize_integer(layer, TATTOO_LAYER_UNDER, TATTOO_LAYER_OVER, TATTOO_LAYER_NORMAL)
	src.date_applied = time2text(world.realtime, "YYYY-MM-DD")
	src.is_signature = is_signature
	src.font = (font in GLOB.tattoo_fonts) ? font : PEN_FONT

/datum/tattoo/proc/get_examine_text(mob/viewer, mob/living/carbon/human/victim)
	if(!is_visible(viewer, victim))
		return ""

	var/display_design = design
	var/display_artist = artist

	if(!display_design || trimtext(display_design) == "")
		display_design = "an intricate design"

	if(!display_artist || trimtext(display_artist) == "")
		display_artist = "an unknown artist"

	// Apply font to design if not default
	if(font && font != PEN_FONT)
		display_design = "<font face='[font]'>[display_design]</font>"

	// Use fountain pen font for signatures, just like the paper system
	if(is_signature)
		display_artist = "<font face='[FOUNTAIN_PEN_FONT]'>[display_artist]</font>"

	var/body_part_description = get_specific_body_part_description(body_part)

	var/text = "<span style='color:[color]'>- [body_part_description]: \"[display_design]\" (by [display_artist])</span>"
	return text

/datum/tattoo/proc/is_visible(mob/viewer, mob/living/carbon/human/victim)
	if(!victim || !viewer)
		return FALSE

	if(get_dist(viewer, victim) > 3)
		return FALSE

	if(!ishuman(victim) || isobserver(viewer))
		return TRUE

	if(victim == viewer)
		return get_tattoo_location_accessible(victim, body_part)

	return get_tattoo_location_accessible(victim, body_part)

/datum/tattoo/Destroy()
	artist = null
	design = null
	body_part = null
	color = null
	date_applied = null
	return ..()

/proc/get_specific_body_part_description(body_zone)
	if(!body_zone)
		return "unknown location"

	// Handle organ slots first
	switch(body_zone)
		if(ORGAN_SLOT_PENIS)
			return "penis"
		if(ORGAN_SLOT_WOMB)
			return "womb"
		if(ORGAN_SLOT_VAGINA)
			return "vagina"
		if(ORGAN_SLOT_TESTICLES)
			return "testicles"
		if(ORGAN_SLOT_BREASTS)
			return "breasts"
		if(ORGAN_SLOT_ANUS)
			return "anus"
		if(ORGAN_SLOT_NIPPLES)
			return "nipples"
		if(ORGAN_SLOT_TAIL)
			return "tail"
		if(ORGAN_SLOT_SLIT)
			return "slit"
		if(ORGAN_SLOT_SHEATH)
			return "sheath"
		if(ORGAN_SLOT_WINGS)
			return "wings"

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
			var/formatted_name = replacetext(replacetext("[body_zone]", "BODY_ZONE_", ""), "_", " ")
			formatted_name = lowertext(formatted_name)
			formatted_name = capitalize(formatted_name)
			return formatted_name

/proc/get_standardized_body_part(body_part_string)
	if(!body_part_string)
		return BODY_ZONE_CHEST

	var/lower_part = lowertext(body_part_string)

	switch(lower_part)
		if("penis")
			return ORGAN_SLOT_PENIS
		if("womb")
			return ORGAN_SLOT_WOMB
		if("vagina")
			return ORGAN_SLOT_VAGINA
		if("testicles", "balls")
			return ORGAN_SLOT_TESTICLES
		if("breasts", "boobs", "tits")
			return ORGAN_SLOT_BREASTS
		if("anus", "asshole")
			return ORGAN_SLOT_ANUS
		if("nipples")
			return ORGAN_SLOT_NIPPLES
		if("tail")
			return ORGAN_SLOT_TAIL
		if("slit")
			return ORGAN_SLOT_SLIT
		if("sheath")
			return ORGAN_SLOT_SHEATH
		if("wings")
			return ORGAN_SLOT_WINGS
		else
			return body_part_string
