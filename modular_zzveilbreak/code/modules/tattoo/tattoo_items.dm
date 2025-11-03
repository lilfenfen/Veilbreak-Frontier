/obj/item/tattoo_kit
	name = "tattoo kit"
	desc = "A kit with all the tools necessary for losing a bet, or making otherwise incredibly indelible decisions."
	icon = 'icons/obj/maintenance_loot.dmi'
	icon_state = "tattoo_kit"
	force = 0
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	/// Current ink color
	var/ink_color = "#000000"
	/// Maximum tattoos allowed per body part
	var/max_tattoos_per_part = 5
	/// Current number of tattoo uses remaining
	var/tattoo_uses = 10
	/// Maximum tattoo uses when fully stocked
	var/tattoo_max_uses = 50
	/// Currently selected body zone
	var/selected_zone = BODY_ZONE_CHEST
	/// The mob currently being tattooed
	var/mob/living/carbon/human/current_target
	/// Current UI step
	var/current_step = "select_part"
	/// Temporary tattoo name during design
	var/tattoo_name = ""
	/// Temporary tattoo description during design
	var/tattoo_desc = ""
	/// Selected tattoo layer
	var/selected_layer = 2

/obj/item/tattoo_kit/attack(mob/living/carbon/human/target, mob/living/user)
	if(!istype(target))
		return ..()

	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return TRUE

	// Check if target allows bodywriting
	if(!target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[target] doesn't allow bodywriting!"))
		return TRUE

	current_target = target
	current_step = "select_part"
	tattoo_name = ""
	tattoo_desc = ""
	selected_layer = 2
	ui_interact(user)
	return TRUE

/obj/item/tattoo_kit/attack_self(mob/user)
	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return

	if(istype(user, /mob/living/carbon/human))
		current_target = user
		current_step = "select_part"
		tattoo_name = ""
		tattoo_desc = ""
		selected_layer = 2
		ui_interact(user)
	else
		to_chat(user, span_warning("Only humans can use this!"))

/obj/item/tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit", name)
		ui.open()

/obj/item/tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	if(!current_target)
		current_target = user

	data["target_name"] = current_target.name
	data["ink_uses"] = tattoo_uses
	data["max_uses"] = tattoo_max_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone
	data["current_step"] = current_step
	data["tattoo_name"] = tattoo_name
	data["tattoo_desc"] = tattoo_desc
	data["selected_layer"] = selected_layer

	// Get all available body parts
	var/list/body_parts = list()
	var/list/all_parts = get_all_available_body_parts(current_target)

	for(var/zone in all_parts)
		var/list/part_info = all_parts[zone]
		var/covered = FALSE

		// Check if body part is covered by clothing (only if user is not the target)
		if(user != current_target)
			var/datum/tattoo/temp_tattoo = new("temp", "temp", zone)
			covered = temp_tattoo.is_hidden_by_clothes(current_target)
			qdel(temp_tattoo)

		body_parts += list(list(
			"zone" = zone,
			"name" = part_info["name"],
			"type" = part_info["type"],
			"covered" = covered,
			"current_tattoos" = part_info["current_tattoos"],
			"max_tattoos" = max_tattoos_per_part
		))

	data["body_parts"] = body_parts

	return data

/obj/item/tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("change_zone")
			var/new_zone = params["zone"]
			if(new_zone in GLOB.tattooable_body_parts)
				selected_zone = new_zone
				. = TRUE

		if("select_bodypart")
			var/zone = params["zone"]
			if(!zone || !body_part_exists(current_target, zone))
				return

			// Check if body part is exposed (only if user is not the target)
			if(usr != current_target)
				var/datum/tattoo/temp_tattoo = new("temp", "temp", zone)
				if(temp_tattoo.is_hidden_by_clothes(current_target))
					to_chat(usr, span_warning("You need to expose [current_target]'s [get_body_zone_display_name(zone)] first!"))
					qdel(temp_tattoo)
					return
				qdel(temp_tattoo)

			// Check tattoo limit
			var/current_tattoos = current_target.get_tattoos(zone)
			if(length(current_tattoos) >= max_tattoos_per_part)
				to_chat(usr, span_warning("This body part already has too many tattoos! (Max: [max_tattoos_per_part])"))
				return

			selected_zone = zone
			current_step = "design_tattoo"
			. = TRUE

		if("update_tattoo_name")
			var/name = params["name"]
			tattoo_name = name
			SStgui.update_uis(src)
			. = TRUE

		if("update_tattoo_desc")
			var/desc = params["desc"]
			tattoo_desc = desc
			SStgui.update_uis(src)
			. = TRUE

		if("update_tattoo_layer")
			var/layer = text2num(params["layer"])
			selected_layer = layer
			SStgui.update_uis(src)
			. = TRUE

		if("apply_tattoo")
			var/apply_name = tattoo_name
			var/apply_desc = tattoo_desc
			var/apply_layer = selected_layer

			if(!apply_name || length(apply_name) == 0 || !apply_desc || length(apply_desc) == 0)
				to_chat(usr, span_warning("Please fill in both the name and description!"))
				return

			// Sanitize inputs
			apply_name = sanitize(apply_name, max_length = 100)
			apply_desc = sanitize(apply_desc, max_length = 500)

			// Ensure name and desc are not empty
			if(!apply_name || apply_name == "")
				apply_name = "Unnamed Tattoo"
			if(!apply_desc || apply_desc == "")
				apply_desc = "A tattoo design"

			// Close UI during application
			if(ui)
				ui.close()

			// Perform tattoo application
			if(do_after(usr, 5 SECONDS, target = current_target))
				var/datum/tattoo/new_tattoo = new(apply_name, apply_desc, selected_zone, ink_color, usr.name, apply_layer)
				if(current_target.add_tattoo(new_tattoo))
					to_chat(usr, span_notice("You successfully apply the tattoo to [current_target]'s [get_body_zone_display_name(selected_zone)]."))
					to_chat(current_target, span_notice("You feel a slight sting as the tattoo is applied to your [get_body_zone_display_name(selected_zone)]."))
					tattoo_uses--
					if(tattoo_uses <= 0)
						to_chat(usr, span_warning("The tattoo kit is now out of ink!"))
						desc = "An empty tattoo kit. All the ink has been used up."

					// Update examine text
					current_target.regenerate_icons()
				else
					to_chat(usr, span_warning("Failed to apply the tattoo!"))
					qdel(new_tattoo)
			else
				to_chat(usr, span_warning("Tattoo application interrupted!"))

			// Reset for next use
			current_step = "select_part"
			tattoo_name = ""
			tattoo_desc = ""
			selected_layer = 2
			. = TRUE

		if("change_ink_color")
			var/new_color = input(usr, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				to_chat(usr, span_notice("You change the ink color to [new_color]."))
			. = TRUE

		if("back_to_selection")
			current_step = "select_part"
			tattoo_name = ""
			tattoo_desc = ""
			selected_layer = 2
			. = TRUE

	return TRUE

/obj/item/tattoo_kit/examine(mob/user)
	. = ..()
	if(!tattoo_uses)
		. += span_warning("This kit has no uses left!")
	else
		. += span_notice("This kit has enough ink for [tattoo_uses] use\s.")
	. += span_boldnotice("You can use a toner cartridge to refill this.")

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
