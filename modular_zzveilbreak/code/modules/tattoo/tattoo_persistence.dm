/datum/preferences/proc/save_tattoo_data(list/save_data)
	if(!parent?.mob)
		return

	var/mob/living/carbon/human/H = parent.mob
	if(!istype(H) || QDELETED(H))
		return

	var/list/tattoo_data = list()
	for(var/datum/tattoo/T as anything in H.body_tattoos)
		if(istype(T) && !QDELETED(T))
			var/body_part_description = get_specific_body_part_description(T.body_part)

			tattoo_data += list(list(
				"artist" = T.artist,
				"design" = T.design,
				"body_part" = body_part_description,
				"color" = T.color,
				"date_applied" = T.date_applied,
				"layer" = T.layer,
				"is_signature" = T.is_signature,
				"font" = T.font
			))

	save_data["tattoos_data"] = tattoo_data
	features["tattoos_data"] = tattoo_data
	features["tattoos"] = H.body_tattoos.Copy()

/datum/preferences/proc/load_tattoo_data(list/save_data)
	if(!features)
		features = list()

	features["tattoos"] = list()
	features["tattoos_data"] = list()

	var/list/tattoo_data = save_data?["tattoos_data"]

	if(!islist(tattoo_data))
		return

	var/list/loaded_tattoos = list()

	for(var/i in 1 to length(tattoo_data))
		var/list/tattoo_info = tattoo_data[i]

		if(!islist(tattoo_info))
			continue

		var/artist = tattoo_info["artist"]
		var/design = tattoo_info["design"]
		var/body_part_string = tattoo_info["body_part"]
		var/color = tattoo_info["color"]
		var/layer = tattoo_info["layer"]
		var/date_applied = tattoo_info["date_applied"]
		var/is_signature = tattoo_info["is_signature"]
		var/font = tattoo_info["font"]

		if(!body_part_string)
			continue

		var/body_part_define = get_standardized_body_part(body_part_string)

		if(!body_part_define)
			continue

		if(!is_valid_tattoo_bodypart(body_part_define))
			continue

		var/final_artist = artist ? sanitize_text(artist) : "Unknown Artist"
		var/final_design = design ? sanitize_text(design) : "An intricate design"
		var/final_color = sanitize_hexcolor(color, default = "#000000")
		var/final_layer = sanitize_integer(layer, TATTOO_LAYER_UNDER, TATTOO_LAYER_OVER, TATTOO_LAYER_NORMAL)
		var/final_is_signature = is_signature ? TRUE : FALSE
		var/final_font = (font && (font in GLOB.tattoo_fonts)) ? font : PEN_FONT

		var/datum/tattoo/T = new(
			final_artist,
			final_design,
			body_part_define,
			final_color,
			final_layer,
			final_is_signature,
			final_font
		)

		if(date_applied)
			T.date_applied = sanitize_text(date_applied)

		loaded_tattoos += T

	features["tattoos"] = loaded_tattoos
	features["tattoos_data"] = tattoo_data

/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/H)
	if(!istype(H) || !features["tattoos"])
		return

	// Clear any existing tattoos
	H.body_tattoos.Cut()

	// Apply tattoos from preferences
	var/list/saved_tattoos = features["tattoos"]
	if(!islist(saved_tattoos))
		return

	for(var/datum/tattoo/T as anything in saved_tattoos)
		if(istype(T) && !QDELETED(T))
			H.add_tattoo(T)

	// Update the mob's appearance
	H.regenerate_icons()
