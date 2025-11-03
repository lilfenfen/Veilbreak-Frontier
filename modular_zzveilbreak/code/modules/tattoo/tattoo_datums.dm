// modular_zzveilbreak/code/modules/tattoo/tattoo_datums.dm

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
    return "<span style='color:[color]'>Tattoo: [desc]</span>"

/datum/tattoo/proc/is_visible(mob/viewer, mob/living/carbon/human/victim)
    if(!victim || !viewer)
        return FALSE

    if(get_dist(viewer, victim) > 7)
        return FALSE

    if(!ishuman(victim) || isobserver(viewer) || victim == viewer)
        return TRUE

    return !is_hidden_by_clothes(victim)

/datum/tattoo/proc/is_hidden_by_clothes(mob/living/carbon/human/target_mob)
    var/obj/item/bodypart/BP = target_mob.get_bodypart(body_part)
    if(!BP)
        return TRUE

    // Check main clothing items
    if((target_mob.w_uniform && (target_mob.w_uniform.body_parts_covered & body_part)) || (target_mob.wear_suit && (target_mob.wear_suit.body_parts_covered & body_part)))
        return TRUE

    // Special case for hospital gown
    if(istype(target_mob.wear_suit, /obj/item/clothing/suit/toggle/labcoat/hospitalgown))
        return TRUE

    // SPLURT EDIT - Extra Inventory compatibility
    // Check undershirt
    if(target_mob.w_shirt && !target_mob.undershirt_hidden())
        if(target_mob.w_shirt.body_parts_covered & body_part)
            return TRUE

    // Check bra
    if(target_mob.w_bra && !target_mob.bra_hidden())
        if(target_mob.w_bra.body_parts_covered & body_part)
            return TRUE

    // Check underwear
    if(target_mob.w_underwear && !target_mob.underwear_hidden())
        if(target_mob.w_underwear.body_parts_covered & body_part)
            return TRUE

    // Check for head/face coverage
    if(body_part == BODY_ZONE_HEAD && (target_mob.obscured_slots & HIDEFACE))
        return TRUE

    return FALSE
