/obj/item/custom_tattoo_kit
	name = "body art kit"
	desc = "A professional tattoo kit with various inks and needles for custom body art."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	w_class = WEIGHT_CLASS_SMALL
	var/custom_tattoo_uses = 20
	var/max_custom_tattoo_uses = 20
	var/ink_color = "#000000"
	var/selected_zone = "chest"
	var/current_step = "select_part"
	var/selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT
	var/artist_name = ""
	var/tattoo_design = ""
	var/mob/living/carbon/human/current_target

/obj/item/custom_tattoo_kit/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/custom_tattoo_kit/Destroy()
	current_target = null
	return ..()

/obj/item/custom_tattoo_kit/examine(mob/user)
	. = ..()
	. += span_notice("It has [custom_tattoo_uses] uses left.")
	. += span_notice("Use it on someone to apply tattoos.")

/obj/item/custom_tattoo_kit/attack(mob/living/target, mob/living/user, params)
	if(!ishuman(target))
		return ..()

	var/mob/living/carbon/human/H = target

	// Check if target allows body modifications
	if(!H.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[H] doesn't allow body modifications!"))
		return TRUE

	// Reset UI state if targeting a new person
	if(current_target != H)
		current_step = "select_part"
		selected_zone = "chest"
		artist_name = ""
		tattoo_design = ""
		selected_font = PEN_FONT
		current_target = H

	// Open the UI for this specific target
	ui_interact(user)
	return TRUE

/obj/item/custom_tattoo_kit/attack_self(mob/user)
	. = ..()
	to_chat(user, span_notice("Use the tattoo kit on someone to apply tattoos."))

/obj/item/custom_tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	if(!current_target)
		to_chat(user, span_warning("No target selected! Use the tattoo kit on someone first."))
		return

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit")
		ui.open()

/obj/item/custom_tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	// Always provide safe defaults for all data
	data["target_name"] = "No Target"
	data["ink_uses"] = custom_tattoo_uses
	data["max_uses"] = max_custom_tattoo_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone
	data["selected_zone_name"] = "chest"
	data["current_step"] = current_step
	data["selected_layer"] = selected_layer
	data["selected_font"] = selected_font
	data["artist_name"] = artist_name
	data["tattoo_design"] = tattoo_design
	data["body_parts"] = list()
	data["preview_text"] = ""

	if(current_target && !QDELETED(current_target))
		data["target_name"] = current_target.name
		// CRITICAL FIX: Convert string zone to display name
		data["selected_zone_name"] = get_custom_tattoo_body_part_description(string_to_zone(selected_zone)) || "chest"

		var/list/body_parts = list()
		var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
		for(var/zone in available_parts)
			// CRITICAL FIX: Zones are now strings from get_all_custom_tattoo_body_parts
			if(!zone || !istext(zone))
				continue

			var/list/part_info = available_parts[zone]
			if(!part_info)
				continue

			body_parts += list(list(
				"zone" = zone,
				"name" = part_info["name"] || "Unknown",
				"covered" = part_info["covered"] ? TRUE : FALSE,
				"current_tattoos" = part_info["current_tattoos"] || 0,
				"max_tattoos" = part_info["max_tattoos"] || CUSTOM_MAX_TATTOOS_PER_PART
			))
		data["body_parts"] = body_parts

		// Generate preview text
		var/preview_text = ""
		if(selected_zone)
			// CRITICAL FIX: Convert string zone to BYOND define for get_custom_tattoos
			var/actual_zone = string_to_zone(selected_zone)
			var/list/tattoos = current_target.get_custom_tattoos(actual_zone)
			if(tattoos)
				for(var/datum/custom_tattoo/T in tattoos)
					if(T && !QDELETED(T))
						var/tattoo_text = T.get_examine_text(user, current_target)
						if(tattoo_text)
							preview_text += tattoo_text + "<br>"

			// Add preview of new tattoo if we're in design mode
			if(current_step == "design_tattoo" && tattoo_design && artist_name)
				var/actual_zone_for_preview = string_to_zone(selected_zone)
				var/datum/custom_tattoo/preview_tattoo = new(artist_name, tattoo_design, actual_zone_for_preview, ink_color, selected_layer, FALSE, selected_font)
				var/preview_tattoo_text = preview_tattoo.get_examine_text(user, current_target)
				if(preview_tattoo_text)
					preview_text += preview_tattoo_text + "<br>"
				qdel(preview_tattoo)

		data["preview_text"] = preview_text

	return data

/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	// Safety check - ensure we still have a valid target
	if(!current_target || QDELETED(current_target))
		to_chat(user, span_warning("The target is no longer valid!"))
		return FALSE

	switch(action)
		if("select_bodypart")
			var/zone = params["zone"]

			// CRITICAL FIX: Zone is now a string from TGUI - validate it
			if(!zone || !istext(zone) || zone == "")
				return FALSE

			// CRITICAL FIX: Use string zone directly for checks
			if(!is_custom_tattoo_bodypart_existing(current_target, zone))
				to_chat(user, span_warning("That body part doesn't exist!"))
				return FALSE

			if(!get_custom_tattoo_location_accessible(current_target, zone))
				var/body_part_name = get_custom_tattoo_body_part_description(string_to_zone(zone))
				to_chat(user, span_warning("[current_target]'s [body_part_name] is covered! Expose it first."))
				return FALSE

			// CRITICAL FIX: Check tattoo limit using converted zone
			var/actual_zone = string_to_zone(zone)
			var/current_tattoos = length(current_target.get_custom_tattoos(actual_zone))
			if(current_tattoos >= CUSTOM_MAX_TATTOOS_PER_PART)
				to_chat(user, span_warning("This body part already has the maximum number of tattoos! (Max: [CUSTOM_MAX_TATTOOS_PER_PART])"))
				return FALSE

			// Store string zone directly
			selected_zone = zone
			current_step = "design_tattoo"

			// Force UI to update with new state
			SStgui.update_uis(src)

			return TRUE

		if("set_layer")
			var/layer = text2num(params["layer"])
			if(isnum(layer))
				selected_layer = sanitize_integer(layer, CUSTOM_TATTOO_LAYER_UNDER, CUSTOM_TATTOO_LAYER_OVER, CUSTOM_TATTOO_LAYER_NORMAL)
				return TRUE

		if("set_font")
			var/font = params["font"]
			if(font && (font in GLOB.custom_tattoo_fonts))
				selected_font = font
				return TRUE

		if("change_ink_color")
			var/new_color = input(user, "Choose ink color:", "Body Art Kit", ink_color) as color|null
			if(new_color)
				ink_color = sanitize_hexcolor(new_color, default = "#000000")
				to_chat(user, span_notice("You change the ink color to [new_color]."))
				return TRUE

		if("back_to_selection")
			current_step = "select_part"
			return TRUE

		if("set_artist_name")
			var/new_name = params["value"]
			if(!isnull(new_name))
				artist_name = sanitize_text(new_name)
				return TRUE

		if("set_tattoo_design")
			var/new_design = params["value"]
			if(!isnull(new_design))
				tattoo_design = sanitize_text(new_design)
				return TRUE

		if("apply_tattoo")
			if(!artist_name || !istext(artist_name) || artist_name == "")
				to_chat(user, span_warning("Please enter a valid artist name!"))
				return FALSE

			if(!tattoo_design || !istext(tattoo_design) || tattoo_design == "")
				to_chat(user, span_warning("Please enter a valid tattoo design description!"))
				return FALSE

			var/trimmed_artist = trimtext(artist_name)
			var/trimmed_design = trimtext(tattoo_design)

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

			if(!get_custom_tattoo_location_accessible(current_target, selected_zone))
				to_chat(user, span_warning("[current_target]'s [get_custom_tattoo_body_part_description(selected_zone)] is covered! Expose it first."))
				return FALSE

			if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
				to_chat(user, span_warning("[current_target] doesn't allow body modifications!"))
				return FALSE

			if(custom_tattoo_uses <= 0)
				to_chat(user, span_warning("This body art kit is out of ink!"))
				return FALSE

			if(ui && !QDELETED(ui))
				ui.close()

			to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [get_custom_tattoo_body_part_description(selected_zone)]..."))

			if(do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
				if(!current_target || QDELETED(current_target))
					to_chat(user, span_warning("The target is no longer valid!"))
					return FALSE

				if(!get_custom_tattoo_location_accessible(current_target, selected_zone))
					to_chat(user, span_warning("The body part became covered during application!"))
					return FALSE

				if(custom_tattoo_uses <= 0)
					to_chat(user, span_warning("The body art kit ran out of ink during application!"))
					return FALSE

				if(!user.is_holding(src))
					to_chat(user, span_warning("You must be holding the body art kit to apply a tattoo!"))
					return FALSE

				// Handle signature placeholders
				var/list/processed_data = process_custom_tattoo_signature_placeholders(trimmed_artist, user)
				var/final_artist = processed_data["text"]
				var/is_signature = processed_data["is_signature"]

				var/sanitized_artist = sanitize_text(final_artist)
				var/sanitized_design = sanitize_text(trimmed_design)
				var/sanitized_layer = selected_layer
				var/sanitized_font = selected_font

				// CRITICAL FIX: Convert selected_zone string back to BYOND define for tattoo creation
				var/tattoo_zone_define = string_to_zone(selected_zone)
				var/datum/custom_tattoo/new_tattoo = new(sanitized_artist, sanitized_design, tattoo_zone_define, ink_color, sanitized_layer, is_signature, sanitized_font)

				if(current_target.add_custom_tattoo(new_tattoo))
					if(current_target.client?.prefs)
						current_target.client.prefs.save_custom_tattoo_data()
					to_chat(user, span_green("Tattoo applied successfully to [current_target]'s [get_custom_tattoo_body_part_description(selected_zone)]!"))
					custom_tattoo_uses = max(0, custom_tattoo_uses - 1)
					current_target.regenerate_icons()

					// Log the action
					user.log_message("applied custom tattoo '[sanitized_design]' by [sanitized_artist] to [current_target]'s [selected_zone]", LOG_GAME)

					// Reset for next tattoo
					current_step = "select_part"
					artist_name = ""
					tattoo_design = ""
					selected_font = PEN_FONT
				else
					to_chat(user, span_warning("Failed to apply tattoo! The body part may have reached its tattoo limit."))
			else
				to_chat(user, span_warning("Tattoo application interrupted!"))

			return TRUE

	return .

// Custom signature processing for tattoos
/obj/item/custom_tattoo_kit/proc/process_custom_tattoo_signature_placeholders(text, mob/user)
	var/list/signatures = list(
		"%s" = user.real_name,
		"%sign" = user.real_name,
		"%d" = time2text(world.realtime, "YYYY-MM-DD"),
		"%date" = time2text(world.realtime, "YYYY-MM-DD"),
		"%t" = time2text(world.realtime, "hh:mm:ss"),
		"%time" = time2text(world.realtime, "hh:mm:ss"),
	)

	for(var/ph in signatures)
		text = replacetext(text, ph, signatures[ph])

	return list("text" = text, "is_signature" = (findtext(text, user.real_name) ? TRUE : FALSE))
