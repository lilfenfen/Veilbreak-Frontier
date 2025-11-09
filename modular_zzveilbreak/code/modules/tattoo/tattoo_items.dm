/obj/item/custom_tattoo_kit
	name = "professional tattoo kit - DEBUG MODE"
	desc = "A complete tattoo application system with multiple ink reservoirs and precision needles. DEBUG MODE ACTIVE."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	w_class = WEIGHT_CLASS_SMALL
	var/ink_uses = 30
	var/max_ink_uses = 30
	var/ink_color = "#000000"
	var/mob/living/carbon/human/current_target
	var/list/expanded_parts = list()
	var/list/artist_names = list()
	var/list/tattoo_designs = list()
	var/list/selected_layers = list()
	var/list/selected_fonts = list()
	var/next_use = 0

/obj/item/custom_tattoo_kit/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/custom_tattoo_kit/Destroy()
	current_target = null
	return ..()

/obj/item/custom_tattoo_kit/examine(mob/user)
	. = ..()
	. += span_info("Ink remaining: [ink_uses]/[max_ink_uses]")
	. += span_warning("DEBUG MODE ACTIVE - Extra logging enabled")

/obj/item/custom_tattoo_kit/update_icon_state()
	icon_state = "tattoo_kit[ink_uses > 0 ? "" : "_empty"]"
	return ..()

/obj/item/custom_tattoo_kit/attack(mob/living/target, mob/living/user, params)
	if(!ishuman(target))
		return ..()

	var/mob/living/carbon/human/human_target = target

	if(!human_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[human_target] doesn't allow body modifications!"))
		return TRUE

	if(world.time < next_use)
		to_chat(user, span_warning("The kit needs a moment to recharge."))
		return TRUE

	if(current_target != human_target)
		current_target = human_target
		to_chat(user, span_warning("DEBUG: New target set: [current_target]"))

	ui_interact(user)
	return TRUE

/obj/item/custom_tattoo_kit/attack_self(mob/user)
	. = ..()
	refill_ink(user)

/obj/item/custom_tattoo_kit/proc/refill_ink(mob/user)
	if(ink_uses >= max_ink_uses)
		to_chat(user, span_warning("The ink reservoir is already full!"))
		return

	ink_uses = max_ink_uses
	to_chat(user, span_notice("Tattoo kit refilled. Current ink: [ink_uses]/[max_ink_uses]"))
	update_appearance()

/obj/item/custom_tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	if(!current_target)
		to_chat(user, span_warning("No target selected!"))
		return

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit")
		ui.open()
		to_chat(user, span_warning("DEBUG: UI opened for target [current_target]"))

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

	// DEBUG: Log the data being sent
	to_chat(user, span_warning("DEBUG UI_DATA:"))
	to_chat(user, span_warning("  target_name: [data["target_name"]]"))
	to_chat(user, span_warning("  ink_uses: [data["ink_uses"]]"))
	to_chat(user, span_warning("  artist_names contents:"))
	for(var/zone in artist_names)
		to_chat(user, span_warning("    [zone] = '[artist_names[zone]]'"))
	to_chat(user, span_warning("  tattoo_designs contents:"))
	for(var/zone in tattoo_designs)
		to_chat(user, span_warning("    [zone] = '[tattoo_designs[zone]]'"))
	to_chat(user, span_warning("  body_parts count: [data["body_parts"] ? data["body_parts"].len : "NULL"]"))

	return data

/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	if(!current_target || QDELETED(current_target) || !istype(current_target, /mob/living/carbon/human))
		to_chat(user, span_warning("The target is no longer valid!"))
		current_target = null
		return FALSE

	if(!user.is_holding(src))
		to_chat(user, span_warning("You must be holding the tattoo kit!"))
		return FALSE

	var/zone = params["zone"]
	if(!zone || !istext(zone))
		to_chat(user, span_warning("DEBUG: No zone parameter or invalid zone: [zone]"))
		return FALSE

	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	if(!(zone in available_parts))
		to_chat(user, span_warning("DEBUG: Zone [zone] not in available_parts: [jointext(available_parts, ", ")]"))
		return FALSE

	to_chat(user, span_warning("DEBUG UI_ACT: action=[action], zone=[zone]"))

	switch(action)
		if("toggle_expand")
			if(zone in expanded_parts)
				expanded_parts -= zone
				to_chat(user, span_warning("DEBUG: Collapsed zone [zone]"))
			else
				expanded_parts |= zone
				if(!(zone in selected_layers))
					selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
				if(!(zone in selected_fonts))
					selected_fonts[zone] = PEN_FONT
				if(!(zone in artist_names))
					artist_names[zone] = ""
				if(!(zone in tattoo_designs))
					tattoo_designs[zone] = ""
				to_chat(user, span_warning("DEBUG: Expanded zone [zone], initialized defaults"))
			return TRUE

		if("set_artist")
			var/value = params["value"]
			to_chat(user, span_warning("DEBUG: set_artist received value: '[value]' (isnull: [isnull(value)], istext: [istext(value)])"))
			// Handle null values by converting to empty string
			if(isnull(value))
				value = ""
			artist_names[zone] = value
			to_chat(user, span_warning("DEBUG: set_artist [zone] = '[value]' (istext: [istext(value)], length: [length(value)]"))
			to_chat(user, span_warning("DEBUG: artist_names[zone] is now: '[artist_names[zone]]'"))
			// Force immediate UI update
			SStgui.update_uis(src)
			return TRUE

		if("set_design")
			var/value = params["value"]
			to_chat(user, span_warning("DEBUG: set_design received value: '[value]' (isnull: [isnull(value)], istext: [istext(value)])"))
			// Handle null values by converting to empty string
			if(isnull(value))
				value = ""
			tattoo_designs[zone] = value
			to_chat(user, span_warning("DEBUG: set_design [zone] = '[value]' (istext: [istext(value)], length: [length(value)]"))
			to_chat(user, span_warning("DEBUG: tattoo_designs[zone] is now: '[tattoo_designs[zone]]'"))
			// Force immediate UI update
			SStgui.update_uis(src)
			return TRUE

		if("set_layer")
			var/layer = params["layer"]
			if(!isnull(layer))
				selected_layers[zone] = text2num(layer)
				to_chat(user, span_warning("DEBUG: set_layer [zone] = [layer]"))
				return TRUE

		if("set_font")
			var/font = params["font"]
			if(!isnull(font))
				selected_fonts[zone] = font
				to_chat(user, span_warning("DEBUG: set_font [zone] = [font]"))
				return TRUE

		if("change_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				to_chat(user, span_warning("DEBUG: change_color to [new_color]"))
				return TRUE

		if("apply_tattoo")
			return handle_apply_tattoo(user, zone, params)

		if("refill_ink")
			refill_ink(user)
			return TRUE

		if("debug_log")
			var/message = params["message"]
			if(message)
				to_chat(user, span_warning("DEBUG FROM UI: [message]"))
				return TRUE

	return FALSE

/obj/item/custom_tattoo_kit/proc/generate_part_preview(zone, mob/user)
	var/preview_text = ""
	var/actual_zone = string_to_zone(zone)
	var/list/tattoos = current_target.get_custom_tattoos(actual_zone)

	if(tattoos)
		for(var/datum/custom_tattoo/tattoo as anything in tattoos)
			if(QDELETED(tattoo))
				continue
			var/tattoo_text = tattoo.get_examine_text(user, current_target)
			if(tattoo_text)
				preview_text += tattoo_text + "<br>"

	if(zone in tattoo_designs && zone in artist_names)
		var/artist = artist_names[zone]
		var/design = tattoo_designs[zone]
		var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
		var/font = selected_fonts[zone] || PEN_FONT

		if(artist && design)
			var/datum/custom_tattoo/preview_tattoo = new(artist, design, actual_zone, ink_color, layer, FALSE, font)
			var/preview_tattoo_text = preview_tattoo.get_examine_text(user, current_target)
			if(preview_tattoo_text)
				preview_text += "<span style='color: [ink_color];'><b>Preview:</b> [preview_tattoo_text]</span><br>"
			qdel(preview_tattoo)

	return preview_text || "No tattoos yet."

/obj/item/custom_tattoo_kit/proc/handle_apply_tattoo(mob/user, zone, list/params)
	to_chat(user, span_warning("=== START handle_apply_tattoo ==="))
	to_chat(user, span_warning("DEBUG: Zone: [zone]"))
	to_chat(user, span_warning("DEBUG: Params received: artist='[params["artist"]]', design='[params["design"]]'"))

	// Try to get values from multiple sources in order of priority
	var/artist_name = params["artist"]
	var/tattoo_design = params["design"]

	to_chat(user, span_warning("DEBUG: From params - Artist: '[artist_name]', Design: '[tattoo_design]'"))

	// If not passed in params, try stored data
	if(!artist_name || artist_name == "")
		artist_name = artist_names[zone]
		to_chat(user, span_warning("DEBUG: From stored - Artist: '[artist_name]'"))
	if(!tattoo_design || tattoo_design == "")
		tattoo_design = tattoo_designs[zone]
		to_chat(user, span_warning("DEBUG: From stored - Design: '[tattoo_design]'"))

	// FINAL DEBUG: Show what we found
	to_chat(user, span_warning("DEBUG: Final values - Artist: '[artist_name]', Design: '[tattoo_design]'"))

	// Check body part availability
	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	var/list/part_info = available_parts[zone]
	if(!part_info)
		to_chat(user, span_warning("The selected body part is no longer available!"))
		to_chat(user, span_warning("DEBUG: Part info not found for zone [zone]"))
		return FALSE

	to_chat(user, span_warning("DEBUG: Part info - [part_info["name"]], covered: [part_info["covered"]], tattoos: [part_info["current_tattoos"]]/[part_info["max_tattoos"]]"))

	if(part_info["covered"])
		to_chat(user, span_warning("[current_target]'s [part_info["name"]] is covered! Expose it first."))
		return FALSE

	if(part_info["current_tattoos"] >= part_info["max_tattoos"])
		to_chat(user, span_warning("This body part already has the maximum number of tattoos!"))
		return FALSE

	if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[current_target] doesn't allow body modifications!"))
		return FALSE

	if(ink_uses <= 0)
		to_chat(user, span_warning("The tattoo kit is out of ink!"))
		return FALSE

	// FINAL VALIDATION
	if(!artist_name || artist_name == "")
		to_chat(user, span_warning("Please enter a valid artist name!"))
		to_chat(user, span_warning("DEBUG: VALIDATION FAILED - No artist name"))
		return FALSE

	if(!tattoo_design || tattoo_design == "")
		to_chat(user, span_warning("Please enter a valid tattoo design description!"))
		to_chat(user, span_warning("DEBUG: VALIDATION FAILED - No tattoo design"))
		return FALSE

	to_chat(user, span_warning("DEBUG: All validations passed, starting application..."))

	// Start application
	to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [part_info["name"]]..."))

	if(!do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	// Create and apply tattoo
	var/tattoo_zone_define = string_to_zone(zone)
	var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
	var/font = selected_fonts[zone] || PEN_FONT

	to_chat(user, span_warning("DEBUG: Creating tattoo - Zone: [tattoo_zone_define], Layer: [layer], Font: [font]"))

	var/datum/custom_tattoo/new_tattoo = new(artist_name, tattoo_design, tattoo_zone_define, ink_color, layer, FALSE, font)

	if(current_target.add_custom_tattoo(new_tattoo))
		ink_uses = max(0, ink_uses - 1)
		next_use = world.time + 2 SECONDS

		if(current_target.client?.prefs)
			current_target.client.prefs.save_custom_tattoo_data()

		current_target.regenerate_icons()
		update_appearance()

		// Clear form data for this zone
		artist_names -= zone
		tattoo_designs -= zone
		selected_layers[zone] = CUSTOM_TATTOO_LAYER_NORMAL
		selected_fonts[zone] = PEN_FONT

		to_chat(user, span_green("Tattoo applied successfully to [current_target]'s [part_info["name"]]!"))
		to_chat(user, span_warning("DEBUG: Tattoo applied successfully!"))
		user.log_message("applied custom tattoo '[tattoo_design]' by [artist_name] to [current_target]'s [zone]", LOG_GAME)
		return TRUE
	else
		to_chat(user, span_warning("Failed to apply tattoo!"))
		to_chat(user, span_warning("DEBUG: add_custom_tattoo returned FALSE"))
		return FALSE
