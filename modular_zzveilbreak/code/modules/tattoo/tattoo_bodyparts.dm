// Custom Tattoo System Body Parts - COMPLETELY SEPARATE

// Global list to store all custom tattooable body parts
GLOBAL_LIST_INIT(custom_tattooable_body_parts, populate_custom_tattooable_body_parts())

// Blacklist for body zones that shouldn't be tattooable
GLOBAL_LIST_INIT(custom_tattoo_blacklist, list(
	BODY_ZONE_PRECISE_EYES,
	BODY_ZONE_PRECISE_MOUTH,
))

/proc/populate_custom_tattooable_body_parts()
	var/list/parts = list()

	// Scan all bodypart types for unique body_zones
	for(var/path in subtypesof(/obj/item/bodypart))
		var/obj/item/bodypart/BP = path
		var/body_zone = initial(BP.body_zone)
		if(body_zone && !(body_zone in parts) && !(body_zone in GLOB.custom_tattoo_blacklist))
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
		if(!(zone in parts) && !(zone in GLOB.custom_tattoo_blacklist))
			parts |= zone

	// Add the organ slots as tattooable body parts
	for(var/organ_slot in CUSTOM_TATTOOABLE_ORGAN_SLOTS)
		if(!(organ_slot in parts) && !(organ_slot in GLOB.custom_tattoo_blacklist))
			parts |= organ_slot

	// Remove any null values and sort for consistency
	parts -= null
	sortTim(parts, GLOBAL_PROC_REF(cmp_text_asc))

	return parts

/proc/get_all_custom_tattoo_body_parts(mob/living/carbon/human/H)
	var/list/available_parts = list()

	if(!istype(H))
		return available_parts

	// Scan through all possible custom tattooable body parts
	for(var/zone in GLOB.custom_tattooable_body_parts)
		// Skip blacklisted zones
		if(zone in GLOB.custom_tattoo_blacklist)
			continue

		var/display_name = get_custom_tattoo_body_part_description(zone)
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
				"current_tattoos" = length(H.get_custom_tattoos(zone))
			)

	return available_parts

/proc/is_custom_tattoo_bodypart_valid(body_zone)
	return (body_zone in GLOB.custom_tattooable_body_parts) && !(body_zone in GLOB.custom_tattoo_blacklist)

/proc/is_custom_tattoo_bodypart_existing(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE

	// Skip blacklisted zones
	if(body_zone in GLOB.custom_tattoo_blacklist)
		return FALSE

	// Check standard bodypart
	if(H.get_bodypart(body_zone))
		return TRUE

	// Check organ slots
	if(H.get_organ_slot(body_zone))
		return TRUE

	return FALSE

// Special accessibility check for organ slots
/proc/get_custom_tattoo_location_accessible(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE

	// For organ slots, we need special handling since they're not standard body parts
	if(body_zone in CUSTOM_TATTOOABLE_ORGAN_SLOTS)
		var/obj/item/organ/organ = H.get_organ_slot(body_zone)
		if(!organ)
			return FALSE

		// For external organs, check if they're covered by clothing
		// This is a simplified check - assume external organs are visible unless specifically covered
		return TRUE

	// For standard body parts, use the existing function
	return get_location_accessible(H, body_zone)

// Helper proc to check if a bodypart exists on a human
/proc/body_part_exists(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE
	return H.get_bodypart(body_zone) || H.get_organ_slot(body_zone)

// Helper proc to get body zone display name
/proc/get_body_zone_display_name(body_zone)
	return get_custom_tattoo_body_part_description(body_zone)
