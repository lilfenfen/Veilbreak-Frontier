// modular_zzveilbreak/code/modules/tattoo/tattoo_ui_data.dm
// Data storage for tattoo UI state - no HTML generation

/datum/custom_tattoo_ui_data
	var/zone = ""
	var/artist_name = ""
	var/tattoo_design = ""
	var/selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT
	var/selected_flair = null
	var/ink_color = "#000000"
	var/design_mode = FALSE
	var/debug_mode = FALSE

	// Static options for TGUI
	var/static/list/font_options = list(
		"PEN_FONT" = "Pen",
		"FOUNTAIN_PEN_FONT" = "Fountain Pen",
		"PRINTER_FONT" = "Printer",
		"CHARCOAL_FONT" = "Charcoal",
		"CRAYON_FONT" = "Crayon"
	)

	var/static/list/flair_options = list(
		"null" = "No Flair",
		"flair_1" = "Pink Flair",
		"flair_2" = "Love Flair",
		"flair_3" = "Brown Flair",
		"flair_4" = "Cyan Flair",
		"flair_5" = "Orange Flair",
		"flair_6" = "Yellow Flair",
		"flair_7" = "Subtle Flair",
		"flair_8" = "Velvet Flair",
		"flair_9" = "Velvet Notice",
		"flair_10" = "Glossy Flair"
	)

	var/static/list/layer_options = list(
		"1" = "Under (Bottom)",
		"2" = "Normal (Middle)",
		"3" = "Over (Top)"
	)

	New(new_zone = "")
		zone = new_zone

	// Clear all data
	proc/clear()
		artist_name = ""
		tattoo_design = ""
		selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
		selected_font = PEN_FONT
		selected_flair = null
		ink_color = "#000000"
		design_mode = FALSE
		debug_mode = FALSE

	// Convert UI data to tattoo parameters for application
	proc/get_tattoo_params()
		return list(
			"artist" = artist_name,
			"design" = tattoo_design,
			"zone" = zone,
			"color" = ink_color,
			"layer" = selected_layer,
			"font" = selected_font,
			"flair" = selected_flair
		)

	// Validate if current data is ready for tattoo application
	proc/is_ready_for_application()
		if(!zone || !design_mode)
			return FALSE
		if(!artist_name || length(artist_name) == 0)
			return FALSE
		if(!tattoo_design || length(tattoo_design) == 0)
			return FALSE
		return TRUE

// TGUI data preparation for the tattoo kit
/obj/item/custom_tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	// Target information
	data["target_name"] = current_target ? current_target.name : null
	data["target_ref"] = current_target ? REF(current_target) : null

	// Kit status
	data["ink_uses"] = ink_uses
	data["max_ink_uses"] = max_ink_uses
	data["applying"] = (world.time < next_use)

	// Get current design data from target's UI data
	var/datum/custom_tattoo_ui_data/ui_data = current_target?.get_tattoo_ui_data("global")
	if(!ui_data)
		ui_data = new()
		if(current_target)
			current_target.set_tattoo_ui_data("global", ui_data)

	// Current design - using the ui_data object directly
	data["artist_name"] = ui_data.artist_name
	data["tattoo_design"] = ui_data.tattoo_design
	data["selected_zone"] = ui_data.zone
	data["selected_layer"] = ui_data.selected_layer
	data["selected_font"] = ui_data.selected_font
	data["selected_flair"] = ui_data.selected_flair
	data["ink_color"] = ui_data.ink_color
	data["design_mode"] = ui_data.design_mode
	data["debug_mode"] = ui_data.debug_mode

	// Available options - using the static lists from the datum
	data["font_options"] = ui_data.font_options
	data["flair_options"] = ui_data.flair_options
	data["layer_options"] = ui_data.layer_options

	// Body parts data
	data["body_parts"] = list()
	if(current_target)
		var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
		for(var/zone_key in available_parts)
			var/list/part_info = available_parts[zone_key]
			data["body_parts"] += list(list(
				"zone" = zone_key,
				"name" = part_info["name"],
				"covered" = part_info["covered"],
				"current_tattoos" = part_info["current_tattoos"],
				"max_tattoos" = part_info["max_tattoos"]
			))

	// Existing tattoos for current zone
	data["existing_tattoos"] = list()
	if(current_target && ui_data.zone)
		var/list/tattoos = current_target.get_custom_tattoos(ui_data.zone)
		for(var/datum/custom_tattoo/T as anything in tattoos)
			if(QDELETED(T)) continue
			data["existing_tattoos"] += list(list(
				"artist" = T.artist,
				"design" = T.design,
				"color" = T.color,
				"layer" = T.layer,
				"is_signature" = T.is_signature,
				"font" = T.font,
				"flair" = T.flair,
				"date_applied" = T.date_applied
			))

	return data

// TGUI action handling for the tattoo kit
/obj/item/custom_tattoo_kit/ui_act(action, params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/user = ui.user
	var/datum/custom_tattoo_ui_data/ui_data = current_target?.get_tattoo_ui_data("global")
	if(!ui_data)
		ui_data = new()
		if(current_target)
			current_target.set_tattoo_ui_data("global", ui_data)

	switch(action)
		if("toggle_debug")
			ui_data.debug_mode = !ui_data.debug_mode
			. = TRUE

		if("select_zone")
			var/zone = params["zone"]
			if(current_target && is_custom_tattoo_bodypart_existing(current_target, zone))
				ui_data.zone = zone
				ui_data.design_mode = TRUE
				. = TRUE

		if("back_to_parts")
			ui_data.design_mode = FALSE
			. = TRUE

		if("set_artist")
			ui_data.artist_name = params["artist"]
			. = TRUE

		if("set_design")
			ui_data.tattoo_design = params["design"]
			. = TRUE

		if("set_font")
			var/font = params["font"]
			if(font in ui_data.font_options)
				ui_data.selected_font = font
				. = TRUE

		if("set_flair")
			var/flair = params["flair"]
			ui_data.selected_flair = (flair == "null") ? null : flair
			. = TRUE

		if("set_layer")
			var/layer = text2num(params["layer"])
			if(layer in list(1, 2, 3))
				ui_data.selected_layer = layer
				. = TRUE

		if("set_color")
			ui_data.ink_color = params["color"]
			. = TRUE

		if("pick_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ui_data.ink_color) as color|null
			if(new_color)
				ui_data.ink_color = new_color
				. = TRUE

		if("apply_tattoo")
			// Use the existing can_apply_tattoo check from tattoo_items.dm
			if(can_apply_tattoo(user))
				apply_tattoo(user)
				. = TRUE

		if("remove_tattoo")
			var/tattoo_index = text2num(params["index"])
			if(current_target && ui_data.zone)
				var/list/tattoos = current_target.get_custom_tattoos(ui_data.zone)
				if(tattoo_index > 0 && tattoo_index <= length(tattoos))
					var/datum/custom_tattoo/tattoo = tattoos[tattoo_index]
					if(current_target.remove_custom_tattoo(tattoo))
						to_chat(user, span_green("Tattoo removed successfully!"))
						. = TRUE

		if("refill_ink")
			refill_ink(user)
			. = TRUE

	// Save UI data back to target
	if(. && current_target)
		current_target.set_tattoo_ui_data("global", ui_data)
