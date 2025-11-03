#define TATTOO_LAYER_UNDER 1
#define TATTOO_LAYER_NORMAL 2
#define TATTOO_LAYER_OVER 3

/datum/tattoo
    var/artist = "Unknown Artist" // Who applied the tattoo
    var/design = "" // The tattoo design/description
    var/body_part = BODY_ZONE_CHEST
    var/color = "#000000"
    var/date_applied = ""
    var/layer = TATTOO_LAYER_NORMAL

/datum/tattoo/New(artist, design, body_part, color, layer = TATTOO_LAYER_NORMAL)
    src.artist = sanitize_text(artist, "Unknown Artist")
    src.design = sanitize_text(design, "An intricate design")
    src.body_part = body_part
    src.color = sanitize_hexcolor(color, default = "#000000")
    src.layer = sanitize_integer(layer, 1, 3, 2)
    src.date_applied = time2text(world.realtime, "YYYY-MM-DD")

/datum/tattoo/proc/get_examine_text(mob/viewer, mob/living/carbon/human/victim)
    if(!is_visible(viewer, victim))
        return ""

    // Make sure we have valid text
    var/display_design = design
    if(!display_design || display_design == "")
        display_design = "an intricate design"

    var/display_artist = artist
    if(!display_artist || display_artist == "")
        display_artist = "an unknown artist"

    // Use the enhanced body part descriptions
    var/body_part_description = get_specific_body_part_description(body_part)

    return "<span style='color:[color]'>- [body_part_description]: \"[display_design]\" (by [display_artist])</span>"

/datum/tattoo/proc/is_visible(mob/viewer, mob/living/carbon/human/victim)
    if(!victim || !viewer)
        return FALSE

    if(get_dist(viewer, victim) > 7)
        return FALSE

    // Observers and non-humans can always see
    if(!ishuman(victim) || isobserver(viewer))
        return TRUE

    // Check if the body part is covered by clothing - APPLIES TO EVERYONE INCLUDING SELF
    return !is_hidden_by_clothes(victim, viewer)

/datum/tattoo/proc/is_hidden_by_clothes(mob/living/carbon/human/target_mob, mob/viewer)
    if(!target_mob)
        return TRUE

    // Special handling for organ-based body parts
    if(body_part in list(ORGAN_SLOT_EXTERNAL_TAIL, ORGAN_SLOT_EXTERNAL_SPINES, ORGAN_SLOT_EXTERNAL_FRILLS,
                        ORGAN_SLOT_EXTERNAL_HORNS, ORGAN_SLOT_EXTERNAL_WINGS, ORGAN_SLOT_WINGS))
        // These are usually always visible unless specifically covered by certain clothing
        var/obj/item/organ/organ = target_mob.get_organ_slot(body_part)
        if(!organ)
            return TRUE

        // Check for specific clothing that might cover these features
        if(target_mob.wear_suit)
            // Some suits might cover wings/tails specifically
            if(istype(target_mob.wear_suit, /obj/item/clothing/suit) && target_mob.wear_suit.flags_inv & HIDETAIL)
                if(body_part == ORGAN_SLOT_EXTERNAL_TAIL)
                    return TRUE
            // Check for spine covering
            if(target_mob.wear_suit.flags_inv & HIDEJUMPSUIT)
                if(body_part == ORGAN_SLOT_EXTERNAL_SPINES)
                    return TRUE

        return FALSE

    var/obj/item/bodypart/BP = target_mob.get_bodypart(body_part)
    if(!BP)
        // Check if it's an organ instead
        var/obj/item/organ/organ = target_mob.get_organ_slot(body_part)
        if(!organ)
            return TRUE

    var/check_flags = body_zone_to_flag(body_part)
    if(!check_flags)
        return FALSE // If we can't map it to a flag, assume it's visible

    // STRICT clothing check - NO EXCEPTIONS
    // Check all possible clothing layers

    // Outer suit coverage
    if(target_mob.wear_suit)
        if(target_mob.wear_suit.body_parts_covered & check_flags)
            return TRUE
        // Check if suit has flags that might cover the area
        if(target_mob.wear_suit.flags_inv & HIDEJUMPSUIT)
            if(check_flags & (CHEST|GROIN|ARMS|LEGS))
                return TRUE

    // Uniform coverage
    if(target_mob.w_uniform)
        if(target_mob.w_uniform.body_parts_covered & check_flags)
            return TRUE

    // Special cases for specific clothing types
    if(istype(target_mob.wear_suit, /obj/item/clothing/suit/toggle/labcoat/hospitalgown))
        return TRUE

    // Additional clothing layers (SPLURT EDIT compatibility)
    if(target_mob.w_shirt && !target_mob.undershirt_hidden())
        if(target_mob.w_shirt.body_parts_covered & check_flags)
            return TRUE

    if(target_mob.w_underwear && !target_mob.underwear_hidden())
        if(target_mob.w_underwear.body_parts_covered & check_flags)
            return TRUE

    // Gloves for hands
    if((check_flags & (HAND_LEFT|HAND_RIGHT)) && target_mob.gloves)
        return TRUE

    // Shoes for feet
    if((check_flags & (FOOT_LEFT|FOOT_RIGHT)) && target_mob.shoes)
        return TRUE

    // Headwear for head
    if((check_flags & HEAD) && target_mob.head)
        return TRUE

    return FALSE

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
        // ADD COVERAGE FOR ORGAN SLOTS
        if(ORGAN_SLOT_BELLY) return CHEST // Stomach is covered by chest clothing
        if(ORGAN_SLOT_BUTT) return GROIN // Backside is covered by groin clothing
        if(ORGAN_SLOT_EXTERNAL_TAIL) return null // Tails are usually exposed
        if(ORGAN_SLOT_EXTERNAL_SPINES) return null // Spines are usually exposed
        if(ORGAN_SLOT_EXTERNAL_FRILLS) return null // Frills are usually exposed
        if(ORGAN_SLOT_EXTERNAL_HORNS) return null // Horns are usually exposed
        if(ORGAN_SLOT_EXTERNAL_WINGS) return null // Wings are usually exposed
        if(ORGAN_SLOT_WINGS) return null // Wings are usually exposed
        else return null

/// Returns more specific descriptions for body parts
/proc/get_specific_body_part_description(body_zone)
    switch(body_zone)
        if(BODY_ZONE_HEAD) return "head"
        if(BODY_ZONE_CHEST) return "chest"
        if(BODY_ZONE_L_ARM) return "left arm"
        if(BODY_ZONE_R_ARM) return "right arm"
        if(BODY_ZONE_L_LEG) return "left leg"
        if(BODY_ZONE_R_LEG) return "right leg"
        if(BODY_ZONE_PRECISE_L_HAND) return "left hand"
        if(BODY_ZONE_PRECISE_R_HAND) return "right hand"
        if(BODY_ZONE_PRECISE_L_FOOT) return "left foot"
        if(BODY_ZONE_PRECISE_R_FOOT) return "right foot"
        if(BODY_ZONE_PRECISE_GROIN) return "groin area"
        // ENHANCED ORGAN DESCRIPTIONS
        if(ORGAN_SLOT_BELLY) return "stomach"
        if(ORGAN_SLOT_BUTT) return "backside"
        if(ORGAN_SLOT_EXTERNAL_TAIL) return "tail"
        if(ORGAN_SLOT_EXTERNAL_SPINES) return "spine ridge"
        if(ORGAN_SLOT_EXTERNAL_FRILLS) return "head frills"
        if(ORGAN_SLOT_EXTERNAL_HORNS) return "horns"
        if(ORGAN_SLOT_EXTERNAL_WINGS) return "wings"
        if(ORGAN_SLOT_WINGS) return "wing membranes"
        else
            return get_body_zone_display_name(body_zone)

/// Converts body part descriptions back to their original defines
/proc/get_body_part_from_description(description)
    switch(description)
        if("head") return BODY_ZONE_HEAD
        if("chest") return BODY_ZONE_CHEST
        if("left arm") return BODY_ZONE_L_ARM
        if("right arm") return BODY_ZONE_R_ARM
        if("left leg") return BODY_ZONE_L_LEG
        if("right leg") return BODY_ZONE_R_LEG
        if("left hand") return BODY_ZONE_PRECISE_L_HAND
        if("right hand") return BODY_ZONE_PRECISE_R_HAND
        if("left foot") return BODY_ZONE_PRECISE_L_FOOT
        if("right foot") return BODY_ZONE_PRECISE_R_FOOT
        if("groin area") return BODY_ZONE_PRECISE_GROIN
        // REVERSE ORGAN MAPPINGS
        if("stomach") return ORGAN_SLOT_BELLY
        if("backside") return ORGAN_SLOT_BUTT
        if("tail") return ORGAN_SLOT_EXTERNAL_TAIL
        if("spine ridge") return ORGAN_SLOT_EXTERNAL_SPINES
        if("head frills") return ORGAN_SLOT_EXTERNAL_FRILLS
        if("horns") return ORGAN_SLOT_EXTERNAL_HORNS
        if("wings") return ORGAN_SLOT_EXTERNAL_WINGS
        if("wing membranes") return ORGAN_SLOT_WINGS
        else
            // Try to parse as a body zone define
            if(description in GLOB.tattooable_body_parts)
                return description
            return null
