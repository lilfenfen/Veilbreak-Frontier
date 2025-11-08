/obj/item/tattoo_kit
	name = "tattoo kit"
	desc = "A professional tattoo application kit."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	force = 0
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL

	// Configuration
	var/ink_color = "#000000"
	var/max_tattoos_per_part = 5
	var/tattoo_uses = 10
	var/tattoo_max_uses = 50

	// UI State
	var/selected_zone = BODY_ZONE_CHEST
	var/mob/living/carbon/human/current_target
	var/current_step = "select_part"
	var/selected_layer = 2

/obj/item/tattoo_kit/attack(mob/living/carbon/human/target, mob/living/user)
	if(!istype(target))
		return ..()

	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return TRUE // Stop further processing

	if(!target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[target] doesn't allow body modifications!"))
		return TRUE // Stop further processing

	current_target = target
	current_step = "select_part"
	ui_interact(user)
	return TRUE // Stop further processing

/obj/item/tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
    // Standard TGUI initialization pattern
    ui = SStgui.try_update_ui(user, src, ui)
    if(!ui)
        ui = new(user, src, "TattooKit", name)
        ui.open()

/obj/item/tattoo_kit/ui_close(mob/user, datum/tgui/ui)
	// Clear the target when the UI is closed to prevent applying tattoos to the wrong person later.
	current_target = null
	current_step = "select_part"
	return ..()

/obj/item/tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	if(!current_target)
		current_target = user

	data["target_name"] = current_target.name
	data["ink_uses"] = tattoo_uses
	data["max_uses"] = tattoo_max_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone
	data["selected_zone_name"] = get_body_zone_display_name(selected_zone)
	data["current_step"] = current_step
	data["selected_layer"] = selected_layer

	// Body parts data
	var/list/body_parts = list()
	var/list/all_parts = get_all_available_body_parts(current_target)

	for(var/zone in all_parts)
		var/list/part_info = all_parts[zone]
		var/covered = !get_location_accessible(current_target, zone)
		var/current_tattoos = length(current_target.get_tattoos(zone))

		body_parts += list(list(
			"zone" = zone,
			"name" = part_info["name"],
			"covered" = covered,
			"current_tattoos" = current_tattoos,
			"max_tattoos" = max_tattoos_per_part
		))

	data["body_parts"] = body_parts
	return data

/obj/item/tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	switch(action)
		if("select_bodypart")
			var/zone = params["zone"]
			if(!zone || !body_part_exists(current_target, zone))
				return FALSE

			if(!get_location_accessible(current_target, zone))
				var/body_part_name = get_body_zone_display_name(zone)
				to_chat(user, span_warning("[current_target == user ? "Your" : "[current_target]'s"] [body_part_name] is covered! Expose it first."))
				return FALSE

			var/current_tattoos = current_target.get_tattoos(zone)
			if(length(current_tattoos) >= max_tattoos_per_part)
				to_chat(user, span_warning("This body part already has the maximum number of tattoos! (Max: [max_tattoos_per_part])"))
				return FALSE

			selected_zone = zone
			current_step = "design_tattoo"
			. = TRUE

		if("set_layer")
			var/layer = text2num(params["layer"])
			selected_layer = sanitize_integer(layer, 1, 3, 2)
			. = TRUE

		if("change_ink_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = sanitize_hexcolor(new_color, default = "#000000")
				to_chat(user, span_notice("You change the ink color to [new_color]."))
			. = TRUE

		if("back_to_selection")
			current_step = "select_part"
			. = TRUE

		if("apply_tattoo")
			// FIXED: Correct parameter names and proper handling
			var/artist_name = params["artist"]
			var/tattoo_design = params["design"]

			// Debug logging
			world.log << "## TATTOO DEBUG: Raw params - artist_name: '[artist_name]', tattoo_design: '[tattoo_design]'"

			// Check if parameters exist and are valid
			if(isnull(artist_name) || artist_name == "")
				to_chat(user, span_warning("Please enter an artist name!"))
				return FALSE

			if(isnull(tattoo_design) || tattoo_design == "")
				to_chat(user, span_warning("Please enter a tattoo design description!"))
				return FALSE

			// Trim and validate
			var/trimmed_artist = trimtext(artist_name)
			var/trimmed_design = trimtext(tattoo_design)

			if(!length(trimmed_artist))
				to_chat(user, span_warning("Artist name cannot be empty!"))
				return FALSE

			if(!length(trimmed_design))
				to_chat(user, span_warning("Tattoo design cannot be empty!"))
				return FALSE

			// Coverage check
			if(!get_location_accessible(current_target, selected_zone))
				to_chat(user, span_warning("[current_target == user ? "Your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)] is covered! Expose it first."))
				return FALSE

			if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
				to_chat(user, span_warning("[current_target] doesn't allow body modifications!"))
				return FALSE

			// Close UI and apply
			if(ui)
				ui.close()

			to_chat(user, span_notice("You begin carefully applying the tattoo..."))

			if(do_after(user, 8 SECONDS, target = current_target))
				// Final checks
				if(!get_location_accessible(current_target, selected_zone))
					to_chat(user, span_warning("The body part became covered during application!"))
					return FALSE

				// Apply tattoo
				var/sanitized_artist = sanitize_text(trimmed_artist)
				var/sanitized_design = sanitize_text(trimmed_design)

				var/datum/tattoo/new_tattoo = new(sanitized_artist, sanitized_design, selected_zone, ink_color, selected_layer)

				if(current_target.add_tattoo(new_tattoo))
					if(current_target.client?.prefs)
						current_target.client.prefs.save_character()

					to_chat(user, span_green("Tattoo applied successfully!"))
					tattoo_uses--
					current_target.regenerate_icons()
				else
					to_chat(user, span_warning("Failed to apply tattoo!"))

			current_step = "select_part"
			. = TRUE

	return .
