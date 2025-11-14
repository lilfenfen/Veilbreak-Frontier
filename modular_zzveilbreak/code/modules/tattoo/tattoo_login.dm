// modular_zzveilbreak/code/modules/tattoo/tattoo_login.dm
// Proc override to apply tattoos on login

/mob/Login()
	. = ..()

	// Only apply to human mobs with valid clients and preferences
	if(!ishuman(src) || !client || !client.prefs)
		return .

	var/mob/living/carbon/human/H = src
	var/datum/preferences/prefs = client.prefs

	// Double-check we have tattoo data to apply
	if(prefs && LAZYLEN(prefs.features["custom_tattoos"]))
		prefs.apply_custom_tattoos_to_mob(H)

	return .
