// modular_zzveilbreak/code/modules/tattoo/tattoo_ui_data.dm
// Complete UI system in DM with dynamic interface generation

/datum/custom_tattoo_ui_data
	var/zone = ""
	var/artist_name = ""
	var/tattoo_design = ""
	var/selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT
	var/selected_flair = null // Added: stores selected flair
	var/ink_color = "#000000"
	var/design_mode = FALSE
	var/debug_mode = FALSE
	var/static/list/font_options = list(
		"PEN_FONT" = "Pen",
		"FOUNTAIN_PEN_FONT" = "Fountain Pen",
		"PRINTER_FONT" = "Printer",
		"CHARCOAL_FONT" = "Charcoal",
		"CRAYON_FONT" = "Crayon"
	)
	// Added: flair options with user-friendly names
	var/static/list/flair_options = list(
		null = "No Flair",
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

	// Generate complete UI HTML based on current state
	proc/generate_interface(mob/living/carbon/human/victim, mob/viewer, ink_uses, max_ink_uses, obj/item/custom_tattoo_kit/kit)
		var/interface_html = "<div class='tattooInterface' style='font-family: Verdana, sans-serif; color: white;'>"

		// Header section
		interface_html += generate_header(victim, ink_uses, max_ink_uses, kit)

		if(!design_mode)
			// Body part selection mode
			interface_html += generate_body_part_selection(victim, viewer, kit)
		else
			// Design mode
			interface_html += generate_design_interface(victim, viewer, ink_uses, kit)

		// Debug tab
		if(debug_mode)
			interface_html += generate_debug_tab(victim, ink_uses, kit)

		interface_html += "</div>"
		return interface_html

	proc/generate_header(mob/living/carbon/human/victim, ink_uses, max_ink_uses, obj/item/custom_tattoo_kit/kit)
		var/target_name = victim ? victim.name : "No Target"
		var/header = "<div style='background: #2a2a2a; padding: 10px; border-radius: 8px 8px 0 0; margin-bottom: 10px;'>"
		header += "<h2 style='margin: 0; color: #4CAF50;'>Tattoo Kit - [target_name]</h2>"

		// Ink status
		var/ink_percent = max_ink_uses ? (ink_uses / max_ink_uses) * 100 : 0
		var/ink_color_class = ink_uses > 0 ? "#4CAF50" : "#f44336"
		header += "<div style='margin-top: 8px;'>"
		header += "<div style='background: #1a1a1a; height: 20px; border-radius: 10px; overflow: hidden;'>"
		header += "<div style='background: [ink_color_class]; height: 100%; width: [ink_percent]%;'></div>"
		header += "</div>"
		header += "<div style='text-align: center; margin-top: 4px;'>Ink: [ink_uses]/[max_ink_uses]</div>"
		header += "</div>"

		// Debug toggle
		header += "<div style='margin-top: 8px; text-align: center;'>"
		header += "<a href='?src=[REF(kit)];tattoo_toggle_debug=1' style='color: #888; font-size: 0.8em; text-decoration: none;'>"
		header += "[debug_mode ? "Hide Debug" : "Show Debug"]"
		header += "</a>"
		header += "</div>"

		header += "</div>"
		return header

	proc/generate_debug_tab(mob/living/carbon/human/victim, ink_uses, obj/item/custom_tattoo_kit/kit)
		var/debug_html = "<div style='background: #1a1a1a; padding: 15px; border-radius: 8px; margin-top: 10px; border: 2px solid #ff4444;'>"
		debug_html += "<h3 style='color: #ff4444; margin-top: 0;'>Debug Information</h3>"

		// Current UI state
		debug_html += "<div style='margin-bottom: 10px;'>"
		debug_html += "<h4 style='color: #ff8888;'>UI Data State:</h4>"
		debug_html += "<div style='background: #0a0a0a; padding: 10px; border-radius: 4px; font-family: monospace; font-size: 0.9em;'>"
		debug_html += "Zone: [zone]<br>"
		debug_html += "Design Mode: [design_mode]<br>"
		debug_html += "Artist: '[artist_name]' (len: [length(artist_name)])<br>"
		debug_html += "Design: '[tattoo_design]' (len: [length(tattoo_design)])<br>"
		debug_html += "Layer: [selected_layer]<br>"
		debug_html += "Font: [selected_font]<br>"
		debug_html += "Flair: [selected_flair]<br>"
		debug_html += "Color: [ink_color]<br>"
		debug_html += "Can Apply: [check_can_apply(ink_uses, victim)]"
		debug_html += "</div></div>"

		debug_html += "</div>"
		return debug_html

	proc/generate_body_part_selection(mob/living/carbon/human/victim, mob/viewer, obj/item/custom_tattoo_kit/kit)
		var/body_html = "<div style='background: #2a2a2a; padding: 15px; border-radius: 0 0 8px 8px;'>"
		body_html += "<h3 style='color: #fff; margin-top: 0;'>Select Body Part</h3>"
		body_html += "<div style='color: #aaa; margin-bottom: 15px;'>Accessible parts in <span style='color: #4CAF50;'>green</span>, covered in <span style='color: #f44336;'>red</span></div>"

		if(!victim)
			body_html += "<div style='text-align: center; color: #666; padding: 40px;'>No target selected</div>"
		else
			var/list/available_parts = get_all_custom_tattoo_body_parts(victim)
			if(!length(available_parts))
				body_html += "<div style='text-align: center; color: #666; padding: 40px;'>No accessible body parts found</div>"
			else
				body_html += "<div style='display: grid; grid-template-columns: repeat(auto-fill, minmax(140px, 1fr)); gap: 10px;'>"

				for(var/zone_key in available_parts)
					var/list/part_info = available_parts[zone_key]
					var/part_name = part_info["name"]
					var/covered = part_info["covered"]
					var/current_tats = part_info["current_tattoos"]
					var/max_tats = part_info["max_tattoos"]

					var/button_color = covered ? "#f44336" : "#4CAF50"
					var/tattoo_status = "([current_tats]/[max_tats])"

					body_html += {"
					<a href='?src=[REF(kit)];tattoo_select_zone=[zone_key]'
					   style='display: block; background: [button_color]; color: white; padding: 12px;
					          border-radius: 6px; text-decoration: none; text-align: center; border: 2px solid [button_color];'>
						<div style='font-weight: bold; margin-bottom: 4px;'>[part_name]</div>
						<div style='font-size: 0.9em; opacity: 0.9;'>[tattoo_status]</div>
					</a>
					"}

				body_html += "</div>"

		body_html += "</div>"
		return body_html

	proc/generate_design_interface(mob/living/carbon/human/victim, mob/viewer, ink_uses, obj/item/custom_tattoo_kit/kit)
		var/design_html = "<div style='background: #2a2a2a; padding: 15px; border-radius: 0 0 8px 8px;'>"

		// Preview section
		design_html += "<div style='margin-bottom: 20px;'>"
		design_html += generate_preview(victim, viewer, kit)
		design_html += "</div>"

		// Design controls
		design_html += "<div style='background: #1a1a1a; padding: 15px; border-radius: 6px;'>"

		var/zone_name = zone ? get_custom_tattoo_body_part_description(zone) : "Unknown Location"
		design_html += "<h3 style='color: #fff; margin-top: 0;'>Design for [zone_name]</h3>"

		// Combined form for artist and design with single update button
		design_html += "<form action='byond://' method='get' style='margin: 0;'>"
		design_html += "<input type='hidden' name='src' value='[REF(kit)]'>"
		design_html += "<input type='hidden' name='update_preview' value='1'>"

		// Artist name
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>"
		design_html += "Artist Name [findtext(artist_name, "%s") ? "<span style='color: #FFD700;'>(Signature Format)</span>" : ""]"
		design_html += "</div>"
		design_html += "<input type='text' name='tattoo_artist' value='[html_encode(artist_name)]' "
		design_html += "style='width: 100%; padding: 8px; background: #2a2a2a; border: 1px solid #444; color: white; border-radius: 4px; margin-bottom: 10px;' "
		design_html += "placeholder='Artist name (use %s for signature)'>"
		design_html += "<div style='color: #888; font-size: 0.9em;'>"
		design_html += "Use %s in name for signature formatting"
		design_html += "</div>"
		design_html += "</div>"

		// Tattoo design
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Tattoo Design</div>"
		design_html += "<textarea name='tattoo_design' "
		design_html += "style='width: 100%; height: 80px; padding: 8px; background: #2a2a2a; border: 1px solid #444; color: white; border-radius: 4px; resize: vertical; margin-bottom: 10px;' "
		design_html += "placeholder='Describe the tattoo design (supports :emoji: shortcodes)'>[html_encode(tattoo_design)]</textarea>"
		design_html += "<div style='color: #888; font-size: 0.9em;'>"
		design_html += "Supports emoji shortcodes like :heart: :smile: :star: etc."
		design_html += "</div>"
		design_html += "</div>"

		// Update Preview button
		design_html += "<div style='margin-bottom: 20px; text-align: center;'>"
		design_html += "<input type='submit' value='Update Preview' style='padding: 10px 20px; background: #2196F3; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 1em;'>"
		design_html += "</div>"
		design_html += "</form>"

		// Font selection
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Font Style</div>"
		design_html += "<div style='display: flex; gap: 8px; flex-wrap: wrap;'>"

		for(var/font_key in font_options)
			var/font_name = font_options[font_key]
			var/is_selected = (selected_font == font_key)
			design_html += "<a href='?src=[REF(kit)];tattoo_set_font=[font_key]' "
			design_html += "style='display: inline-block; background: [is_selected ? "#4CAF50" : "#444"]; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 0.9em;'>"
			design_html += "[font_name]"
			design_html += "</a>"

		design_html += "</div>"
		design_html += "</div>"

		// Flair selection (NEW)
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Text Flair</div>"
		design_html += "<div style='display: flex; gap: 8px; flex-wrap: wrap;'>"

		for(var/flair_key in flair_options)
			var/flair_name = flair_options[flair_key]
			var/is_selected = (selected_flair == flair_key)
			var/button_color = is_selected ? "#4CAF50" : "#444"
			design_html += "<a href='?src=[REF(kit)];tattoo_set_flair=[flair_key]' "
			design_html += "style='display: inline-block; background: [button_color]; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 0.9em;'>"
			design_html += "[flair_name]"
			design_html += "</a>"

		design_html += "</div>"
		design_html += "<div style='color: #888; font-size: 0.9em; margin-top: 5px;'>"
		design_html += "Adds special styling to your tattoo text"
		design_html += "</div>"
		design_html += "</div>"

		// Layer selection with layer availability info
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Tattoo Layer</div>"
		design_html += "<div style='display: flex; gap: 8px;'>"

		var/list/layer_options = list(
			"1" = "Under (Bottom)",
			"2" = "Normal (Middle)",
			"3" = "Over (Top)"
		)

		var/list/current_tattoos = get_custom_tattoos_fallback(victim, zone)
		var/list/taken_layers = list()
		for(var/datum/custom_tattoo/T in current_tattoos)
			taken_layers += T.layer

		for(var/layer_key in layer_options)
			var/layer_num = text2num(layer_key)
			var/layer_name = layer_options[layer_key]
			var/is_selected = (selected_layer == layer_num)
			var/is_taken = (layer_num in taken_layers)
			var/button_color = is_selected ? "#4CAF50" : "#444"
			var/button_text = layer_name

			if(is_taken)
				button_color = "#f44336"
				button_text = "[layer_name] (Taken)"

			design_html += "<a href='?src=[REF(kit)];tattoo_set_layer=[layer_key]' "
			design_html += "style='display: inline-block; background: [button_color]; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 0.9em;'"
			if(is_taken)
				design_html += " onclick='return confirm(\"This layer already has a tattoo. Are you sure you want to select it?\");'"
			design_html += ">"
			design_html += "[button_text]"
			design_html += "</a>"

		design_html += "</div>"
		design_html += "<div style='color: #888; font-size: 0.9em; margin-top: 5px;'>"
		design_html += "Only one tattoo per layer allowed per body part"
		design_html += "</div>"
		design_html += "</div>"

		// Color selection
		design_html += "<div style='margin-bottom: 20px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Ink Color</div>"
		design_html += "<div style='display: flex; align-items: center; gap: 10px;'>"
		design_html += "<div style='width: 30px; height: 30px; background: [ink_color]; border: 2px solid white; border-radius: 4px;'></div>"
		design_html += "<a href='?src=[REF(kit)];tattoo_change_color=1' "
		design_html += "style='display: inline-block; background: #2196F3; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none;'>Change Color</a>"
		design_html += "<span style='color: #888;'>Current: [ink_color]</span>"
		design_html += "</div>"
		design_html += "</div>"

		// Action buttons
		var/can_apply = check_can_apply(ink_uses, victim)
		design_html += "<div style='display: flex; gap: 10px;'>"

		// Back button
		design_html += "<a href='?src=[REF(kit)];tattoo_back_to_parts=1' "
		design_html += "style='display: inline-block; background: #666; color: white; padding: 10px 20px; border-radius: 4px; text-decoration: none;'>← Back to Parts</a>"

		// Apply button
		if(victim)
			design_html += "<a href='?src=[REF(kit)];tattoo_apply=1' "
			design_html += "style='display: inline-block; background: [can_apply ? "#4CAF50" : "#666"]; color: white; padding: 10px 20px; border-radius: 4px; text-decoration: none; flex-grow: 1; text-align: center;'"
			design_html += ">"
			design_html += "Apply Tattoo ([ink_uses] use[ink_uses != 1 ? "s" : ""] left)"
			design_html += "</a>"
		else
			design_html += "<a href='#' style='display: inline-block; background: #666; color: white; padding: 10px 20px; border-radius: 4px; text-decoration: none; flex-grow: 1; text-align: center;'>No Target</a>"

		design_html += "</div>"

		design_html += "</div>"
		design_html += "</div>"

		return design_html

	proc/check_can_apply(ink_uses, mob/victim)
		if(!victim || !zone || !design_mode)
			return FALSE
		if(!artist_name || length(artist_name) == 0)
			return FALSE
		if(!tattoo_design || length(tattoo_design) == 0)
			return FALSE
		if(ink_uses <= 0)
			return FALSE
		if(!is_custom_tattoo_bodypart_existing(victim, zone))
			return FALSE
		if(!get_custom_tattoo_location_accessible(victim, zone))
			return FALSE

		// Check if layer is already taken
		var/list/current_tattoos = get_custom_tattoos_fallback(victim, zone)
		for(var/datum/custom_tattoo/T in current_tattoos)
			if(T.layer == selected_layer)
				return FALSE

		if(length(current_tattoos) >= CUSTOM_MAX_TATTOOS_PER_PART)
			return FALSE
		return TRUE

	proc/generate_preview(mob/living/carbon/human/victim, mob/viewer, obj/item/custom_tattoo_kit/kit)
		if(!victim || !zone)
			return "<div style='background: #1a1a1a; padding: 20px; border-radius: 6px; color: #666; text-align: center;'>Select a body part to begin designing</div>"

		var/list/existing_tattoos = get_custom_tattoos_fallback(victim, zone)
		var/body_part_name = get_custom_tattoo_body_part_description(zone)

		var/preview_html = "<div style='background: #1a1a1a; padding: 15px; border-radius: 6px; border: 2px solid #333;'>"
		preview_html += "<h3 style='margin-top: 0; color: #fff; text-align: center; border-bottom: 1px solid #333; padding-bottom: 8px;'>[body_part_name] Preview</h3>"

		// Show existing tattoos in this zone
		if(length(existing_tattoos))
			preview_html += "<div style='margin-bottom: 15px;'>"
			preview_html += "<h4 style='color: #aaa; margin-bottom: 8px;'>Existing Tattoos:</h4>"
			preview_html += "<div style='background: #0a0a0a; padding: 10px; border-radius: 4px; max-height: 120px; overflow-y: auto;'>"

			for(var/datum/custom_tattoo/T as anything in existing_tattoos)
				if(QDELETED(T)) continue
				var/tattoo_html = T.get_examine_text_tgui(viewer, victim)
				preview_html += "<div style='margin: 5px 0; padding: 5px; background: #151515; border-left: 3px solid [T.color]; border-radius: 2px;'>"
				preview_html += "<span style='color: [T.color];'>[tattoo_html]</span>"
				preview_html += "</div>"

			preview_html += "</div></div>"

		// Show new design preview in examine format
		if(artist_name && length(artist_name) > 0 && tattoo_design && length(tattoo_design) > 0)
			preview_html += "<div style='border: 2px dashed [ink_color]; padding: 12px; border-radius: 6px; background: rgba([hex_to_rgb(ink_color)], 0.1);'>"
			preview_html += "<h4 style='color: [ink_color]; margin-top: 0;'>New Design Preview:</h4>"

			// Generate examine-style preview matching tattoo_datums.dm format
			var/display_design = tattoo_design
			var/display_artist = artist_name

			// Replace %s with actual artist name for preview
			if(findtext(display_artist, "%s") && kit && viewer)
				display_artist = replacetext(display_artist, "%s", viewer.name)

			// Apply text emoji parsing for preview
			display_design = parse_text_emojis(display_design)

			// Apply safe span for preview if flair is selected
			if(selected_flair && GLOB.custom_tattoo_flairs[selected_flair])
				var/flair_type = GLOB.custom_tattoo_flairs[selected_flair]
				display_design = apply_safe_span(display_design, flair_type)

			// Use the same format as examine text
			var/body_part_desc = get_custom_tattoo_body_part_description(zone)
			preview_html += "<div style='color: [ink_color]; font-family: monospace;'>"
			preview_html += "- [body_part_desc]: \"[display_design]\" (by [sanitize_text(display_artist)])"
			preview_html += "</div>"

			preview_html += "<div style='color: #888; font-size: 0.9em; margin-top: 10px;'>"
			preview_html += "Layer: [selected_layer == 1 ? "Under" : selected_layer == 2 ? "Normal" : "Over"] | "
			preview_html += "Font: [font_options[selected_font] || selected_font] | "
			preview_html += "Flair: [flair_options[selected_flair] || "None"] | "
			preview_html += "Color: <span style='color: [ink_color];'>[ink_color]</span>"
			preview_html += "</div>"
			preview_html += "</div>"
		else
			preview_html += "<div style='color: #666; text-align: center; padding: 20px; border: 1px dashed #333; border-radius: 4px;'>"
			if(!artist_name && !tattoo_design)
				preview_html += "Enter artist name and design description to see preview"
			else if(!artist_name || length(artist_name) == 0)
				preview_html += "Enter artist name to see preview"
			else
				preview_html += "Enter design description to see preview"
			preview_html += "</div>"

		preview_html += "</div>"
		return preview_html

	// Handle UI interactions
	proc/handle_topic(href, href_list, mob/user, obj/item/custom_tattoo_kit/kit)
		if(!kit || !user)
			return FALSE

		// Handle preview update (both artist and design)
		if(href_list["update_preview"])
			var/new_artist = href_list["tattoo_artist"]
			var/new_design = href_list["tattoo_design"]

			if(new_artist)
				artist_name = new_artist
			if(new_design)
				tattoo_design = new_design

			if(kit.current_target)
				kit.current_target.set_tattoo_ui_data("global", src)
			kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_select_zone"])
			var/new_zone = href_list["tattoo_select_zone"]
			if(kit.current_target && is_custom_tattoo_bodypart_existing(kit.current_target, new_zone))
				zone = new_zone
				design_mode = TRUE
				if(kit.current_target)
					kit.current_target.set_tattoo_ui_data("global", src)
				kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_back_to_parts"])
			design_mode = FALSE
			if(kit.current_target)
				kit.current_target.set_tattoo_ui_data("global", src)
			kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_toggle_debug"])
			debug_mode = !debug_mode
			kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_set_font"])
			var/new_font = href_list["tattoo_set_font"]
			if(new_font in font_options)
				selected_font = new_font
				if(kit.current_target)
					kit.current_target.set_tattoo_ui_data("global", src)
				kit.ui_interact(user)
			return TRUE

		// NEW: Handle flair selection
		if(href_list["tattoo_set_flair"])
			var/new_flair = href_list["tattoo_set_flair"]
			if(new_flair in flair_options)
				selected_flair = (new_flair == "null") ? null : new_flair
				if(kit.current_target)
					kit.current_target.set_tattoo_ui_data("global", src)
				kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_set_layer"])
			var/new_layer = text2num(href_list["tattoo_set_layer"])
			if(new_layer in list(1, 2, 3))
				selected_layer = new_layer
				if(kit.current_target)
					kit.current_target.set_tattoo_ui_data("global", src)
				kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_change_color"])
			var/new_color = input(user, "Choose ink color:", "Tattoo Kit", ink_color) as color|null
			if(new_color)
				ink_color = new_color
				if(kit.current_target)
					kit.current_target.set_tattoo_ui_data("global", src)
				kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_apply"])
			if(kit.can_apply_tattoo(user))
				kit.apply_tattoo(user)
			else
				to_chat(user, span_warning("Cannot apply tattoo - check requirements."))
			return TRUE

		return FALSE

	// Clear all data
	proc/clear()
		artist_name = ""
		tattoo_design = ""
		selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
		selected_font = PEN_FONT
		selected_flair = null
		ink_color = "#000000"
		design_mode = FALSE

// Fallback helper to get tattoos for a victim if the mob helper isn't available
/proc/get_custom_tattoos_fallback(mob/living/carbon/human/victim, body_zone)
	if(!istype(victim) || !victim.custom_body_tattoos)
		return list()

	var/search_zone = istext(body_zone) ? string_to_zone(body_zone) : body_zone
	var/search_zone_string = zone_to_string(search_zone)
	var/list/found_tattoos = list()

	for(var/datum/custom_tattoo/T as anything in victim.custom_body_tattoos)
		if(QDELETED(T))
			continue
		var/tattoo_zone_string = zone_to_string(T.body_part)
		if(tattoo_zone_string == search_zone_string)
			found_tattoos += T

	return sortTim(found_tattoos, GLOBAL_PROC_REF(cmp_custom_tattoo_layer_asc))

// Helper proc to convert hex color to RGB values for rgba()
/proc/hex_to_rgb(hex_color)
	if(!hex_color || length(hex_color) != 7) return "0,0,0"
	var/r = hex2num(copytext(hex_color, 2, 4))
	var/g = hex2num(copytext(hex_color, 4, 6))
	var/b = hex2num(copytext(hex_color, 6, 8))
	return "[r],[g],[b]"
