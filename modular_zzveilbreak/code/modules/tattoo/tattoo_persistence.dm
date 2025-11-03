// Tattoo data management procs
/datum/preferences/proc/save_tattoos_modular()
	if(!features)
		features = list()

	var/list/tattoo_data = list()
	if(LAZYACCESS(features, "tattoos"))
		for(var/datum/tattoo/T as anything in features["tattoos"])
			if(!QDELETED(T))
				tattoo_data += list(list(
					"name" = T.name,
					"desc" = T.desc,
					"body_part" = T.body_part,
					"color" = T.color,
					"creator" = T.creator,
					"date_applied" = T.date_applied,
					"layer" = T.layer
				))

	// Store in features - this will be automatically saved by the main savefile system
	LAZYSET(features, "tattoos_data", tattoo_data)

/datum/preferences/proc/load_tattoos_modular()
	if(!features || !LAZYACCESS(features, "tattoos_data"))
		return

	var/list/tattoo_data = features["tattoos_data"]
	if(!islist(tattoo_data))
		return

	features["tattoos"] = list()
	for(var/list/tattoo_info as anything in tattoo_data)
		if(is_valid_tattoo_bodypart(tattoo_info["body_part"]))
			var/datum/tattoo/T = new(
				tattoo_info["name"],
				tattoo_info["desc"],
				tattoo_info["body_part"],
				tattoo_info["color"],
				tattoo_info["creator"],
				tattoo_info["layer"] || TATTOO_LAYER_NORMAL
			)
			T.date_applied = tattoo_info["date_applied"]
			features["tattoos"] += T

/datum/preferences/proc/apply_tattoos_to_mob_modular(mob/living/carbon/human/character)
	if(!istype(character) || !features || !features["tattoos"])
		return

	character.body_tattoos = list()
	for(var/datum/tattoo/T as anything in features["tattoos"])
		if(!QDELETED(T))
			character.body_tattoos += T
