// Tattoo Persistence System
// Handles saving and loading tattoos between rounds

/// Saves tattoo data to preferences
/datum/preferences/proc/save_tattoo_data(list/save_data)
    if(!features)
        features = list()

    // Get tattoos from current mob if available, otherwise use stored data
    var/mob/living/carbon/human/H = parent?.mob
    var/list/tattoos_to_save = H?.body_tattoos || LAZYACCESS(features, "tattoos") || list()

    world.log << "DEBUG SAVE: Starting save_tattoo_data for [parent?.ckey]"
    world.log << "DEBUG SAVE: Mob has [length(H?.body_tattoos || list())] tattoos, features has [length(LAZYACCESS(features, "tattoos") || list())]"

    var/list/tattoo_data = list()
    for(var/datum/tattoo/T as anything in tattoos_to_save)
        if(istype(T) && !QDELETED(T))
            // Convert body part to string description for saving
            var/body_part_description = get_specific_body_part_description(T.body_part)
            world.log << "DEBUG SAVE: Saving tattoo '[T.design]' on [T.body_part] -> '[body_part_description]'"
            tattoo_data += list(list(
                "artist" = T.artist,
                "design" = T.design,
                "body_part" = body_part_description, // Save as string, not define
                "color" = T.color,
                "date_applied" = T.date_applied,
                "layer" = T.layer
            ))

    // Store in features for persistence
    LAZYSET(features, "tattoos_data", tattoo_data)

    // Also store directly in save_data if provided (for modular save system integration)
    if(save_data)
        save_data["tattoos_data"] = tattoo_data

    world.log << "DEBUG SAVE: Saved [length(tattoo_data)] tattoos to features and save_data"

    // Trigger character save to ensure persistence
    save_character()

// LEGACY SUPPORT - If your code is calling the wrong proc name
/datum/preferences/proc/save_tattoos_data(list/save_data)
    save_tattoo_data(save_data)

/// Loads tattoo data from preferences
/datum/preferences/proc/load_tattoo_data(list/save_data)
    if(!features)
        features = list()

    world.log << "DEBUG LOAD: Starting load_tattoo_data for [parent?.ckey]"

    var/list/tattoo_data
    if(save_data && LAZYACCESS(save_data, "tattoos_data"))
        tattoo_data = save_data["tattoos_data"]
        world.log << "DEBUG LOAD: Found tattoo_data in save_data: [length(tattoo_data)] entries"
    else if(LAZYACCESS(features, "tattoos_data"))
        tattoo_data = features["tattoos_data"]
        world.log << "DEBUG LOAD: Found tattoo_data in features: [length(tattoo_data)] entries"
    else
        world.log << "DEBUG LOAD: No tattoo_data found anywhere"
        features["tattoos"] = list()
        return

    if(!islist(tattoo_data))
        world.log << "DEBUG LOAD: tattoo_data is not a list: [tattoo_data]"
        features["tattoos"] = list()
        return

    features["tattoos"] = list()
    world.log << "DEBUG LOAD: Processing [length(tattoo_data)] tattoo entries"

    for(var/list/tattoo_info as anything in tattoo_data)
        if(!islist(tattoo_info))
            world.log << "DEBUG LOAD: Skipping non-list tattoo_info: [tattoo_info]"
            continue

        // Sanitize and validate all data
        var/artist = sanitize_text(tattoo_info["artist"], "Unknown Artist")
        var/design = sanitize_text(tattoo_info["design"], "An intricate design")
        var/body_part_string = tattoo_info["body_part"]
        var/color = sanitize_hexcolor(tattoo_info["color"], default = "#000000")
        var/layer = sanitize_integer(tattoo_info["layer"], 1, 3, 2)
        var/date_applied = sanitize_text(tattoo_info["date_applied"], time2text(world.realtime, "YYYY-MM-DD"))

        world.log << "DEBUG LOAD: Processing tattoo: '[design]' on '[body_part_string]'"

        // === USE THE UPDATED CONVERSION FUNCTION ===
        var/body_part_define = get_body_part_from_description(body_part_string)

        if(body_part_define)
            world.log << "DEBUG LOAD: Conversion function result: '[body_part_string]' -> [body_part_define]"
        else
            // If conversion failed, check if it's already a valid define
            if(body_part_string in GLOB.tattooable_body_parts)
                body_part_define = body_part_string
                world.log << "DEBUG LOAD: Using as valid define: [body_part_string]"
            else
                world.log << "DEBUG LOAD: WARNING: No conversion found for '[body_part_string]', using as-is"
                body_part_define = body_part_string
        // === END CONVERSION LOGIC ===

        world.log << "DEBUG LOAD: Final body part: [body_part_define]"
        world.log << "DEBUG LOAD: Is valid tattoo bodypart? [is_valid_tattoo_bodypart(body_part_define)]"

        if(body_part_define && is_valid_tattoo_bodypart(body_part_define))
            var/datum/tattoo/T = new(artist, design, body_part_define, color, layer)
            T.date_applied = date_applied
            features["tattoos"] += T
            world.log << "DEBUG LOAD: Successfully created tattoo datum"
        else
            world.log << "DEBUG LOAD: FAILED to create tattoo - invalid body part"

    world.log << "DEBUG LOAD: Loaded [length(features["tattoos"])] tattoos total"

/// Applies saved tattoos to a mob
/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/character)
    if(!istype(character) || !features)
        world.log << "DEBUG APPLY: apply_tattoos_to_mob failed - no character or features"
        return

    world.log << "DEBUG APPLY: Starting apply_tattoos_to_mob for [character.ckey]"

    // Ensure tattoo data is loaded
    if(!LAZYACCESS(features, "tattoos"))
        world.log << "DEBUG APPLY: No tattoos in features, loading data"
        load_tattoo_data()

    world.log << "DEBUG APPLY: Features has [length(features["tattoos"])] tattoos to apply"

    character.body_tattoos = list()
    for(var/datum/tattoo/T as anything in features["tattoos"])
        if(istype(T) && !QDELETED(T))
            character.body_tattoos += T
            world.log << "DEBUG APPLY: Applied tattoo: '[T.design]' on [T.body_part]"

    world.log << "DEBUG APPLY: Mob now has [length(character.body_tattoos)] tattoos"

    // Test visibility of first tattoo
    if(length(character.body_tattoos))
        var/datum/tattoo/first_tattoo = character.body_tattoos[1]
        world.log << "DEBUG APPLY: Testing visibility of first tattoo:"
        world.log << "DEBUG APPLY: - Design: [first_tattoo.design]"
        world.log << "DEBUG APPLY: - Body part: [first_tattoo.body_part]"
        world.log << "DEBUG APPLY: - Is visible to self: [first_tattoo.is_visible(character, character)]"

        // Test examine text
        var/examine_text = first_tattoo.get_examine_text(character, character)
        world.log << "DEBUG APPLY: - Examine text: [examine_text ? examine_text : "EMPTY"]"

    // Update examine text and icons
    character.regenerate_icons()
    world.log << "DEBUG APPLY: apply_tattoos_to_mob completed"

// =====================
// HOOKS
// =====================

/// Hook to load tattoos when preferences are loaded
/hook/character_setup/proc/load_character_tattoos(datum/preferences/prefs)
    world.log << "DEBUG HOOK: load_character_tattoos hook called"
    if(istype(prefs))
        prefs.load_tattoo_data()
        return TRUE
    return FALSE

/// Hook to apply tattoos when a new human mob is created
/hook/mob_new/proc/apply_saved_tattoos(mob/living/carbon/human/H)
    world.log << "DEBUG HOOK: apply_saved_tattoos hook called for [H?.ckey]"
    if(istype(H) && H.client?.prefs)
        H.client.prefs.apply_tattoos_to_mob(H)
        return TRUE
    world.log << "DEBUG HOOK: apply_saved_tattoos hook failed - not human or no client/prefs"
    return FALSE

// =====================
// MANAGEMENT TOOLS
// =====================

/// Clears all tattoos from preferences
/datum/preferences/proc/clear_all_tattoos()
    if(!features)
        return

    features["tattoos"] = list()
    features["tattoos_data"] = list()

    // Also clear from current mob if it exists
    var/mob/living/carbon/human/H = parent?.mob
    if(istype(H))
        H.body_tattoos = list()
        H.regenerate_icons()

    save_character()

/// Removes a specific tattoo by reference
/datum/preferences/proc/remove_specific_tattoo(datum/tattoo/tattoo_to_remove)
    if(!features || !tattoo_to_remove)
        return FALSE

    var/list/current_tattoos = LAZYACCESS(features, "tattoos")
    if(!current_tattoos || !(tattoo_to_remove in current_tattoos))
        return FALSE

    current_tattoos -= tattoo_to_remove
    qdel(tattoo_to_remove)

    // Update the mob if it exists
    var/mob/living/carbon/human/H = parent?.mob
    if(istype(H) && (tattoo_to_remove in H.body_tattoos))
        H.body_tattoos -= tattoo_to_remove
        H.regenerate_icons()

    // Save the changes
    save_tattoo_data()
    return TRUE

/// Gets all tattoos for a specific body part
/datum/preferences/proc/get_tattoos_for_bodypart(body_zone)
    if(!features || !body_zone)
        return list()

    if(!LAZYACCESS(features, "tattoos"))
        load_tattoo_data()

    var/list/result = list()
    for(var/datum/tattoo/T as anything in features["tattoos"])
        if(T.body_part == body_zone)
            result += T

    return result

/// Counts total tattoos across all body parts
/datum/preferences/proc/count_total_tattoos()
    if(!features)
        return 0

    if(!LAZYACCESS(features, "tattoos"))
        load_tattoo_data()

    return length(features["tattoos"])

// =====================
// DEBUG & ADMIN TOOLS
// =====================

/// Debug proc to view tattoo data
/datum/preferences/proc/debug_view_tattoos()
    if(!features)
        return "No features data"

    if(!LAZYACCESS(features, "tattoos"))
        load_tattoo_data()

    var/list/tattoos = features["tattoos"]
    if(!length(tattoos))
        return "No tattoos found"

    var/output = "Total Tattoos: [length(tattoos)]\n"
    for(var/datum/tattoo/T as anything in tattoos)
        output += "- [T.design] on [T.body_part] by [T.artist] (Layer: [T.layer])\n"

    return output

/// Admin proc to force reload tattoos on current mob
/datum/preferences/proc/force_reload_tattoos()
    var/mob/living/carbon/human/H = parent?.mob
    if(istype(H))
        apply_tattoos_to_mob(H)
        return TRUE
    return FALSE

// =====================
// COMPATIBILITY WRAPPERS
// =====================

// Wrapper procs for backward compatibility with existing systems

/// Legacy support - saves tattoos directly to a save_data list
/proc/save_tattoos_to_list(list/save_data, list/tattoos)
    if(!save_data || !islist(tattoos))
        return

    var/list/tattoo_data = list()
    for(var/datum/tattoo/T as anything in tattoos)
        if(istype(T) && !QDELETED(T))
            tattoo_data += list(list(
                "artist" = T.artist,
                "design" = T.design,
                "body_part" = T.body_part,
                "color" = T.color,
                "date_applied" = T.date_applied,
                "layer" = T.layer
            ))

    save_data["tattoos_data"] = tattoo_data

/// Legacy support - loads tattoos directly from a save_data list
/proc/load_tattoos_from_list(list/save_data)
    if(!save_data || !LAZYACCESS(save_data, "tattoos_data"))
        return list()

    var/list/tattoo_data = save_data["tattoos_data"]
    var/list/tattoos = list()

    for(var/list/tattoo_info as anything in tattoo_data)
        if(!islist(tattoo_info))
            continue

        var/artist = sanitize_text(tattoo_info["artist"], "Unknown Artist")
        var/design = sanitize_text(tattoo_info["design"], "An intricate design")
        var/body_part = tattoo_info["body_part"]
        var/color = sanitize_hexcolor(tattoo_info["color"], default = "#000000")
        var/layer = sanitize_integer(tattoo_info["layer"], 1, 3, 2)
        var/date_applied = sanitize_text(tattoo_info["date_applied"], time2text(world.realtime, "YYYY-MM-DD"))

        if(is_valid_tattoo_bodypart(body_part))
            var/datum/tattoo/T = new(artist, design, body_part, color, layer)
            T.date_applied = date_applied
            tattoos += T

    return tattoos

// =====================
// INITIALIZATION
// =====================

// Initialize the tattoo system when the world starts
/hook/roundstart/proc/initialize_tattoo_persistence()
    // Register our hooks
    // These will automatically be called by the hook system

    // Log initialization
    world.log << "Tattoo persistence system initialized"
    return TRUE
