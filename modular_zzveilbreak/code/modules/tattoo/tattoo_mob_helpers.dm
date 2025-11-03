/mob/living/carbon/human
    var/list/datum/tattoo/body_tattoos = list()

/mob/living/carbon/human/proc/add_tattoo(datum/tattoo/new_tattoo)
    if(!new_tattoo || !istype(new_tattoo) || (new_tattoo in body_tattoos))
        return FALSE

    if(!is_valid_tattoo_bodypart(new_tattoo.body_part))
        return FALSE

    body_tattoos += new_tattoo

    // Save to preferences when tattoo is added
    if(client?.prefs)
        client.prefs.features["tattoos"] = body_tattoos.Copy()
        client.prefs.save_character()

    return TRUE

/mob/living/carbon/human/proc/remove_tattoo(datum/tattoo/tattoo)
    if(!tattoo || !(tattoo in body_tattoos))
        return FALSE

    body_tattoos -= tattoo
    qdel(tattoo)

    // Save to preferences when tattoo is removed
    if(client?.prefs)
        client.prefs.features["tattoos"] = body_tattoos.Copy()
        client.prefs.save_character()

    return TRUE

/mob/living/carbon/human/proc/get_tattoos(body_zone)
    . = list()
    for(var/datum/tattoo/T as anything in body_tattoos)
        if(T.body_part == body_zone)
            . += T
    . = sortTim(., GLOBAL_PROC_REF(cmp_tattoo_layer_asc))

/mob/living/carbon/human/proc/get_visible_tattoos(mob/viewer)
    . = list()
    for(var/datum/tattoo/T as anything in body_tattoos)
        if(T.is_visible(viewer, src))
            . += T
    . = sortTim(., GLOBAL_PROC_REF(cmp_tattoo_layer_asc))

/proc/cmp_tattoo_layer_asc(datum/tattoo/A, datum/tattoo/B)
    return A.layer - B.layer

// Examine override
/mob/living/carbon/human/examine(mob/user)
    . = ..()

    var/list/visible_tattoos = get_visible_tattoos(user)
    if(length(visible_tattoos))
        . += "<span class='notice'>They have visible tattoos:</span>"
        for(var/datum/tattoo/T as anything in visible_tattoos)
            var/tattoo_text = T.get_examine_text(user, src)
            if(tattoo_text)
                . += tattoo_text
