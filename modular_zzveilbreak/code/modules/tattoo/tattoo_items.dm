/obj/item/custom_tattoo_kit
	name = "body art kit"
	desc = "A professional tattoo kit with various inks and needles for custom body art."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	w_class = WEIGHT_CLASS_SMALL
	var/custom_tattoo_uses = 20
	var/max_custom_tattoo_uses = 20
	var/ink_color = "#000000"
	var/list/expanded_parts = list() // Track which body parts are expanded
	var/list/artist_names = list() // Store artist names per body part
	var/list/tattoo_designs = list() // Store tattoo designs per body part
	var/list/selected_layers = list() // Store layers per body part
	var/list/selected_fonts = list() // Store fonts per body part
	var/mob/living/carbon/human/current_target

/obj/item/custom_tattoo_kit/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/custom_tattoo_kit/Destroy()
	current_target = null
	expanded_parts.Cut()
	artist_names.Cut()
	tattoo_designs.Cut()
	selected_layers.Cut()
	selected_fonts.Cut()
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
		expanded_parts.Cut()
		artist_names.Cut()
		tattoo_designs.Cut()
		selected_layers.Cut()
		selected_fonts.Cut()
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
	data["expanded_parts"] = expanded_parts
	data["artist_names"] = artist_names
	data["tattoo_designs"] = tattoo_designs
	data["selected_layers"] = selected_layers
	data["selected_fonts"] = selected_fonts
	data["body_parts"] = list()

	if(current_target && !QDELETED(current_target))
		data["target_name"] = current_target.name

		var/list/body_parts = list()
		var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
		for(var/zone in available_parts)
			if(!zone || !istext(zone))
				continue

			var/list/part_info = available_parts[zone]
			if(!part_info)
				continue

			// Generate preview text for this specific body part
			var/preview_text = ""
			var/actual_zone = string_to_zone(zone)
			var/list/tattoos = current_target.get_custom_tattoos(actual_zone)
			if(tattoos)
				for(var/datum/custom_tattoo/T in tattoos)
					if(T && !QDELETED(T))
						var/tattoo_text = T.get_examine_text(user, current_target)
						if(tattoo_text)
							preview_text += tattoo_text + "<br>"

			// Add preview of new tattoo if we have design data for this part
			if(zone in tattoo_designs && zone in artist_names)
				var/artist = artist_names[zone]
				var/design = tattoo_designs[zone]
				var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
				var/font = selected_fonts[zone] || PEN_FONT

				if(design && artist)
					var/datum/custom_tattoo/preview_tattoo = new(artist, design, actual_zone, ink_color, layer, FALSE, font)
					var/preview_tattoo_text = preview_tattoo.get_examine_text(user, current_target)
					if(preview_tattoo_text)
						preview_text += preview_tattoo_text + "<br>"
					qdel(preview_tattoo)

			body_parts += list(list(
				"zone" = zone,
				"name" = part_info["name"] || "Unknown",
				"covered" = part_info["covered"] ? TRUE : FALSE,
				"current_tattoos" = part_info["current_tattoos"] || 0,
				"max_tattoos" = part_info["max_tattoos"] || CUSTOM_MAX_TATTOOS_PER_PART,
				"preview_text" = preview_text,
				"expanded" = (zone in expanded_parts) ? TRUE : FALSE
			))

		data["body_parts"] = body_parts

	return data

/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	// Enhanced safety check
	if(!current_target || QDELETED(current_target) || !istype(current_target, /mob/living/carbon/human))
		to_chat(user, span_warning("The target is no longer valid!"))
		current_target = null
		return FALSE

	switch(action)
		if("toggle_expand")
			var/zone = params["zone"]

			if(!zone || !istext(zone))
				return FALSE

			// Check if this zone exists and is valid
			var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
			if(!(zone in available_parts))
				return FALSE

			// Toggle expansion state
			if(zone in expanded_parts)
				expanded_parts -= zone
			else
				expanded_parts |= zone
				// Initialize default values if this is first expansion
				if(!(zone in selected_layers))
					selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
				if(!(zone in selected_fonts))
					selected_fonts[zone] = PEN_FONT

			return TRUE

		if("set_artist_name")
			var/zone = params["zone"]
			var/new_name = params["value"]

			if(!zone || !istext(zone) || isnull(new_name))
				return FALSE

			// Validate zone exists
			var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
			if(!(zone in available_parts))
				return FALSE

			artist_names[zone] = sanitize_text(new_name)
			return TRUE

		if("set_tattoo_design")
			var/zone = params["zone"]
			var/new_design = params["value"]

			if(!zone || !istext(zone) || isnull(new_design))
				return FALSE

			// Validate zone exists
			var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
			if(!(zone in available_parts))
				return FALSE

			tattoo_designs[zone] = sanitize_text(new_design)
			return TRUE

		if("set_layer")
			var/zone = params["zone"]
			var/layer = text2num(params["layer"])

			if(!zone || !istext(zone) || !isnum(layer))
				return FALSE

			// Validate zone exists
			var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
			if(!(zone in available_parts))
				return FALSE

			selected_layers[zone] = sanitize_integer(layer, CUSTOM_TATTOO_LAYER_UNDER, CUSTOM_TATTOO_LAYER_OVER, CUSTOM_TATTOO_LAYER_NORMAL)
			return TRUE

		if("set_font")
			var/zone = params["zone"]
			var/font = params["font"]

			if(!zone || !istext(zone) || !font)
				return FALSE

			// Validate zone exists and font is valid
			var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
			if(!(zone in available_parts) || !(font in GLOB.custom_tattoo_fonts))
				return FALSE

			selected_fonts[zone] = font
			return TRUE

		if("change_ink_color")
			var/new_color = input(user, "Choose ink color:", "Body Art Kit", ink_color) as color|null
			if(new_color)
				ink_color = sanitize_hexcolor(new_color, default = "#000000")
				to_chat(user, span_notice("You change the ink color to [new_color]."))
				return TRUE

		if("apply_tattoo")
			var/zone = params["zone"]

			if(!zone || !istext(zone))
				to_chat(user, span_warning("Invalid body part selection!"))
				return FALSE

			// Get data for this specific body part
			var/artist_name = artist_names[zone]
			var/tattoo_design = tattoo_designs[zone]
			var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
			var/font = selected_fonts[zone] || PEN_FONT

			// Validation checks
			if(!artist_name || !istext(artist_name) || trimtext(artist_name) == "")
				to_chat(user, span_warning("Please enter a valid artist name!"))
				return FALSE

			if(!tattoo_design || !istext(tattoo_design) || trimtext(tattoo_design) == "")
				to_chat(user, span_warning("Please enter a valid tattoo design description!"))
				return FALSE

			var/trimmed_artist = trimtext(artist_name)
			var/trimmed_design = trimtext(tattoo_design)

			if(length(trimmed_artist) > 50)
				to_chat(user, span_warning("Artist name is too long! Maximum 50 characters."))
				return FALSE

			if(length(trimmed_design) > 500)
				to_chat(user, span_warning("Tattoo design is too long! Maximum 500 characters."))
				return FALSE

			// Check accessibility and availability
			var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
			if(!(zone in available_parts))
				to_chat(user, span_warning("The selected body part is no longer available!"))
				return FALSE

			var/list/part_info = available_parts[zone]
			if(part_info["covered"])
				to_chat(user, span_warning("[current_target]'s [part_info["name"]] is covered! Expose it first."))
				return FALSE

			if(part_info["current_tattoos"] >= part_info["max_tattoos"])
				to_chat(user, span_warning("This body part already has the maximum number of tattoos! (Max: [CUSTOM_MAX_TATTOOS_PER_PART])"))
				return FALSE

			if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
				to_chat(user, span_warning("[current_target] doesn't allow body modifications!"))
				return FALSE

			if(custom_tattoo_uses <= 0)
				to_chat(user, span_warning("This body art kit is out of ink!"))
				return FALSE

			if(ui && !QDELETED(ui))
				ui.close()

			to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [part_info["name"]]..."))

			if(do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
				// Re-validate everything after the delay
				if(!current_target || QDELETED(current_target) || !user.is_holding(src))
					to_chat(user, span_warning("The application was interrupted!"))
					return FALSE

				// Re-check all conditions
				var/list/current_parts = get_all_custom_tattoo_body_parts(current_target)
				if(!(zone in current_parts) || current_parts[zone]["covered"])
					to_chat(user, span_warning("The body part became unavailable during application!"))
					return FALSE

				if(custom_tattoo_uses <= 0)
					to_chat(user, span_warning("The body art kit ran out of ink during application!"))
					return FALSE

				// Process signature placeholders
				var/list/processed_data = process_custom_tattoo_signature_placeholders(trimmed_artist, user)
				var/final_artist = processed_data["text"]
				var/is_signature = processed_data["is_signature"]

				var/sanitized_artist = sanitize_text(final_artist)
				var/sanitized_design = sanitize_text(trimmed_design)

				// Convert string zone to BYOND define and create tattoo
				var/tattoo_zone_define = string_to_zone(zone)
				var/datum/custom_tattoo/new_tattoo = new(sanitized_artist, sanitized_design, tattoo_zone_define, ink_color, layer, is_signature, font)

				if(current_target.add_custom_tattoo(new_tattoo))
					if(current_target.client?.prefs)
						current_target.client.prefs.save_custom_tattoo_data()
					to_chat(user, span_green("Tattoo applied successfully to [current_target]'s [part_info["name"]]!"))
					custom_tattoo_uses = max(0, custom_tattoo_uses - 1)
					current_target.regenerate_icons()

					// Log the action
					user.log_message("applied custom tattoo '[sanitized_design]' by [sanitized_artist] to [current_target]'s [zone]", LOG_GAME)

					// Clear the form data for this body part
					artist_names -= zone
					tattoo_designs -= zone
					selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
					selected_fonts[zone] = PEN_FONT
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
