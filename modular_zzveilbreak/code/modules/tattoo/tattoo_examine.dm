// modular_zzveilbreak/code/modules/tattoo/tattoo_examine.dm

// Override examine to show visible tattoos
/mob/living/carbon/human/examine(mob/user)
    . = ..()

    var/list/visible_tattoos = get_visible_tattoos(user)
    if(length(visible_tattoos))
        . += "<span class='notice'>They have visible tattoos:</span>"
        for(var/datum/tattoo/T as anything in visible_tattoos)
            var/tattoo_text = T.get_examine_text(user, src)
            if(tattoo_text)
                . += tattoo_text
