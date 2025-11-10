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
	to_chat(user, span_warning("DEBUG: Tattoo kit opened on [current_target]"))
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
		to_chat(user, span_warning("DEBUG: No current target in ui_interact"))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit")
		ui.open()
		to_chat(user, span_warning("DEBUG: New TGUI opened"))

/obj/item/custom_tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	// ALWAYS provide current state
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
	if(selected_zone && current_target)
		data["preview_text"] = generate_preview()
	else
		data["preview_text"] = "Select a body part to begin designing."

	// Body parts list
	data["body_parts"] = list()
	if(current_target)
		var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
		for(var/zone in available_parts)
			var/list/part_info = available_parts[zone]
			data["body_parts"] += list(list(
				"zone" = zone,
				"name" = part_info["name"],
				"covered" = part_info["covered"],
				"current_tattoos" = part_info["current_tattoos"],
				"max_tattoos" = part_info["max_tattoos"]
			))

	// DEBUG: Show what data is being sent
	to_chat(user, span_warning("DEBUG: ui_data sending - artist: '[artist_name]', design: '[tattoo_design]', zone: [selected_zone]"))

	return data

/obj/item/custom_tattoo_kit/proc/generate_preview()
	var/preview_text = ""

	// Just show raw data for debugging
	if(artist_name && tattoo_design)
		preview_text += "<b>RAW DEBUG PREVIEW:</b><br>"
		preview_text += "Artist: [artist_name]<br>"
		preview_text += "Design: [tattoo_design]<br>"
		preview_text += "Zone: [selected_zone]<br>"
		preview_text += "Layer: [selected_layer]<br>"
		preview_text += "Font: [selected_font]<br>"
		preview_text += "Color: [ink_color]<br>"

	return preview_text || "No preview data."

/obj/item/custom_tattoo_kit/proc/can_apply_tattoo()
	if(!selected_zone || !current_target || ink_uses <= 0)
		to_chat(usr, span_warning("DEBUG: can_apply_tattoo failed - zone: [selected_zone], target: [current_target], ink: [ink_uses]"))
		return FALSE
	if(!artist_name || !tattoo_design)
		to_chat(usr, span_warning("DEBUG: can_apply_tattoo failed - artist: '[artist_name]', design: '[tattoo_design]'"))
		return FALSE
	to_chat(usr, span_warning("DEBUG: can_apply_tattoo SUCCESS"))
	return TRUE

/obj/item/custom_tattoo_kit/proc/apply_tattoo(mob/user)
	to_chat(user, span_warning("DEBUG: apply_tattoo called - artist: '[artist_name]', design: '[tattoo_design]'"))

	if(!can_apply_tattoo())
		to_chat(user, span_warning("DEBUG: apply_tattoo blocked by can_apply_tattoo"))
		return FALSE

	to_chat(user, span_notice("You begin carefully applying the tattoo..."))

	if(!do_after(user, 8 SECONDS, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	// Create tattoo with raw data - no sanitization
	var/datum/custom_tattoo/new_tattoo = new(
		artist_name,
		tattoo_design,
		selected_zone,  // Use raw zone, no conversion
		ink_color,
		selected_layer,
		FALSE,
		selected_font
	)

	to_chat(user, span_warning("DEBUG: Tattoo datum created - artist: '[new_tattoo.artist]', design: '[new_tattoo.design]'"))

	if(current_target.add_custom_tattoo(new_tattoo))
		ink_uses--
		next_use = world.time + 2 SECONDS
		current_target.regenerate_icons()
		update_appearance()
		SStgui.update_uis(src)
		to_chat(user, span_green("Tattoo applied successfully!"))
		to_chat(user, span_warning("DEBUG: Tattoo applied successfully, fields cleared"))
		return TRUE
	else
		to_chat(user, span_warning("Failed to apply tattoo!"))
		to_chat(user, span_warning("DEBUG: Tattoo application failed in add_custom_tattoo"))
		return FALSE

/obj/item/custom_tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	if(!current_target || QDELETED(current_target))
		to_chat(usr, span_warning("DEBUG: ui_act - no current target"))
		return FALSE

	to_chat(usr, span_warning("DEBUG: ui_act received - action: [action], params: [json_encode(params)]"))

	switch(action)
		if("select_zone")
			selected_zone = params["zone"]
			to_chat(usr, span_warning("DEBUG: Zone selected: [selected_zone]"))
			. = TRUE

		if("set_artist")
			artist_name = params["value"]
			to_chat(usr, span_warning("DEBUG: Artist set to: '[artist_name]'"))
			. = TRUE

		if("set_design")
			tattoo_design = params["value"]
			to_chat(usr, span_warning("DEBUG: Design set to: '[tattoo_design]'"))
			. = TRUE

		if("set_layer")
			selected_layer = text2num(params["layer"])
			to_chat(usr, span_warning("DEBUG: Layer set to: [selected_layer]"))
			. = TRUE

		if("set_font")
			selected_font = params["font"]
			to_chat(usr, span_warning("DEBUG: Font set to: [selected_font]"))
			. = TRUE

		if("change_color")
			var/new_color = input(usr, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				to_chat(usr, span_warning("DEBUG: Color changed to: [ink_color]"))
				. = TRUE

		if("apply_tattoo")
			. = apply_tattoo(usr)

		if("refill_ink")
			refill_ink(usr)
			. = TRUE

	if(.)
		SStgui.update_uis(src)
		to_chat(usr, span_warning("DEBUG: UI update triggered after [action]"))
