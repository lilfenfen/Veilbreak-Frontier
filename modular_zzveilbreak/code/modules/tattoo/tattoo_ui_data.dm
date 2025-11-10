// modular_zzveilbreak/code/modules/tattoo/tattoo_ui_data.dm
// Datum to store per-zone UI draft data for tattoos.

/datum/custom_tattoo_ui_data
	// zone identifier (string like "chest", "l_arm", "penis", etc.)
	var/zone = ""
	// fields that represent the UI draft state
	var/artist_name = ""
	var/tattoo_design = ""
	var/selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT
	// cached preview HTML (server-generated), optional
	var/preview_cache = ""

	// Constructor: accepts optional zone id
	New(new_zone = "")
		zone = new_zone

	// Populate this datum from a mob's stored UI draft (if present)
	proc/sync_from_mob(mob/living/carbon/human/H)
		if(!istype(H))
			return
		var/datum/custom_tattoo_ui_data/store = H.get_tattoo_ui_data(zone)
		if(istype(store))
			artist_name = store.artist_name
			tattoo_design = store.tattoo_design
			selected_layer = store.selected_layer
			selected_font = store.selected_font
			preview_cache = store.preview_cache

	// Export a lightweight list suitable for TGUI serialization
	proc/export_data()
		return list(
			"zone" = zone,
			"artist_name" = artist_name,
			"tattoo_design" = tattoo_design,
			"selected_layer" = selected_layer,
			"selected_font" = selected_font,
			"preview_cache" = preview_cache
		)

	// Generate a minimal preview cache string (usually server side will create richer HTML)
	proc/generate_preview(mob/viewer, mob/living/carbon/human/victim, ink_color = "#000000")
		preview_cache = "<b>Artist:</b> [artist_name]<br><b>Design:</b> [tattoo_design]<br><b>Color:</b> <span style='color:[ink_color]'>■</span>"
		return preview_cache
