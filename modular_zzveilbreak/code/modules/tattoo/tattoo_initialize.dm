/proc/modular_zzveilbreak_erp_pref_override()
	// Add our preference to the global list if it doesn't exist
	if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
		GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting
		world.log << "Tattoo preference registered successfully"

/proc/initialize_tattoo_system()
    // Initialize global body parts list
    GLOB.tattooable_body_parts = populate_tattooable_body_parts()

    // Register surgery
    if(!GLOB.surgeries_list)
        GLOB.surgeries_list = list()
    GLOB.surgeries_list += typesof(/datum/surgery/tattoo_removal)

    // Register tattoo preference using our modular override
    modular_zzveilbreak_erp_pref_override()

    // Log initialization
    world.log << "Tattoo system initialized successfully"

/world/New()
    ..()
    addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(initialize_tattoo_system)), 0)
