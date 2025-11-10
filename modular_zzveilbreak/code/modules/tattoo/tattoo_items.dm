// modular_zzveilbreak/code/modules/tattoo/tattoo_items.dm
// Tattoo kit item + TGUI integration. Uses SStgui subsystem for updates.

/obj/item/custom_tattoo_kit
	name = "professional tattoo kit"
	desc = "A complete tattoo application system with multiple ink reservoirs and precision needles."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	w_class = WEIGHT_CLASS_SMALL
	var/ink_uses = 30
	var/max_ink_uses = 30
	var/ink_color = "#000000"
	var/mob/living/carbon/human/current_target = null
	var/next_use = 0
	var/selected_zone = null
	// Store UI data temporarily in the kit for the current session
	var/datum/custom_tattoo_ui_data/current_ui_data

/obj/item/custom_tattoo_kit/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/custom_tattoo_kit/Destroy()
	current_target = null
	current_ui_data = null
	return ..()

/obj/item/custom_tattoo_kit/examine(mob/user)
	. = ..()
	. += span_info("Ink remaining: [ink_uses]/[max_ink_uses]")

/obj/item/custom_tattoo_kit/update_icon_state()
	icon_state = (ink_uses > 0) ? "tgun" : "tgun_empty"
	return ..()

// When attacking a mob with the kit, open UI if allowed
/obj/item/custom_tattoo_kit/attack(mob/living/target, mob/living/user, params)
	if(!ishuman(target))
		return ..()
	var/mob/living/carbon/human/human_target = target
	if(!human_target.client?.prefs?.read_preference(CUSTOM_TATTOO_PREFERENCE_PATH))
		to_chat(user, span_warning("[human_target] doesn't allow body modifications!"))
		return TRUE
	if(world.time < next_use)
		to_chat(user, span_warning("The kit needs a moment to recharge."))
		return TRUE
	current_target = human_target
	selected_zone = null
	current_ui_data = null
	ui_interact(user)
	return TRUE

/obj/item/custom_tattoo_kit/attack_self(mob/user)
	refill_ink(user)

// Refill ink
/obj/item/custom_tattoo_kit/proc/refill_ink(mob/user)
	if(ink_uses >= max_ink_uses)
		to_chat(user, span_warning("The ink reservoir is already full!"))
		return
	ink_uses = max_ink_uses
	to_chat(user, span_notice("Tattoo kit refilled. Current ink: [ink_uses]/[max_ink_uses]"))
	update_appearance()

// Open or update the TGUI for the user
/obj/item/custom_tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	if(!current_target || QDELETED(current_target))
		to_chat(user, span_warning("No target selected!"))
		return
	var/datum/tgui/active_ui = SStgui.try_update_ui(user, src, ui)
	if(!active_ui)
		active_ui = new(user, src, "TattooKit")
		active_ui.open()

// Provide data for TGUI
/obj/item/custom_tattoo_kit/ui_data(mob/user)
	// If no target, provide safe defaults
	if(!current_target || QDELETED(current_target))
		return list(
			"target_name" = "No Target",
			"ink_uses" = ink_uses,
			"max_ink_uses" = max_ink_uses,
			"ink_color" = ink_color,
			"selected_zone" = null,
			"artist_name" = "",
			"tattoo_design" = "",
			"selected_layer" = CUSTOM_TATTOO_LAYER_NORMAL,
			"selected_font" = PEN_FONT,
			"preview_text" = "Select a body part to begin designing.",
			"body_parts" = list()
		)

	var/list/data = list()
	data["target_name"] = current_target?.name || "Unknown Target"
	data["ink_uses"] = ink_uses
	data["max_ink_uses"] = max_ink_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone

	// Use current_ui_data if we have it, otherwise try to load from target
	if(selected_zone && current_ui_data)
		data["artist_name"] = current_ui_data.artist_name
		data["tattoo_design"] = current_ui_data.tattoo_design
		data["selected_layer"] = current_ui_data.selected_layer
		data["selected_font"] = current_ui_data.selected_font
		data["preview_text"] = generate_selected_preview(selected_zone, user)
	else if(selected_zone)
		// Try to load from target's stored UI data
		var/datum/custom_tattoo_ui_data/target_ui_data = current_target.get_tattoo_ui_data(selected_zone)
		if(target_ui_data)
			current_ui_data = target_ui_data
			data["artist_name"] = current_ui_data.artist_name
			data["tattoo_design"] = current_ui_data.tattoo_design
			data["selected_layer"] = current_ui_data.selected_layer
			data["selected_font"] = current_ui_data.selected_font
			data["preview_text"] = generate_selected_preview(selected_zone, user)
		else
			// No existing data, create new
			current_ui_data = new(selected_zone)
			data["artist_name"] = ""
			data["tattoo_design"] = ""
			data["selected_layer"] = CUSTOM_TATTOO_LAYER_NORMAL
			data["selected_font"] = PEN_FONT
			data["preview_text"] = "Design a new tattoo for this area."
	else
		// No zone selected, use defaults
		data["artist_name"] = ""
		data["tattoo_design"] = ""
		data["selected_layer"] = CUSTOM_TATTOO_LAYER_NORMAL
		data["selected_font"] = PEN_FONT
		data["preview_text"] = "Select a body part to begin designing."

	// List all body parts for UI table
	data["body_parts"] = list()
	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	for(var/zone in available_parts)
		var/list/part_info = available_parts[zone]
		data["body_parts"] += list(list(
			"zone" = zone,
			"name" = part_info["name"] || "Unknown",
			"covered" = part_info["covered"] ? TRUE : FALSE,
			"current_tattoos" = part_info["current_tattoos"] || 0,
			"max_tattoos" = part_info["max_tattoos"] || CUSTOM_MAX_TATTOOS_PER_PART
		))

	return data

// Build preview HTML text to show in TGUI preview panel
/obj/item/custom_tattoo_kit/proc/generate_selected_preview(zone, mob/user)
	var/preview_text = ""
	var/actual_zone = string_to_zone(zone)
	var/list/tattoos = current_target.get_custom_tattoos(actual_zone)

	// list existing tattoos in that area
	if(tattoos && length(tattoos) > 0)
		preview_text += "<b>Existing Tattoos:</b><br>"
		for(var/datum/custom_tattoo/tattoo as anything in tattoos)
			if(QDELETED(tattoo)) continue
			var/tattoo_text = tattoo.get_examine_text_tgui(user, current_target)
			if(tattoo_text)
				preview_text += tattoo_text + "<br>"
		preview_text += "<br>"

	// Show preview for new tattoo (if UI draft exists)
	if(current_ui_data)
		var/artist = current_ui_data.artist_name
		var/design = current_ui_data.tattoo_design
		var/layer = current_ui_data.selected_layer || CUSTOM_TATTOO_LAYER_NORMAL
		var/font = current_ui_data.selected_font || PEN_FONT
		if(artist && design)
			var/datum/custom_tattoo/preview_tattoo = new(artist, design, actual_zone, ink_color, layer, FALSE, font)
			var/preview_tattoo_text = preview_tattoo.get_examine_text_tgui(user, current_target)
			if(preview_tattoo_text)
				preview_text += "<b>New Tattoo Preview:</b><br>"
				preview_text += preview_tattoo_text + "<br>"
			qdel(preview_tattoo)
		else if(artist || design)
			preview_text += "<b>Draft Tattoo (incomplete):</b><br>"
			if(artist)
				preview_text += "Artist: [artist]<br>"
			if(design)
				preview_text += "Design: [design]<br>"

	return preview_text || "No tattoos on this area. Design a new one above!"

// Save current UI data to target
/obj/item/custom_tattoo_kit/proc/save_ui_data_to_target()
	if(selected_zone && current_ui_data && current_target)
		current_target.set_tattoo_ui_data(selected_zone, current_ui_data)

// Attempt to apply tattoo to selected zone (called from UI)
/obj/item/custom_tattoo_kit/proc/handle_apply_tattoo(mob/user, zone)
	if(!current_target || QDELETED(current_target))
		return FALSE

	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	var/list/part_info = available_parts[zone]
	if(!part_info)
		return FALSE

	if(part_info["covered"])
		to_chat(user, span_warning("[current_target]'s [part_info["name"]] is covered! Expose it first."))
		return FALSE

	if(part_info["current_tattoos"] >= part_info["max_tattoos"])
		to_chat(user, span_warning("This body part already has the maximum number of tattoos!"))
		return FALSE

	if(!current_target.client?.prefs?.read_preference(CUSTOM_TATTOO_PREFERENCE_PATH))
		to_chat(user, span_warning("[current_target] doesn't allow body modifications!"))
		return FALSE

	if(ink_uses <= 0)
		to_chat(user, span_warning("The tattoo kit is out of ink!"))
		return FALSE

	if(!current_ui_data)
		to_chat(user, span_warning("No tattoo design data found!"))
		return FALSE

	var/artist_name = trim(current_ui_data.artist_name)
	var/tattoo_design = trim(current_ui_data.tattoo_design)

	if(!artist_name || artist_name == "")
		to_chat(user, span_warning("Please enter a valid artist name!"))
		return FALSE

	if(!tattoo_design || tattoo_design == "")
		to_chat(user, span_warning("Please enter a valid tattoo design description!"))
		return FALSE

	to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [part_info["name"]]..."))

	if(!do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	var/tattoo_zone_define = string_to_zone(zone)
	var/layer = current_ui_data.selected_layer || CUSTOM_TATTOO_LAYER_NORMAL
	var/font = current_ui_data.selected_font || PEN_FONT

	var/datum/custom_tattoo/new_tattoo = new(artist_name, tattoo_design, tattoo_zone_define, ink_color, layer, FALSE, font)

	if(current_target.add_custom_tattoo(new_tattoo))
		ink_uses = max(0, ink_uses - 1)
		next_use = world.time + 2 SECONDS
		// Clear the UI data after successful application
		current_target.clear_tattoo_ui_data(zone)
		current_ui_data = null
		if(current_target.client?.prefs)
			current_target.client.prefs.save_custom_tattoo_data()
		current_target.regenerate_icons()
		update_appearance()
		SStgui.update_uis(src)
		to_chat(user, span_green("Tattoo applied successfully to [current_target]'s [part_info["name"]]!"))
		user.log_message("applied custom tattoo '[tattoo_design]' by [artist_name] to [current_target]'s [zone]", LOG_GAME)
		return TRUE
	else
		to_chat(user, span_warning("Failed to apply tattoo!"))
		return FALSE

// TGUI action handler for the item
/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = usr

	if(!current_target || QDELETED(current_target) || !istype(current_target, /mob/living/carbon/human))
		to_chat(user, span_warning("The target is no longer valid!"))
		current_target = null
		current_ui_data = null
		return FALSE

	if(!user.is_holding(src))
		to_chat(user, span_warning("You must be holding the tattoo kit!"))
		return FALSE

	switch(action)
		if("select_zone")
			var/zone = params["zone"]
			if(!zone || !istext(zone))
				return FALSE
			var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
			if(!(zone in available_parts))
				return FALSE
			selected_zone = zone
			// Load or create UI data for the selected zone
			current_ui_data = current_target.get_tattoo_ui_data(selected_zone)
			if(!current_ui_data)
				current_ui_data = new(selected_zone)
			SStgui.update_uis(src)
			return TRUE

		if("set_artist")
			if(!selected_zone)
				to_chat(user, span_warning("No body part selected!"))
				return FALSE
			var/value = params["value"] || ""
			if(!current_ui_data)
				current_ui_data = new(selected_zone)
			current_ui_data.artist_name = value
			// Save to target immediately
			save_ui_data_to_target()
			SStgui.update_uis(src)
			return TRUE

		if("set_design")
			if(!selected_zone)
				to_chat(user, span_warning("No body part selected!"))
				return FALSE
			var/value = params["value"] || ""
			if(!current_ui_data)
				current_ui_data = new(selected_zone)
			current_ui_data.tattoo_design = value
			// Save to target immediately
			save_ui_data_to_target()
			SStgui.update_uis(src)
			return TRUE

		if("set_layer")
			if(!selected_zone)
				to_chat(user, span_warning("No body part selected!"))
				return FALSE
			var/layer = params["layer"]
			if(isnull(layer))
				return FALSE
			if(!current_ui_data)
				current_ui_data = new(selected_zone)
			current_ui_data.selected_layer = text2num(layer)
			// Save to target immediately
			save_ui_data_to_target()
			SStgui.update_uis(src)
			return TRUE

		if("set_font")
			if(!selected_zone)
				to_chat(user, span_warning("No body part selected!"))
				return FALSE
			var/font = params["font"]
			if(isnull(font))
				return FALSE
			if(!current_ui_data)
				current_ui_data = new(selected_zone)
			current_ui_data.selected_font = font
			// Save to target immediately
			save_ui_data_to_target()
			SStgui.update_uis(src)
			return TRUE

		if("change_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				SStgui.update_uis(src)
				return TRUE

		if("apply_tattoo")
			if(!selected_zone)
				to_chat(user, span_warning("No body part selected!"))
				return FALSE
			return handle_apply_tattoo(user, selected_zone)

		if("refill_ink")
			refill_ink(user)
			SStgui.update_uis(src)
			return TRUE

	return FALSE
