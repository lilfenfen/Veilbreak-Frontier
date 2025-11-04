// TGUI for tattoo kit following surgery initiator pattern
/datum/tgui_module/tattoo_kit
	var/mob/living/carbon/human/target
	var/obj/item/tattoo_kit/kit
	var/mob/user
	var/selected_zone = BODY_ZONE_CHEST
	var/current_step = "select_part"
	var/datum/tgui/ui

/datum/tgui_module/tattoo_kit/New(_user, _kit, _target)
	user = _user
	kit = _kit
	target = _target

/datum/tgui_module/tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	data["target_name"] = target.name
	data["ink_uses"] = kit.tattoo_uses
	data["max_uses"] = kit.tattoo_max_uses
	data["ink_color"] = kit.ink_color
	data["selected_zone"] = selected_zone
	data["current_step"] = current_step

	// Get all available body parts for the selected zone
	var/list/body_parts = list()
	var/list/all_parts = get_all_available_body_parts(target)

	for(var/zone in all_parts)
		var/list/part_info = all_parts[zone]
		if(zone == selected_zone)
			var/covered = FALSE

			// Check if the body part is covered by clothing
			if(user != target)
				var/datum/tattoo/temp_tattoo = new("temp", "temp", zone)
				covered = temp_tattoo.is_hidden_by_clothes(target)
				qdel(temp_tattoo)

			body_parts += list(list(
				"zone" = zone,
				"name" = part_info["name"],
				"type" = part_info["type"],
				"covered" = covered,
				"current_tattoos" = part_info["current_tattoos"],
				"max_tattoos" = kit.max_tattoos_per_part
			))

	data["body_parts"] = body_parts

	return data

/datum/tgui_module/tattoo_kit/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	switch(action)
		if("change_zone")
			var/new_zone = params["new_zone"]
			if(new_zone in GLOB.tattooable_body_parts)
				selected_zone = new_zone
				. = TRUE

		if("select_bodypart")
			var/zone = params["zone"]
			if(!zone || !body_part_exists(target, zone))
				return

			// Check if body part is exposed (only if user is not the target)
			if(user != target)
				var/datum/tattoo/temp_tattoo = new("temp", "temp", zone)
				if(temp_tattoo.is_hidden_by_clothes(target))
					to_chat(user, "<span class='warning'>You need to expose [target]'s [get_body_zone_display_name(zone)] first!</span>")
					qdel(temp_tattoo)
					return
				qdel(temp_tattoo)

			// Check if body part has reached tattoo limit
			var/current_tattoos = target.get_tattoos(zone)
			if(length(current_tattoos) >= kit.max_tattoos_per_part)
				to_chat(user, "<span class='warning'>This body part already has too many tattoos! (Max: [kit.max_tattoos_per_part])</span>")
				return

			selected_zone = zone
			current_step = "design_tattoo"
			. = TRUE

		if("design_tattoo")
			var/tattoo_name = params["name"]
			var/tattoo_desc = params["desc"]
			var/tattoo_layer = text2num(params["layer"])

			if(!tattoo_name || !tattoo_desc || !selected_zone)
				return

			// Sanitize inputs
			tattoo_name = sanitize(tattoo_name, max_length = 100)
			tattoo_desc = sanitize(tattoo_desc, max_length = 500)

			// Close UI during application
			if(src.ui)
				src.ui.close()

			// Perform the tattoo application with do_after
			if(do_after(user, 50, target = target))
				var/datum/tattoo/new_tattoo = new(tattoo_name, tattoo_desc, selected_zone, kit.ink_color, user.name, tattoo_layer)
				if(target.add_tattoo(new_tattoo))
					to_chat(user, "<span class='notice'>You successfully apply the tattoo to [target]'s [get_body_zone_display_name(selected_zone)].</span>")
					to_chat(target, "<span class='notice'>You feel a slight sting as the tattoo is applied to your [get_body_zone_display_name(selected_zone)].</span>")
					kit.tattoo_uses--
					if(kit.tattoo_uses <= 0)
						to_chat(user, "<span class='warning'>The tattoo kit is now out of ink!</span>")
						kit.desc = "An empty tattoo kit. All the ink has been used up."

					// Force update the examine text
					target.regenerate_icons()
				else
					to_chat(user, "<span class='warning'>Failed to apply the tattoo!</span>")
					qdel(new_tattoo)
			else
				to_chat(user, "<span class='warning'>Tattoo application interrupted!</span>")

			// Reset for next use
			selected_zone = BODY_ZONE_CHEST
			current_step = "select_part"
			. = TRUE

		if("change_ink_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", kit.ink_color) as color|null
			if(new_color)
				kit.ink_color = new_color
				to_chat(user, "<span class='notice'>You change the ink color to [new_color].</span>")
			. = TRUE

		if("back_to_selection")
			current_step = "select_part"
			. = TRUE

/datum/tgui_module/tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	src.ui = ui
	ui.open()

// Proc to open the tattoo kit UI
/obj/item/tattoo_kit/proc/open_tattoo_interface(mob/user, mob/living/carbon/human/target)
	if(!user || !target)
		return

	if(tattoo_uses <= 0)
		to_chat(user, "<span class='warning'>This tattoo kit is out of ink!</span>")
		return

	// Check if target allows bodywriting
	if(!target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, "<span class='warning'>[target] doesn't allow bodywriting!</span>")
		return

	var/datum/tgui_module/tattoo_kit/tattoo_ui = new(user, src, target)
	tattoo_ui.ui_interact(user)
