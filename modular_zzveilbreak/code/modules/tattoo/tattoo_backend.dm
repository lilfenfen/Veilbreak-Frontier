// Backend integration for tattoo system

/datum/controller/subsystem/tattoo
	name = "Tattoo System"
	init_order = INIT_ORDER_TATTOO
	flags = SS_NO_FIRE

/datum/controller/subsystem/tattoo/Initialize()
	// Initialize global lists
	GLOB.tattooable_body_parts = populate_tattooable_body_parts()

	// Register surgeries
	if(!GLOB.surgeries_list)
		GLOB.surgeries_list = list()
	GLOB.surgeries_list += typesof(/datum/surgery/tattoo_removal)

	// Register surgery step
	if(!GLOB.surgery_steps[/datum/surgery_step/cauterize_tattoo])
		GLOB.surgery_steps[/datum/surgery_step/cauterize_tattoo] = new /datum/surgery_step/cauterize_tattoo

	// Ensure preference is registered
	modular_zzveilbreak_erp_pref_override()

	return ..()

// TGUI data backend
/datum/controller/subsystem/tattoo/proc/get_tattoo_data_for_ui(mob/living/carbon/human/target, obj/item/tattoo_kit/kit)
	var/list/data = list()

	if(!target || !kit)
		return data

	data["target_name"] = target.name
	data["ink_uses"] = kit.tattoo_uses
	data["max_uses"] = kit.tattoo_max_uses
	data["ink_color"] = kit.ink_color
	data["selected_zone"] = kit.selected_zone
	data["selected_zone_name"] = get_body_zone_display_name(kit.selected_zone)
	data["current_step"] = kit.current_step
	data["selected_layer"] = kit.selected_layer

	// Get body parts data
	var/list/body_parts = list()
	var/list/all_parts = get_all_available_body_parts(target)

	for(var/zone in all_parts)
		var/list/part_info = all_parts[zone]
		var/covered = !get_tattoo_location_accessible(target, zone)
		var/current_tattoos = length(target.get_tattoos(zone))

		body_parts += list(list(
			"zone" = zone,
			"name" = part_info["name"],
			"covered" = covered,
			"current_tattoos" = current_tattoos,
			"max_tattoos" = MAX_TATTOOS_PER_PART
		))

	data["body_parts"] = body_parts

	return data

// Handle TGUI actions
/datum/controller/subsystem/tattoo/proc/handle_tattoo_action(mob/user, action, list/params, obj/item/tattoo_kit/kit)
	if(!user || !kit || !action)
		return FALSE

	switch(action)
		if("select_bodypart")
			var/zone = params["zone"]
			return kit.select_bodypart(user, zone)

		if("set_layer")
			var/layer = text2num(params["layer"])
			return kit.set_layer(user, layer)

		if("change_ink_color")
			return kit.change_ink_color(user)

		if("back_to_selection")
			return kit.back_to_selection(user)

		if("apply_tattoo")
			var/artist = params["artist"]
			var/design = params["design"]
			return kit.apply_tattoo(user, artist, design)

	return FALSE

// Additional helper procs for the tattoo kit
/obj/item/tattoo_kit/proc/select_bodypart(mob/user, zone)
	if(!zone || !current_target || !body_part_exists(current_target, zone))
		return FALSE

	if(!get_tattoo_location_accessible(current_target, zone))
		var/body_part_name = get_body_zone_display_name(zone)
		to_chat(user, span_warning("[current_target == user ? "Your" : "[current_target]'s"] [body_part_name] is covered! Expose it first."))
		return FALSE

	var/current_tattoos = current_target.get_tattoos(zone)
	if(length(current_tattoos) >= max_tattoos_per_part)
		to_chat(user, span_warning("This body part already has the maximum number of tattoos! (Max: [max_tattoos_per_part])"))
		return FALSE

	selected_zone = zone
	current_step = "design_tattoo"
	return TRUE

/obj/item/tattoo_kit/proc/set_layer(mob/user, layer)
	if(isnum(layer))
		selected_layer = sanitize_integer(layer, TATTOO_LAYER_UNDER, TATTOO_LAYER_OVER, TATTOO_LAYER_NORMAL)
		return TRUE
	return FALSE

/obj/item/tattoo_kit/proc/change_ink_color(mob/user)
	var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
	if(new_color)
		ink_color = sanitize_hexcolor(new_color, default = "#000000")
		to_chat(user, span_notice("You change the ink color to [new_color]."))
		return TRUE
	return FALSE

/obj/item/tattoo_kit/proc/back_to_selection(mob/user)
	current_step = "select_part"
	return TRUE

/obj/item/tattoo_kit/proc/apply_tattoo(mob/user, artist, design)
	// Validation is handled in the main ui_act proc
	// This is just a stub for the backend system
	return TRUE
