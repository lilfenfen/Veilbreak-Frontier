/datum/preference/toggle/allow_bodywriting
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "allow_bodywriting_pref"  // CHANGED: to match TGUI
	default_value = FALSE

/datum/preference/toggle/allow_bodywriting/apply_to_client(client/client, value)
	return
