// modular_zzveilbreak/code/modules/tattoo/tattoo_datums.dm
// Datum for storing a single tattoo. Provides examine text and visibility helpers.

/datum/custom_tattoo
	var/artist = "Unknown Artist"
	var/design = "An intricate design"
	var/body_part = BODY_ZONE_CHEST
	var/color = "#000000"
	var/date_applied = ""
	var/layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/is_signature = FALSE
	var/font = PEN_FONT

	// Constructor - MINIMAL sanitization only for security, not formatting
	New(artist_in, design_in, body_part_in, color_in, layer_in = CUSTOM_TATTOO_LAYER_NORMAL, is_signature_in = FALSE, font_in = PEN_FONT)
		// Preserve exact input for artist and design
		artist = artist_in || "Unknown Artist"
		design = design_in || "An intricate design"

		// Only sanitize where absolutely necessary for security/functionality
		body_part = body_part_in || BODY_ZONE_CHEST
		color = sanitize_hexcolor(color_in, default = "#000000") // Security: prevent invalid colors
		layer = sanitize_integer(layer_in, CUSTOM_TATTOO_LAYER_UNDER, CUSTOM_TATTOO_LAYER_OVER, CUSTOM_TATTOO_LAYER_NORMAL)
		date_applied = time2text(world.realtime, "YYYY-MM-DD")
		is_signature = is_signature_in
		font = (font_in in GLOB.custom_tattoo_fonts) ? font_in : PEN_FONT // Security: valid font only

	// Returns an HTML-safe examine string for TGUI (uses emoji images if requested)
	proc/get_examine_text(viewer, victim, use_emoji_images = FALSE)
		if(!is_custom_tattoo_visible(viewer, victim))
			return ""

		// Use EXACT stored data - no processing unless requested
		var/display_design = design
		var/display_artist = artist

		// Only apply visual formatting for UI display, never modify content
		if(use_emoji_images && CONFIG_GET(flag/emojis))
			display_design = emoji_parse(display_design)

		if(use_emoji_images && font && font != PEN_FONT)
			display_design = "<font face='[font]'>[display_design]</font>"

		if(use_emoji_images && is_signature)
			display_artist = "<font face='[FOUNTAIN_PEN_FONT]'>[display_artist]</font>"

		var/body_part_description = get_custom_tattoo_body_part_description(body_part)
		var/text = "<span style='color:[color]'>- [body_part_description]: \"[display_design]\" (by [display_artist])</span>"
		return text

	// Convenience wrapper for TGUI preview (forces emoji/image mode)
	proc/get_examine_text_tgui(viewer, victim)
		return get_examine_text(viewer, victim, TRUE)

	// Visibility checks (distance + clothing)
	proc/is_custom_tattoo_visible(viewer, victim)
		if(!victim || !viewer)
			return FALSE
		if(get_dist(viewer, victim) > 3)
			return FALSE
		if(!ishuman(victim) || isobserver(viewer))
			return TRUE
		if(victim == viewer)
			return get_custom_tattoo_location_accessible(victim, body_part)
		return get_custom_tattoo_location_accessible(victim, body_part)

	Destroy()
		artist = null
		design = null
		body_part = null
		color = null
		date_applied = null
		return ..()

// ---------------- Utilities ----------------

// Human-readable body part description
/proc/get_custom_tattoo_body_part_description(body_zone)
	if(!body_zone) return "unknown location"
	// organ-first mapping
	switch(body_zone)
		if(ORGAN_SLOT_PENIS) return "penis"
		if(ORGAN_SLOT_WOMB) return "womb"
		if(ORGAN_SLOT_VAGINA) return "vagina"
		if(ORGAN_SLOT_TESTICLES) return "testicles"
		if(ORGAN_SLOT_BREASTS) return "breasts"
		if(ORGAN_SLOT_ANUS) return "anus"
		if(ORGAN_SLOT_NIPPLES) return "nipples"
		if(ORGAN_SLOT_TAIL) return "tail"
		if(ORGAN_SLOT_SLIT) return "slit"
		if(ORGAN_SLOT_SHEATH) return "sheath"
		if(ORGAN_SLOT_WINGS) return "wings"
	// normal zones
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
	// fallback: pretty-print define
	var/formatted_name = replacetext(replacetext("[body_zone]", "BODY_ZONE_", ""), "_", " ")
	formatted_name = lowertext(formatted_name)
	formatted_name = capitalize(formatted_name)
	return formatted_name

/proc/get_custom_tattoo_standardized_body_part(body_part_string)
	if(!body_part_string) return BODY_ZONE_CHEST
	var/lower_part = lowertext(body_part_string)
	switch(lower_part)
		if("penis") return ORGAN_SLOT_PENIS
		if("womb") return ORGAN_SLOT_WOMB
		if("vagina") return ORGAN_SLOT_VAGINA
		if("testicles", "balls") return ORGAN_SLOT_TESTICLES
		if("breasts", "boobs", "tits") return ORGAN_SLOT_BREASTS
		if("anus", "asshole") return ORGAN_SLOT_ANUS
		if("nipples") return ORGAN_SLOT_NIPPLES
		if("tail") return ORGAN_SLOT_TAIL
		if("slit") return ORGAN_SLOT_SLIT
		if("sheath") return ORGAN_SLOT_SHEATH
		if("wings") return ORGAN_SLOT_WINGS
		else return string_to_zone(body_part_string)

/proc/process_tattoo_design(design, artist, is_signature)
	if(!design || !istext(design)) return "An intricate design"
	var/processed_design = design
	if(findtext(processed_design, "%s"))
		processed_design = replacetext(processed_design, "%s", artist || "Unknown Artist")
	return processed_design

/proc/replace_emoji_codes_text(text)
	if(!text) return text
	var/processed_text = text
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
