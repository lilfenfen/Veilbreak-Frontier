/obj/item/custom_tattoo_kit
	name = "professional tattoo kit"
	desc = "A complete tattoo application system with multiple ink reservoirs and precision needles."
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
		return FALSE

	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	if(!(zone in available_parts))
		return FALSE

	switch(action)
		if("toggle_expand")
			if(zone in expanded_parts)
				expanded_parts -= zone
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
			return TRUE

		if("set_artist")
			var/value = params["value"]
			if(!isnull(value))
				artist_names[zone] = value
				return TRUE

		if("set_design")
			var/value = params["value"]
			if(!isnull(value))
				tattoo_designs[zone] = value
				return TRUE

		if("set_layer")
			var/layer = params["layer"]
			if(!isnull(layer))
				selected_layers[zone] = text2num(layer)
				return TRUE

		if("set_font")
			var/font = params["font"]
			if(!isnull(font))
				selected_fonts[zone] = font
				return TRUE

		if("change_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				return TRUE

		if("apply_tattoo")
			return handle_apply_tattoo(user, zone, params)

		if("refill_ink")
			refill_ink(user)
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
	// Get the values directly from our stored data
	var/artist_name = artist_names[zone]
	var/tattoo_design = tattoo_designs[zone]

	// DEBUG: Check what we have
	to_chat(user, "DEBUG: artist_names[zone] = '[artist_name]'")
	to_chat(user, "DEBUG: tattoo_designs[zone] = '[tattoo_design]'")
	to_chat(user, "DEBUG: artist_names type: [istext(artist_name)]")
	to_chat(user, "DEBUG: tattoo_designs type: [istext(tattoo_design)]")

	// Check if we have values from UI parameters as fallback
	if(!artist_name || artist_name == "")
		artist_name = params["artist"]
	if(!tattoo_design || tattoo_design == "")
		tattoo_design = params["design"]

	// FINAL VALIDATION
	if(!artist_name || artist_name == "")
		to_chat(user, span_warning("Please enter a valid artist name!"))
		return FALSE

	if(!tattoo_design || tattoo_design == "")
		to_chat(user, span_warning("Please enter a valid tattoo design description!"))
		return FALSE

	// Check body part availability
	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	var/list/part_info = available_parts[zone]
	if(!part_info)
		to_chat(user, span_warning("The selected body part is no longer available!"))
		return FALSE

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

	// Start application
	to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [part_info["name"]]..."))

	if(!do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	// Create and apply tattoo
	var/tattoo_zone_define = string_to_zone(zone)
	var/layer = selected_layers[zone] || CUSTOM_TATTOO_LAYER_NORMAL
	var/font = selected_fonts[zone] || PEN_FONT

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
		user.log_message("applied custom tattoo '[tattoo_design]' by [artist_name] to [current_target]'s [zone]", LOG_GAME)
		return TRUE
	else
		to_chat(user, span_warning("Failed to apply tattoo!"))
		return FALSE
