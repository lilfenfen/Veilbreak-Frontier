/obj/item/custom_tattoo_kit
	name = "body art kit"
	desc = "A professional tattoo kit with various inks and needles for custom body art."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	w_class = WEIGHT_CLASS_SMALL

	/// How many uses of ink remain
	var/custom_tattoo_uses = 20
	/// Maximum uses of ink
	var/max_custom_tattoo_uses = 20
	/// Current ink color
	var/ink_color = "#000000"
	/// The human we're currently working on
	var/mob/living/carbon/human/current_target
	/// Which body parts are currently expanded in the UI
	var/list/expanded_parts = list()
	/// Artist names for each body part
	var/list/artist_names = list()
	/// Tattoo designs for each body part
	var/list/tattoo_designs = list()
	/// Selected layers for each body part
	var/list/selected_layers = list()
	/// Selected fonts for each body part
	var/list/selected_fonts = list()

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
	. += span_notice("It has [custom_tattoo_uses] uses left.")
	. += span_notice("Use it on someone to apply tattoos.")

/obj/item/custom_tattoo_kit/attack(mob/living/target, mob/living/user, params)
	if(!ishuman(target))
		return ..()

	var/mob/living/carbon/human/human_target = target

	// Check if target allows body modifications
	if(!human_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[human_target] doesn't allow body modifications!"))
		return TRUE

	// Reset UI state if targeting a new person
	if(current_target != human_target)
		expanded_parts = list()
		artist_names = list()
		tattoo_designs = list()
		selected_layers = list()
		selected_fonts = list()
		current_target = human_target

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

	data["target_name"] = current_target?.name || "No Target"
	data["ink_uses"] = custom_tattoo_uses
	data["max_uses"] = max_custom_tattoo_uses
	data["ink_color"] = ink_color
	data["expanded_parts"] = expanded_parts
	data["artist_names"] = artist_names
	data["tattoo_designs"] = tattoo_designs
	data["selected_layers"] = selected_layers
	data["selected_fonts"] = selected_fonts
	data["body_parts"] = list()

	if(!current_target || QDELETED(current_target))
		return data

	var/list/body_parts = list()
	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)

	for(var/zone in available_parts)
		var/list/part_info = available_parts[zone]
		if(!part_info)
			continue

		// Generate preview text for this specific body part
		var/preview_text = generate_part_preview(zone, user)

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

/// Generates preview text for a specific body part
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

	// Show preview of new tattoo if we have design data
	if(zone in tattoo_designs && zone in artist_names)
		var/artist = artist_names[zone]
		var/design = tattoo_designs[zone]
		var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
		var/font = selected_fonts[zone] || PEN_FONT

		if(trimtext(design) && trimtext(artist))
			var/datum/custom_tattoo/preview_tattoo = new(artist, design, actual_zone, ink_color, layer, FALSE, font)
			var/preview_tattoo_text = preview_tattoo.get_examine_text(user, current_target)
			if(preview_tattoo_text)
				preview_text += preview_tattoo_text + "<br>"
			qdel(preview_tattoo)

	return preview_text

/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	// Safety validation
	if(!can_interact_with_target(user))
		return FALSE

	switch(action)
		if("toggle_expand")
			return handle_toggle_expand(params["zone"])

		if("set_artist_name")
			return handle_set_artist_name(params["zone"], params["value"])

		if("set_tattoo_design")
			return handle_set_tattoo_design(params["zone"], params["value"])

		if("set_layer")
			return handle_set_layer(params["zone"], params["layer"])

		if("set_font")
			return handle_set_font(params["zone"], params["font"])

		if("change_ink_color")
			return handle_change_ink_color(user)

		if("apply_tattoo")
			return handle_apply_tattoo(user, params["zone"])

	return FALSE

/// Check if we can safely interact with the current target
/obj/item/custom_tattoo_kit/proc/can_interact_with_target(mob/user)
	if(!current_target || QDELETED(current_target) || !istype(current_target, /mob/living/carbon/human))
		to_chat(user, span_warning("The target is no longer valid!"))
		current_target = null
		return FALSE

	if(!user.is_holding(src))
		to_chat(user, span_warning("You must be holding the body art kit!"))
		return FALSE

	return TRUE

/// Validate that a zone exists and is accessible
/obj/item/custom_tattoo_kit/proc/validate_zone(zone)
	if(!zone || !istext(zone))
		return FALSE

	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	return (zone in available_parts)

/// Handle toggling expansion of a body part section
/obj/item/custom_tattoo_kit/proc/handle_toggle_expand(zone)
	if(!validate_zone(zone))
		return FALSE

	if(zone in expanded_parts)
		expanded_parts -= zone
	else
		expanded_parts |= zone
		// Initialize default values for new expanded part
		if(!(zone in selected_layers))
			selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
		if(!(zone in selected_fonts))
			selected_fonts[zone] = PEN_FONT

	return TRUE

/// Handle setting artist name for a body part
/obj/item/custom_tattoo_kit/proc/handle_set_artist_name(zone, value)
	if(!validate_zone(zone) || isnull(value))
		return FALSE

	artist_names[zone] = sanitize_text(value)
	return TRUE

/// Handle setting tattoo design for a body part
/obj/item/custom_tattoo_kit/proc/handle_set_tattoo_design(zone, value)
	if(!validate_zone(zone) || isnull(value))
		return FALSE

	tattoo_designs[zone] = sanitize_text(value)
	return TRUE

/// Handle setting layer for a body part
/obj/item/custom_tattoo_kit/proc/handle_set_layer(zone, layer_string)
	if(!validate_zone(zone) || !layer_string)
		return FALSE

	var/layer = text2num(layer_string)
	if(!isnum(layer))
		return FALSE

	selected_layers[zone] = sanitize_integer(layer, CUSTOM_TATTOO_LAYER_UNDER, CUSTOM_TATTOO_LAYER_OVER, CUSTOM_TATTOO_LAYER_NORMAL)
	return TRUE

/// Handle setting font for a body part
/obj/item/custom_tattoo_kit/proc/handle_set_font(zone, font)
	if(!validate_zone(zone) || !font)
		return FALSE

	if(!(font in GLOB.custom_tattoo_fonts))
		return FALSE

	selected_fonts[zone] = font
	return TRUE

/// Handle changing ink color
/obj/item/custom_tattoo_kit/proc/handle_change_ink_color(mob/user)
	var/new_color = input(user, "Choose ink color:", "Body Art Kit", ink_color) as color|null
	if(!new_color)
		return FALSE

	ink_color = sanitize_hexcolor(new_color, default = "#000000")
	to_chat(user, span_notice("You change the ink color to [new_color]."))
	return TRUE

/// Handle applying a tattoo to a body part
/obj/item/custom_tattoo_kit/proc/handle_apply_tattoo(mob/user, zone)
	if(!validate_zone(zone))
		to_chat(user, span_warning("Invalid body part selection!"))
		return FALSE

	// Get and validate form data
	var/list/validation_result = validate_tattoo_data(zone, user)
	if(!validation_result["success"])
		to_chat(user, span_warning(validation_result["message"]))
		return FALSE

	var/artist_name = validation_result["artist"]
	var/tattoo_design = validation_result["design"]
	var/layer = validation_result["layer"]
	var/font = validation_result["font"]
	var/part_info = validation_result["part_info"]

	to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [part_info["name"]]..."))

	if(!do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	// Re-validate everything after the delay
	if(!can_interact_with_target(user))
		return FALSE

	var/list/revalidation_result = revalidate_tattoo_data(zone)
	if(!revalidation_result["success"])
		to_chat(user, span_warning(revalidation_result["message"]))
		return FALSE

	// Process signature placeholders and create tattoo
	var/list/processed_data = process_custom_tattoo_signature_placeholders(artist_name, user)
	var/final_artist = processed_data["text"]
	var/is_signature = processed_data["is_signature"]

	var/sanitized_artist = sanitize_text(final_artist)
	var/sanitized_design = sanitize_text(tattoo_design)

	// Create and apply the tattoo
	var/tattoo_zone_define = string_to_zone(zone)
	var/datum/custom_tattoo/new_tattoo = new(sanitized_artist, sanitized_design, tattoo_zone_define, ink_color, layer, is_signature, font)

	if(current_target.add_custom_tattoo(new_tattoo))
		on_tattoo_applied_success(user, zone, sanitized_artist, sanitized_design, part_info)
	else
		to_chat(user, span_warning("Failed to apply tattoo! The body part may have reached its tattoo limit."))

	return TRUE

/// Validate tattoo data before application
/obj/item/custom_tattoo_kit/proc/validate_tattoo_data(zone, mob/user)
	var/list/result = list("success" = FALSE)

	// Get form data
	var/artist_name = artist_names[zone]
	var/tattoo_design = tattoo_designs[zone]
	var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
	var/font = selected_fonts[zone] || PEN_FONT

	// Validate required fields
	if(!artist_name || !istext(artist_name) || trimtext(artist_name) == "")
		result["message"] = "Please enter a valid artist name!"
		return result

	if(!tattoo_design || !istext(tattoo_design) || trimtext(tattoo_design) == "")
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

	if(custom_tattoo_uses <= 0)
		result["message"] = "This body art kit is out of ink!"
		return result

	// All validation passed
	result["success"] = TRUE
	result["artist"] = trimmed_artist
	result["design"] = trimmed_design
	result["layer"] = layer
	result["font"] = font
	result["part_info"] = part_info

	return result

/// Re-validate tattoo data after do_after delay
/obj/item/custom_tattoo_kit/proc/revalidate_tattoo_data(zone)
	var/list/result = list("success" = FALSE)

	// Re-check body part availability
	var/list/current_parts = get_all_custom_tattoo_body_parts(current_target)
	if(!(zone in current_parts) || current_parts[zone]["covered"])
		result["message"] = "The body part became unavailable during application!"
		return result

	if(custom_tattoo_uses <= 0)
		result["message"] = "The body art kit ran out of ink during application!"
		return result

	result["success"] = TRUE
	return result

/// Handle successful tattoo application
/obj/item/custom_tattoo_kit/proc/on_tattoo_applied_success(mob/user, zone, artist, design, part_info)
	// Save to preferences
	if(current_target.client?.prefs)
		current_target.client.prefs.save_custom_tattoo_data()

	// Update state
	custom_tattoo_uses = max(0, custom_tattoo_uses - 1)
	current_target.regenerate_icons()

	// Clear form data for this body part
	artist_names -= zone
	tattoo_designs -= zone
	selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
	selected_fonts[zone] = PEN_FONT

	// Notify user and log
	to_chat(user, span_green("Tattoo applied successfully to [current_target]'s [part_info["name"]]!"))
	user.log_message("applied custom tattoo '[design]' by [artist] to [current_target]'s [zone]", LOG_GAME)

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
