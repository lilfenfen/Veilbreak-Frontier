/datum/custom_tattoo
	var/artist = "Unknown Artist"
	var/design = ""
	var/body_part = BODY_ZONE_CHEST
	var/color = "#000000"
	var/date_applied = ""
	var/layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/is_signature = FALSE
	var/font = PEN_FONT

/datum/custom_tattoo/New(artist, design, body_part, color, layer = CUSTOM_TATTOO_LAYER_NORMAL, is_signature = FALSE, font = PEN_FONT)
	src.artist = artist || "Unknown Artist"
	src.design = process_tattoo_design(design || "An intricate design", artist, is_signature)
	src.body_part = body_part || BODY_ZONE_CHEST
	src.color = sanitize_hexcolor(color, default = "#000000")
	src.layer = sanitize_integer(layer, CUSTOM_TATTOO_LAYER_UNDER, CUSTOM_TATTOO_LAYER_OVER, CUSTOM_TATTOO_LAYER_NORMAL)
	src.date_applied = time2text(world.realtime, "YYYY-MM-DD")
	src.is_signature = is_signature
	src.font = (font in GLOB.custom_tattoo_fonts) ? font : PEN_FONT

/datum/custom_tattoo/proc/get_examine_text(mob/viewer, mob/living/carbon/human/victim, use_emoji_images = FALSE)
	if(!is_custom_tattoo_visible(viewer, victim))
		return ""

	var/display_design = design
	var/display_artist = artist

	if(!display_design || trimtext(display_design) == "")
		display_design = "an intricate design"

	if(!display_artist || trimtext(display_artist) == "")
		display_artist = "an unknown artist"

	// Handle %s signature replacement in examine text
	if(findtext(display_design, "%s"))
		display_design = replacetext(display_design, "%s", display_artist)

	// Apply emoji parsing based on context
	if(use_emoji_images && CONFIG_GET(flag/emojis))
		display_design = emoji_parse(display_design)
	else
		// For non-TGUI contexts, use text-only emoji replacement
		display_design = replace_emoji_codes_text(display_design)

	// Apply font to design if not default - only in TGUI context
	if(use_emoji_images && font && font != PEN_FONT)
		display_design = "<font face='[font]'>[display_design]</font>"

	// Use fountain pen font for signatures in TGUI context
	if(use_emoji_images && is_signature)
		display_artist = "<font face='[FOUNTAIN_PEN_FONT]'>[display_artist]</font>"

	var/body_part_description = get_custom_tattoo_body_part_description(body_part)

	var/text = "<span style='color:[color]'>- [body_part_description]: \"[display_design]\" (by [display_artist])</span>"
	return text

/datum/custom_tattoo/proc/get_examine_text_tgui(mob/viewer, mob/living/carbon/human/victim)
	return get_examine_text(viewer, victim, TRUE)

/datum/custom_tattoo/proc/is_custom_tattoo_visible(mob/viewer, mob/living/carbon/human/victim)
	if(!victim || !viewer)
		return FALSE

	if(get_dist(viewer, victim) > 3)
		return FALSE

	if(!ishuman(victim) || isobserver(viewer))
		return TRUE

	if(victim == viewer)
		return get_custom_tattoo_location_accessible(victim, body_part)

	return get_custom_tattoo_location_accessible(victim, body_part)

/datum/custom_tattoo/Destroy()
	artist = null
	design = null
	body_part = null
	color = null
	date_applied = null
	return ..()

/proc/get_custom_tattoo_body_part_description(body_zone)
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

/proc/get_custom_tattoo_standardized_body_part(body_part_string)
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

// Process tattoo design with emoji and signature support
/proc/process_tattoo_design(design, artist, is_signature)
	if(!design || !istext(design))
		return "An intricate design"

	var/processed_design = design

	// Handle %s signature replacement
	if(findtext(processed_design, "%s"))
		processed_design = replacetext(processed_design, "%s", artist || "Unknown Artist")

	return processed_design

// Replace emoji codes with text descriptions for non-TGUI contexts
/proc/replace_emoji_codes_text(text)
	if(!text)
		return text

	var/processed_text = text

	// Basic emoji code to text mapping for examine contexts
	var/static/list/emoji_to_text = list(
		":heart:" = "♥",
		":smile:" = "☺",
		":sad:" = "☹",
		":star:" = "★",
		":skull:" = "☠",
		":fire:" = "🔥",
		":peace:" = "☮",
		":radioactive:" = "☢",
		":biohazard:" = "☣",
		":yin_yang:" = "☯",
		":note:" = "♪",
		":sun:" = "☀",
		":cloud:" = "☁",
		":umbrella:" = "☂",
		":snowman:" = "☃",
		":phone:" = "☎",
		":envelope:" = "✉",
		":pencil:" = "✏",
		":check:" = "✓",
		":x:" = "✗",
		":warning:" = "⚠",
		":arrow_up:" = "↑",
		":arrow_down:" = "↓",
		":arrow_left:" = "←",
		":arrow_right:" = "→"
	)

	for(var/emoji_code in emoji_to_text)
		var/emoji_char = emoji_to_text[emoji_code]
		processed_text = replacetext(processed_text, emoji_code, emoji_char)

	return processed_text
