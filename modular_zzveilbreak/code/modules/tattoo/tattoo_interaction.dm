// Tattoo/Bodywriting Preference - Following ERP preference pattern
/datum/preference/toggle/allow_bodywriting
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "allow_bodywriting_pref"  // CHANGED: to match TGUI
	default_value = FALSE

/datum/preference/toggle/allow_bodywriting/apply_to_client(client/client, value)
	return

// Extend the interactable component to include tattoo preferences
/datum/component/interactable
	/// Add tattoo preference to the list
	var/static/list/tattoo_preference_paths = list(
		"allow_bodywriting_pref" = /datum/preference/toggle/allow_bodywriting
	)

/datum/component/interactable/ui_data(mob/living/user)
	. = ..()

	// Add tattoo preferences to the UI data
	if(user.client?.prefs)
		for(var/entry in tattoo_preference_paths)
			var/pref_path = tattoo_preference_paths[entry]
			if(pref_path)
				.[entry] = user.client.prefs.read_preference(pref_path)

/datum/component/interactable/update_cached_preferences(mob/living/user, list/preferences)
	if(LAZYLEN(preferences))
		for(var/entry in preferences)
			var/pref_path
			if(character_preference_paths[entry])
				pref_path = character_preference_paths[entry]
			else if(preference_paths[entry])
				pref_path = preference_paths[entry]
			else if(tattoo_preference_paths[entry])
				pref_path = tattoo_preference_paths[entry]

			if(pref_path)
				cached_preferences[entry] = user.client?.prefs.read_preference(pref_path)
		return

	cached_preferences = list()
	// Existing preferences
	for(var/entry in character_preference_paths)
		cached_preferences[entry] = user.client?.prefs.read_preference(character_preference_paths[entry])
	for(var/entry in preference_paths)
		cached_preferences[entry] = user.client?.prefs.read_preference(preference_paths[entry])
	// Tattoo preferences
	for(var/entry in tattoo_preference_paths)
		cached_preferences[entry] = user.client?.prefs.read_preference(tattoo_preference_paths[entry])

// Handle preference changes from TGUI
/datum/component/interactable/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("pref")
			var/pref_key = params["pref"]
			var/datum/preference/preference

			// Find which preference list contains this key
			if(character_preference_paths[pref_key])
				preference = GLOB.preference_entries[character_preference_paths[pref_key]]
			else if(preference_paths[pref_key])
				preference = GLOB.preference_entries[preference_paths[pref_key]]
			else if(tattoo_preference_paths[pref_key])
				preference = GLOB.preference_entries[tattoo_preference_paths[pref_key]]

			if(preference)
				var/current_value = usr.client.prefs.read_preference(preference.type)
				var/new_value = !current_value
				usr.client.prefs.write_preference(preference, new_value)
				update_cached_preferences(usr, list(pref_key))
				return TRUE

	return FALSE
