#define TATTOO_LAYER_UNDER 1
#define TATTOO_LAYER_NORMAL 2
#define TATTOO_LAYER_OVER 3

/datum/tattoo
    var/name = "Tattoo"
    var/desc = ""
    var/body_part = BODY_ZONE_CHEST
    var/color = "#000000"
    var/creator = ""
    var/date_applied = ""
    var/layer = TATTOO_LAYER_NORMAL

/datum/tattoo/New(name, desc, body_part, color, creator, layer = TATTOO_LAYER_NORMAL)
    src.name = name
    src.desc = desc
    src.body_part = body_part
    src.color = color
    src.creator = creator
    src.layer = layer
    src.date_applied = time2text(world.realtime, "YYYY-MM-DD")

/datum/tattoo/proc/get_examine_text(mob/viewer, mob/living/carbon/human/victim)
    if(!is_visible(viewer, victim))
        return ""
    return "<span style='color:[color]'>- \"[desc]\" ([name])</span>"

/datum/tattoo/proc/is_visible(mob/viewer, mob/living/carbon/human/victim)
    if(!victim || !viewer)
        return FALSE

    if(get_dist(viewer, victim) > 7)
        return FALSE

    if(!ishuman(victim) || isobserver(viewer) || victim == viewer)
        return TRUE

    // Always show tattoos to the person who has them, regardless of clothing
    if(victim == viewer)
        return TRUE

    return !is_hidden_by_clothes(victim)

/datum/tattoo/proc/is_hidden_by_clothes(mob/living/carbon/human/target_mob)
    // If it's the person looking at themselves, always show tattoos
    if(target_mob == usr)
        return FALSE

    var/obj/item/bodypart/BP = target_mob.get_bodypart(body_part)
    if(!BP)
        return TRUE

    // Convert body_zone to bodypart flag for coverage checking
    var/check_flags = body_zone_to_flag(body_part)

    if(!check_flags)
        return FALSE // If we can't map it to a flag, assume it's visible

    // Check clothing coverage
    if(target_mob.w_uniform && (target_mob.w_uniform.body_parts_covered & check_flags))
        return TRUE
    if(target_mob.wear_suit && (target_mob.wear_suit.body_parts_covered & check_flags))
        return TRUE

    // Special case for hospital gown
    if(istype(target_mob.wear_suit, /obj/item/clothing/suit/toggle/labcoat/hospitalgown))
        return TRUE

    // SPLURT EDIT - Extra Inventory compatibility
    if(target_mob.w_shirt && !target_mob.undershirt_hidden() && (target_mob.w_shirt.body_parts_covered & check_flags))
        return TRUE
    if(target_mob.w_bra && !target_mob.bra_hidden() && (target_mob.w_bra.body_parts_covered & check_flags))
        return TRUE
    if(target_mob.w_underwear && !target_mob.underwear_hidden() && (target_mob.w_underwear.body_parts_covered & check_flags))
        return TRUE

    return FALSE

// Helper proc to convert body_zone to clothing coverage flags
/proc/body_zone_to_flag(body_zone)
    switch(body_zone)
        if(BODY_ZONE_HEAD) return HEAD
        if(BODY_ZONE_CHEST) return CHEST
        if(BODY_ZONE_L_ARM) return ARM_LEFT
        if(BODY_ZONE_R_ARM) return ARM_RIGHT
        if(BODY_ZONE_L_LEG) return LEG_LEFT
        if(BODY_ZONE_R_LEG) return LEG_RIGHT
        if(BODY_ZONE_PRECISE_L_HAND) return HAND_LEFT
        if(BODY_ZONE_PRECISE_R_HAND) return HAND_RIGHT
        if(BODY_ZONE_PRECISE_L_FOOT) return FOOT_LEFT
        if(BODY_ZONE_PRECISE_R_FOOT) return FOOT_RIGHT
        if(BODY_ZONE_PRECISE_GROIN) return GROIN
        // For custom zones, try to be permissive
        else return null
