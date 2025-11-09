/mob/living/carbon/human
	var/list/datum/custom_tattoo/custom_body_tattoos = list()

/proc/cmp_custom_tattoo_layer_asc(datum/custom_tattoo/A, datum/custom_tattoo/B)
	return A.layer - B.layer

/mob/living/carbon/human/proc/add_custom_tattoo(datum/custom_tattoo/new_tattoo)
	if(!new_tattoo || QDELETED(new_tattoo) || !istype(new_tattoo))
		return FALSE

	if(!is_custom_tattoo_bodypart_valid(new_tattoo.body_part))
		return FALSE

	// Check if we've reached the maximum tattoos for this body part
	var/current_tattoos = length(get_custom_tattoos(new_tattoo.body_part))
	if(current_tattoos >= CUSTOM_MAX_TATTOOS_PER_PART)
		return FALSE

	LAZYADD(custom_body_tattoos, new_tattoo)

	// Save to preferences if we have a client
	if(client?.prefs)
		client.prefs.save_custom_tattoo_data()

	// Update appearance
	regenerate_icons()

	return TRUE

/mob/living/carbon/human/proc/remove_custom_tattoo(datum/custom_tattoo/tattoo)
	if(!tattoo || !(tattoo in custom_body_tattoos))
		return FALSE

	custom_body_tattoos -= tattoo
	qdel(tattoo)

	// Save to preferences if we have a client
	if(client?.prefs)
		client.prefs.save_custom_tattoo_data()

	// Update appearance
	regenerate_icons()

	return TRUE

/mob/living/carbon/human/proc/get_custom_tattoos(body_zone)
	. = list()
	if(!body_zone)
		return .
	for(var/datum/custom_tattoo/T as anything in custom_body_tattoos)
		// CRITICAL FIX: Convert both sides to comparable values
		var/tattoo_zone_string = zone_to_string(T.body_part)
		var/search_zone_string = istext(body_zone) ? body_zone : zone_to_string(body_zone)

		if(tattoo_zone_string == search_zone_string)
			. += T
	. = sortTim(., GLOBAL_PROC_REF(cmp_custom_tattoo_layer_asc))

/mob/living/carbon/human/examine(mob/user)
	. = ..()

	var/list/visible_tattoos = get_visible_custom_tattoos(user)

	if(length(visible_tattoos))
		. += span_notice("<b>Visible Tattoos:</b>")
		for(var/datum/custom_tattoo/T as anything in visible_tattoos)
			var/tattoo_text = T.get_examine_text(user, src)
			if(tattoo_text)
				. += " [tattoo_text]"

/mob/living/carbon/human/verb/examine_my_custom_tattoos()
	set name = "Examine My Tattoos"
	set category = "IC"
	set desc = "Look at your own tattoos"

	var/list/visible_tattoos = get_visible_custom_tattoos(src)
	if(!length(visible_tattoos))
		to_chat(src, span_notice("You don't see any tattoos on your exposed skin."))
		return

	to_chat(src, span_notice("<b>Your Visible Tattoos:</b>"))
	for(var/datum/custom_tattoo/T as anything in visible_tattoos)
		var/tattoo_text = T.get_examine_text(src, src)
		if(tattoo_text)
			to_chat(src, " • [tattoo_text]")

/mob/living/carbon/human/Login()
	. = ..()
	if(client?.prefs)
		client.prefs.apply_custom_tattoos_to_mob(src)
		// Force icon update after loading tattoos
		regenerate_icons()

/mob/living/carbon/human/Initialize(mapload)
	. = ..()
	addtimer(CALLBACK(src, .proc/load_custom_tattoos_from_prefs), 1 SECONDS)

/mob/living/carbon/human/proc/load_custom_tattoos_from_prefs()
	if(client?.prefs)
		client.prefs.apply_custom_tattoos_to_mob(src)
		// Force icon update
		addtimer(CALLBACK(src, .proc/regenerate_icons), 1 SECONDS)

/mob/living/carbon/human/proc/get_visible_custom_tattoos(mob/viewer)
	. = list()
	for(var/datum/custom_tattoo/T as anything in custom_body_tattoos)
		var/visible = T.is_custom_tattoo_visible(viewer, src)
		if(visible)
			. += T

	. = sortTim(., GLOBAL_PROC_REF(cmp_custom_tattoo_layer_asc))
