/mob/living/carbon/human
    var/list/datum/tattoo/body_tattoos = list()

// Comparison proc for sorting tattoos by layer
/proc/cmp_tattoo_layer_asc(datum/tattoo/A, datum/tattoo/B)
    return A.layer - B.layer

// Override the original add_tattoo proc with enhanced functionality
/mob/living/carbon/human/proc/add_tattoo_zzveilbreak(datum/tattoo/new_tattoo)
    if(!new_tattoo || QDELETED(new_tattoo) || !istype(new_tattoo))
        return FALSE

    if(!is_valid_tattoo_bodypart(new_tattoo.body_part))
        return FALSE

    body_tattoos += new_tattoo

    // Enhanced saving to preferences - trigger character save
    if(client?.prefs)
        client.prefs.save_character()

    return TRUE

// Override the original remove_tattoo proc
/mob/living/carbon/human/proc/remove_tattoo_zzveilbreak(datum/tattoo/tattoo)
    if(!tattoo || !(tattoo in body_tattoos))
        return FALSE

    body_tattoos -= tattoo
    qdel(tattoo)

    // Enhanced saving to preferences - trigger character save
    if(client?.prefs)
        client.prefs.save_character()

    return TRUE

// Enhanced tattoo retrieval with better error handling
/mob/living/carbon/human/proc/get_tattoos_zzveilbreak(body_zone)
    . = list()
    for(var/datum/tattoo/T as anything in body_tattoos)
        if(T.body_part == body_zone)
            . += T
    . = sortTim(., GLOBAL_PROC_REF(cmp_tattoo_layer_asc))

// Enhanced visibility checking
/mob/living/carbon/human/proc/get_visible_tattoos_zzveilbreak(mob/viewer)
    . = list()
    for(var/datum/tattoo/T as anything in body_tattoos)
        var/visible = T.is_visible(viewer, src)
        if(visible)
            . += T

    . = sortTim(., GLOBAL_PROC_REF(cmp_tattoo_layer_asc))

// Override the original procs
/mob/living/carbon/human/proc/add_tattoo(datum/tattoo/new_tattoo)
	return add_tattoo_zzveilbreak(new_tattoo)

/mob/living/carbon/human/proc/remove_tattoo(datum/tattoo/tattoo)
	return remove_tattoo_zzveilbreak(tattoo)

/mob/living/carbon/human/proc/get_tattoos(body_zone)
	return get_tattoos_zzveilbreak(body_zone)

/mob/living/carbon/human/proc/get_visible_tattoos(mob/viewer)
	return get_visible_tattoos_zzveilbreak(viewer)

// Enhanced examine with better formatting
/mob/living/carbon/human/examine(mob/user)
	. = ..()

	var/list/visible_tattoos = get_visible_tattoos_zzveilbreak(user)

	if(length(visible_tattoos))
		. += span_notice("<b>Visible Tattoos:</b>")
		for(var/datum/tattoo/T as anything in visible_tattoos)
			var/tattoo_text = T.get_examine_text(user, src)
			if(tattoo_text)
				. += " [tattoo_text]" // Indented bullet points

// Enhanced verb for players to check their own tattoos
/mob/living/carbon/human/verb/examine_my_tattoos()
    set name = "Examine My Tattoos"
    set category = "IC"
    set desc = "Look at your own tattoos"

    var/list/visible_tattoos = get_visible_tattoos_zzveilbreak(src)
    if(!length(visible_tattoos))
        to_chat(src, span_notice("You don't see any tattoos on your exposed skin."))
        return

    to_chat(src, span_notice("<b>Your Visible Tattoos:</b>"))
    for(var/datum/tattoo/T as anything in visible_tattoos)
        var/tattoo_text = T.get_examine_text(src, src)
        if(tattoo_text)
            to_chat(src, " • [tattoo_text]")

// Enhanced login handling
/mob/living/carbon/human/Login()
	. = ..()

	// Enhanced tattoo application with fallback
	if(client?.prefs)
		client.prefs.apply_tattoos_to_mob_zzveilbreak(src)

// Enhanced initialization
/mob/living/carbon/human/Initialize(mapload)
	. = ..()

	// Load tattoos after species and bodyparts are set up
	addtimer(CALLBACK(src, .proc/load_tattoos_from_prefs_zzveilbreak), 1 SECONDS)

/mob/living/carbon/human/proc/load_tattoos_from_prefs_zzveilbreak()
	if(client?.prefs)
		client.prefs.apply_tattoos_to_mob_zzveilbreak(src)
