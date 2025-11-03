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

	// Open the TGUI interface
	open_tattoo_interface(user, M)
	return TRUE

/obj/item/tattoo_kit/attack_self(mob/user)
	var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
	if(new_color)
		ink_color = new_color
		to_chat(user, "<span class='notice'>You change the ink color to [new_color].</span>")

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
