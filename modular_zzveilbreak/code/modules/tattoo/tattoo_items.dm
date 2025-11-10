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
	var/selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT

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
	if(!human_target.client?.prefs?.read_preference(CUSTOM_TATTOO_PREFERENCE_PATH))
		to_chat(user, span_warning("[human_target] doesn't allow body modifications!"))
		return TRUE
	current_target = human_target
	ui_interact(user)
	return TRUE

/obj/item/custom_tattoo_kit/attack_self(mob/user)
	refill_ink(user)

/obj/item/custom_tattoo_kit/proc/refill_ink(mob/user)
	if(ink_uses >= max_ink_uses)
		to_chat(user, span_warning("The ink reservoir is already full!"))
		return
	ink_uses = max_ink_uses
	to_chat(user, span_notice("Tattoo kit refilled. Current ink: [ink_uses]/[max_ink_uses]"))
	update_appearance()
	SStgui.update_uis(src)

/obj/item/custom_tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	if(!current_target || QDELETED(current_target))
		to_chat(user, span_warning("No target selected!"))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit")
		ui.open()

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

	return data

/obj/item/custom_tattoo_kit/proc/generate_preview()
	var/preview_text = ""
	var/actual_zone = string_to_zone(selected_zone)
	var/list/tattoos = current_target.get_custom_tattoos(actual_zone)

	// Existing tattoos
	if(length(tattoos))
		preview_text += "<b>Existing Tattoos:</b><br>"
		for(var/datum/custom_tattoo/tattoo in tattoos)
			preview_text += tattoo.get_examine_text_tgui(usr, current_target) + "<br>"
		preview_text += "<br>"

	// New tattoo preview
	if(artist_name && tattoo_design)
		var/datum/custom_tattoo/preview_tattoo = new(artist_name, tattoo_design, actual_zone, ink_color, selected_layer, FALSE, selected_font)
		preview_text += "<b>New Tattoo Preview:</b><br>"
		preview_text += preview_tattoo.get_examine_text_tgui(usr, current_target) + "<br>"
		qdel(preview_tattoo)

	return preview_text || "No tattoos on this area. Design a new one above!"

/obj/item/custom_tattoo_kit/proc/can_apply_tattoo()
	if(!selected_zone || !current_target || ink_uses <= 0)
		return FALSE
	if(!artist_name || !tattoo_design)
		return FALSE
	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	var/list/part_info = available_parts[selected_zone]
	if(!part_info || part_info["covered"])
		return FALSE
	if(part_info["current_tattoos"] >= part_info["max_tattoos"])
		return FALSE
	return TRUE

/obj/item/custom_tattoo_kit/proc/apply_tattoo(mob/user)
	if(!can_apply_tattoo())
		return FALSE

	var/list/available_parts = get_all_custom_tattoo_body_parts(current_target)
	var/list/part_info = available_parts[selected_zone]

	to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target]'s [part_info["name"]]..."))

	if(!do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
		to_chat(user, span_warning("Tattoo application interrupted!"))
		return FALSE

	var/tattoo_zone_define = string_to_zone(selected_zone)
	var/datum/custom_tattoo/new_tattoo = new(
		trim(artist_name),
		trim(tattoo_design),
		tattoo_zone_define,
		ink_color,
		selected_layer,
		FALSE,
		selected_font
	)

	if(current_target.add_custom_tattoo(new_tattoo))
		ink_uses--
		next_use = world.time + 2 SECONDS
		// Clear design after successful application
		artist_name = ""
		tattoo_design = ""
		current_target.regenerate_icons()
		update_appearance()
		SStgui.update_uis(src)
		to_chat(user, span_green("Tattoo applied successfully!"))
		user.log_message("applied custom tattoo to [current_target]", LOG_GAME)
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
			selected_zone = params["zone"]
			// Reset design when changing zones
			artist_name = ""
			tattoo_design = ""
			. = TRUE

		if("set_artist")
			artist_name = params["value"]
			. = TRUE

		if("set_design")
			tattoo_design = params["value"]
			. = TRUE

		if("set_layer")
			selected_layer = text2num(params["layer"])
			. = TRUE

		if("set_font")
			selected_font = params["font"]
			. = TRUE

		if("change_color")
			var/new_color = input(usr, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				. = TRUE

		if("apply_tattoo")
			. = apply_tattoo(usr)

		if("refill_ink")
			refill_ink(usr)
			. = TRUE

	if(.)
		SStgui.update_uis(src)
