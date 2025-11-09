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

// CRITICAL FIX: Convert BYOND zone defines to string identifiers for TGUI
/proc/zone_to_string(zone)
	switch(zone)
		if(BODY_ZONE_HEAD) return "head"
		if(BODY_ZONE_CHEST) return "chest"
		if(BODY_ZONE_L_ARM) return "l_arm"
		if(BODY_ZONE_R_ARM) return "r_arm"
		if(BODY_ZONE_L_LEG) return "l_leg"
		if(BODY_ZONE_R_LEG) return "r_leg"
		if(BODY_ZONE_PRECISE_L_HAND) return "l_hand"
		if(BODY_ZONE_PRECISE_R_HAND) return "r_hand"
		if(BODY_ZONE_PRECISE_L_FOOT) return "l_foot"
		if(BODY_ZONE_PRECISE_R_FOOT) return "r_foot"
		if(BODY_ZONE_PRECISE_GROIN) return "groin"
		if(ORGAN_SLOT_PENIS) return "penis"
		if(ORGAN_SLOT_WOMB) return "womb"
		if(ORGAN_SLOT_VAGINA) return "vagina"
		if(ORGAN_SLOT_TESTICLES) return "testicles"
		if(ORGAN_SLOT_BREASTS) return "breasts"
		if(ORGAN_SLOT_ANUS) return "anus"
		if(ORGAN_SLOT_NIPPLES) return "nipples"
		if(ORGAN_SLOT_TAIL) return "tail"
		if(ORGAN_SLOT_SLIT) return "slit"
		if(ORGAN_SLOT_SHEATH) return "sheath"
		if(ORGAN_SLOT_WINGS) return "wings"
		else
			// Fallback: convert define to string
			var/string_zone = "[zone]"
			string_zone = replacetext(string_zone, "BODY_ZONE_", "")
			string_zone = replacetext(string_zone, "ORGAN_SLOT_", "")
			string_zone = lowertext(string_zone)
			return string_zone

// CRITICAL FIX: Convert string identifiers back to BYOND zone defines
/proc/string_to_zone(zone_string)
	switch(zone_string)
		if("head") return BODY_ZONE_HEAD
		if("chest") return BODY_ZONE_CHEST
		if("l_arm") return BODY_ZONE_L_ARM
		if("r_arm") return BODY_ZONE_R_ARM
		if("l_leg") return BODY_ZONE_L_LEG
		if("r_leg") return BODY_ZONE_R_LEG
		if("l_hand") return BODY_ZONE_PRECISE_L_HAND
		if("r_hand") return BODY_ZONE_PRECISE_R_HAND
		if("l_foot") return BODY_ZONE_PRECISE_L_FOOT
		if("r_foot") return BODY_ZONE_PRECISE_R_FOOT
		if("groin") return BODY_ZONE_PRECISE_GROIN
		if("penis") return ORGAN_SLOT_PENIS
		if("womb") return ORGAN_SLOT_WOMB
		if("vagina") return ORGAN_SLOT_VAGINA
		if("testicles") return ORGAN_SLOT_TESTICLES
		if("breasts") return ORGAN_SLOT_BREASTS
		if("anus") return ORGAN_SLOT_ANUS
		if("nipples") return ORGAN_SLOT_NIPPLES
		if("tail") return ORGAN_SLOT_TAIL
		if("slit") return ORGAN_SLOT_SLIT
		if("sheath") return ORGAN_SLOT_SHEATH
		if("wings") return ORGAN_SLOT_WINGS
		else
			// Try to find matching define
			for(var/zone in GLOB.custom_tattooable_body_parts)
				if(zone_to_string(zone) == zone_string)
					return zone
			return BODY_ZONE_CHEST // Fallback

/proc/get_all_custom_tattoo_body_parts(mob/living/carbon/human/H)
	var/list/available_parts = list()

	if(!istype(H) || QDELETED(H))
		return available_parts

	// Scan through all possible custom tattooable body parts
	for(var/zone in GLOB.custom_tattooable_body_parts)
		// Skip blacklisted zones
		if(zone in GLOB.custom_tattoo_blacklist)
			continue

		var/display_name = get_custom_tattoo_body_part_description(zone)
		var/exists = FALSE
		var/covered = TRUE

		// Check if it's a standard bodypart (arms, legs, chest, head)
		var/obj/item/bodypart/BP = H.get_bodypart(zone)
		if(BP)
			exists = TRUE
			covered = !get_custom_tattoo_location_accessible(H, zone)
		else
			// Check if it's an organ slot that exists on the mob
			var/obj/item/organ/organ = H.get_organ_slot(zone)
			if(organ)
				exists = TRUE
				covered = !get_custom_tattoo_location_accessible(H, zone)

		if(exists)
			// CRITICAL FIX: Convert BYOND define to string for TGUI
			var/string_zone = zone_to_string(zone)
			available_parts[string_zone] = list(
				"name" = display_name || "Unknown",
				"zone" = string_zone,  // LINE 136: Send string to TGUI
				"covered" = covered,
				"current_tattoos" = length(H.get_custom_tattoos(zone)),
				"max_tattoos" = CUSTOM_MAX_TATTOOS_PER_PART
			)

	return available_parts

// FIX: Removed duplicate function definition
/proc/is_custom_tattoo_bodypart_existing(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE

	// CRITICAL FIX: Convert string zone back to BYOND define for checking
	var/actual_zone = istext(body_zone) ? string_to_zone(body_zone) : body_zone

	// Skip blacklisted zones
	if(actual_zone in GLOB.custom_tattoo_blacklist)
		return FALSE

	// Check standard bodypart
	if(H.get_bodypart(actual_zone))
		return TRUE

	// Check organ slots
	if(H.get_organ_slot(actual_zone))
		return TRUE

	return FALSE

// Update other functions to handle string zones
/proc/get_custom_tattoo_location_accessible(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE

	// CRITICAL FIX: Convert string zone back to BYOND define
	var/actual_zone = istext(body_zone) ? string_to_zone(body_zone) : body_zone

	// For organ slots, we need special handling since they're not standard body parts
	if(actual_zone in CUSTOM_TATTOOABLE_ORGAN_SLOTS)
		var/obj/item/organ/organ = H.get_organ_slot(actual_zone)
		if(!organ)
			return FALSE
		// For external organs, check if they're covered by clothing
		// This is a simplified check - assume external organs are visible unless specifically covered
		return TRUE

	// For standard body parts, use the existing function
	return get_location_accessible(H, actual_zone)

/proc/is_custom_tattoo_bodypart_valid(body_zone)
	return (body_zone in GLOB.custom_tattooable_body_parts) && !(body_zone in GLOB.custom_tattoo_blacklist)

