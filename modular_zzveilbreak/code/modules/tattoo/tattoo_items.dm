/obj/item/tattoo_kit
	name = "tattoo kit"
	desc = "A kit with all the tools necessary for losing a bet, or making otherwise incredibly indelible decisions."
	icon = 'icons/obj/maintenance_loot.dmi'
	icon_state = "tattoo_kit"
	force = 0
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	var/ink_color = "#000000"
	var/max_tattoos_per_part = 5
	var/tattoo_uses = 10
	var/tattoo_max_uses = 50

/obj/item/tattoo_kit/attack(mob/living/carbon/human/M, mob/living/user)
	if(!istype(M))
		return ..()

	if(M == user)
		to_chat(user, "<span class='warning'>You can't tattoo yourself!</span>")
		return

	// Check if target allows bodywriting
	if(!M.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, "<span class='warning'>[M] doesn't allow bodywriting!</span>")
		return

	if(tattoo_uses <= 0)
		to_chat(user, "<span class='warning'>This tattoo kit is out of ink!</span>")
		return

	var/obj/item/bodypart/target_part = M.get_bodypart(user.zone_selected)
	if(!target_part)
		to_chat(user, "<span class='warning'>No body part there!</span>")
		return

	// Check if body part is exposed for application
	var/datum/tattoo/temp_tattoo = new("temp", "temp", target_part.body_zone)
	if(temp_tattoo.is_hidden_by_clothes(M))
		to_chat(user, "<span class='warning'>You need to expose [M]'s [parse_zone(target_part.body_zone)] first!</span>")
		qdel(temp_tattoo)
		return
	qdel(temp_tattoo)

	start_tattoo_application(M, user, target_part)

/obj/item/tattoo_kit/proc/start_tattoo_application(mob/living/carbon/human/M, mob/living/user, obj/item/bodypart/target_part)
	var/current_tattoos = M.get_tattoos(target_part.body_zone)
	if(length(current_tattoos) >= max_tattoos_per_part)
		to_chat(user, "<span class='warning'>This body part already has too many tattoos! (Max: [max_tattoos_per_part])</span>")
		return

	var/tattoo_name = input(user, "Enter tattoo name:", "Tattoo Design") as text|null
	if(!tattoo_name)
		return

	var/tattoo_desc = input(user, "Enter tattoo description (supports basic HTML):", "Tattoo Design") as message|null
	if(!tattoo_desc)
		return

	tattoo_desc = sanitize(tattoo_desc, max_length = 500)

	var/layer_choice = input(user, "Select tattoo layer:", "Tattoo Layer") as null|anything in list("Under", "Normal", "Over")
	var/tattoo_layer = TATTOO_LAYER_NORMAL
	switch(layer_choice)
		if("Under") tattoo_layer = TATTOO_LAYER_UNDER
		if("Over") tattoo_layer = TATTOO_LAYER_OVER

	if(do_after(user, 50, target = M))
		var/datum/tattoo/new_tattoo = new(tattoo_name, tattoo_desc, target_part.body_zone, ink_color, user.name, tattoo_layer)
		if(M.add_tattoo(new_tattoo))
			to_chat(user, "<span class='notice'>You successfully apply the tattoo to [M]'s [parse_zone(target_part.body_zone)].</span>")
			to_chat(M, "<span class='notice'>You feel a slight sting as the tattoo is applied to your [parse_zone(target_part.body_zone)].</span>")
			tattoo_uses--
			if(tattoo_uses <= 0)
				to_chat(user, "<span class='warning'>The tattoo kit is now out of ink!</span>")
				desc = "An empty tattoo kit. All the ink has been used up."
		else
			to_chat(user, "<span class='warning'>Failed to apply the tattoo!</span>")
			qdel(new_tattoo)

/obj/item/tattoo_kit/attack_self(mob/user)
	var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
	if(new_color)
		ink_color = new_color
		to_chat(user, "<span class='notice'>You change the ink color to [ink_color].</span>")

/obj/item/tattoo_kit/examine(mob/user)
	. = ..()
	if(!tattoo_uses)
		. += "<span class='warning'>This kit has no uses left!</span>"
	else
		. += "<span class='notice'>This kit has enough ink for [tattoo_uses] use\s.</span>"
	. += "<span class='boldnotice'>You can use a toner cartridge to refill this.</span>"

/obj/item/tattoo_kit/item_interaction(mob/living/user, obj/item/toner/ink_cart, list/modifiers)
	if(!istype(ink_cart))
		return NONE
	var/added_amount = round(ink_cart.charges / 5)
	if(added_amount == 0)
		balloon_alert(user, "none left!")
		return ITEM_INTERACT_BLOCKING
	if(tattoo_uses >= tattoo_max_uses)
		balloon_alert(user, "already full!")
		return ITEM_INTERACT_BLOCKING

	added_amount = min(tattoo_uses + added_amount, tattoo_max_uses)
	tattoo_uses += min(tattoo_max_uses, added_amount)
	qdel(ink_cart)
	balloon_alert(user, "added tattoo ink")
	return ITEM_INTERACT_SUCCESS

// Advanced tattoo kit with body part selection
/obj/item/tattoo_kit/advanced
	name = "advanced tattoo kit"
	desc = "A professional-grade tattoo kit with precision tools and body part selection."
	tattoo_uses = 30
	tattoo_max_uses = 100
	max_tattoos_per_part = 10

/obj/item/tattoo_kit/advanced/examine(mob/user)
	. = list()
	. += "[icon2html(src, user)] [desc]"
	. += "It is a small item."
	if(!tattoo_uses)
		. += "<span class='warning'>This kit has no uses left!</span>"
	else
		. += "<span class='notice'>This kit has enough ink for [tattoo_uses] use\s.</span>"
	. += "<span class='boldnotice'>You can use a toner cartridge to refill this.</span>"
