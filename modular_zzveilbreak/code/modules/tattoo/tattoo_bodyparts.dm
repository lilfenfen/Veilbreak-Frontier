// modular_zzveilbreak/code/modules/tattoo/tattoo_bodyparts.dm
// Body part discovery and conversion helpers with common sense coverage

GLOBAL_LIST_INIT(custom_tattooable_body_parts, populate_custom_tattooable_body_parts())
GLOBAL_LIST_INIT(custom_tattoo_blacklist, list(
	BODY_ZONE_PRECISE_EYES,
	BODY_ZONE_PRECISE_MOUTH,
))

// Common sense coverage relationships - if parent is covered, children are covered
GLOBAL_LIST_INIT(coverage_relationships, list(
	// Torso covers chest, belly, breasts, nipples
	BODY_ZONE_CHEST = list(ORGAN_SLOT_BELLY, ORGAN_SLOT_BREASTS, ORGAN_SLOT_NIPPLES),
	// Groin covers genitals and backside
	BODY_ZONE_PRECISE_GROIN = list(
		ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_TESTICLES,
		ORGAN_SLOT_ANUS, ORGAN_SLOT_BUTT, ORGAN_SLOT_WOMB,
		ORGAN_SLOT_SLIT, ORGAN_SLOT_SHEATH
	),
	// Arms cover hands
	BODY_ZONE_L_ARM = list(BODY_ZONE_PRECISE_L_HAND),
	BODY_ZONE_R_ARM = list(BODY_ZONE_PRECISE_R_HAND),
	// Legs cover feet
	BODY_ZONE_L_LEG = list(BODY_ZONE_PRECISE_L_FOOT),
	BODY_ZONE_R_LEG = list(BODY_ZONE_PRECISE_R_FOOT),
))

// Cache for body parts per mob
GLOBAL_LIST_EMPTY(cached_body_parts)

/proc/populate_custom_tattooable_body_parts()
	var/list/parts = list()
	for(var/path in subtypesof(/obj/item/bodypart))
		var/obj/item/bodypart/BP = path
		var/body_zone = initial(BP.body_zone)
		if(body_zone && !(body_zone in parts) && !(body_zone in GLOB.custom_tattoo_blacklist))
			parts |= body_zone

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

	for(var/organ_slot in CUSTOM_TATTOOABLE_ORGAN_SLOTS)
		if(!(organ_slot in parts) && !(organ_slot in GLOB.custom_tattoo_blacklist))
			parts |= organ_slot

	parts -= null
	sortTim(parts, GLOBAL_PROC_REF(cmp_text_asc))
	return parts

/proc/zone_to_string(zone)
	if(isnull(zone))
		return "chest"
	if(istext(zone))
		return zone
	switch(zone)
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
		if(ORGAN_SLOT_BUTT) return "butt"
		if(ORGAN_SLOT_BELLY) return "belly"
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
		else
			return "chest"

/proc/string_to_zone(zone_string)
	if(!zone_string || !istext(zone_string))
		return BODY_ZONE_CHEST
	var/clean_zone = lowertext(zone_string)
	switch(clean_zone)
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
		if("butt") return ORGAN_SLOT_BUTT
		if("belly") return ORGAN_SLOT_BELLY
		else
			return BODY_ZONE_CHEST

/proc/is_custom_tattoo_bodypart_existing(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE
	var/actual_zone = istext(body_zone) ? string_to_zone(body_zone) : body_zone
	if(!actual_zone)
		return FALSE
	if(actual_zone in GLOB.custom_tattoo_blacklist)
		return FALSE
	if(H.get_bodypart(actual_zone))
		return TRUE
	if(H.get_organ_slot(actual_zone))
		return TRUE
	return FALSE

// Enhanced coverage checking with common sense relationships
/proc/get_custom_tattoo_location_accessible(mob/living/carbon/human/H, body_zone)
	if(!istype(H) || !body_zone)
		return FALSE
	var/actual_zone = istext(body_zone) ? string_to_zone(body_zone) : body_zone
	if(!actual_zone)
		return FALSE

	// Check if this zone is covered by any parent zone
	for(var/parent_zone in GLOB.coverage_relationships)
		var/list/children = GLOB.coverage_relationships[parent_zone]
		if(actual_zone in children)
			// If parent zone is covered, this child zone is also covered
			if(!get_location_accessible(H, parent_zone))
				return FALSE

	// Special handling for organ slots
	if(actual_zone in CUSTOM_TATTOOABLE_ORGAN_SLOTS)
		var/obj/item/organ/organ = H.get_organ_slot(actual_zone)
		if(!organ)
			return FALSE
		// For organs, check if the general area is accessible
		switch(actual_zone)
			if(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_TESTICLES, ORGAN_SLOT_ANUS, ORGAN_SLOT_BUTT, ORGAN_SLOT_WOMB, ORGAN_SLOT_SLIT, ORGAN_SLOT_SHEATH)
				return get_location_accessible(H, BODY_ZONE_PRECISE_GROIN)
			if(ORGAN_SLOT_BREASTS, ORGAN_SLOT_NIPPLES, ORGAN_SLOT_BELLY)
				return get_location_accessible(H, BODY_ZONE_CHEST)
			else
				return TRUE

	return get_location_accessible(H, actual_zone)

/proc/is_custom_tattoo_bodypart_valid(body_zone)
	return (body_zone in GLOB.custom_tattooable_body_parts) && !(body_zone in GLOB.custom_tattoo_blacklist)

/proc/get_all_custom_tattoo_body_parts(mob/living/carbon/human/H)
	if(!istype(H) || QDELETED(H))
		return list()

	// Simple cache key based on the mob's reference
	var/cache_key = REF(H)
	if(GLOB.cached_body_parts[cache_key])
		return GLOB.cached_body_parts[cache_key]

	var/list/available_parts = list()
	for(var/zone in GLOB.custom_tattooable_body_parts)
		if(zone in GLOB.custom_tattoo_blacklist)
			continue

		var/display_name = get_custom_tattoo_body_part_description(zone)
		var/exists = FALSE
		var/covered = TRUE
		var/obj/item/bodypart/BP = H.get_bodypart(zone)

		if(BP)
			exists = TRUE
			covered = !get_custom_tattoo_location_accessible(H, zone)
		else
			var/obj/item/organ/organ = H.get_organ_slot(zone)
			if(organ)
				exists = TRUE
				covered = !get_custom_tattoo_location_accessible(H, zone)

		if(exists)
			var/string_zone = zone_to_string(zone)
			if(!string_zone || !istext(string_zone))
				continue
			var/current_tattoos = length(H.get_custom_tattoos(string_zone))
			available_parts[string_zone] = list(
				"name" = display_name || "Unknown Body Part",
				"zone" = string_zone,
				"covered" = covered,
				"current_tattoos" = current_tattoos,
				"max_tattoos" = CUSTOM_MAX_TATTOOS_PER_PART
			)

	// Cache for a short time (5 seconds)
	GLOB.cached_body_parts[cache_key] = available_parts
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(clear_body_part_cache), cache_key), 5 SECONDS)

	return available_parts

/proc/clear_body_part_cache(cache_key)
	GLOB.cached_body_parts -= cache_key
