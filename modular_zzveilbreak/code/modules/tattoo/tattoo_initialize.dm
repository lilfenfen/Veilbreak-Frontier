/proc/initialize_tattoo_system()
    // Global list is already defined in tattoo_bodyparts.dm, just populate it
    GLOB.tattooable_body_parts = populate_tattooable_body_parts()

    // Register surgery
    if(!GLOB.surgeries_list)
        GLOB.surgeries_list = list()
    GLOB.surgeries_list += typesof(/datum/surgery/tattoo_removal)

    // Register tattoo preference
    GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting] = new /datum/preference/toggle/allow_bodywriting

// Simple hook system for preferences
/hook/preferences_loaded/proc/load_tattoo_data(datum/preferences/prefs)
    if(prefs)
        prefs.load_tattoos()
    return TRUE

/hook/character_applied/proc/apply_tattoo_data(mob/living/carbon/human/character, datum/preferences/prefs)
    if(character && prefs)
        prefs.apply_tattoos_to_mob(character)
    return TRUE

// Initialize on world start
/world/New()
    ..()
    addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(initialize_tattoo_system)), 0)
