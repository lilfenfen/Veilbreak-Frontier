// modular_zzveilbreak/code/modules/tattoo/tattoo_prefs.dm
/datum/preference/toggle/allow_bodywriting
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "allow_bodywriting"
	default_value = FALSE

/datum/preference/toggle/allow_bodywriting/apply_to_client(client/client, value)
	return TRUE

/datum/preference/text_list/custom_tattoos
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_tattoos"
