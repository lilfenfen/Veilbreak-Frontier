// Strict preference checking for bodywriting - CONSENT IS PARAMOUNT
// Only uses the explicit allow_bodywriting_pref toggle, no fallbacks or assumptions

/proc/can_mob_have_bodywriting(mob/living/carbon/human/target, mob/user)
	if(!istype(target))
		if(user)
			to_chat(user, span_warning("Invalid target!"))
		return FALSE

	if(!target.client?.prefs)
		if(user)
			to_chat(user, span_warning("[target] has no client preferences!"))
		return FALSE

	// METHOD 1: Use the preference datum (primary method)
	var/datum/preference/toggle/allow_bodywriting/pref_datum = GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting]
	var/pref_value
	if(pref_datum)
		pref_value = target.client.prefs.read_preference(pref_datum)

	// METHOD 2: Check raw savefile data (fallback method)
	var/raw_value = target.client.prefs.read_preference("allow_bodywriting_pref")

	// DEBUG OUTPUT - Show what we found
	if(user)
		to_chat(user, span_notice("Bodywriting consent check for [target]:"))
		to_chat(user, span_notice("  Preference datum: [isnull(pref_value) ? "NOT FOUND" : (pref_value ? "ALLOWED" : "DENIED")]"))
		to_chat(user, span_notice("  Raw savefile: [isnull(raw_value) ? "NOT FOUND" : (raw_value ? "ALLOWED" : "DENIED")]"))

	// DECISION LOGIC - CONSENT IS EXPLICIT AND REQUIRED
	var/final_result = FALSE

	// Priority 1: Explicit preference datum value
	if(!isnull(pref_value))
		final_result = pref_value
	// Priority 2: Explicit raw savefile value
	else if(!isnull(raw_value))
		final_result = raw_value
	// NO FALLBACKS - If preference is not found, assume DENIED
	// Consent must be explicitly given, not assumed from other ERP prefs

	if(user)
		if(final_result)
			to_chat(user, span_notice("[target] has explicitly allowed bodywriting."))
		else
			to_chat(user, span_warning("[target] has NOT allowed bodywriting modifications!"))
			if(isnull(pref_value) && isnull(raw_value))
				to_chat(user, span_warning("(Bodywriting preference not found in their settings)"))

	return final_result

// Additional helper for clearer consent messaging
/proc/get_bodywriting_consent_status(mob/living/carbon/human/target)
	if(!istype(target) || !target.client?.prefs)
		return "NO_PREFS"

	var/datum/preference/toggle/allow_bodywriting/pref_datum = GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting]
	var/pref_value
	if(pref_datum)
		pref_value = target.client.prefs.read_preference(pref_datum)

	var/raw_value = target.client.prefs.read_preference("allow_bodywriting_pref")

	if(!isnull(pref_value))
		return pref_value ? "EXPLICIT_ALLOW" : "EXPLICIT_DENY"
	else if(!isnull(raw_value))
		return raw_value ? "EXPLICIT_ALLOW" : "EXPLICIT_DENY"
	else
		return "NOT_SET"


/datum/tgui_module/mob_interaction/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("pref")
			var/pref_key = params["pref"]
			if(pref_key == "allow_bodywriting_pref")
				return handle_bodywriting_pref(usr, params)

	return FALSE

// Handle the bodywriting preference toggle
/datum/tgui_module/mob_interaction/proc/handle_bodywriting_pref(mob/user, list/params)
	if(!user?.client?.prefs)
		return FALSE

	// Get the current value and toggle it
	var/datum/preference/toggle/allow_bodywriting/pref_datum = GLOB.preference_entries[/datum/preference/toggle/allow_bodywriting]
	if(!pref_datum)
		return FALSE

	var/current_value = user.client.prefs.read_preference(pref_datum)
	var/new_value = !current_value

	// Update the preference
	user.client.prefs.write_preference(pref_datum, new_value)

	// Log the change
	user.log_message("toggled bodywriting preference to [new_value ? "ON" : "OFF"]", LOG_GAME)

	// Notify the user
	to_chat(user, span_notice("Bodywriting preference [new_value ? "enabled" : "disabled"]."))

	return TRUE
