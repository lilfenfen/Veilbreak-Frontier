// Tattoo Persistence System
// Handles saving and loading tattoos between rounds

/// Enhanced tattoo data saving with proper savefile integration
/datum/preferences/proc/save_tattoo_data_zzveilbreak(list/save_data)
	if(!parent?.mob)
		return

	var/mob/living/carbon/human/H = parent.mob
	if(!istype(H))
		return

	// Convert to saveable format
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
				"layer" = T.layer
			))

	// Store in the provided save_data list (character slot data)
	save_data["tattoos_data"] = tattoo_data

	// Also store in features for quick access
	features["tattoos_data"] = tattoo_data
	features["tattoos"] = H.body_tattoos.Copy()

	// DEBUG: Log what we're saving
	world.log << "DEBUG: Saving tattoo data: [json_encode(tattoo_data)]"

/// Enhanced tattoo data loading with proper savefile integration
/datum/preferences/proc/load_tattoo_data_zzveilbreak(list/save_data)
	if(!features)
		features = list()

	// Clear existing tattoos
	features["tattoos"] = list()
	features["tattoos_data"] = list()

	// Load from the provided save_data list (character slot data)
	var/list/tattoo_data = save_data?["tattoos_data"]

	if(!islist(tattoo_data))
		world.log << "DEBUG: No tattoo data found or not a list"
		return

	// DEBUG: Log what we're loading
	world.log << "DEBUG: Loading tattoo data: [json_encode(tattoo_data)]"

	// Convert loaded data back to tattoo datums
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

		if(!body_part_string)
			continue

		// Convert body part string back to define
		var/body_part_define = get_standardized_body_part(body_part_string)

		if(!body_part_define)
			continue

		if(!is_valid_tattoo_bodypart(body_part_define))
			continue

		// DEBUG: Log each tattoo being created
		world.log << "DEBUG: Creating tattoo from save - Artist: [artist], Design: [design], Body Part: [body_part_define]"

		// Use proper BYOND sanitization
		var/sanitized_artist = sanitize_text(artist)
		if(sanitized_artist == "")
			sanitized_artist = "Unknown Artist"

		var/sanitized_design = sanitize_text(design)
		if(sanitized_design == "")
			sanitized_design = "An intricate design"

		var/sanitized_color = sanitize_hexcolor(color, default = "#000000")
		var/sanitized_layer = sanitize_integer(layer, 1, 3, 2)

		// Create the tattoo datum with sanitized values
		var/datum/tattoo/T = new(
			sanitized_artist,
			sanitized_design,
			body_part_define,
			sanitized_color,
			sanitized_layer
		)
		T.date_applied = sanitize_text(date_applied)

		loaded_tattoos += T

	// Store in features
	features["tattoos"] = loaded_tattoos
	features["tattoos_data"] = tattoo_data

	world.log << "DEBUG: Loaded [length(loaded_tattoos)] tattoos"

/// Enhanced tattoo application to mob
/datum/preferences/proc/apply_tattoos_to_mob_zzveilbreak(mob/living/carbon/human/character)
	if(!istype(character))
		return

	if(!features)
		// If features isn't loaded, try to load from current character slot
		var/list/current_save_data = savefile?.get_entry("character[default_slot]")
		if(current_save_data)
			load_tattoo_data_zzveilbreak(current_save_data)

	// Ensure we have tattoo data loaded
	if(!features["tattoos"])
		var/list/current_save_data = savefile?.get_entry("character[default_slot]")
		if(current_save_data)
			load_tattoo_data_zzveilbreak(current_save_data)

	var/list/tattoos_to_apply = features["tattoos"]

	if(!tattoos_to_apply || !islist(tattoos_to_apply))
		character.body_tattoos = list()
		return

	// Apply tattoos to mob
	character.body_tattoos = tattoos_to_apply.Copy()
	character.regenerate_icons()

	world.log << "DEBUG: Applied [length(tattoos_to_apply)] tattoos to mob"

// Override the original procs with our enhanced versions
/datum/preferences/proc/save_tattoo_data(list/save_data)
	save_tattoo_data_zzveilbreak(save_data)

/datum/preferences/proc/load_tattoo_data(list/save_data)
	load_tattoo_data_zzveilbreak(save_data)

/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/character)
	apply_tattoos_to_mob_zzveilbreak(character)
