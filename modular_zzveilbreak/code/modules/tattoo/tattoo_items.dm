// modular_zzveilbreak/code/modules/tattoo/tattoo_items.dm
/obj/item/custom_tattoo_kit
	name = "professional tattoo kit"
	desc = "A complete tattoo application system with multiple ink reservoirs and precision needles."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	w_class = WEIGHT_CLASS_SMALL
	var/ink_uses = 30
	var/max_ink_uses = 30
	var/mob/living/carbon/human/current_target = null
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
	icon_state = (ink_uses > 0) ? "tgun" : "tgun_empty"
	return ..()

/obj/item/custom_tattoo_kit/attack(mob/living/target, mob/living/user, params)
	if(!ishuman(target))
		return ..()
	var/mob/living/carbon/human/human_target = target

	// Check if target allows body modifications
	if(!human_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[human_target] doesn't allow body modifications!"))
		return TRUE

	current_target = human_target
	ui_interact(user)
	return TRUE

/obj/item/custom_tattoo_kit/attack_self(mob/user)
	refill_ink(user)

/obj/item/custom_tattoo_kit/proc/refill_ink(mob/user)
	ink_uses = max_ink_uses
	to_chat(user, span_notice("Tattoo kit refilled."))
	update_appearance()
	if(current_target)
		ui_interact(user)

/obj/item/custom_tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit")
		ui.open()

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

	// Current design
	data["artist_name"] = ui_data.artist_name
	data["tattoo_design"] = ui_data.tattoo_design
	data["selected_zone"] = ui_data.zone
	data["selected_layer"] = ui_data.selected_layer
	data["selected_font"] = ui_data.selected_font
	data["selected_flair"] = ui_data.selected_flair
	data["ink_color"] = ui_data.ink_color
	data["design_mode"] = ui_data.design_mode
	data["debug_mode"] = ui_data.debug_mode

	// Available options
	data["font_options"] = ui_data.font_options
	data["flair_options"] = ui_data.flair_options

	// Layer options with display names
	data["layer_options"] = list(
		"1" = "Under (Bottom)",
		"2" = "Normal (Middle)",
		"3" = "Over (Top)"
	)

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
			if(can_apply_tattoo(user))
				apply_tattoo(user)
				. = TRUE

	// Save UI data back to target
	if(. && current_target)
		current_target.set_tattoo_ui_data("global", ui_data)

/obj/item/custom_tattoo_kit/proc/can_apply_tattoo(mob/user)
	if(!current_target)
		to_chat(user, span_warning("No target selected."))
		return FALSE

	var/datum/custom_tattoo_ui_data/ui_data = current_target.get_tattoo_ui_data("global")
	if(!ui_data)
		to_chat(user, span_warning("UI data not found."))
		return FALSE

	if(!ui_data.zone || !ui_data.design_mode)
		to_chat(user, span_warning("No body part selected or not in design mode."))
		return FALSE

	// Check if fields have content
	if(!ui_data.artist_name || length(ui_data.artist_name) == 0)
		to_chat(user, span_warning("Artist name is required."))
		return FALSE
	if(!ui_data.tattoo_design || length(ui_data.tattoo_design) == 0)
		to_chat(user, span_warning("Tattoo design is required."))
		return FALSE

	if(ink_uses <= 0)
		to_chat(user, span_warning("No ink remaining."))
		return FALSE

	if(!is_custom_tattoo_bodypart_existing(current_target, ui_data.zone))
		to_chat(user, span_warning("Body part doesn't exist."))
		return FALSE

	if(!get_custom_tattoo_location_accessible(current_target, ui_data.zone))
		to_chat(user, span_warning("Body part is not accessible."))
		return FALSE

	var/current_tattoos = length(current_target.get_custom_tattoos(ui_data.zone))
	if(current_tattoos >= CUSTOM_MAX_TATTOOS_PER_PART)
		to_chat(user, span_warning("Maximum tattoos reached for this body part."))
		return FALSE

	return TRUE

/obj/item/custom_tattoo_kit/proc/apply_tattoo(mob/user)
	if(!can_apply_tattoo(user))
		return FALSE

	to_chat(user, span_notice("You begin carefully applying the tattoo..."))

	if(!do_after(user, 8 SECONDS, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	var/datum/custom_tattoo_ui_data/ui_data = current_target.get_tattoo_ui_data("global")
	if(!ui_data)
		to_chat(user, span_warning("UI data lost during application."))
		return FALSE

	// Auto-detect signature format based on %s
	var/is_signature_format = findtext(ui_data.artist_name, "%s")
	var/final_artist = ui_data.artist_name
	if(is_signature_format)
		final_artist = replacetext(final_artist, "%s", user.name)

	// Create tattoo with current UI data (including flair)
	var/datum/custom_tattoo/new_tattoo = new(
		final_artist,
		ui_data.tattoo_design,
		ui_data.zone,
		ui_data.ink_color,
		ui_data.selected_layer,
		is_signature_format,
		ui_data.selected_font,
		ui_data.selected_flair
	)

	if(current_target.add_custom_tattoo(new_tattoo))
		ink_uses = max(0, ink_uses - 1)
		next_use = world.time + 2 SECONDS
		current_target.regenerate_icons()
		update_appearance()

		// Clear design but keep zone selected
		ui_data.artist_name = ""
		ui_data.tattoo_design = ""

		// Refresh UI
		ui_interact(user)
		to_chat(user, span_green("Tattoo applied successfully!"))
		return TRUE
	else
		to_chat(user, span_warning("Failed to apply tattoo!"))
		return FALSE
