/proc/initialize_tattoo_system()
    // Initialize global body parts list
    GLOB.tattooable_body_parts = populate_tattooable_body_parts()

    // Register surgery
    if(!GLOB.surgeries_list)
        GLOB.surgeries_list = list()
    GLOB.surgeries_list += typesof(/datum/surgery/tattoo_removal)

    // Register tattoo preference
    if(!GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting])
        GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting

    world.log << "Tattoo system initialized successfully"

/world/New()
    ..()
    addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(initialize_tattoo_system)), 0)
