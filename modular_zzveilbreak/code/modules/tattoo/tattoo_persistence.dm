// Tattoo Persistence System
// Handles saving and loading tattoos between rounds

/// Saves tattoo data to preferences - called from various places
/datum/preferences/proc/save_tattoo_data()
	world.log << "=== TATTOO SAVE START ==="

	if(!features)
		features = list()
		world.log << "DEBUG: Created new features list"

	// Get tattoos from current mob if available
	var/list/tattoos_to_save = list()
	var/mob/living/carbon/human/H = parent?.mob

	if(H?.body_tattoos)
		tattoos_to_save = H.body_tattoos.Copy()
		world.log << "DEBUG: Got [length(tattoos_to_save)] tattoos from mob"
	else
		world.log << "DEBUG: No mob tattoos found"

	// Convert to saveable format
	var/list/tattoo_data = list()
	for(var/datum/tattoo/T as anything in tattoos_to_save)
		if(istype(T) && !QDELETED(T))
			var/body_part_description = get_specific_body_part_description(T.body_part)
			world.log << "DEBUG: Converting tattoo: [T.design] on [T.body_part] -> [body_part_description]"

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

	world.log << "DEBUG: Saved [length(tattoo_data)] tattoos to features"

	// Save to file
	save_character()
	world.log << "=== TATTOO SAVE COMPLETE ==="

/// Loads tattoo data from preferences - called during character setup
/datum/preferences/proc/load_tattoo_data()
	world.log << "=== TATTOO LOAD START ==="

	if(!features)
		features = list()
		world.log << "DEBUG: Created new features list"

	// Check if we have tattoo data in features
	var/has_tattoo_data = features && features["tattoos_data"]

	world.log << "DEBUG: Has tattoo data in features: [has_tattoo_data]"

	if(!has_tattoo_data)
		world.log << "DEBUG: No tattoo data found in features"
		features["tattoos"] = list()
		features["tattoos_data"] = list()
		world.log << "=== TATTOO LOAD COMPLETE (EMPTY) ==="
		return

	var/list/tattoo_data = features["tattoos_data"]

	if(!islist(tattoo_data))
		world.log << "DEBUG: Tattoo data is not a list, initializing empty"
		features["tattoos"] = list()
		features["tattoos_data"] = list()
		world.log << "=== TATTOO LOAD COMPLETE (EMPTY) ==="
		return

	world.log << "DEBUG: Found [length(tattoo_data)] tattoo entries in save data"

	// Convert loaded data back to tattoo datums
	var/list/loaded_tattoos = list()
	var/successful_loads = 0

	for(var/i in 1 to length(tattoo_data))
		var/list/tattoo_info = tattoo_data[i]

		if(!islist(tattoo_info))
			world.log << "DEBUG: Skipping non-list entry [i]"
			continue

		var/artist = tattoo_info["artist"]
		var/design = tattoo_info["design"]
		var/body_part_string = tattoo_info["body_part"]
		var/color = tattoo_info["color"]
		var/layer = tattoo_info["layer"]
		var/date_applied = tattoo_info["date_applied"]

		world.log << "DEBUG: Processing entry [i]: [design] on [body_part_string]"

		if(!body_part_string)
			world.log << "DEBUG: No body part, skipping entry [i]"
			continue

		// Convert body part string back to define
		var/body_part_define = get_standardized_body_part(body_part_string)
		world.log << "DEBUG: Body part conversion: [body_part_string] -> [body_part_define]"

		if(!body_part_define)
			world.log << "DEBUG: Failed to convert body part, skipping"
			continue

		if(!is_valid_tattoo_bodypart(body_part_define))
			world.log << "DEBUG: Invalid body part for tattoos, skipping"
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
		successful_loads++
		world.log << "DEBUG: Successfully loaded tattoo: [T.design] on [T.body_part]"

	// Store in features
	features["tattoos"] = loaded_tattoos
	world.log << "DEBUG: Successfully loaded [successful_loads] out of [length(tattoo_data)] tattoos"
	world.log << "=== TATTOO LOAD COMPLETE ==="

/// Applies saved tattoos to a mob - called when mob is created
/// Applies saved tattoos to a mob - called when mob is created
/// Applies saved tattoos to a mob - called when mob is created
/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/character)
	world.log << "=== TATTOO APPLY START ==="

	if(!istype(character))
		world.log << "DEBUG: Not a human mob, skipping"
		return

	world.log << "DEBUG: Applying tattoos to [character] ([character.ckey])"

	if(!features)
		world.log << "DEBUG: No features, loading data"
		load_tattoo_data()

	// Ensure we have tattoo data loaded
	if(!features["tattoos"])
		world.log << "DEBUG: No tattoos in features, loading data"
		load_tattoo_data()

	var/list/tattoos_to_apply = features["tattoos"]

	if(!tattoos_to_apply || !islist(tattoos_to_apply))
		world.log << "DEBUG: No tattoos to apply, setting empty list"
		character.body_tattoos = list()
		world.log << "=== TATTOO APPLY COMPLETE (EMPTY) ==="
		return

	world.log << "DEBUG: Applying [length(tattoos_to_apply)] tattoos to mob"

	// Apply tattoos to mob
	character.body_tattoos = tattoos_to_apply.Copy()

	// Verify application - check each tattoo individually
	world.log << "DEBUG: Mob now has [length(character.body_tattoos)] tattoos"
	for(var/datum/tattoo/T as anything in character.body_tattoos)
		world.log << "DEBUG: Applied tattoo: '[T.design]' on [T.body_part]"
		world.log << "DEBUG: Tattoo details - Artist: [T.artist], Color: [T.color], Layer: [T.layer]"

		// Test the body part
		var/body_part_define = T.body_part
		world.log << "DEBUG: Body part define: [body_part_define]"
		world.log << "DEBUG: Is valid tattoo bodypart: [is_valid_tattoo_bodypart(body_part_define)]"

		// Test if body part exists on mob
		var/body_part_exists = body_part_exists(character, body_part_define)
		world.log << "DEBUG: Body part exists on mob: [body_part_exists]"

		// Test visibility immediately
		var/visible = T.is_visible(character, character)
		world.log << "DEBUG: Immediate visibility check: [visible]"

	character.regenerate_icons()
	world.log << "DEBUG: Character icons regenerated"
	world.log << "=== TATTOO APPLY COMPLETE ==="

// =====================
// PREFERENCE SYSTEM INTEGRATION
// =====================

/// Called when preferences are loaded
/datum/preferences/proc/load_tattoos()
	world.log << "=== PREFERENCE LOAD TATTOOS ==="
	load_tattoo_data()

/// Called when preferences are saved
/datum/preferences/proc/save_tattoos()
	world.log << "=== PREFERENCE SAVE TATTOOS ==="
	save_tattoo_data()

// =====================
// HOOKS - THESE ARE CRITICAL
// =====================

/// Hook when character is set up in preferences
/hook/character_setup/proc/load_character_tattoos(datum/preferences/prefs)
	world.log << "=== CHARACTER SETUP HOOK ==="
	if(istype(prefs))
		world.log << "DEBUG: Loading tattoos for [prefs.parent?.ckey]"
		prefs.load_tattoo_data()
		return TRUE
	world.log << "DEBUG: Invalid prefs in character_setup hook"
	return FALSE

/// Hook when new mob is created
/hook/mob_new/proc/apply_saved_tattoos(mob/living/carbon/human/H)
	world.log << "=== MOB NEW HOOK ==="
	if(istype(H) && H.client?.prefs)
		world.log << "DEBUG: Applying tattoos to new mob [H] ([H.ckey])"
		H.client.prefs.apply_tattoos_to_mob(H)
		return TRUE
	world.log << "DEBUG: No client/prefs or not human, skipping tattoo application"
	return FALSE

// =====================
// COMPATIBILITY WRAPPERS
// =====================

// Legacy support for different call patterns
/datum/preferences/proc/save_tattoos_data()
	save_tattoo_data()

/datum/preferences/proc/load_tattoos_data()
	load_tattoo_data()

/datum/preferences/proc/save_tattoos_modular()
	save_tattoo_data()

/datum/preferences/proc/load_tattoos_modular()
	load_tattoo_data()

/// Debug function to check tattoo status
/datum/preferences/proc/debug_tattoo_status()
	world.log << "=== TATTOO STATUS DEBUG ==="
	world.log << "DEBUG: Features exists: [!!features]"
	if(features)
		world.log << "DEBUG: Features keys: [json_encode(features)]"
		world.log << "DEBUG: Has tattoos key: [!!features["tattoos"]]"
		world.log << "DEBUG: Has tattoos_data key: [!!features["tattoos_data"]]"

		if(features["tattoos"])
			world.log << "DEBUG: Tattoos count: [length(features["tattoos"])]"

		if(features["tattoos_data"])
			world.log << "DEBUG: Tattoos data count: [length(features["tattoos_data"])]"
