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
    world.log << "=== GET VISIBLE TATTOOS DEBUG ==="
    world.log << "DEBUG: Checking [length(body_tattoos)] total tattoos on [src]"

    for(var/datum/tattoo/T as anything in body_tattoos)
        world.log << "DEBUG: Checking tattoo: [T.design] on [T.body_part]"
        var/visible = T.is_visible(viewer, src)
        world.log << "DEBUG: Tattoo [T.design] visible: [visible]"
        if(visible)
            . += T
            world.log << "DEBUG: Added tattoo [T.design] to visible list"

    world.log << "DEBUG: Total visible tattoos: [length(.)]"
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
	world.log << "=== HUMAN EXAMINE DEBUG ==="
	world.log << "DEBUG: Found [length(visible_tattoos)] visible tattoos on [src]"

	if(length(visible_tattoos))
		. += span_notice("<b>Visible Tattoos:</b>")
		for(var/datum/tattoo/T as anything in visible_tattoos)
			var/tattoo_text = T.get_examine_text(user, src)
			if(tattoo_text)
				. += " [tattoo_text]" // Indented bullet points
				world.log << "DEBUG: Added tattoo text to examine: [tattoo_text]"
			else
				world.log << "DEBUG: No tattoo text returned for [T.design]"


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


/mob/living/carbon/human/Login()
	. = ..()
	world.log << "=== HUMAN LOGIN ==="
	world.log << "DEBUG: [src] logged in, client: [client], prefs: [client?.prefs]"

	// Manual tattoo application if hooks aren't working
	if(client?.prefs && !length(body_tattoos))
		world.log << "DEBUG: Manually applying tattoos on login"
		client.prefs.apply_tattoos_to_mob(src)
