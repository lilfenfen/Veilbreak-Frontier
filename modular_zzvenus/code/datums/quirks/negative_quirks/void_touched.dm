/datum/quirk/void_touched
	name = "Void-Touched"
	desc = "Your voice is gone and your skin shimmers like the void."
	icon = FA_ICON_STAR
	value = -4
	mob_trait = TRAIT_MUTE
	gain_text = span_danger("The void steals your voice and stains your skin.")
	lose_text = span_notice("The void's grasp loosens from your voice and form.")
	medical_record_text = "Patient presents with total mutism and anomalous dermal refraction."
	/// Type for the bodypart texture we add
	var/bodypart_overlay_type = /datum/bodypart_overlay/texture/spacey
	/// Color in which we paint the space texture
	var/space_color = COLOR_WHITE

/datum/quirk_constant_data/void_touched
	associated_typepath = /datum/quirk/void_touched
	customization_options = list(/datum/preference/color/void_touched_color)

/// Preference for the Void-Touched quirk's space texture color.
/datum/preference/color/void_touched_color
	savefile_key = "void_touched_color"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED

/datum/preference/color/void_touched_color/is_accessible(datum/preferences/preferences)
	if (!..(preferences))
		return FALSE

	return /datum/quirk/void_touched::name in preferences.all_quirks

/datum/preference/color/void_touched_color/apply_to_human(mob/living/carbon/human/target, value)
	return

/datum/quirk/void_touched/add(client/client_source)
	. = ..()
	var/selected_color = client_source?.prefs.read_preference(/datum/preference/color/void_touched_color)
	if(!isnull(selected_color) && selected_color)
		space_color = selected_color

	// Keep visuals in sync with limb changes
	RegisterSignal(quirk_holder, COMSIG_CARBON_ATTACH_LIMB, PROC_REF(texture_limb))
	RegisterSignal(quirk_holder, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(untexture_limb))

	// Apply to existing limbs
	var/mob/living/carbon/carbon_holder = quirk_holder
	for(var/obj/item/bodypart/part as anything in carbon_holder.bodyparts)
		texture_limb(quirk_holder, part)
	quirk_holder.update_body()

/datum/quirk/void_touched/remove()
	. = ..()
	UnregisterSignal(quirk_holder, list(COMSIG_CARBON_ATTACH_LIMB, COMSIG_CARBON_REMOVE_LIMB))

	var/mob/living/carbon/carbon_holder = quirk_holder
	for(var/obj/item/bodypart/part as anything in carbon_holder.bodyparts)
		untexture_limb(quirk_holder, part)

	quirk_holder.update_body()

/// Apply the space texture (mirrors voided trauma's logic)
/datum/quirk/void_touched/proc/texture_limb(atom/source, obj/item/bodypart/limb)
	SIGNAL_HANDLER
	limb.add_bodypart_overlay(new bodypart_overlay_type(), update = FALSE)
	limb.add_color_override(space_color, LIMB_COLOR_VOIDWALKER_CURSE)
	// Update draw_color so mutant overlays (genitals) can inherit it
	limb.draw_color = space_color
	// Force mutant overlays (genitals) to re-inherit the color
	for(var/datum/bodypart_overlay/mutant/mutant_overlay in limb.bodypart_overlays)
		mutant_overlay.inherit_color(limb, force = TRUE)
	if(istype(limb, /obj/item/bodypart/head))
		var/obj/item/bodypart/head/head = limb
		head.head_flags &= ~HEAD_EYESPRITES

/// Remove the space texture
/datum/quirk/void_touched/proc/untexture_limb(atom/source, obj/item/bodypart/limb)
	SIGNAL_HANDLER
	var/overlay = locate(bodypart_overlay_type) in limb.bodypart_overlays
	if(overlay)
		limb.remove_bodypart_overlay(overlay, update = FALSE)
	limb.remove_color_override(LIMB_COLOR_VOIDWALKER_CURSE)
	// Force mutant overlays (genitals) to re-inherit the color (now without our override)
	for(var/datum/bodypart_overlay/mutant/mutant_overlay in limb.bodypart_overlays)
		mutant_overlay.inherit_color(limb, force = TRUE)

	if(istype(limb, /obj/item/bodypart/head))
		var/obj/item/bodypart/head/head = limb
		head.head_flags = initial(head.head_flags)


