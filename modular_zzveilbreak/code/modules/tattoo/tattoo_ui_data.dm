// modular_zzveilbreak/code/modules/tattoo/tattoo_ui_data.dm
// Data storage for tattoo UI state - no HTML generation

/datum/custom_tattoo_ui_data
	var/zone = ""
	var/artist_name = ""
	var/tattoo_design = ""
	var/selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT
	var/selected_flair = null
	var/ink_color = "#000000"
	var/design_mode = FALSE
	var/debug_mode = FALSE

	// Static options for TGUI
	var/static/list/font_options = list(
		"PEN_FONT" = "Pen",
		"FOUNTAIN_PEN_FONT" = "Fountain Pen",
		"PRINTER_FONT" = "Printer",
		"CHARCOAL_FONT" = "Charcoal",
		"CRAYON_FONT" = "Crayon"
	)

	var/static/list/flair_options = list(
		"null" = "No Flair",
		"flair_1" = "Pink Flair",
		"flair_2" = "Love Flair",
		"flair_3" = "Brown Flair",
		"flair_4" = "Cyan Flair",
		"flair_5" = "Orange Flair",
		"flair_6" = "Yellow Flair",
		"flair_7" = "Subtle Flair",
		"flair_8" = "Velvet Flair",
		"flair_9" = "Velvet Notice",
		"flair_10" = "Glossy Flair"
	)

	New(new_zone = "")
		zone = new_zone

	// Clear all data
	proc/clear()
		artist_name = ""
		tattoo_design = ""
		selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
		selected_font = PEN_FONT
		selected_flair = null
		ink_color = "#000000"
		design_mode = FALSE
