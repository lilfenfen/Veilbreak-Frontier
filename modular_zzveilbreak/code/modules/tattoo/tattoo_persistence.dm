// Tattoo Persistence System
// Handles saving and loading tattoos between rounds

/// Saves tattoo data to preferences
/datum/preferences/proc/save_tattoo_data(list/save_data)
    if(!features)
        features = list()

    // Initialize the keys if they don't exist
    if(!("tattoos" in features))
        features["tattoos"] = list()
    if(!("tattoos_data" in features))
        features["tattoos_data"] = list()

    // Get tattoos from current mob if available
    var/mob/living/carbon/human/H = parent?.mob
    var/list/tattoos_to_save = list()

    if(H?.body_tattoos)
        tattoos_to_save = H.body_tattoos.Copy()

    // Convert tattoos to saveable format
    var/list/tattoo_data = list()
    for(var/datum/tattoo/T as anything in tattoos_to_save)
        if(istype(T) && !QDELETED(T))
            var/body_part_description = get_specific_body_part_description(T.body_part)

            tattoo_data += list(list(
                "artist" = T.artist,
                "design" = T.design,
                "body_part" = body_part_description,
                "color" = T.color,
                "date_applied" = T.date_applied,
                "layer" = T.layer
            ))

    // Store in features
    features["tattoos_data"] = tattoo_data

    // Also store in save_data if provided
    if(save_data)
        save_data["tattoos_data"] = tattoo_data

    // Save character
    save_character()

// Legacy support
/datum/preferences/proc/save_tattoos_data(list/save_data)
    save_tattoo_data(save_data)

/// Loads tattoo data from preferences
/datum/preferences/proc/load_tattoo_data(list/save_data)
    if(!features)
        features = list()

    // Initialize the keys if they don't exist
    if(!("tattoos" in features))
        features["tattoos"] = list()
    if(!("tattoos_data" in features))
        features["tattoos_data"] = list()

    var/list/tattoo_data

    // Try to get data from save_data first, then features
    if(save_data && ("tattoos_data" in save_data))
        tattoo_data = save_data["tattoos_data"]
    else if("tattoos_data" in features)
        tattoo_data = features["tattoos_data"]
    else
        return

    if(!islist(tattoo_data))
        return

    // Convert loaded data back to tattoo datums
    var/list/loaded_tattoos = list()

    for(var/list/tattoo_info as anything in tattoo_data)
        if(!islist(tattoo_info))
            continue

        // Extract data
        var/artist = tattoo_info["artist"] || "Unknown Artist"
        var/design = tattoo_info["design"] || "An intricate design"
        var/body_part_string = tattoo_info["body_part"]
        var/color = tattoo_info["color"] || "#000000"
        var/layer = tattoo_info["layer"] || 2
        var/date_applied = tattoo_info["date_applied"] || time2text(world.realtime, "YYYY-MM-DD")

        if(!body_part_string)
            continue

        // Convert body part string back to define
        var/body_part_define = get_standardized_body_part(body_part_string)

        if(!body_part_define || !is_valid_tattoo_bodypart(body_part_define))
            continue

        // Create the tattoo datum
        var/datum/tattoo/T = new(
            sanitize_text(artist, "Unknown Artist"),
            sanitize_text(design, "An intricate design"),
            body_part_define,
            sanitize_hexcolor(color, "#000000"),
            sanitize_integer(layer, 1, 3, 2)
        )
        T.date_applied = sanitize_text(date_applied, time2text(world.realtime, "YYYY-MM-DD"))

        loaded_tattoos += T

    // Store the loaded tattoos
    features["tattoos"] = loaded_tattoos

// Legacy support
/datum/preferences/proc/load_tattoos_data(list/save_data)
    load_tattoo_data(save_data)

/// Applies saved tattoos to a mob
/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/character)
    if(!istype(character) || !features)
        return

    // Initialize the keys if they don't exist
    if(!("tattoos" in features))
        features["tattoos"] = list()
    if(!("tattoos_data" in features))
        features["tattoos_data"] = list()

    // Ensure we have loaded tattoo data
    if(!length(features["tattoos"]))
        load_tattoo_data()

    var/list/tattoos_to_apply = features["tattoos"]

    if(!islist(tattoos_to_apply))
        character.body_tattoos = list()
        return

    // Clear existing tattoos and apply new ones
    character.body_tattoos = list()

    for(var/datum/tattoo/T as anything in tattoos_to_apply)
        if(istype(T) && !QDELETED(T))
            character.body_tattoos += T

    character.regenerate_icons()

// =====================
// HOOKS
// =====================

/// Hook to load tattoos when preferences are loaded
/hook/character_setup/proc/load_character_tattoos(datum/preferences/prefs)
    if(istype(prefs))
        prefs.load_tattoo_data()
        return TRUE
    return FALSE

/// Hook to apply tattoos when a new human mob is created
/hook/mob_new/proc/apply_saved_tattoos(mob/living/carbon/human/H)
    if(istype(H) && H.client?.prefs)
        H.client.prefs.apply_tattoos_to_mob(H)
        return TRUE
    return FALSE

// =====================
// MANAGEMENT TOOLS
// =====================

/// Clears all tattoos from preferences
/datum/preferences/proc/clear_all_tattoos()
    if(!features)
        features = list()

    features["tattoos"] = list()
    features["tattoos_data"] = list()

    // Clear from current mob
    var/mob/living/carbon/human/H = parent?.mob
    if(istype(H))
        H.body_tattoos = list()
        H.regenerate_icons()

    save_character()

/// Gets all tattoos for a specific body part
/datum/preferences/proc/get_tattoos_for_bodypart(body_zone)
    if(!features || !body_zone)
        return list()

    if(!("tattoos" in features))
        features["tattoos"] = list()

    var/list/result = list()
    for(var/datum/tattoo/T as anything in features["tattoos"])
        if(T.body_part == body_zone)
            result += T

    return result

/// Counts total tattoos across all body parts
/datum/preferences/proc/count_total_tattoos()
    if(!features)
        return 0

    if(!("tattoos" in features))
        features["tattoos"] = list()

    return length(features["tattoos"])

// =====================
// COMPATIBILITY WRAPPERS
// =====================

/datum/preferences/proc/save_tattoos_modular(list/save_data)
    save_tattoo_data(save_data)

/datum/preferences/proc/load_tattoos_modular(list/save_data)
    load_tattoo_data(save_data)

// =====================
// INITIALIZATION
// =====================

/hook/roundstart/proc/initialize_tattoo_persistence()
    return TRUE
