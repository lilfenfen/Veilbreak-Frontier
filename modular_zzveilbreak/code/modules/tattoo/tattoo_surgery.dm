/// Tattoo Removal Surgery
/// Allows removal of tattoos through surgical means with various tools
/// Supports multiple tattoo locations and tool types with different success rates

/datum/surgery/tattoo_removal
    name = "Tattoo Removal"
    steps = list(/datum/surgery_step/cauterize_tattoo)
    possible_locs = list(
        BODY_ZONE_HEAD,
        BODY_ZONE_CHEST,
        BODY_ZONE_L_ARM,
        BODY_ZONE_R_ARM,
        BODY_ZONE_L_LEG,
        BODY_ZONE_R_LEG
    ) // Default fallback locations

/datum/surgery/tattoo_removal/New()
    ..()
    // If the global exists and is populated, use it instead of fallback
    if(GLOB.tattooable_body_parts && length(GLOB.tattooable_body_parts))
        src.possible_locs = GLOB.tattooable_body_parts.Copy()

/datum/surgery/tattoo_removal/can_start(mob/user, mob/living/carbon/target)
    // Final check - if global is now available and we're still using fallback, upgrade
    if(GLOB.tattooable_body_parts && length(GLOB.tattooable_body_parts) && possible_locs[1] == BODY_ZONE_HEAD)
        src.possible_locs = GLOB.tattooable_body_parts.Copy()

    if(!istype(target, /mob/living/carbon/human))
        return FALSE

    var/mob/living/carbon/human/H = target

    // Check if target allows bodywriting (for removal consent)
    if(!H.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
        to_chat(user, "<span class='warning'>[H] doesn't allow bodywriting modifications!</span>")
        return FALSE

    // Check if the selected zone exists (either as bodypart or organ)
    if(!body_part_exists(H, user.zone_selected))
        return FALSE

    // Check if there are tattoos to remove in the target zone
    return length(H.get_tattoos(user.zone_selected))

// ============================================================
// SURGERY STEP: CAUTERIZE TATTOO
// ============================================================

/datum/surgery_step/cauterize_tattoo
    name = "cauterize tattoo"
    implements = list(
        /obj/item/cautery = 100,
        /obj/item/cigarette = 75,
        /obj/item/lighter = 50,
        /obj/item/weldingtool = 125,
        TOOL_SCALPEL = 25
    )
    time = 45
    var/datum/tattoo/operated_tattoo

/datum/surgery_step/cauterize_tattoo/tool_check(mob/user, obj/item/tool)
    // Check if tools need to be activated first
    if(istype(tool, /obj/item/weldingtool))
        var/obj/item/weldingtool/WT = tool
        if(!WT.welding)
            to_chat(user, "<span class='warning'>You need to turn [tool] on first!</span>")
            return FALSE

    if(istype(tool, /obj/item/lighter))
        var/obj/item/lighter/L = tool
        if(!L.lit)
            to_chat(user, "<span class='warning'>You need to light [tool] first!</span>")
            return FALSE

    if(istype(tool, /obj/item/cigarette))
        var/obj/item/cigarette/C = tool
        if(!C.lit)
            to_chat(user, "<span class='warning'>You need to light [tool] first!</span>")
            return FALSE

    return TRUE

/datum/surgery_step/cauterize_tattoo/preop(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
    if(!istype(target, /mob/living/carbon/human))
        return

    var/mob/living/carbon/human/H = target
    var/list/tattoos = H.get_tattoos(target_zone)

    // Safety check - ensure tattoos exist
    if(!length(tattoos))
        to_chat(user, "<span class='warning'>No tattoos found to remove!</span>")
        return SURGERY_STEP_FAIL

    // Handle single vs multiple tattoo selection
    var/datum/tattoo/to_remove
    if(length(tattoos) == 1)
        to_remove = tattoos[1]
    else
        var/list/tattoo_choices = list()
        for(var/datum/tattoo/T as anything in tattoos)
            tattoo_choices["[T.design] by [T.artist]"] = T
        var/choice = input(user, "Which tattoo would you like to remove?", "Tattoo Removal") as null|anything in tattoo_choices
        to_remove = tattoo_choices[choice]

    if(!to_remove)
        return SURGERY_STEP_FAIL

    operated_tattoo = to_remove

    // Generate appropriate message based on tool
    var/burn_message
    if(istype(tool, /obj/item/cautery))
        burn_message = "You begin carefully cauterizing the tattoo from [target]'s [parse_zone(target_zone)]..."
    else if(istype(tool, /obj/item/weldingtool))
        burn_message = "You begin burning away the tattoo from [target]'s [parse_zone(target_zone)] with the welding tool..."
    else if(istype(tool, /obj/item/cigarette) || istype(tool, /obj/item/lighter))
        burn_message = "You begin carefully burning the tattoo from [target]'s [parse_zone(target_zone)]..."
    else
        burn_message = "You begin scraping away the tattoo from [target]'s [parse_zone(target_zone)]..."

    display_results(
        user,
        target,
        "<span class='notice'>[burn_message]</span>",
        "<span class='notice'>[user] begins removing a tattoo from your [parse_zone(target_zone)] with [tool].</span>",
        "<span class='notice'>[user] begins working on your [parse_zone(target_zone)] with [tool].</span>"
    )

/datum/surgery_step/cauterize_tattoo/success(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery, default_display_results = FALSE)
    if(!istype(target, /mob/living/carbon/human) || !operated_tattoo)
        return FALSE

    var/mob/living/carbon/human/H = target

    // Determine success chance based on tool quality
    var/success_chance = 100
    if(istype(tool, /obj/item/weldingtool))
        success_chance = 90  // Powerful but imprecise
    else if(istype(tool, /obj/item/cautery))
        success_chance = 95  // Medical grade tool
    else if(istype(tool, /obj/item/cigarette) || istype(tool, /obj/item/lighter))
        success_chance = 70  // Improvised tools
    else if(istype(tool, TOOL_SCALPEL))
        success_chance = 60  // Not designed for this purpose

    // Check for failure
    if(!prob(success_chance))
        display_results(
            user,
            target,
            "<span class='warning'>You accidentally burn [target] badly while trying to remove the tattoo!</span>",
            "<span class='userdanger'>[user] accidentally burns you badly while trying to remove the tattoo!</span>",
            "<span class='warning'>[user] accidentally causes a bad burn on your [parse_zone(target_zone)]!</span>"
        )
        var/obj/item/bodypart/BP = H.get_bodypart(target_zone)
        if(BP)
            BP.receive_damage(burn = 15)
        return TRUE

    // Attempt tattoo removal
    if(H.remove_tattoo(operated_tattoo))
        var/success_message
        if(istype(tool, /obj/item/cautery))
            success_message = "You successfully cauterize away the tattoo."
        else if(istype(tool, /obj/item/weldingtool))
            success_message = "You successfully burn away the tattoo."
        else
            success_message = "You successfully remove the tattoo."

        display_results(
            user,
            target,
            "<span class='notice'>[success_message]</span>",
            "<span class='notice'>[user] successfully removes the tattoo from your [parse_zone(target_zone)].</span>",
            "<span class='notice'>[user] successfully works on your [parse_zone(target_zone)].</span>"
        )

        // Apply minor burn damage from the procedure
        var/obj/item/bodypart/BP = H.get_bodypart(target_zone)
        if(BP)
            BP.receive_damage(burn = 5)
        return TRUE
    else
        // Tattoo removal failed (shouldn't normally happen)
        display_results(
            user,
            target,
            "<span class='warning'>You fail to remove the tattoo!</span>",
            "<span class='warning'>[user] fails to remove the tattoo from your [parse_zone(target_zone)]!</span>",
            "<span class='warning'>[user] fails to work on your [parse_zone(target_zone)]!</span>"
        )
        return FALSE

/datum/surgery_step/cauterize_tattoo/failure(mob/user, mob/living/carbon/target, target_zone, obj/item/tool, datum/surgery/surgery)
    display_results(
        user,
        target,
        "<span class='warning'>You mess up the tattoo removal procedure!</span>",
        "<span class='userdanger'>[user] messes up the tattoo removal procedure on your [parse_zone(target_zone)]!</span>",
        "<span class='warning'>[user] messes up the procedure on your [parse_zone(target_zone)]!</span>"
    )
    var/obj/item/bodypart/BP = target.get_bodypart(target_zone)
    if(BP)
        BP.receive_damage(burn = 10)
