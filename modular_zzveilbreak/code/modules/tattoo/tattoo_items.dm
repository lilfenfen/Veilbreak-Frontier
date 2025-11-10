// modular_zzveilbreak/code/modules/tattoo/tattoo_items.dm
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

	// SIMPLE STATE - No complex datums
	var/selected_zone = null
	var/artist_name = ""
	var/tattoo_design = ""
	var/selected_layer = 2
	var/selected_font = "PEN_FONT"

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
	current_target = human_target
	ui_interact(user)
	return TRUE

/obj/item/custom_tattoo_kit/attack_self(mob/user)
	refill_ink(user)

/obj/item/custom_tattoo_kit/proc/refill_ink(mob/user)
	ink_uses = max_ink_uses
	to_chat(user, span_notice("Tattoo kit refilled."))
	update_appearance()
	SStgui.update_uis(src)

/obj/item/custom_tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	if(!current_target || QDELETED(current_target))
		to_chat(user, span_warning("No target selected."))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit")
		ui.open()

/obj/item/custom_tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	// ALWAYS provide current state with null checks
	data["target_name"] = current_target?.name || "No Target"
	data["ink_uses"] = ink_uses
	data["max_ink_uses"] = max_ink_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone
	data["artist_name"] = artist_name
	data["tattoo_design"] = tattoo_design
	data["selected_layer"] = selected_layer
	data["selected_font"] = selected_font

	// Generate preview
	data["preview_text"] = generate_preview()

	// Body parts list
	data["body_parts"] = list()
	if(current_target)
		var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
		for(var/zone in available_parts)
			var/list/part_info = available_parts[zone]
			data["body_parts"] += list(list(
				"zone" = zone,
				"name" = part_info["name"] || "Unknown",
				"covered" = part_info["covered"] || FALSE,
				"current_tattoos" = part_info["current_tattoos"] || 0,
				"max_tattoos" = part_info["max_tattoos"] || 0
			))

	return data

/obj/item/custom_tattoo_kit/proc/generate_preview()
	if(!selected_zone || !current_target)
		return "Select a body part to begin designing."

	var/preview_text = "<div style='text-align: center;'>"

	if(artist_name && tattoo_design)
		preview_text += "<h3 style='color: [ink_color]; margin-bottom: 8px;'>Tattoo Preview</h3>"
		preview_text += "<div style='border: 1px dashed [ink_color]; padding: 10px; border-radius: 4px;'>"
		preview_text += "<strong>Artist:</strong> [artist_name]<br>"
		preview_text += "<strong>Design:</strong> [tattoo_design]<br>"
		preview_text += "<strong>Location:</strong> [selected_zone]<br>"
		preview_text += "<strong>Layer:</strong> [selected_layer == 1 ? "Under" : selected_layer == 2 ? "Normal" : "Over"]<br>"
		preview_text += "<strong>Style:</strong> [selected_font]<br>"
		preview_text += "</div>"
		preview_text += "<div style='margin-top: 8px; font-size: 0.8em; color: #666;'>"
		preview_text += "Color: <span style='color: [ink_color];'>[ink_color]</span>"
		preview_text += "</div>"
	else
		preview_text += "<div style='padding: 20px; color: #666;'>"
		preview_text += "<i>Enter artist name and design description to see preview</i>"
		preview_text += "</div>"

	preview_text += "</div>"
	return preview_text

/obj/item/custom_tattoo_kit/proc/can_apply_tattoo()
	if(!selected_zone || !current_target || ink_uses <= 0)
		return FALSE
	if(!artist_name || !tattoo_design)
		return FALSE
	if(!is_custom_tattoo_bodypart_existing(current_target, selected_zone))
		return FALSE
	if(!get_custom_tattoo_location_accessible(current_target, selected_zone))
		return FALSE
	var/current_tattoos = length(current_target.get_custom_tattoos(selected_zone))
	if(current_tattoos >= CUSTOM_MAX_TATTOOS_PER_PART)
		return FALSE
	return TRUE

/obj/item/custom_tattoo_kit/proc/apply_tattoo(mob/user)
	if(!can_apply_tattoo())
		to_chat(user, span_warning("Cannot apply tattoo - check requirements."))
		return FALSE

	to_chat(user, span_notice("You begin carefully applying the tattoo..."))

	if(!do_after(user, 8 SECONDS, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	// Create tattoo with current data - NO SANITIZATION of artist/design
	var/datum/custom_tattoo/new_tattoo = new(
		artist_name,        // Preserved exactly as user entered
		tattoo_design,      // Preserved exactly as user entered
		selected_zone,
		ink_color,
		selected_layer,
		FALSE,
		selected_font
	)

	if(current_target.add_custom_tattoo(new_tattoo))
		ink_uses = max(0, ink_uses - 1)
		next_use = world.time + 2 SECONDS
		current_target.regenerate_icons()
		update_appearance()
		SStgui.update_uis(src)
		to_chat(user, span_green("Tattoo applied successfully!"))
		return TRUE
	else
		to_chat(user, span_warning("Failed to apply tattoo!"))
		return FALSE

/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	if(!current_target || QDELETED(current_target))
		return FALSE

	switch(action)
		if("select_zone")
			var/new_zone = params["zone"]
			if(new_zone && is_custom_tattoo_bodypart_existing(current_target, new_zone))
				selected_zone = new_zone
				. = TRUE
			else
				selected_zone = null
				. = TRUE

		if("set_artist")
			var/new_artist = params["value"] || "" // NO TRIMMING - preserve exact input
			// Only validate presence, don't modify data
			if(length(new_artist) > 0)
				artist_name = new_artist
				. = TRUE
			else
				artist_name = ""
				. = TRUE

		if("set_design")
			var/new_design = params["value"] || "" // NO TRIMMING - preserve exact input
			if(length(new_design) > 0)
				tattoo_design = new_design
				. = TRUE
			else
				tattoo_design = ""
				. = TRUE

		if("set_layer")
			var/new_layer = text2num(params["layer"])
			if(new_layer in list(1, 2, 3))
				selected_layer = new_layer
				. = TRUE

		if("set_font")
			var/new_font = params["font"]
			if(new_font in list("PEN_FONT", "FOUNTAIN_PEN_FONT", "PRINTER_FONT"))
				selected_font = new_font
				. = TRUE

		if("change_color")
			var/new_color = input(usr, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				. = TRUE

		if("apply_tattoo")
			if(can_apply_tattoo())
				. = apply_tattoo(usr)
			else
				to_chat(usr, span_warning("Cannot apply tattoo - check requirements."))
				. = FALSE

		if("refill_ink")
			refill_ink(usr)
			. = TRUE

	if(.)
		SStgui.update_uis(src)
