// modular_zzveilbreak/code/modules/tattoo/tattoo_mob_helpers.dm

/mob/living/carbon/human
    var/list/datum/tattoo/body_tattoos = list()

/mob/living/carbon/human/proc/add_tattoo(datum/tattoo/new_tattoo)
    if(!new_tattoo || !istype(new_tattoo) || (new_tattoo in body_tattoos))
        return FALSE

    if(!is_valid_tattoo_bodypart(new_tattoo.body_part))
        return FALSE

    body_tattoos += new_tattoo
    return TRUE

/mob/living/carbon/human/proc/remove_tattoo(datum/tattoo/tattoo)
    if(!tattoo || !(tattoo in body_tattoos))
        return FALSE

    body_tattoos -= tattoo
    qdel(tattoo)
    update_tattoo_persistence()
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
