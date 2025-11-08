// Tattoo/Bodywriting Preference
/datum/preference/toggle/allow_bodywriting
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "allow_bodywriting_pref"
	default_value = FALSE

/datum/preference/toggle/allow_bodywriting/apply_to_client(client/client, value)
	return ..()


// Enhanced preference loading
/proc/modular_zzveilbreak_erp_pref_override()
	if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
		GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting

// Hook into preference loading
/hook/preferences_loaded/proc/setup_tattoo_preferences()
	modular_zzveilbreak_erp_pref_override()
	return TRUE
