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
	var/flair = null // Added: stores selected flair type

	// Constructor - MINIMAL sanitization only for security, not formatting
	New(artist_in, design_in, body_part_in, color_in, layer_in = CUSTOM_TATTOO_LAYER_NORMAL, is_signature_in = FALSE, font_in = PEN_FONT, flair_in = null)
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
		flair = (flair_in in GLOB.custom_tattoo_flairs) ? flair_in : null // Security: valid flair only

	// Returns text-based examine string with emojis and safe span support
	proc/get_examine_text(viewer, victim)
		if(!is_custom_tattoo_visible(viewer, victim))
			return ""

		var/display_design = design
		var/display_artist = artist

		// Apply text emoji parsing
		display_design = parse_text_emojis(display_design)

		// Apply flair formatting with safe spans
		if(flair && GLOB.custom_tattoo_flairs[flair])
			var/flair_type = GLOB.custom_tattoo_flairs[flair]
			display_design = apply_safe_span(display_design, flair_type)

		var/body_part_description = get_custom_tattoo_body_part_description(body_part)
		var/text = "- [body_part_description]: \"[display_design]\" (by [display_artist])"
		return text

	// Convenience wrapper for TGUI preview (same as examine text now)
	proc/get_examine_text_tgui(viewer, victim)
		return get_examine_text(viewer, victim)

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
		flair = null
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
		if(ORGAN_SLOT_BUTT) return "butt"
		if(ORGAN_SLOT_BELLY) return "belly"
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
		if("butt") return ORGAN_SLOT_BUTT
		if("belly") return ORGAN_SLOT_BELLY
		else return string_to_zone(body_part_string)

// Parse text emojis (replace :emoji: with actual unicode characters)
/proc/parse_text_emojis(text)
	if(!text || !istext(text))
		return text

	var/processed = text
	for(var/emoji_code in GLOB.text_emoji_mappings)
		var/emoji_char = GLOB.text_emoji_mappings[emoji_code]
		processed = replacetext(processed, emoji_code, emoji_char)

	return processed

// Apply safe span formatting - only allows pre-approved span classes
/proc/apply_safe_span(text, span_class)
	if(!text || !span_class)
		return text

	// Only allow span classes from our safe list
	if(!(span_class in GLOB.safe_span_classes))
		return text

	// Use the existing sanitize_text proc from the helpers file
	var/sanitized_text = sanitize_text(text)

	// Apply the safe span
	return "<span class='[span_class]'>[sanitized_text]</span>"

// Simple HTML stripping that preserves emoji shortcodes
/proc/strip_html_proper(text)
	if(!text) return text

	var/processed = text
	// Basic HTML tag removal - handle common patterns without regex
	processed = replacetext(processed, "<span class='pink'>", "")
	processed = replacetext(processed, "<span class='userlove'>", "")
	processed = replacetext(processed, "<span class='brown'>", "")
	processed = replacetext(processed, "<span class='cyan'>", "")
	processed = replacetext(processed, "<span class='orange'>", "")
	processed = replacetext(processed, "<span class='yellow'>", "")
	processed = replacetext(processed, "<span class='subtle'>", "")
	processed = replacetext(processed, "<span class='velvet'>", "")
	processed = replacetext(processed, "<span class='velvet_notice'>", "")
	processed = replacetext(processed, "<span class='glossy'>", "")
	processed = replacetext(processed, "</span>", "")
	processed = replacetext(processed, "<font", "")
	processed = replacetext(processed, "</font>", "")

	// Remove any remaining angle brackets
	processed = replacetext(processed, "<", "")
	processed = replacetext(processed, ">", "")

	return trim(processed)
