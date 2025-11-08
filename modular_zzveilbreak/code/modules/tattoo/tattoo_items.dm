/obj/item/tattoo_kit
	name = "tattoo kit"
	desc = "A professional tattoo application kit."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	force = 0
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL

	var/ink_color = "#000000"
	var/max_tattoos_per_part = MAX_TATTOOS_PER_PART
	var/tattoo_uses = 10
	var/tattoo_max_uses = 50

	var/selected_zone = BODY_ZONE_CHEST
	var/mob/living/carbon/human/current_target
	var/current_step = "select_part"
	var/selected_layer = TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT
	var/artist_name = ""
	var/tattoo_design = ""

/obj/item/tattoo_kit/proc/reset_ui_state()
	selected_zone = BODY_ZONE_CHEST
	current_step = "select_part"
	selected_layer = TATTOO_LAYER_NORMAL
	current_target = null
	artist_name = ""
	tattoo_design = ""
	selected_font = PEN_FONT

/obj/item/tattoo_kit/attack(mob/living/carbon/human/target, mob/living/user)
	if(!istype(target))
		return ..()

	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return TRUE

	if(!target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[target] doesn't allow body modifications!"))
		return TRUE

	current_target = target
	current_step = "select_part"
	ui_interact(user)
	return TRUE

/obj/item/tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit", name)
		ui.open()

/obj/item/tattoo_kit/ui_close(mob/user, datum/tgui/ui)
	// Don't reset state on close - allow reopening to continue where left off
	return ..()

/obj/item/tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	if(!current_target && istype(user, /mob/living/carbon/human))
		current_target = user

	if(!current_target)
		data["target_name"] = "No target"
		data["ink_uses"] = tattoo_uses
		data["max_uses"] = tattoo_max_uses
		data["ink_color"] = ink_color
		data["selected_zone"] = selected_zone
		data["selected_zone_name"] = "Unknown"
		data["current_step"] = current_step
		data["selected_layer"] = selected_layer
		data["selected_font"] = selected_font
		data["artist_name"] = artist_name
		data["tattoo_design"] = tattoo_design
		data["body_parts"] = list()
		data["preview_text"] = ""
		return data

	data["target_name"] = current_target.name
	data["ink_uses"] = tattoo_uses
	data["max_uses"] = tattoo_max_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone
	data["selected_zone_name"] = get_body_zone_display_name(selected_zone)
	data["current_step"] = current_step
	data["selected_layer"] = selected_layer
	data["selected_font"] = selected_font
	data["artist_name"] = artist_name
	data["tattoo_design"] = tattoo_design

	var/list/body_parts = list()
	var/list/all_parts = get_all_available_body_parts(current_target)

	for(var/zone in all_parts)
		var/list/part_info = all_parts[zone]
		var/covered = !get_tattoo_location_accessible(current_target, zone)
		var/current_tattoos = length(current_target.get_tattoos(zone))

		body_parts += list(list(
			"zone" = zone,
			"name" = part_info["name"],
			"covered" = covered,
			"current_tattoos" = current_tattoos,
			"max_tattoos" = max_tattoos_per_part
		))

	data["body_parts"] = body_parts

	// Generate preview data
	data["preview_text"] = generate_preview_text()

	return data

/obj/item/tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	switch(action)
		if("select_bodypart")
			var/zone = params["zone"]
			if(!zone || !current_target || !body_part_exists(current_target, zone))
				return FALSE

			if(!get_tattoo_location_accessible(current_target, zone))
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
			if(isnum(layer))
				selected_layer = sanitize_integer(layer, TATTOO_LAYER_UNDER, TATTOO_LAYER_OVER, TATTOO_LAYER_NORMAL)
				. = TRUE

		if("set_font")
			var/font = params["font"]
			if(font && (font in GLOB.tattoo_fonts))
				selected_font = font
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

		if("set_artist_name")
			var/new_name = params["value"]
			if(new_name)
				artist_name = sanitize_text(new_name)
				. = TRUE

		if("set_tattoo_design")
			var/new_design = params["value"]
			if(new_design)
				tattoo_design = sanitize_text(new_design)
				. = TRUE

		if("apply_tattoo")
			var/artist_name_param = params["artist"]
			var/tattoo_design_param = params["design"]
			var/layer_param = text2num(params["layer"])
			var/font_param = params["font"]

			// Enhanced validation like fax machine
			if(!artist_name_param || !istext(artist_name_param) || artist_name_param == "")
				to_chat(user, span_warning("Please enter a valid artist name!"))
				return FALSE

			if(!tattoo_design_param || !istext(tattoo_design_param) || tattoo_design_param == "")
				to_chat(user, span_warning("Please enter a valid tattoo design description!"))
				return FALSE

			var/trimmed_artist = trimtext(artist_name_param)
			var/trimmed_design = trimtext(tattoo_design_param)

			if(!length(trimmed_artist))
				to_chat(user, span_warning("Artist name cannot be empty or just spaces!"))
				return FALSE

			if(!length(trimmed_design))
				to_chat(user, span_warning("Tattoo design cannot be empty or just spaces!"))
				return FALSE

			if(length(trimmed_artist) > 50)
				to_chat(user, span_warning("Artist name is too long! Maximum 50 characters."))
				return FALSE

			if(length(trimmed_design) > 500)
				to_chat(user, span_warning("Tattoo design is too long! Maximum 500 characters."))
				return FALSE

			if(!current_target)
				to_chat(user, span_warning("No target found for tattoo application!"))
				return FALSE

			if(!get_tattoo_location_accessible(current_target, selected_zone))
				to_chat(user, span_warning("[current_target == user ? "Your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)] is covered! Expose it first."))
				return FALSE

			if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
				to_chat(user, span_warning("[current_target] doesn't allow body modifications!"))
				return FALSE

			if(tattoo_uses <= 0)
				to_chat(user, span_warning("This tattoo kit is out of ink!"))
				return FALSE

			if(ui && !QDELETED(ui))
				ui.close()

			to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [get_body_zone_display_name(selected_zone)]..."))

			if(do_after(user, TATTOO_APPLICATION_TIME, target = current_target))
				if(!current_target || QDELETED(current_target))
					to_chat(user, span_warning("The target is no longer valid!"))
					return FALSE

				if(!get_tattoo_location_accessible(current_target, selected_zone))
					to_chat(user, span_warning("The body part became covered during application!"))
					return FALSE

				if(tattoo_uses <= 0)
					to_chat(user, span_warning("The tattoo kit ran out of ink during application!"))
					return FALSE

				if(!user.is_holding(src))
					to_chat(user, span_warning("You must be holding the tattoo kit to apply a tattoo!"))
					return FALSE

				// Handle signature placeholders like paper system
				var/list/processed_data = process_signature_placeholders(trimmed_artist, user)
				var/final_artist = processed_data["text"]
				var/is_signature = processed_data["is_signature"]

				var/sanitized_artist = sanitize_text(final_artist)
				var/sanitized_design = sanitize_text(trimmed_design)
				var/sanitized_layer = sanitize_integer(layer_param, TATTOO_LAYER_UNDER, TATTOO_LAYER_OVER, selected_layer)
				var/sanitized_font = (font_param in GLOB.tattoo_fonts) ? font_param : selected_font

				var/datum/tattoo/new_tattoo = new(sanitized_artist, sanitized_design, selected_zone, ink_color, sanitized_layer, is_signature, sanitized_font)

				if(current_target.add_tattoo(new_tattoo))
					if(current_target.client?.prefs)
						current_target.client.prefs.save_character()
					to_chat(user, span_green("Tattoo applied successfully to [current_target]'s [get_body_zone_display_name(selected_zone)]!"))
					tattoo_uses = max(0, tattoo_uses - 1)
					current_target.regenerate_icons()

					user.log_message("applied tattoo '[sanitized_design]' by [sanitized_artist] to [current_target]'s [selected_zone]", LOG_GAME)
				else
					to_chat(user, span_warning("Failed to apply tattoo! The body part may have reached its tattoo limit."))
			else
				to_chat(user, span_warning("Tattoo application interrupted!"))

			// Reset state after successful application
			current_step = "select_part"
			artist_name = ""
			tattoo_design = ""
			selected_font = PEN_FONT
			. = TRUE

	return .

/**
 * Processes signature placeholders in the artist name, similar to the paper system.
 * Replaces %s and %sign with the user's real name, and handles date/time placeholders.
 * Returns a list containing the processed text and whether it's a signature.
 *
 * Arguments:
 * * text - The text to process for placeholders
 * * user - The mob whose signature should be used
 */
/obj/item/tattoo_kit/proc/process_signature_placeholders(text, mob/user)
	if(!text || !user)
		return list("text" = text, "is_signature" = FALSE)

	var/processed_text = text
	var/is_signature = FALSE

	// Handle signature placeholders
	if((processed_text == "%sign") || (processed_text == "%s"))
		processed_text = user.real_name
		is_signature = TRUE

	// Handle date and time placeholders for consistency with paper system
	else if((processed_text == "%date") || (processed_text == "%d"))
		processed_text = "[time2text(world.timeofday, "DD/MM", NO_TIMEZONE)]/[CURRENT_STATION_YEAR]"
	else if((processed_text == "%time") || (processed_text == "%t"))
		processed_text = time2text(world.timeofday, "hh:mm", NO_TIMEZONE)

	return list("text" = processed_text, "is_signature" = is_signature)

/**
 * Generates preview text for the tattoo that shows how it will appear in examination.
 * This includes existing tattoos on the selected body part to show layering.
 */
/obj/item/tattoo_kit/proc/generate_preview_text()
	if(!selected_zone)
		return ""

	var/body_part_description = get_specific_body_part_description(selected_zone)
	var/list/all_tattoos = list()

	// Add existing tattoos on the selected body part
	if(current_target)
		var/list/existing_tattoos = current_target.get_tattoos(selected_zone)
		all_tattoos += existing_tattoos

	// Add the current tattoo being designed (if any)
	if(tattoo_design && artist_name)
		var/list/processed_data = process_signature_placeholders(artist_name, usr)
		var/final_artist = processed_data["text"]
		var/is_signature = processed_data["is_signature"]

		var/preview_tattoo = new /datum/tattoo(
			final_artist,
			tattoo_design,
			selected_zone,
			ink_color,
			selected_layer,
			is_signature,
			selected_font
		)
		all_tattoos += preview_tattoo

	// Sort tattoos by layer for proper preview
	all_tattoos = sortTim(all_tattoos, GLOBAL_PROC_REF(cmp_tattoo_layer_asc))

	var/preview_text = ""
	for(var/datum/tattoo/T as anything in all_tattoos)
		var/tattoo_text = T.get_examine_text(usr, current_target)
		if(tattoo_text)
			preview_text += "[tattoo_text]\n"

	if(preview_text == "")
		preview_text = "No tattoos on [body_part_description]."

	return preview_text
