/obj/item/custom_tattoo_kit
	name = "professional tattoo kit"
	desc = "A complete tattoo application system with multiple ink reservoirs and precision needles."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	w_class = WEIGHT_CLASS_SMALL
	/// Current ink uses remaining
	var/ink_uses = 30
	/// Maximum ink capacity
	var/max_ink_uses = 30
	/// Current selected ink color
	var/ink_color = "#000000"
	/// Currently targeted human
	var/mob/living/carbon/human/current_target
	/// Which body parts are expanded in UI
	var/list/expanded_parts = list()
	/// Temporary storage for artist names per body part
	var/list/artist_names = list()
	/// Temporary storage for tattoo designs per body part
	var/list/tattoo_designs = list()
	/// Selected layers per body part
	var/list/selected_layers = list()
	/// Selected fonts per body part
	var/list/selected_fonts = list()
	/// Cooldown to prevent spam
	var/next_use = 0

/obj/item/custom_tattoo_kit/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/custom_tattoo_kit/Destroy()
	current_target = null
	expanded_parts = null
	artist_names = null
	tattoo_designs = null
	selected_layers = null
	selected_fonts = null
	return ..()

/obj/item/custom_tattoo_kit/examine(mob/user)
	. = ..()
	. += span_info("Ink remaining: [ink_uses]/[max_ink_uses]")
	. += span_info("Current color: <font color='[ink_color]'>█</font>")
	. += span_info("Use on someone to apply tattoos.")

/obj/item/custom_tattoo_kit/update_icon_state()
	icon_state = "tattoo_kit[ink_uses > 0 ? "" : "_empty"]"
	return ..()

/obj/item/custom_tattoo_kit/attack(mob/living/target, mob/living/user, params)
	if(!ishuman(target))
		return ..()

	var/mob/living/carbon/human/human_target = target

	// Check preferences
	if(!human_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[human_target] doesn't allow body modifications!"))
		return TRUE

	// Check cooldown
	if(world.time < next_use)
		to_chat(user, span_warning("The kit needs a moment to recharge."))
		return TRUE

	// Reset UI state if new target
	if(current_target != human_target)
		reset_ui_state()
		current_target = human_target

	ui_interact(user)
	return TRUE

/obj/item/custom_tattoo_kit/attack_self(mob/user)
	. = ..()
	refill_ink(user)

/obj/item/custom_tattoo_kit/proc/reset_ui_state()
	expanded_parts = list()
	artist_names = list()
	tattoo_designs = list()
	selected_layers = list()
	selected_fonts = list()

/obj/item/custom_tattoo_kit/proc/refill_ink(mob/user)
	if(ink_uses >= max_ink_uses)
		to_chat(user, span_warning("The ink reservoir is already full!"))
		return

	ink_uses = max_ink_uses
	to_chat(user, span_notice("Tattoo kit refilled. Current ink: [ink_uses]/[max_ink_uses]"))
	update_appearance()

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

	data["target_name"] = current_target?.name || "Unknown Target"
	data["ink_uses"] = ink_uses
	data["max_ink_uses"] = max_ink_uses
	data["ink_color"] = ink_color
	data["expanded_parts"] = expanded_parts
	data["artist_names"] = artist_names
	data["tattoo_designs"] = tattoo_designs
	data["selected_layers"] = selected_layers
	data["selected_fonts"] = selected_fonts

	// Get available body parts
	data["body_parts"] = list()
	if(current_target && !QDELETED(current_target))
		var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
		for(var/zone in available_parts)
			var/list/part_info = available_parts[zone]
			var/preview_text = generate_part_preview(zone, user)

			data["body_parts"] += list(list(
				"zone" = zone,
				"name" = part_info["name"] || "Unknown",
				"covered" = part_info["covered"] ? TRUE : FALSE,
				"current_tattoos" = part_info["current_tattoos"] || 0,
				"max_tattoos" = part_info["max_tattoos"] || CUSTOM_MAX_TATTOOS_PER_PART,
				"preview_text" = preview_text,
				"expanded" = (zone in expanded_parts) ? TRUE : FALSE
			))

	return data

/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	// Safety checks
	if(!can_interact_with_target(user))
		return FALSE

	switch(action)
		if("toggle_expand")
			var/zone = params["zone"]
			if(validate_zone(zone))
				if(zone in expanded_parts)
					expanded_parts -= zone
				else
					expanded_parts |= zone
					// Initialize defaults for new expanded part
					if(!(zone in selected_layers))
						selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
					if(!(zone in selected_fonts))
						selected_fonts[zone] = PEN_FONT
					// Initialize empty artist and design if not set
					if(!(zone in artist_names))
						artist_names[zone] = ""
					if(!(zone in tattoo_designs))
						tattoo_designs[zone] = ""
				return TRUE

		if("set_artist")
			var/zone = params["zone"]
			var/value = params["value"]
			if(validate_zone(zone) && !isnull(value))
				// Properly sanitize: trim and limit length
				var/trimmed_value = trimtext(value)
				if(length(trimmed_value) > 50)
					trimmed_value = copytext(trimmed_value, 1, 51)
				artist_names[zone] = trimmed_value
				return TRUE

		if("set_design")
			var/zone = params["zone"]
			var/value = params["value"]
			if(validate_zone(zone) && !isnull(value))
				// Properly sanitize: trim and limit length
				var/trimmed_value = trimtext(value)
				if(length(trimmed_value) > 500)
					trimmed_value = copytext(trimmed_value, 1, 501)
				tattoo_designs[zone] = trimmed_value
				return TRUE

		if("set_layer")
			var/zone = params["zone"]
			var/layer = text2num(params["layer"])
			if(validate_zone(zone) && !isnull(layer))
				selected_layers[zone] = sanitize_integer(layer, CUSTOM_TATTOO_LAYER_UNDER, CUSTOM_TATTOO_LAYER_OVER, CUSTOM_TATTOO_LAYER_NORMAL)
				return TRUE

		if("set_font")
			var/zone = params["zone"]
			var/font = params["font"]
			if(validate_zone(zone) && !isnull(font) && (font in GLOB.custom_tattoo_fonts))
				selected_fonts[zone] = font
				return TRUE

		if("change_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = sanitize_hexcolor(new_color, default = "#000000")
				return TRUE

		if("apply_tattoo")
			var/zone = params["zone"]
			return handle_apply_tattoo(user, zone)

		if("refill_ink")
			refill_ink(user)
			return TRUE

	return FALSE

/obj/item/custom_tattoo_kit/proc/can_interact_with_target(mob/user)
	if(!current_target || QDELETED(current_target) || !istype(current_target, /mob/living/carbon/human))
		to_chat(user, span_warning("The target is no longer valid!"))
		current_target = null
		return FALSE

	if(!user.is_holding(src))
		to_chat(user, span_warning("You must be holding the tattoo kit!"))
		return FALSE

	return TRUE

/obj/item/custom_tattoo_kit/proc/validate_zone(zone)
	if(!zone || !istext(zone))
		return FALSE

	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	return (zone in available_parts)

/obj/item/custom_tattoo_kit/proc/generate_part_preview(zone, mob/user)
	var/preview_text = ""
	var/actual_zone = string_to_zone(zone)
	var/list/tattoos = current_target.get_custom_tattoos(actual_zone)

	// Show existing tattoos
	if(tattoos)
		for(var/datum/custom_tattoo/tattoo as anything in tattoos)
			if(QDELETED(tattoo))
				continue
			var/tattoo_text = tattoo.get_examine_text(user, current_target)
			if(tattoo_text)
				preview_text += tattoo_text + "<br>"

	// Show preview of new tattoo
	if(zone in tattoo_designs && zone in artist_names)
		var/artist = artist_names[zone]
		var/design = tattoo_designs[zone]
		var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
		var/font = selected_fonts[zone] || PEN_FONT

		if(trimtext(design) && trimtext(artist))
			var/datum/custom_tattoo/preview_tattoo = new(artist, design, actual_zone, ink_color, layer, FALSE, font)
			var/preview_tattoo_text = preview_tattoo.get_examine_text(user, current_target)
			if(preview_tattoo_text)
				preview_text += "<span style='color: [ink_color];'><b>Preview:</b> [preview_tattoo_text]</span><br>"
			qdel(preview_tattoo)

	return preview_text || "No tattoos yet."

/obj/item/custom_tattoo_kit/proc/handle_apply_tattoo(mob/user, zone)
	if(!validate_zone(zone))
		to_chat(user, span_warning("Invalid body part selection!"))
		return FALSE

	// Validate tattoo data
	var/list/validation_result = validate_tattoo_data(zone, user)
	if(!validation_result["success"])
		to_chat(user, span_warning(validation_result["message"]))
		return FALSE

	var/artist_name = validation_result["artist"]
	var/tattoo_design = validation_result["design"]
	var/layer = validation_result["layer"]
	var/font = validation_result["font"]
	var/part_info = validation_result["part_info"]

	// Start application
	to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [part_info["name"]]..."))
	current_target.visible_message(span_notice("[user] begins tattooing [current_target]'s [part_info["name"]]."), span_notice("You feel a sharp, buzzing sensation on your [part_info["name"]] as [user] begins tattooing."))

	if(!do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	// Re-validate after delay
	if(!can_interact_with_target(user))
		return FALSE

	var/list/revalidation_result = revalidate_tattoo_data(zone)
	if(!revalidation_result["success"])
		to_chat(user, span_warning(revalidation_result["message"]))
		return FALSE

	// Create and apply tattoo
	var/tattoo_zone_define = string_to_zone(zone)
	var/list/processed_data = process_signature_placeholders(artist_name, user)
	var/final_artist = processed_data["text"]
	var/is_signature = processed_data["is_signature"]

	var/sanitized_artist = sanitize_text(final_artist)
	var/sanitized_design = sanitize_text(tattoo_design)

	var/datum/custom_tattoo/new_tattoo = new(sanitized_artist, sanitized_design, tattoo_zone_define, ink_color, layer, is_signature, font)

	if(current_target.add_custom_tattoo(new_tattoo))
		on_tattoo_applied_success(user, zone, sanitized_artist, sanitized_design, part_info)
		return TRUE
	else
		to_chat(user, span_warning("Failed to apply tattoo! The body part may have reached its tattoo limit."))
		return FALSE

/obj/item/custom_tattoo_kit/proc/validate_tattoo_data(zone, mob/user)
	var/list/result = list("success" = FALSE)

	// Get form data - use empty strings as defaults
	var/artist_name = artist_names[zone] || ""
	var/tattoo_design = tattoo_designs[zone] || ""
	var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
	var/font = selected_fonts[zone] || PEN_FONT

	// Validate required fields - check for empty strings after trim
	if(!istext(artist_name) || trimtext(artist_name) == "")
		result["message"] = "Please enter a valid artist name!"
		return result

	if(!istext(tattoo_design) || trimtext(tattoo_design) == "")
		result["message"] = "Please enter a valid tattoo design description!"
		return result

	var/trimmed_artist = trimtext(artist_name)
	var/trimmed_design = trimtext(tattoo_design)

	// Validate lengths
	if(length(trimmed_artist) > 50)
		result["message"] = "Artist name is too long! Maximum 50 characters."
		return result

	if(length(trimmed_design) > 500)
		result["message"] = "Tattoo design is too long! Maximum 500 characters."
		return result

	// Check body part availability
	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	var/list/part_info = available_parts[zone]
	if(!part_info)
		result["message"] = "The selected body part is no longer available!"
		return result

	if(part_info["covered"])
		result["message"] = "[current_target]'s [part_info["name"]] is covered! Expose it first."
		return result

	if(part_info["current_tattoos"] >= part_info["max_tattoos"])
		result["message"] = "This body part already has the maximum number of tattoos! (Max: [CUSTOM_MAX_TATTOOS_PER_PART])"
		return result

	// Check permissions and resources
	if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		result["message"] = "[current_target] doesn't allow body modifications!"
		return result

	if(ink_uses <= 0)
		result["message"] = "The tattoo kit is out of ink!"
		return result

	// All validation passed
	result["success"] = TRUE
	result["artist"] = trimmed_artist
	result["design"] = trimmed_design
	result["layer"] = layer
	result["font"] = font
	result["part_info"] = part_info

	return result

/obj/item/custom_tattoo_kit/proc/revalidate_tattoo_data(zone)
	var/list/result = list("success" = FALSE)

	// Re-check body part availability
	var/list/current_parts = get_all_custom_tattoo_body_parts(current_target)
	if(!(zone in current_parts) || current_parts[zone]["covered"])
		result["message"] = "The body part became unavailable during application!"
		return result

	if(ink_uses <= 0)
		result["message"] = "The tattoo kit ran out of ink during application!"
		return result

	result["success"] = TRUE
	return result

/obj/item/custom_tattoo_kit/proc/on_tattoo_applied_success(mob/user, zone, artist, design, part_info)
	// Update state
	ink_uses = max(0, ink_uses - 1)
	next_use = world.time + 2 SECONDS

	// Save to preferences
	if(current_target.client?.prefs)
		current_target.client.prefs.save_custom_tattoo_data()

	// Update appearance
	current_target.regenerate_icons()
	update_appearance()

	// Clear form data for this body part
	artist_names -= zone
	tattoo_designs -= zone
	selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
	selected_fonts[zone] = PEN_FONT

	// Notify and log
	to_chat(user, span_green("Tattoo applied successfully to [current_target]'s [part_info["name"]]!"))
	to_chat(current_target, span_notice("You feel a lasting impression on your [part_info["name"]] as the tattoo is completed."))

	user.log_message("applied custom tattoo '[design]' by [artist] to [current_target]'s [zone]", LOG_GAME)

/obj/item/custom_tattoo_kit/proc/process_signature_placeholders(text, mob/user)
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
