// modular_zzveilbreak/code/modules/tattoo/tattoo_initialize.dm
// Initialization hooks for tattoo subsystem: preference entry creation and other startup tasks.

// Ensure preference entries exist for bodywriting & storage
/proc/modular_zzveilbreak_erp_pref_override()
	// Create toggle if not present
	if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
		GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting
	// Create storage list pref if not present
	if(!GLOB.preference_entries[/datum/preference/text_list/custom_tattoos])
		GLOB.preference_entries[/datum/preference/text_list/custom_tattoos] = new /datum/preference/text_list/custom_tattoos

/hook/preferences_loaded/proc/setup_tattoo_preferences()
	modular_zzveilbreak_erp_pref_override()
	return TRUE
