// modular_zzveilbreak/code/modules/tattoo/tattoo_bodyparts.dm

// Global list to store all tattooable body parts
GLOBAL_LIST_INIT(tattooable_body_parts, populate_tattooable_body_parts())

/proc/populate_tattooable_body_parts()
    var/list/parts = list()

    // Simply scan all bodypart types and collect their body_zone values
    for(var/path in subtypesof(/obj/item/bodypart))
        var/obj/item/bodypart/BP = path
        var/body_zone = initial(BP.body_zone)
        if(body_zone && !(body_zone in parts))
            parts |= body_zone

    return parts

/proc/get_body_zone_display_name(body_zone)
    // Convert body zone to readable name
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
        else
            // For any custom body zones, format the text nicely
            name = replacetext(replacetext("[body_zone]", "BODY_ZONE_", ""), "_", " ")
            name = lowertext(name)
            name = capitalize(name)

    return name

/proc/get_available_body_parts(mob/living/carbon/human/H)
    var/list/available_parts = list()

    // Simply use all tattooable body parts that exist on the human
    for(var/zone in GLOB.tattooable_body_parts)
        var/obj/item/bodypart/BP = H?.get_bodypart(zone)
        if(BP)
            available_parts[get_body_zone_display_name(zone)] = zone

    return available_parts

/proc/is_valid_tattoo_bodypart(body_zone)
    return body_zone in GLOB.tattooable_body_parts
