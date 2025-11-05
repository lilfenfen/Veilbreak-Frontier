/mob/living/carbon/human
	var/list/datum/tattoo/body_tattoos = list()

// Helper proc for bodywriting preference check - MOVED HERE FROM UTILS TO AVOID DUPLICATE
/mob/living/carbon/human/proc/allows_bodywriting()
	return can_mob_have_bodywriting(src)

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

/// Remove all tattoos from a specific body zone (called when limb is removed)
/mob/living/carbon/human/proc/remove_tattoos_by_zone(body_zone)
	if(!body_zone)
		return 0

	var/removed_count = 0
	var/list/tattoos_to_remove = list()

	// Find all tattoos on the specified body zone
	for(var/datum/tattoo/T as anything in body_tattoos)
		if(T.body_part == body_zone)
			tattoos_to_remove += T

	// Remove them
	for(var/datum/tattoo/T as anything in tattoos_to_remove)
		if(remove_tattoo(T))
			removed_count++

	return removed_count

/mob/living/carbon/human/proc/get_tattoos(body_zone)
	. = list()
	for(var/datum/tattoo/T as anything in body_tattoos)
		if(T.body_part == body_zone)
			. += T
	. = sortTim(., GLOBAL_PROC_REF(cmp_tattoo_layer_asc))

/mob/living/carbon/human/proc/get_visible_tattoos(mob/viewer)
	. = list()
	for(var/datum/tattoo/T as anything in body_tattoos)
		var/visible = T.is_visible(viewer, src)
		if(visible)
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

/mob/living/carbon/human/Login()
	. = ..()

	// Load tattoos from preferences
	if(client?.prefs)
		client.prefs.apply_tattoos_to_mob(src)

// Debug verb to check preference state
/mob/living/carbon/human/verb/check_bodywriting_pref()
	set name = "Check Bodywriting Pref"
	set category = "Debug"

	if(!client?.prefs)
		to_chat(src, span_warning("No client or prefs found!"))
		return

	to_chat(src, span_notice("=== BODYWRITING CONSENT DEBUG ==="))

	// Check through the preference system
	var/pref_value = client.prefs.read_preference(/datum/preference/toggle/allow_bodywriting)
	to_chat(src, span_notice("Preference system value: [isnull(pref_value) ? "NOT SET" : (pref_value ? "ALLOWED" : "DENIED")]"))

	// Check raw savefile data
	var/raw_value = client.prefs.read_preference("allow_bodywriting_pref")
	to_chat(src, span_notice("Raw savefile value: [isnull(raw_value) ? "NOT SET" : (raw_value ? "ALLOWED" : "DENIED")]"))

	// Check what our helper proc returns
	var/helper_result = allows_bodywriting()
	to_chat(src, span_notice("Consent status: [helper_result ? "GRANTED" : "DENIED"]"))

	// Check detailed consent status
	var/consent_status = get_bodywriting_consent_status(src)
	to_chat(src, span_notice("Detailed status: [consent_status]"))

	// Explain what this means
	switch(consent_status)
		if("EXPLICIT_ALLOW")
			to_chat(src, span_green("You have EXPLICITLY ALLOWED bodywriting/tattoos."))
		if("EXPLICIT_DENY")
			to_chat(src, span_alert("You have EXPLICITLY DENIED bodywriting/tattoos."))
		if("NOT_SET")
			to_chat(src, span_warning("You have NOT SET your bodywriting preference. It will default to DENIED."))
		if("NO_PREFS")
			to_chat(src, span_warning("No preference data found."))

// Debug verb to force enable bodywriting
/mob/living/carbon/human/verb/force_enable_bodywriting()
	set name = "Force Enable Bodywriting"
	set category = "Debug"

	if(!client?.prefs)
		to_chat(src, span_warning("No client or prefs found!"))
		return

	client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting], TRUE)
	to_chat(src, span_green("Bodywriting preference explicitly set to ALLOWED"))

	// Also set raw savefile value for compatibility
	client.prefs.write_preference("allow_bodywriting_pref", TRUE)
	to_chat(src, span_green("Raw savefile value also set to ALLOWED"))

	to_chat(src, span_notice("You have now EXPLICITLY CONSENTED to bodywriting/tattoos."))

// Debug verb to force disable bodywriting
/mob/living/carbon/human/verb/force_disable_bodywriting()
	set name = "Force Disable Bodywriting"
	set category = "Debug"

	if(!client?.prefs)
		to_chat(src, span_warning("No client or prefs found!"))
		return

	client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting], FALSE)
	to_chat(src, span_alert("Bodywriting preference explicitly set to DENIED"))

	// Also set raw savefile value for compatibility
	client.prefs.write_preference("allow_bodywriting_pref", FALSE)
	to_chat(src, span_alert("Raw savefile value also set to DENIED"))

	to_chat(src, span_notice("You have now EXPLICITLY DENIED bodywriting/tattoos."))

// Debug verb to clear all tattoos
/mob/living/carbon/human/verb/clear_all_tattoos()
	set name = "Clear All Tattoos"
	set category = "Debug"

	body_tattoos = list()
	if(client?.prefs)
		client.prefs.save_tattoo_data()
	regenerate_icons()
	to_chat(src, span_notice("All tattoos cleared."))

// =============================================
// HOOKS FOR TATTOO REMOVAL ON LIMB LOSS
// =============================================

/// Hook called when a bodypart is removed - removes tattoos from that bodypart
/hook/bodypart_removed/proc/remove_limb_tattoos(obj/item/bodypart/removed_limb, dismembered)
	if(!istype(removed_limb) || !removed_limb.owner)
		return TRUE

	var/mob/living/carbon/human/H = removed_limb.owner
	if(!istype(H))
		return TRUE

	// Remove tattoos from the lost limb
	var/removed_count = H.remove_tattoos_by_zone(removed_limb.body_zone)

	if(removed_count > 0)
		to_chat(H, span_notice("You feel the tattoos on your lost [removed_limb.name] fade away."))

	return TRUE

/// Hook called when an organ is removed - removes tattoos from that organ slot
/hook/organ_removed/proc/remove_organ_tattoos(obj/item/organ/removed_organ, special)
	if(!istype(removed_organ) || !removed_organ.owner || !removed_organ.zone)
		return TRUE

	var/mob/living/carbon/human/H = removed_organ.owner
	if(!istype(H))
		return TRUE

	// Remove tattoos from the lost organ's zone
	var/removed_count = H.remove_tattoos_by_zone(removed_organ.zone)

	if(removed_count > 0)
		to_chat(H, span_notice("You feel the tattoos on your lost [removed_organ.name] fade away."))

	return TRUE
