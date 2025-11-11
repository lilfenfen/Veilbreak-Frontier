// modular_zzveilbreak/code/modules/tattoo/tattoo_persistence.dm
// Save/load custom tattoos to the preferences system (character-level storage).

/datum/preferences/proc/save_custom_tattoo_data()
	if(!parent?.mob)
		return

	var/mob/living/carbon/human/H = parent.mob
	if(!istype(H) || QDELETED(H))
		return

	var/list/tattoo_data = list()
	for(var/datum/custom_tattoo/T as anything in H.custom_body_tattoos)
		if(istype(T) && !QDELETED(T))
			tattoo_data += list(list(
				"artist" = T.artist,
				"design" = T.design,
				"body_part" = T.body_part,
				"color" = T.color,
				"date_applied" = T.date_applied,
				"layer" = T.layer,
				"is_signature" = T.is_signature,
				"font" = T.font,
				"flair" = T.flair // NEW: Save flair
			))

	// Store in features which gets saved automatically with preferences
	features["custom_tattoos"] = tattoo_data

/datum/preferences/proc/load_custom_tattoo_data()
	if(!features)
		features = list()

	var/list/tattoo_data = features["custom_tattoos"]
	if(!islist(tattoo_data))
		return

	var/list/loaded_tattoos = list()
	for(var/i in 1 to length(tattoo_data))
		var/list/tattoo_info = tattoo_data[i]
		if(!islist(tattoo_info))
			continue

		var/artist = tattoo_info["artist"]
		var/design = tattoo_info["design"]
		var/body_part = tattoo_info["body_part"]
		var/color = tattoo_info["color"]
		var/layer = tattoo_info["layer"]
		var/date_applied = tattoo_info["date_applied"]
		var/is_signature = tattoo_info["is_signature"]
		var/font = tattoo_info["font"]
		var/flair = tattoo_info["flair"] // NEW: Load flair

		if(!body_part)
			continue

		if(!is_custom_tattoo_bodypart_valid(body_part))
			continue

		var/final_artist = artist ? sanitize_text(artist) : "Unknown Artist"
		var/final_design = design ? sanitize_text(design) : "An intricate design"
		var/final_color = sanitize_hexcolor(color, default = "#000000")
		var/final_layer = sanitize_integer(layer, CUSTOM_TATTOO_LAYER_UNDER, CUSTOM_TATTOO_LAYER_OVER, CUSTOM_TATTOO_LAYER_NORMAL)
		var/final_is_signature = is_signature ? TRUE : FALSE
		var/final_font = (font && (font in GLOB.custom_tattoo_fonts)) ? font : PEN_FONT
		var/final_flair = (flair && (flair in GLOB.custom_tattoo_flairs)) ? flair : null // NEW: Validate flair

		var/datum/custom_tattoo/T = new(final_artist, final_design, body_part, final_color, final_layer, final_is_signature, final_font, final_flair)
		if(date_applied)
			T.date_applied = sanitize_text(date_applied)

		loaded_tattoos += T

	// Store the actual tattoo objects for runtime use
	features["custom_tattoos_loaded"] = loaded_tattoos

/datum/preferences/proc/apply_custom_tattoos_to_mob(mob/living/carbon/human/H)
	if(!istype(H))
		return

	H.custom_body_tattoos.Cut()

	// Use the loaded tattoo objects if available, otherwise load from data
	var/list/saved_tattoos = features["custom_tattoos_loaded"]
	if(!islist(saved_tattoos) || !length(saved_tattoos))
		load_custom_tattoo_data()
		saved_tattoos = features["custom_tattoos_loaded"]

	if(!islist(saved_tattoos))
		return

	for(var/datum/custom_tattoo/T as anything in saved_tattoos)
		if(istype(T) && !QDELETED(T))
			// Create a fresh copy to avoid reference issues
			var/datum/custom_tattoo/new_tattoo = new(T.artist, T.design, T.body_part, T.color, T.layer, T.is_signature, T.font, T.flair)
			if(T.date_applied)
				new_tattoo.date_applied = T.date_applied
			H.add_custom_tattoo(new_tattoo)

	H.regenerate_icons()
