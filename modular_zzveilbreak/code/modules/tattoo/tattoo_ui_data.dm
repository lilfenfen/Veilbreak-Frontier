// modular_zzveilbreak/code/modules/tattoo/tattoo_ui_data.dm
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

	// Static options for TGUI - array of objects format
	var/static/list/font_options = list(
		list("name" = "Pen", "value" = "PEN_FONT"),
		list("name" = "Fountain Pen", "value" = "FOUNTAIN_PEN_FONT"),
		list("name" = "Printer", "value" = "PRINTER_FONT"),
		list("name" = "Charcoal", "value" = "CHARCOAL_FONT"),
		list("name" = "Crayon", "value" = "CRAYON_FONT")
	)

	var/static/list/flair_options = list(
		list("name" = "No Flair", "value" = "null"),
		list("name" = "Pink Flair", "value" = "flair_1"),
		list("name" = "Love Flair", "value" = "flair_2"),
		list("name" = "Brown Flair", "value" = "flair_3"),
		list("name" = "Cyan Flair", "value" = "flair_4"),
		list("name" = "Orange Flair", "value" = "flair_5"),
		list("name" = "Yellow Flair", "value" = "flair_6"),
		list("name" = "Subtle Flair", "value" = "flair_7"),
		list("name" = "Velvet Flair", "value" = "flair_8"),
		list("name" = "Velvet Notice", "value" = "flair_9"),
		list("name" = "Glossy Flair", "value" = "flair_10")
	)

	var/static/list/layer_options = list(
		list("name" = "Under (Bottom)", "value" = "1"),
		list("name" = "Normal (Middle)", "value" = "2"),
		list("name" = "Over (Top)", "value" = "3")
	)

	New(new_zone = "")
		zone = new_zone

	proc/clear()
		artist_name = ""
		tattoo_design = ""
		selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
		selected_font = PEN_FONT
		selected_flair = null
		ink_color = "#000000"
		design_mode = FALSE

	proc/is_ready_for_application()
		return zone && design_mode && artist_name && tattoo_design

/obj/item/custom_tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit")
		ui.set_autoupdate(FALSE)
		ui.open()

/obj/item/custom_tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	// Basic info
	data["target_name"] = current_target ? current_target.name : "No Target"
	data["ink_uses"] = ink_uses
	data["max_ink_uses"] = max_ink_uses
	data["applying"] = (world.time < next_use)

	// Get or create UI data
	var/datum/custom_tattoo_ui_data/ui_data = current_target?.get_tattoo_ui_data("global")
	if(!ui_data && current_target)
		ui_data = new()
		current_target.set_tattoo_ui_data("global", ui_data)

	if(ui_data)
		data["artist_name"] = ui_data.artist_name
		data["tattoo_design"] = ui_data.tattoo_design
		data["selected_zone"] = ui_data.zone
		data["selected_layer"] = ui_data.selected_layer
		data["selected_font"] = ui_data.selected_font
		data["selected_flair"] = ui_data.selected_flair
		data["ink_color"] = ui_data.ink_color
		data["design_mode"] = ui_data.design_mode
		data["debug_mode"] = ui_data.debug_mode

	// Options
	data["font_options"] = ui_data.font_options
	data["flair_options"] = ui_data.flair_options
	data["layer_options"] = ui_data.layer_options

	// Body parts - ensure proper structure
	data["body_parts"] = list()
	if(current_target)
		var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
		if(islist(available_parts))
			for(var/zone_key in available_parts)
				var/list/part_info = available_parts[zone_key]
				if(islist(part_info))
					data["body_parts"] += list(list(
						"zone" = zone_key,
						"name" = part_info["name"] || "Unknown",
						"covered" = part_info["covered"] ? 1 : 0,
						"current_tattoos" = part_info["current_tattoos"] || 0,
						"max_tattoos" = part_info["max_tattoos"] || 3
					))

	// Existing tattoos
	data["existing_tattoos"] = list()
	if(current_target && ui_data && ui_data.zone)
		var/list/tattoos = current_target.get_custom_tattoos(ui_data.zone)
		if(islist(tattoos))
			for(var/datum/custom_tattoo/T in tattoos)
				if(istype(T) && !QDELETED(T))
					data["existing_tattoos"] += list(list(
						"artist" = T.artist || "Unknown",
						"design" = T.design || "Unknown",
						"color" = T.color || "#000000",
						"layer" = T.layer || 2,
						"font" = T.font || "PEN_FONT",
						"flair" = T.flair || "null",
						"date" = T.date_applied || "Unknown"
					))

	return data

/obj/item/custom_tattoo_kit/ui_act(action, params)
	. = ..()
	if(.)
		return

	var/mob/user = usr
	var/datum/custom_tattoo_ui_data/ui_data = current_target?.get_tattoo_ui_data("global")
	if(!ui_data && current_target)
		ui_data = new()
		current_target.set_tattoo_ui_data("global", ui_data)

	if(!ui_data)
		return

	switch(action)
		if("select_zone")
			var/zone = params["zone"]
			if(current_target && is_custom_tattoo_bodypart_existing(current_target, zone))
				ui_data.zone = zone
				ui_data.design_mode = TRUE
				. = TRUE

		if("back")
			ui_data.design_mode = FALSE
			. = TRUE

		if("set_artist")
			ui_data.artist_name = params["value"]
			. = TRUE

		if("set_design")
			ui_data.tattoo_design = params["value"]
			. = TRUE

		if("set_font")
			ui_data.selected_font = params["value"]
			. = TRUE

		if("set_flair")
			ui_data.selected_flair = params["value"]
			. = TRUE

		if("set_layer")
			ui_data.selected_layer = text2num(params["value"])
			. = TRUE

		if("set_color")
			ui_data.ink_color = params["value"]
			. = TRUE

		if("pick_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ui_data.ink_color) as color|null
			if(new_color)
				ui_data.ink_color = new_color
				. = TRUE

		if("apply")
			if(can_apply_tattoo(user))
				apply_tattoo(user)
				. = TRUE

		if("remove")
			var/index = text2num(params["index"])
			if(current_target && ui_data.zone)
				var/list/tattoos = current_target.get_custom_tattoos(ui_data.zone)
				if(index > 0 && index <= tattoos.len)
					var/datum/custom_tattoo/tattoo = tattoos[index]
					if(current_target.remove_custom_tattoo(tattoo))
						to_chat(user, span_green("Tattoo removed!"))
						. = TRUE

		if("refill")
			refill_ink(user)
			. = TRUE

	if(. && current_target)
		current_target.set_tattoo_ui_data("global", ui_data)
		SStgui.update_uis(src)
