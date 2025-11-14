// modular_zzveilbreak/code/modules/tattoo/tattoo_mob_helpers.dm
// Mob helpers for storing applied tattoos and per-zone UI data.

// Global comparator proc so sortTim can refer to it safely.
/proc/cmp_custom_tattoo_layer_asc(datum/custom_tattoo/A, datum/custom_tattoo/B)
	if(!istype(A) || !istype(B))
		return 0
	return A.layer - B.layer

/mob/living/carbon/human
	// list of applied tattoo datums
	var/list/custom_body_tattoos = list()
	// per-zone UI storage (string -> datum/custom_tattoo_ui_data)
	var/list/tattoo_ui_data = list()

// Add a tattoo datum to the mob. Returns TRUE on success.
/mob/living/carbon/human/proc/add_custom_tattoo(datum/custom_tattoo/new_tattoo)
	if(!istype(new_tattoo) || QDELETED(new_tattoo))
		return FALSE

	// Convert string zone to define if needed
	var/actual_zone = istext(new_tattoo.body_part) ? string_to_zone(new_tattoo.body_part) : new_tattoo.body_part

	if(!is_custom_tattoo_bodypart_valid(actual_zone))
		return FALSE

	if(!custom_body_tattoos)
		custom_body_tattoos = list()

	// Check if layer is already taken for this body part
	var/list/current_tattoos = get_custom_tattoos(actual_zone)
	for(var/datum/custom_tattoo/existing_tattoo in current_tattoos)
		if(existing_tattoo.layer == new_tattoo.layer)
			return FALSE // Layer already taken

	if(length(current_tattoos) >= CUSTOM_MAX_TATTOOS_PER_PART)
		return FALSE

	// Ensure the tattoo has the correct zone
	new_tattoo.body_part = actual_zone

	LAZYADD(custom_body_tattoos, new_tattoo)
	sortTim(custom_body_tattoos, GLOBAL_PROC_REF(cmp_custom_tattoo_layer_asc))

	// Save to preferences
	if(client?.prefs)
		client.prefs.save_custom_tattoo_data()

	regenerate_icons()
	return TRUE

// Remove a tattoo from the mob.
/mob/living/carbon/human/proc/remove_custom_tattoo(datum/custom_tattoo/tattoo)
	if(!tattoo || !custom_body_tattoos || !(tattoo in custom_body_tattoos))
		return FALSE

	custom_body_tattoos -= tattoo
	qdel(tattoo)

	// Save to preferences
	if(client?.prefs)
		client.prefs.save_custom_tattoo_data()

	regenerate_icons()
	return TRUE

// Get a list of tattoos for a given body zone (string or define)
/mob/living/carbon/human/proc/get_custom_tattoos(body_zone)
	. = list()
	if(!body_zone || !custom_body_tattoos)
		return .

	var/search_zone = istext(body_zone) ? string_to_zone(body_zone) : body_zone
	var/search_zone_string = zone_to_string(search_zone)
	for(var/datum/custom_tattoo/T as anything in custom_body_tattoos)
		if(QDELETED(T))
			continue
		var/tattoo_zone_string = zone_to_string(T.body_part)
		if(tattoo_zone_string == search_zone_string)
			. += T
	. = sortTim(., GLOBAL_PROC_REF(cmp_custom_tattoo_layer_asc))
	return .

// Lazy accessors for per-zone UI data
/mob/living/carbon/human/proc/get_tattoo_ui_data(zone)
	LAZYINITLIST(tattoo_ui_data)
	return tattoo_ui_data[zone]

/mob/living/carbon/human/proc/set_tattoo_ui_data(zone, datum/custom_tattoo_ui_data/data)
	if(!istype(data))
		return FALSE
	LAZYINITLIST(tattoo_ui_data)
	tattoo_ui_data[zone] = data
	return TRUE

/mob/living/carbon/human/proc/clear_tattoo_ui_data(zone)
	if(tattoo_ui_data)
		tattoo_ui_data -= zone

// Clear all UI data
/mob/living/carbon/human/proc/clear_all_tattoo_ui_data()
	tattoo_ui_data = null

// Return visible tattoos to a given viewer
/mob/living/carbon/human/proc/get_visible_custom_tattoos(mob/viewer)
	. = list()
	for(var/datum/custom_tattoo/T as anything in custom_body_tattoos)
		if(QDELETED(T))
			continue
		if(T.is_custom_tattoo_visible(viewer, src))
			. += T
	. = sortTim(., GLOBAL_PROC_REF(cmp_custom_tattoo_layer_asc))
	return .

// Get tattoo examine text for display in examine proc
/mob/living/carbon/human/proc/get_tattoo_examine_text(mob/viewer)
	var/list/visible_tattoos = get_visible_custom_tattoos(viewer)
	if(!length(visible_tattoos))
		return list()

	var/list/tattoo_text = list()
	for(var/datum/custom_tattoo/tattoo as anything in visible_tattoos)
		var/examine_text = tattoo.get_examine_text(viewer, src)
		if(examine_text)
			tattoo_text += examine_text

	return tattoo_text

// Override the human examine to include tattoos
/mob/living/carbon/human/examine(mob/user)
	. = ..()

	var/list/tattoo_examines = get_tattoo_examine_text(user)
	if(length(tattoo_examines))
		// Add spacing if there are previous entries
		if(length(.) > 0 && .[length(.)])
			. += ""
		. += span_notice("[p_they(TRUE)] [p_have()] visible tattoos:")
		. += tattoo_examines
