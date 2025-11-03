// modular_zzveilbreak/code/modules/tattoo/tattoo_surgery.dm

/datum/surgery/tattoo_removal
    name = "Tattoo Removal"
    steps = list(/datum/surgery_step/cauterize_tattoo)
    possible_locs = list()

/datum/surgery/tattoo_removal/New()
    ..()
    src.possible_locs = GLOB.tattooable_body_parts.Copy()

/datum/surgery/tattoo_removal/can_start(mob/user, mob/living/carbon/target)
    if(!istype(target, /mob/living/carbon/human))
        return FALSE

    var/mob/living/carbon/human/H = target

    // Check if target allows bodywriting (for removal consent)
    if(!H.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
        to_chat(user, "<span class='warning'>[H] doesn't allow bodywriting modifications!</span>")
        return FALSE

    var/obj/item/bodypart/BP = H.get_bodypart(user.zone_selected)
    return BP && length(H.get_tattoos(BP.body_zone))

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
    if(!length(tattoos))
        to_chat(user, "<span class='warning'>No tattoos found to remove!</span>")
        return SURGERY_STEP_FAIL
    var/datum/tattoo/to_remove
    if(length(tattoos) == 1)
        to_remove = tattoos[1]
    else
        var/list/tattoo_choices = list()
        for(var/datum/tattoo/T as anything in tattoos)
            tattoo_choices["[T.name] - [T.desc]"] = T
        var/choice = input(user, "Which tattoo would you like to remove?", "Tattoo Removal") as null|anything in tattoo_choices
        to_remove = tattoo_choices[choice]
    if(!to_remove)
        return SURGERY_STEP_FAIL
    operated_tattoo = to_remove
    var/burn_message
    if(istype(tool, /obj/item/cautery))
        burn_message = "You begin carefully cauterizing the '[to_remove.name]' tattoo from [target]'s [parse_zone(target_zone)]..."
    else if(istype(tool, /obj/item/weldingtool))
        burn_message = "You begin burning away the '[to_remove.name]' tattoo from [target]'s [parse_zone(target_zone)] with the welding tool..."
    else if(istype(tool, /obj/item/cigarette) || istype(tool, /obj/item/lighter))
        burn_message = "You begin carefully burning the '[to_remove.name]' tattoo from [target]'s [parse_zone(target_zone)]..."
    else
        burn_message = "You begin scraping away the '[to_remove.name]' tattoo from [target]'s [parse_zone(target_zone)]..."
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
    var/success_chance = 100
    if(istype(tool, /obj/item/weldingtool))
        success_chance = 90
    else if(istype(tool, /obj/item/cautery))
        success_chance = 95
    else if(istype(tool, /obj/item/cigarette) || istype(tool, /obj/item/lighter))
        success_chance = 70
    else if(istype(tool, TOOL_SCALPEL))
        success_chance = 60
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
    if(H.remove_tattoo(operated_tattoo))
        var/success_message
        if(istype(tool, /obj/item/cautery))
            success_message = "You successfully cauterize away the '[operated_tattoo.name]' tattoo."
        else if(istype(tool, /obj/item/weldingtool))
            success_message = "You successfully burn away the '[operated_tattoo.name]' tattoo."
        else
            success_message = "You successfully remove the '[operated_tattoo.name]' tattoo."
        display_results(
            user,
            target,
            "<span class='notice'>[success_message]</span>",
            "<span class='notice'>[user] successfully removes the tattoo from your [parse_zone(target_zone)].</span>",
            "<span class='notice'>[user] successfully works on your [parse_zone(target_zone)].</span>"
        )
        var/obj/item/bodypart/BP = H.get_bodypart(target_zone)
        if(BP)
            BP.receive_damage(burn = 5)
        return TRUE
    else
        display_results(
            user,
            target,
            "<span class='warning'>You fail to remove the tattoo!</span>",
            "<span class='warning'>[user] fails to remove the tattoo from your [parse_zone(target_zone)]!</span>",
            "<span class='warning'>[user] fails to work on your [parse_zone(target_zone)]!</span>"
        )
        return FALSE
