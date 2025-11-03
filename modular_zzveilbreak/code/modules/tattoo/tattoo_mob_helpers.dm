/mob/living/carbon/human
    var/list/datum/tattoo/body_tattoos = list()

/mob/living/carbon/human/proc/add_tattoo(datum/tattoo/new_tattoo)
    if(!new_tattoo || QDELETED(new_tattoo) || !istype(new_tattoo))
        return FALSE

    if(!is_valid_tattoo_bodypart(new_tattoo.body_part))
        return FALSE

    body_tattoos += new_tattoo

    // Save to preferences
    if(client?.prefs)
        client.prefs.save_tattoo_data()

    return TRUE

/mob/living/carbon/human/proc/remove_tattoo(datum/tattoo/tattoo)
    if(!tattoo || !(tattoo in body_tattoos))
        return FALSE

    body_tattoos -= tattoo
    qdel(tattoo)

    // Save to preferences
    if(client?.prefs)
        client.prefs.save_tattoo_data()

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

/mob/living/carbon/human/proc/can_see_own_tattoo(body_zone)
    // Check if the person can see their own tattoo on a specific body part
    var/datum/tattoo/temp_tattoo = new("temp", "temp", body_zone)
    var/visible = temp_tattoo.is_visible(src, src)
    qdel(temp_tattoo)
    return visible

/proc/cmp_tattoo_layer_asc(datum/tattoo/A, datum/tattoo/B)
    return A.layer - B.layer

/mob/living/carbon/human/examine(mob/user)
    . = ..()

    var/list/visible_tattoos = get_visible_tattoos(user)
    if(length(visible_tattoos))
        . += span_notice("<b>Visible Tattoos:</b>")
        for(var/datum/tattoo/T as anything in visible_tattoos)
            var/tattoo_text = T.get_examine_text(user, src)
            if(tattoo_text)
                . += " [tattoo_text]" // Indented bullet points
				

// Verb for players to check their own tattoos
/mob/living/carbon/human/verb/examine_my_tattoos()
    set name = "Examine My Tattoos"
    set category = "IC"
    set desc = "Look at your own tattoos"

    var/list/visible_tattoos = get_visible_tattoos(src)
    if(!length(visible_tattoos))
        to_chat(src, span_notice("You don't see any tattoos on your exposed skin."))
        return

    to_chat(src, span_notice("<b>Your Visible Tattoos:</b>"))
    for(var/datum/tattoo/T as anything in visible_tattoos)
        var/tattoo_text = T.get_examine_text(src, src)
        if(tattoo_text)
            to_chat(src, " • [tattoo_text]")
