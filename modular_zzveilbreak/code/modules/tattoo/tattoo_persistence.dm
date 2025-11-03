/mob/living/carbon/human/proc/update_tattoo_persistence()
    if(!client?.prefs)
        return

    var/datum/preferences/prefs = client.prefs
    if(!prefs)
        return

    // Save tattoos to preferences features instead of metadata
    var/list/tattoo_data = list()
    for(var/datum/tattoo/T as anything in body_tattoos)
        if(!QDELETED(T))
            tattoo_data += list(list(
                "name" = T.name,
                "desc" = T.desc,
                "body_part" = T.body_part,
                "color" = T.color,
                "creator" = T.creator,
                "date_applied" = T.date_applied,
                "layer" = T.layer
            ))

    // Use features to store tattoo data
    LAZYSET(prefs.features, "tattoos", tattoo_data)
    prefs.save_preferences()

// Hook into preference loading/saving
/datum/preferences/proc/load_tattoos()
    if(!LAZYACCESS(features, "tattoos"))
        return

    var/list/tattoo_data = features["tattoos"]
    if(!islist(tattoo_data))
        return

    // Initialize tattoos list if it doesn't exist
    if(!LAZYACCESS(features, "tattoos_list"))
        LAZYSET(features, "tattoos_list", list())

    features["tattoos_list"] = list()
    for(var/list/tattoo_info as anything in tattoo_data)
        if(is_valid_tattoo_bodypart(tattoo_info["body_part"]))
            var/datum/tattoo/T = new(
                tattoo_info["name"],
                tattoo_info["desc"],
                tattoo_info["body_part"],
                tattoo_info["color"],
                tattoo_info["creator"],
                tattoo_info["layer"] || TATTOO_LAYER_NORMAL
            )
            T.date_applied = tattoo_info["date_applied"]
            features["tattoos_list"] += T

/datum/preferences/proc/apply_tattoos_to_mob(mob/living/carbon/human/character)
    if(!istype(character) || !features || !features["tattoos_list"])
        return

    character.body_tattoos = list()
    for(var/datum/tattoo/T as anything in features["tattoos_list"])
        if(!QDELETED(T))
            character.body_tattoos += T
