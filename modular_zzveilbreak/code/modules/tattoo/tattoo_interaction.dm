// Extend the interactable component to include tattoo preferences
/datum/component/interactable
    /// Add tattoo preference to the list
    var/static/list/tattoo_preference_paths = list(
        "allow_bodywriting_pref" = /datum/preference/toggle/allow_bodywriting
    )

/datum/component/interactable/ui_data(mob/living/user)
    . = ..()

    // Add tattoo preferences to the UI data
    if(user.client?.prefs)
        for(var/entry in tattoo_preference_paths)
            .[entry] = cached_preferences[entry]

/datum/component/interactable/update_cached_preferences(mob/living/user, list/preferences)
    if(LAZYLEN(preferences))
        for(var/entry in preferences)
            cached_preferences[entry] = user.client?.prefs.read_preference(
                character_preference_paths[entry] || preference_paths[entry] || tattoo_preference_paths[entry]
            )
        return

    cached_preferences = list()
    // Existing preferences
    for(var/entry in character_preference_paths)
        cached_preferences[entry] = user.client?.prefs.read_preference(character_preference_paths[entry])
    for(var/entry in preference_paths)
        cached_preferences[entry] = user.client?.prefs.read_preference(preference_paths[entry])
    // Tattoo preferences
    for(var/entry in tattoo_preference_paths)
        cached_preferences[entry] = user.client?.prefs.read_preference(tattoo_preference_paths[entry])
