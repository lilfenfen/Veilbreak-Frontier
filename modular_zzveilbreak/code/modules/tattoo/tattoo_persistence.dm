// Tattoo Persistence System
// Handles saving and loading tattoos between rounds

/// Saves tattoo data to preferences - called from various places
/datum/preferences/proc/save_tattoo_data()
	if(!features)
		features = list()

	// Get tattoos from current mob if available
	var/list/tattoos_to_save = list()
	var/mob/living/carbon/human/H = parent?.mob

	if(H?.body_tattoos)
		tattoos_to_save = H.body_tattoos.Copy()

	// Convert to saveable format
	var/list/tattoo_data = list()
	for(var/datum/tattoo/T as anything in tattoos_to_save)
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

	// Store in features
	features["tattoos_data"] = tattoo_data
	features["tattoos"] = tattoos_to_save

	// Save to file
	save_character()

/// Loads tattoo data from preferences - called during character setup
/datum/preferences/proc/load_tattoo_data()
	if(!features)
		features = list()

	// Check if we have tattoo data in features
	var/has_tattoo_data = features && features["tattoos_data"]

	if(!has_tattoo_data)
		features["tattoos"] = list()
		features["tattoos_data"] = list()
		return

	var/list/tattoo_data = features["tattoos_data"]

	if(!islist(tattoo_data))
		features["tattoos"] = list()
		features["tattoos_data"] = list()
		return

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

		// Set defaults for missing values
		if(!artist) artist = "Unknown Artist"
		if(!design) design = "An intricate design"
		if(!color) color = "#000000"
		if(!layer) layer = 2
		if(!date_applied) date_applied = time2text(world.realtime, "YYYY-MM-DD")

		// Create the tattoo datum
		var/datum/tattoo/T = new(
			sanitize_text(artist),
			sanitize_text(design),
			body_part_define,
			sanitize_hexcolor(color, 6, TRUE, "#000000"),
			sanitize_integer(layer, 1, 3, 2)
		)
		T.date_applied = sanitize_text(date_applied)

		loaded_tattoos += T

	// Store in features
	features["tattoos"] = loaded_tattoos

/// Applies saved tattoos to a mob - called when mob is created
/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/character)
	if(!istype(character))
		return

	if(!features)
		load_tattoo_data()

	// Ensure we have tattoo data loaded
	if(!features["tattoos"])
		load_tattoo_data()

	var/list/tattoos_to_apply = features["tattoos"]

	if(!tattoos_to_apply || !islist(tattoos_to_apply))
		character.body_tattoos = list()
		return

	// Apply tattoos to mob
	character.body_tattoos = tattoos_to_apply.Copy()
	character.regenerate_icons()

// =====================
// PREFERENCE SYSTEM INTEGRATION
// =====================

/// Called when preferences are loaded
/datum/preferences/proc/load_tattoos()
	load_tattoo_data()

/// Called when preferences are saved
/datum/preferences/proc/save_tattoos()
	save_tattoo_data()

// =====================
// HOOKS - THESE ARE CRITICAL
// =====================

/// Hook when character is set up in preferences
/hook/character_setup/proc/load_character_tattoos(datum/preferences/prefs)
	if(istype(prefs))
		prefs.load_tattoo_data()
		return TRUE
	return FALSE

/// Hook when new mob is created
/hook/mob_new/proc/apply_saved_tattoos(mob/living/carbon/human/H)
	if(istype(H) && H.client?.prefs)
		H.client.prefs.apply_tattoos_to_mob(H)
		return TRUE
	return FALSE
