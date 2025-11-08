/proc/modular_zzveilbreak_erp_pref_override()
	if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
		GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting

/proc/initialize_tattoo_system()
	GLOB.tattooable_body_parts = populate_tattooable_body_parts()

	if(!GLOB.surgeries_list)
		GLOB.surgeries_list = list()
	GLOB.surgeries_list += typesof(/datum/surgery/tattoo_removal)

	// Register the surgery step
	if(!GLOB.surgery_steps[/datum/surgery_step/cauterize_tattoo])
		GLOB.surgery_steps[/datum/surgery_step/cauterize_tattoo] = new /datum/surgery_step/cauterize_tattoo

	modular_zzveilbreak_erp_pref_override()

/world/New()
	..()
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(initialize_tattoo_system)), 0)

/hook/startup/proc/register_tattoo_preferences()
	modular_zzveilbreak_erp_pref_override()
	return TRUE
