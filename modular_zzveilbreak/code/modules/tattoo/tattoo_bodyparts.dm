// Global list to store all tattooable body parts
GLOBAL_LIST_INIT(tattooable_body_parts, populate_tattooable_body_parts())

// Blacklist for body zones that shouldn't be tattooable
GLOBAL_LIST_INIT(tattoo_blacklist, list(
	BODY_ZONE_PRECISE_EYES,
	BODY_ZONE_PRECISE_MOUTH,
))

/proc/populate_tattooable_body_parts()
	var/list/parts = list()

	// Scan all bodypart types for unique body_zones
	for(var/path in subtypesof(/obj/item/bodypart))
		var/obj/item/bodypart/BP = path
		var/body_zone = initial(BP.body_zone)
		if(body_zone && !(body_zone in parts) && !(body_zone in GLOB.tattoo_blacklist))
			parts |= body_zone

	// Add all known body zone defines as fallback
	var/list/fallback_zones = list(
		BODY_ZONE_HEAD,
		BODY_ZONE_CHEST,
		BODY_ZONE_L_ARM,
		BODY_ZONE_R_ARM,
		BODY_ZONE_L_LEG,
		BODY_ZONE_R_LEG,
		BODY_ZONE_PRECISE_L_HAND,
		BODY_ZONE_PRECISE_R_HAND,
		BODY_ZONE_PRECISE_L_FOOT,
		BODY_ZONE_PRECISE_R_FOOT,
		BODY_ZONE_PRECISE_GROIN,
	)

	for(var/zone in fallback_zones)
		if(!(zone in parts) && !(zone in GLOB.tattoo_blacklist))
			parts |= zone

	// Add the organ slots as tattooable body parts
	for(var/organ_slot in TATTOOABLE_ORGAN_SLOTS)
		if(!(organ_slot in parts) && !(organ_slot in GLOB.tattoo_blacklist))
			parts |= organ_slot

	// Remove any null values and sort for consistency
	parts -= null
	sortTim(parts, GLOBAL_PROC_REF(cmp_text_asc))

	return parts

/proc/get_body_zone_display_name(body_zone)
	if(!body_zone)
		return "Unknown"

	// Handle organ slots first
	switch(body_zone)
		if(ORGAN_SLOT_PENIS)
			return "Penis"
		if(ORGAN_SLOT_WOMB)
			return "Womb"
		if(ORGAN_SLOT_VAGINA)
			return "Vagina"
		if(ORGAN_SLOT_TESTICLES)
			return "Testicles"
		if(ORGAN_SLOT_BREASTS)
			return "Breasts"
		if(ORGAN_SLOT_ANUS)
			return "Anus"
		if(ORGAN_SLOT_NIPPLES)
			return "Nipples"
		if(ORGAN_SLOT_TAIL)
			return "Tail"
		if(ORGAN_SLOT_SLIT)
			return "Slit"
		if(ORGAN_SLOT_SHEATH)
			return "Sheath"
		if(ORGAN_SLOT_WINGS)
			return "Wings"

	var/name = ""
	switch(body_zone)
		if(BODY_ZONE_HEAD) name = "Head"
		if(BODY_ZONE_CHEST) name = "Chest"
		if(BODY_ZONE_L_ARM) name = "Left Arm"
		if(BODY_ZONE_R_ARM) name = "Right Arm"
		if(BODY_ZONE_L_LEG) name = "Left Leg"
		if(BODY_ZONE_R_LEG) name = "Right Leg"
		if(BODY_ZONE_PRECISE_L_HAND) name = "Left Hand"
		if(BODY_ZONE_PRECISE_R_HAND) name = "Right Hand"
		if(BODY_ZONE_PRECISE_L_FOOT) name = "Left Foot"
		if(BODY_ZONE_PRECISE_R_FOOT) name = "Right Foot"
		if(BODY_ZONE_PRECISE_GROIN) name = "Groin"
		else
			// For any custom body zones, format the text nicely
			name = replacetext(replacetext("[body_zone]", "BODY_ZONE_", ""), "_", " ")
			name = lowertext(name)
			name = capitalize(name)

	return name

/proc/get_all_available_body_parts(mob/living/carbon/human/H)
	var/list/available_parts = list()

	if(!istype(H))
		return available_parts

	// Scan through all possible tattooable body parts
	for(var/zone in GLOB.tattooable_body_parts)
		// Skip blacklisted zones
		if(zone in GLOB.tattoo_blacklist)
			continue

		var/display_name = get_body_zone_display_name(zone)
		var/exists = FALSE
		var/type = "bodypart"

		// Check if it's a standard bodypart (arms, legs, chest, head)
		var/obj/item/bodypart/BP = H.get_bodypart(zone)
		if(BP)
			exists = TRUE
		else
			// Check if it's an organ slot that exists on the mob
			var/obj/item/organ/organ = H.get_organ_slot(zone)
			if(organ)
				exists = TRUE
				type = "organ"

		if(exists)
			available_parts[zone] = list(
				"name" = display_name,
				"zone" = zone,
				"type" = type,
				"current_tattoos" = length(H.get_tattoos(zone))
			)

	return available_parts

/proc/is_valid_tattoo_bodypart(body_zone)
	return (body_zone in GLOB.tattooable_body_parts) && !(body_zone in GLOB.tattoo_blacklist)

/proc/body_part_exists(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE

	// Skip blacklisted zones
	if(body_zone in GLOB.tattoo_blacklist)
		return FALSE

	// Check standard bodypart
	if(H.get_bodypart(body_zone))
		return TRUE

	// Check organ slots
	if(H.get_organ_slot(body_zone))
		return TRUE

	return FALSE

// Special accessibility check for organ slots
/proc/get_tattoo_location_accessible(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE

	// For organ slots, we need special handling since they're not standard body parts
	if(body_zone in TATTOOABLE_ORGAN_SLOTS)
		var/obj/item/organ/organ = H.get_organ_slot(body_zone)
		if(!organ)
			return FALSE

		// For external organs, check if they're covered by clothing
		// This is a simplified check - assume external organs are visible unless specifically covered
		return TRUE

	// For standard body parts, use the existing function
	return get_location_accessible(H, body_zone)
