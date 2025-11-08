// Tattoo/Bodywriting Preference
/datum/preference/toggle/allow_bodywriting
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "allow_bodywriting"
	default_value = FALSE

/datum/preference/toggle/allow_bodywriting/apply_to_client(client/client, value)
	return TRUE

// Ensure the preference is properly registered
/hook/startup/proc/register_tattoo_preference()
	if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
		GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting
	return TRUE
