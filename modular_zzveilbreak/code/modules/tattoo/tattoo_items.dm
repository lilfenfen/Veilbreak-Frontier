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
	/// Selected tattoo layer
	var/selected_layer = 2
	/// Temporary artist name storage during design
	var/artist_name = ""
	/// Temporary tattoo design storage during design
	var/tattoo_design = ""

/obj/item/tattoo_kit/Initialize(mapload)
	. = ..()
	// Initialize temporary storage variables
	artist_name = ""
	tattoo_design = ""

/obj/item/tattoo_kit/attack(mob/living/carbon/human/target, mob/living/user)
	if(!istype(target))
		return ..()

	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return TRUE

	// Check if target allows bodywriting
	if(!target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
		to_chat(user, span_warning("[target] doesn't allow body modifications!"))
		return TRUE

	current_target = target
	current_step = "select_part"
	selected_layer = 2
	artist_name = ""
	tattoo_design = ""

	world.log << "TATDAT: Tattoo kit attack - opening UI for [target.name]"
	ui_interact(user)
	return TRUE

/obj/item/tattoo_kit/attack_self(mob/user)
	if(tattoo_uses <= 0)
		to_chat(user, span_warning("This tattoo kit is out of ink!"))
		return

	if(istype(user, /mob/living/carbon/human))
		current_target = user
		current_step = "select_part"
		selected_layer = 2
		artist_name = ""
		tattoo_design = ""
		world.log << "TATDAT: Tattoo kit attack_self - opening UI for self"
		ui_interact(user)
	else
		to_chat(user, span_warning("Only humans can use this!"))

/obj/item/tattoo_kit/ui_interact(mob/user, datum/tgui/ui)
	world.log << "TATDAT: ui_interact called - current_step: [current_step], selected_zone: [selected_zone], artist_name: '[artist_name]', tattoo_design: '[tattoo_design]'"
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		world.log << "TATDAT: Creating new UI instance for TattooKit"
		ui = new(user, src, "TattooKit", name)
		ui.open()
	else
		world.log << "TATDAT: Updating existing UI instance"

/obj/item/tattoo_kit/ui_data(mob/user)
	var/list/data = list()

	if(!current_target)
		current_target = user
		world.log << "TATDAT: ui_data - current_target was null, set to user"

	data["target_name"] = current_target.name
	data["ink_uses"] = tattoo_uses
	data["max_uses"] = tattoo_max_uses
	data["ink_color"] = ink_color
	data["selected_zone"] = selected_zone
	data["selected_zone_name"] = get_body_zone_display_name(selected_zone)
	data["current_step"] = current_step
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
	world.log << "TATDAT: ui_act START - action: [action], params: [json_encode(params)]"
	world.log << "TATDAT: Current state - artist_name: '[artist_name]', tattoo_design: '[tattoo_design]'"

	. = ..()
	if(.)
		world.log << "TATDAT: ui_act - parent returned TRUE, skipping"
		return

	var/mob/user = usr

	switch(action)
		if("select_bodypart")
			var/zone = params["zone"]
			world.log << "TATDAT: select_bodypart - zone: [zone]"
			if(!zone || !body_part_exists(current_target, zone))
				world.log << "TATDAT: select_bodypart - invalid zone"
				return FALSE

			if(is_bodypart_covered(current_target, zone, user))
				var/body_part_name = get_body_zone_display_name(zone)
				to_chat(user, span_warning("[current_target == user ? "Your" : "[current_target]'s"] [body_part_name] is covered! Expose it first."))
				return FALSE

			var/current_tattoos = current_target.get_tattoos(zone)
			if(length(current_tattoos) >= max_tattoos_per_part)
				to_chat(user, span_warning("This body part already has the maximum number of tattoos! (Max: [max_tattoos_per_part])"))
				return FALSE

			selected_zone = zone
			current_step = "design_tattoo"
			selected_layer = 2
			artist_name = ""
			tattoo_design = ""
			world.log << "TATDAT: select_bodypart - SUCCESS, selected_zone: [selected_zone], current_step: [current_step]"
			. = TRUE

		if("set_artist_name")
			var/new_name = params["value"]
			world.log << "TATDAT: set_artist_name - value: '[new_name]'"
			if(!isnull(new_name))
				artist_name = sanitize_text(new_name)
				world.log << "TATDAT: set_artist_name - stored: '[artist_name]'"
			else
				artist_name = ""
				world.log << "TATDAT: set_artist_name - null value, set to empty"
			. = TRUE

		if("set_tattoo_design")
			var/new_design = params["value"]
			world.log << "TATDAT: set_tattoo_design - value: '[new_design]'"
			if(!isnull(new_design))
				tattoo_design = sanitize_text(new_design)
				world.log << "TATDAT: set_tattoo_design - stored: '[tattoo_design]'"
			else
				tattoo_design = ""
				world.log << "TATDAT: set_tattoo_design - null value, set to empty"
			. = TRUE

		if("set_layer")
			var/layer = text2num(params["layer"])
			selected_layer = sanitize_integer(layer, 1, 3, 2)
			world.log << "TATDAT: set_layer - layer: [layer], selected_layer: [selected_layer]"
			. = TRUE

		if("change_ink_color")
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = sanitize_hexcolor(new_color, default = "#000000")
				to_chat(user, span_notice("You change the ink color to [new_color]."))
			. = TRUE

		if("back_to_selection")
			current_step = "select_part"
			selected_layer = 2
			artist_name = ""
			tattoo_design = ""
			world.log << "TATDAT: back_to_selection - reset to selection"
			. = TRUE

		if("apply_tattoo")
			world.log << "TATDAT: apply_tattoo - STARTING TATTOO APPLICATION PROCESS"

			// Use the stored values from the set_ actions
			var/final_artist = artist_name
			var/final_design = tattoo_design

			world.log << "TATDAT: apply_tattoo - STORED VALUES - artist_name: '[final_artist]', tattoo_design: '[final_design]'"

			// Handle null values properly
			if(isnull(final_artist))
				final_artist = ""
			if(isnull(final_design))
				final_design = ""

			// Use proper string validation
			var/trimmed_artist = trimtext(final_artist)
			var/trimmed_design = trimtext(final_design)

			world.log << "TATDAT: apply_tattoo - AFTER TRIMMING - trimmed_artist: '[trimmed_artist]' (length: [length(trimmed_artist)]), trimmed_design: '[trimmed_design]' (length: [length(trimmed_design)])"

			if(!trimmed_artist || length(trimmed_artist) == 0)
				world.log << "TATDAT: apply_tattoo - VALIDATION FAILED: artist name empty"
				to_chat(user, span_warning("Please fill in the artist name!"))
				return FALSE

			if(!trimmed_design || length(trimmed_design) == 0)
				world.log << "TATDAT: apply_tattoo - VALIDATION FAILED: tattoo design empty"
				to_chat(user, span_warning("Please fill in the tattoo design!"))
				return FALSE

			world.log << "TATDAT: apply_tattoo - VALIDATION PASSED"

			if(is_bodypart_covered(current_target, selected_zone, user))
				world.log << "TATDAT: apply_tattoo - VALIDATION FAILED: bodypart covered"
				to_chat(user, span_warning("[current_target == user ? "Your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)] became covered! Aborting."))
				return FALSE

			if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
				world.log << "TATDAT: apply_tattoo - VALIDATION FAILED: body modifications not allowed"
				to_chat(user, span_warning("[current_target] doesn't allow body modifications!"))
				return FALSE

			world.log << "TATDAT: apply_tattoo - ALL VALIDATIONS PASSED, STARTING APPLICATION"

			// Close UI during application
			if(ui)
				ui.close()

			// Perform tattoo application
			to_chat(user, span_notice("You begin carefully applying the tattoo to [current_target == user ? "your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)]..."))

			if(do_after(user, 8 SECONDS, target = current_target))
				world.log << "TATDAT: apply_tattoo - DO_AFTER COMPLETED SUCCESSFULLY"

				// Final checks after delay
				if(is_bodypart_covered(current_target, selected_zone, user))
					world.log << "TATDAT: apply_tattoo - FINAL CHECK FAILED: bodypart covered during application"
					to_chat(user, span_warning("The body part became covered during application! Tattoo failed."))
					return FALSE

				if(!current_target.client?.prefs?.read_preference(/datum/preference/toggle/allow_bodywriting))
					world.log << "TATDAT: apply_tattoo - FINAL CHECK FAILED: consent revoked during application"
					to_chat(user, span_warning("[current_target] revoked body modification consent during application!"))
					return FALSE

				world.log << "TATDAT: apply_tattoo - FINAL CHECKS PASSED, CREATING TATTOO"

				// Create and apply tattoo
				var/sanitized_artist = sanitize_text(trimmed_artist)
				var/sanitized_design = sanitize_text(trimmed_design)

				world.log << "TATDAT: apply_tattoo - CREATING TATTOO OBJECT - artist: '[sanitized_artist]', design: '[sanitized_design]', zone: [selected_zone], color: [ink_color], layer: [selected_layer]"

				var/datum/tattoo/new_tattoo = new(sanitized_artist, sanitized_design, selected_zone, ink_color, selected_layer)

				world.log << "TATDAT: apply_tattoo - TATTOO OBJECT CREATED, ATTEMPTING TO ADD TO TARGET"

				if(current_target.add_tattoo(new_tattoo))
					world.log << "TATDAT: apply_tattoo - TATTOO APPLIED SUCCESSFULLY!"
					// Save to preferences
					if(current_target.client?.prefs)
						current_target.client.prefs.save_character()
						world.log << "TATDAT: apply_tattoo - PREFERENCES SAVED"

					to_chat(user, span_green("You successfully apply \"[sanitized_design]\" to [current_target == user ? "your" : "[current_target]'s"] [get_body_zone_display_name(selected_zone)]."))
					if(current_target != user)
						to_chat(current_target, span_notice("You feel a stinging sensation as [user] tattoos your [get_body_zone_display_name(selected_zone)]."))

					tattoo_uses--
					world.log << "TATDAT: apply_tattoo - TATTOO USES DECREMENTED TO: [tattoo_uses]"
					if(tattoo_uses <= 0)
						to_chat(user, span_warning("The tattoo kit is now out of ink!"))
						desc = "An empty tattoo kit. All the ink has been used up."

					current_target.regenerate_icons()
					world.log << "TATDAT: apply_tattoo - ICONS REGENERATED"
				else
					world.log << "TATDAT: apply_tattoo - FAILED TO APPLY TATTOO TO TARGET!"
					to_chat(user, span_warning("Failed to apply the tattoo!"))
					qdel(new_tattoo)
			else
				world.log << "TATDAT: apply_tattoo - DO_AFTER INTERRUPTED"
				to_chat(user, span_warning("Tattoo application interrupted!"))

			// Reset for next use
			current_step = "select_part"
			artist_name = ""
			tattoo_design = ""
			selected_layer = 2
			world.log << "TATDAT: apply_tattoo - PROCESS COMPLETED, RESETTING STATE"
			. = TRUE

	// Force UI update after any action
	if(.)
		world.log << "TATDAT: ui_act - action [action] returning TRUE, forcing UI update"
		SStgui.update_uis(src)
	else
		world.log << "TATDAT: ui_act - action [action] returning FALSE, no UI update"

	world.log << "TATDAT: ui_act END - action: [action] completed"
	return .

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
