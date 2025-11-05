// Tattoo Persistence System

/// Saves tattoo data to preferences
/datum/preferences/proc/save_tattoo_data()
	if(!parent?.mob)
		return

	var/mob/living/carbon/human/H = parent.mob
	if(!istype(H) || !H.body_tattoos)
		return

	// Convert to saveable format
	var/list/tattoo_data = list()
	for(var/datum/tattoo/T as anything in H.body_tattoos)
		if(istype(T) && !QDELETED(T))
			tattoo_data += list(list(
				"artist" = T.artist,
				"design" = T.design,
				"body_part" = T.body_part,
				"color" = T.color,
				"date_applied" = T.date_applied,
				"layer" = T.layer
			))

	// Store in character data
	write_preference(GLOB.preference_entries[/datum/preference/text_list/tattoos], tattoo_data)

	// Debug message
	if(parent)
		to_chat(parent, span_notice("Tattoo data saved: [length(tattoo_data)] tattoos"))

/// Loads tattoo data from preferences
/datum/preferences/proc/load_tattoo_data()
	if(!parent?.mob)
		return list()

	var/list/tattoo_data = read_preference(/datum/preference/text_list/tattoos)
	if(!tattoo_data || !islist(tattoo_data))
		return list()

	return tattoo_data

/// Apply saved tattoos to a mob
/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/character)
	if(!istype(character))
		return

	// Clear existing tattoos
	character.body_tattoos = list()

	var/list/tattoo_data = load_tattoo_data()
	if(!length(tattoo_data))
		return

	// Convert loaded data back to tattoo datums
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

		if(!body_part || !is_valid_tattoo_bodypart(body_part))
			continue

		// Set defaults for missing values
		if(!artist || artist == "") artist = "Unknown Artist"
		if(!design || design == "") design = "An intricate design"
		if(!color || color == "") color = "#000000"
		if(!layer) layer = 2
		if(!date_applied || date_applied == "") date_applied = time2text(world.realtime, "YYYY-MM-DD")

		// Create the tattoo datum
		var/datum/tattoo/T = new(
			sanitize_text(artist),
			sanitize_text(design),
			body_part,
			sanitize_hexcolor(color, 6, TRUE, "#000000"),
			sanitize_integer(layer, 1, 3, 2)
		)
		T.date_applied = sanitize_text(date_applied)

		character.body_tattoos += T

	// Debug message
	to_chat(character, span_notice("Loaded [length(character.body_tattoos)] tattoos"))
	character.regenerate_icons()
