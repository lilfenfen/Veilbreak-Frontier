/obj/item/tattoo_kit
	name = "tattoo kit"
	desc = "A professional tattoo application kit with various inks and precision tools."
	icon = 'modular_zzveilbreak/icons/item_icons/tattoo.dmi'
	icon_state = "tgun"
	force = 0
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	/// Current ink color
	var/ink_color = "#000000"
	/// Maximum tattoos allowed per body part
	var/max_tattoos_per_part = 5
	/// Current number of tattoo uses remaining
	var/tattoo_uses = 10
	/// Maximum tattoo uses when fully stocked
	var/tattoo_max_uses = 50
	/// Currently selected body zone
	var/selected_zone = BODY_ZONE_CHEST
	/// The mob currently being tattooed
	var/mob/living/carbon/human/current_target
	/// Current UI step
	var/current_step = "select_part"
	/// Temporary artist name during design
	var/artist_name = ""
	/// Temporary tattoo design during design
	var/tattoo_design = ""
	/// Selected tattoo layer
	var/selected_layer = 2

/obj/item/tattoo_kit/attack(mob/living/carbon/human/target, mob/living/user)
	if(!istype(target))
		return ..()
/*
	if(target == user)
		to_chat(user, span_warning("You can't tattoo yourself!"))
		return TRUE
*/
	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return TRUE

	// Check if target allows bodywriting
	if(!target.allows_bodywriting())
		to_chat(user, span_warning("[target] doesn't allow body modifications!"))
		return TRUE

	current_target = target
	current_step = "select_part"
	artist_name = ""
	tattoo_design = ""
	selected_layer = 2
	ui_interact(user)
	return TRUE

/obj/item/tattoo_kit/attack_self(mob/user)
	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return

	if(istype(user, /mob/living/carbon/human))
		current_target = user
		current_step = "select_part"
		artist_name = ""
		tattoo_design = ""
		selected_layer = 2
		ui_interact(user)
	else
		to_chat(user, span_warning("Only humans can use this!"))

/obj/item/tattoo_kit/ui_state(mob/user)
	return GLOB.inventory_state

/obj/item/tattoo_kit/ui_static_data(mob/user)
	var/list/data = list()
	data["max_tattoo_length"] = 500
	data["max_artist_length"] = 50
	return data

/obj/item/tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TattooKit", name)
		ui.open()

/obj/item/tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	if(!current_target)
		current_target = user

	data["target_name"] = current_target.name
	data["ink_uses"] = tattoo_uses
	data["max_uses"] = tattoo_max_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone
	data["selected_zone_name"] = get_body_zone_display_name(selected_zone)
	data["current_step"] = current_step
	data["artist_name"] = artist_name
	data["tattoo_design"] = tattoo_design
	data["selected_layer"] = selected_layer

	// Get all available body parts with coverage checking
	var/list/body_parts = list()
	var/list/all_parts = get_all_available_body_parts(current_target)

	for(var/zone in all_parts)
		var/list/part_info = all_parts[zone]
		var/covered = is_bodypart_covered(current_target, zone, user)
		var/current_tattoos = length(current_target.get_tattoos(zone))

		body_parts += list(list(
			"zone" = zone,
			"name" = part_info["name"],
			"type" = part_info["type"],
			"covered" = covered,
			"current_tattoos" = current_tattoos,
			"max_tattoos" = max_tattoos_per_part
		))

	data["body_parts"] = body_parts

	return data

/obj/item/tattoo_kit/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("select_bodypart")
			var/zone = params["zone"]
			if(!zone || !body_part_exists(current_target, zone))
				return FALSE

			// Check if target allows bodywriting
			if(!current_target.allows_bodywriting())
				to_chat(usr, span_warning("[current_target] doesn't allow body modifications!"))
				return FALSE

			// STRICT coverage check - no exceptions
			if(is_bodypart_covered(current_target, zone, usr))
				var/body_part_name = get_body_zone_display_name(zone)
				// Different message for organ-based parts vs standard body parts
				if(zone in list(ORGAN_SLOT_EXTERNAL_TAIL, ORGAN_SLOT_EXTERNAL_SPINES, ORGAN_SLOT_EXTERNAL_FRILLS,
								ORGAN_SLOT_EXTERNAL_HORNS, ORGAN_SLOT_EXTERNAL_WINGS, ORGAN_SLOT_WINGS))
					to_chat(usr, span_warning("[current_target == usr ? "Your" : "[current_target]'s"] [body_part_name] is covered or inaccessible! Make sure it's exposed."))
				else
					to_chat(usr, span_warning("[current_target == usr ? "Your" : "[current_target]'s"] [body_part_name] is covered by clothing! Expose it first."))
				return FALSE

			// Check tattoo limit
			var/current_tattoos = current_target.get_tattoos(zone)
			if(length(current_tattoos) >= max_tattoos_per_part)
				to_chat(usr, span_warning("This body part already has the maximum number of tattoos! (Max: [max_tattoos_per_part])"))
				return FALSE

			selected_zone = zone
			current_step = "design_tattoo"
			return TRUE

		if("update_artist_name")
			var/name = params["name"]
			artist_name = sanitize_text(name, "Unknown Artist")
			return TRUE

		if("update_tattoo_design")
			var/design = params["design"]
			tattoo_design = sanitize_text(design, "An intricate design")
			return TRUE

		if("update_tattoo_layer")
			var/layer = text2num(params["layer"])
			selected_layer = sanitize_integer(layer, 1, 3, 2)
			return TRUE

		if("change_ink_color")
			var/new_color = input(usr, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = sanitize_hexcolor(new_color, default = "#000000")
				to_chat(usr, span_notice("You change the ink color to [new_color]."))
			return TRUE

		if("back_to_selection")
			current_step = "select_part"
			artist_name = ""
			tattoo_design = ""
			selected_layer = 2
			return TRUE

		if("apply_tattoo")
			var/apply_artist = params["artist"] || artist_name
			var/apply_design = params["design"] || tattoo_design
			var/apply_layer = text2num(params["layer"]) || selected_layer

			// Final validation
			if(!apply_artist || length(apply_artist) == 0 || !apply_design || length(apply_design) == 0)
				to_chat(usr, span_warning("Please fill in both the artist name and tattoo design!"))
				return FALSE

			// Sanitize inputs using your functions
			apply_artist = sanitize_text(apply_artist, "Unknown Artist")
			apply_design = sanitize_text(apply_design, "An intricate design")
			apply_layer = sanitize_integer(apply_layer, 1, 3, 2)

			// STRICT FINAL CHECK - cannot proceed if covered
			if(is_bodypart_covered(current_target, selected_zone, usr))
				to_chat(usr, span_warning("[current_target == usr ? "Your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)] became covered! Aborting."))
				current_step = "select_part"
				artist_name = ""
				tattoo_design = ""
				selected_layer = 2
				return FALSE

			// Close UI during application
			if(ui)
				ui.close()

			// Perform tattoo application with progress bar
			to_chat(usr, span_notice("You begin carefully applying the tattoo to [current_target == usr ? "your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)]..."))

			if(do_after(usr, 8 SECONDS, target = current_target))
				// ONE FINAL CHECK - clothing could have been put on during the delay
				if(is_bodypart_covered(current_target, selected_zone, usr))
					to_chat(usr, span_warning("The body part became covered during application! Tattoo failed."))
					// Apply 10 brute damage for interruption
					apply_tattoo_damage(current_target, selected_zone, 10, usr)
					return FALSE

				var/datum/tattoo/new_tattoo = new(apply_artist, apply_design, selected_zone, ink_color, apply_layer)
				if(current_target.add_tattoo(new_tattoo))
					// Apply 15 brute damage for successful application
					apply_tattoo_damage(current_target, selected_zone, 15, usr)

					// Save to preferences
					if(current_target.client?.prefs)
						current_target.client.prefs.save_tattoo_data()

					to_chat(usr, span_green("You successfully apply \"[apply_design]\" to [current_target == usr ? "your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)]."))
					if(current_target != usr)
						to_chat(current_target, span_notice("You feel a stinging sensation as [usr] tattoos your [get_body_zone_display_name(selected_zone)]."))

					tattoo_uses--
					if(tattoo_uses <= 0)
						to_chat(usr, span_warning("The tattoo kit is now out of ink!"))
						desc = "An empty tattoo kit. All the ink has been used up."

					current_target.regenerate_icons()
				else
					to_chat(usr, span_warning("Failed to apply the tattoo! The skin might be too damaged."))
					qdel(new_tattoo)
			else
				to_chat(usr, span_warning("Tattoo application interrupted!"))
				// Apply 10 brute damage for interruption
				apply_tattoo_damage(current_target, selected_zone, 10, usr)

			// Reset for next use
			current_step = "select_part"
			artist_name = ""
			tattoo_design = ""
			selected_layer = 2
			return TRUE

	return FALSE

/// Applies bruise damage from tattoo application
/obj/item/tattoo_kit/proc/apply_tattoo_damage(mob/living/carbon/human/target, body_zone, damage_amount, mob/user)
	if(!istype(target) || damage_amount <= 0)
		return

	var/obj/item/bodypart/BP = target.get_bodypart(body_zone)
	if(BP)
		BP.receive_damage(brute = damage_amount, wound_bonus = CANT_WOUND)
		target.visible_message(
			span_warning("The tattoo needle leaves a painful-looking mark on [target]'s [get_body_zone_display_name(body_zone)]!"),
			span_userdanger("The tattoo needle stings painfully!")
		)

		// Force pain reaction
		target.emote("scream")
		target.do_jitter_animation(300) // Use do_jitter_animation instead of Jitter()

		// Update health and check for crit
		target.updatehealth()
		if(target.health <= target.crit_threshold && target.stat == CONSCIOUS)
			to_chat(user, span_danger("[target] has been knocked unconscious by the pain!"))
			target.Unconscious(100)

		// Show different message based on who is being tattooed
		if(target == user)
			to_chat(user, span_warning("The tattoo process leaves a painful bruise on your [get_body_zone_display_name(body_zone)]."))
		else
			to_chat(user, span_warning("The tattoo process leaves a painful bruise on [target]'s [get_body_zone_display_name(body_zone)]."))

// Helper proc to check if a bodypart is covered by clothing
/proc/is_bodypart_covered(mob/living/carbon/human/target, body_zone, mob/user)
	if(!target || !body_zone)
		return TRUE
	return !get_location_accessible(target, body_zone)

/obj/item/tattoo_kit/examine(mob/user)
	. = ..()
	if(!tattoo_uses)
		. += span_warning("This kit has no ink left!")
	else
		. += span_notice("It has enough ink for [tattoo_uses] more tattoo\s.")
	. += span_info("You can use a toner cartridge to refill it.")

/obj/item/tattoo_kit/item_interaction(mob/living/user, obj/item/toner/ink_cart, list/modifiers)
	if(!istype(ink_cart))
		return NONE

	var/added_amount = round(ink_cart.charges / 5)
	if(added_amount == 0)
		balloon_alert(user, "cartridge empty!")
		return ITEM_INTERACT_BLOCKING

	if(tattoo_uses >= tattoo_max_uses)
		balloon_alert(user, "kit already full!")
		return ITEM_INTERACT_BLOCKING

	var/actual_add = min(added_amount, tattoo_max_uses - tattoo_uses)
	tattoo_uses += actual_add
	qdel(ink_cart)
	balloon_alert(user, "added [actual_add] uses")
	desc = "A professional tattoo application kit. It has enough ink for [tattoo_uses] uses."
	return ITEM_INTERACT_SUCCESS

/obj/item/tattoo_kit/advanced
	name = "advanced tattoo kit"
	desc = "A professional-grade tattoo kit with precision tools and a wider color selection."
	icon_state = "tgun"
	tattoo_uses = 30
	tattoo_max_uses = 100
	max_tattoos_per_part = 8
