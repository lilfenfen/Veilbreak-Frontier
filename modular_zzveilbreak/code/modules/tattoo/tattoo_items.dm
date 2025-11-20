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

/obj/item/custom_tattoo_kit/proc/can_apply_tattoo(mob/user)
	if(!current_target)
		to_chat(user, span_warning("No target selected."))
		return FALSE

	var/datum/custom_tattoo_ui_data/ui_data = current_target.get_tattoo_ui_data("global")
	if(!ui_data)
		to_chat(user, span_warning("UI data not found."))
		return FALSE

	// Use the UI data validation method
	if(!ui_data.is_ready_for_application())
		to_chat(user, span_warning("Design not complete or no body part selected."))
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

	if(!do_after(user, CUSTOM_TATTOO_APPLICATION_TIME, target = current_target))
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

	// Create tattoo using the ui_data parameters
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
