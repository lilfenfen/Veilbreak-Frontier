/proc/initialize_tattoo_system()
	GLOB.tattooable_body_parts = populate_tattooable_body_parts()

	if(!GLOB.surgeries_list)
		GLOB.surgeries_list = list()
	GLOB.surgeries_list += typesof(/datum/surgery/tattoo_removal)

	// Register the surgery step
	if(!GLOB.surgery_steps[/datum/surgery_step/cauterize_tattoo])
		GLOB.surgery_steps[/datum/surgery_step/cauterize_tattoo] = new /datum/surgery_step/cauterize_tattoo

	// Ensure preference is registered
	if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
		GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting

/world/New()
	..()
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(initialize_tattoo_system)), 0)
