/proc/modular_zzveilbreak_erp_pref_override()
	if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
		GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting
	if(!GLOB.preference_entries[/datum/preference/text_list/custom_tattoos])
		GLOB.preference_entries[/datum/preference/text_list/custom_tattoos] = new /datum/preference/text_list/custom_tattoos

/proc/initialize_tattoo_system()
	// Initialize our custom body parts list
	GLOB.custom_tattooable_body_parts = populate_custom_tattooable_body_parts()

	// Register our custom surgery
	if(!GLOB.surgeries_list)
		GLOB.surgeries_list = list()
	GLOB.surgeries_list += /datum/surgery/custom_tattoo_removal

	// Register our surgery step
	if(!GLOB.surgery_steps[/datum/surgery_step/cauterize_custom_tattoo])
		GLOB.surgery_steps[/datum/surgery_step/cauterize_custom_tattoo] = new /datum/surgery_step/cauterize_custom_tattoo

	modular_zzveilbreak_erp_pref_override()

/world/New()
	..()
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(initialize_tattoo_system)), 0)

/hook/startup/proc/register_tattoo_preferences()
	modular_zzveilbreak_erp_pref_override()
	return TRUE
