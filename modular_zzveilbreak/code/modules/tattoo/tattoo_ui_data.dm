// modular_zzveilbreak/code/modules/tattoo/tattoo_ui_data.dm
// Complete UI system in DM with dynamic interface generation

/datum/custom_tattoo_ui_data
	var/zone = ""
	var/artist_name = ""
	var/tattoo_design = ""
	var/selected_layer = CUSTOM_TATTOO_LAYER_NORMAL
	var/selected_font = PEN_FONT
	var/ink_color = "#000000"
	var/preview_cache = ""
	var/design_mode = FALSE
	var/static/list/font_options = list(
		"PEN_FONT" = "Pen",
		"FOUNTAIN_PEN_FONT" = "Fountain Pen",
		"PRINTER_FONT" = "Printer",
		"CHARCOAL_FONT" = "Charcoal",
		"CRAYON_FONT" = "Crayon"
	)

	New(new_zone = "")
		zone = new_zone

	// Generate complete UI HTML based on current state
	proc/generate_interface(mob/living/carbon/human/victim, mob/viewer, ink_uses, max_ink_uses)
		var/interface_html = "<div class='tattooInterface' style='font-family: Verdana, sans-serif; color: white;'>"

		// Header section
		interface_html += generate_header(victim, ink_uses, max_ink_uses)

		if(!design_mode)
			// Body part selection mode
			interface_html += generate_body_part_selection(victim, viewer)
		else
			// Design mode
			interface_html += generate_design_interface(victim, viewer, ink_uses)

		interface_html += "</div>"
		return interface_html

	proc/generate_header(mob/living/carbon/human/victim, ink_uses, max_ink_uses)
		var/target_name = victim ? victim.name : "No Target"
		var/header = "<div style='background: #2a2a2a; padding: 10px; border-radius: 8px 8px 0 0; margin-bottom: 10px;'>"
		header += "<h2 style='margin: 0; color: #4CAF50;'>Tattoo Kit - [target_name]</h2>"

		// Ink status
		var/ink_percent = max_ink_uses ? (ink_uses / max_ink_uses) * 100 : 0
		var/ink_color_class = ink_uses > 0 ? "#4CAF50" : "#f44336"
		header += "<div style='margin-top: 8px;'>"
		header += "<div style='background: #1a1a1a; height: 20px; border-radius: 10px; overflow: hidden;'>"
		header += "<div style='background: [ink_color_class]; height: 100%; width: [ink_percent]%; transition: width 0.3s;'></div>"
		header += "</div>"
		header += "<div style='text-align: center; margin-top: 4px;'>Ink: [ink_uses]/[max_ink_uses]</div>"
		header += "</div>"

		header += "</div>"
		return header

	proc/generate_body_part_selection(mob/living/carbon/human/victim, mob/viewer)
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
					var/button_hover = covered ? "#d32f2f" : "#388E3C"
					var/tattoo_status = "([current_tats]/[max_tats])"

					body_html += {"
					<a href='?src=[REF(victim)];tattoo_select_zone=[zone_key]'
					   style='display: block; background: [button_color]; color: white; padding: 12px;
					          border-radius: 6px; text-decoration: none; text-align: center;
					          transition: background 0.2s; border: 2px solid [button_color];'
					   onmouseover='this.style.background=\"[button_hover]\"'
					   onmouseout='this.style.background=\"[button_color]\"'>
						<div style='font-weight: bold; margin-bottom: 4px;'>[part_name]</div>
						<div style='font-size: 0.9em; opacity: 0.9;'>[tattoo_status]</div>
					</a>
					"}

				body_html += "</div>"

		body_html += "</div>"
		return body_html

	proc/generate_design_interface(mob/living/carbon/human/victim, mob/viewer, ink_uses)
		var/design_html = "<div style='background: #2a2a2a; padding: 15px; border-radius: 0 0 8px 8px;'>"

		// Preview section - generate FIRST to ensure it's current
		design_html += "<div style='margin-bottom: 20px;'>"
		design_html += generate_preview(victim, viewer)
		design_html += "</div>"

		// Design controls
		design_html += "<div style='background: #1a1a1a; padding: 15px; border-radius: 6px;'>"

		var/zone_name = zone ? get_custom_tattoo_body_part_description(zone) : "Unknown Location"
		design_html += "<h3 style='color: #fff; margin-top: 0;'>Design for [zone_name]</h3>"

		// Artist name - automatically handles %s for signature
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>"
		design_html += "Artist Name [findtext(artist_name, "%s") ? "<span style='color: #FFD700;'>(Signature Format)</span>" : ""]"
		design_html += "</div>"
		design_html += "<form action='byond://' method='GET' style='margin: 0;'>"
		design_html += "<input type='hidden' name='src' value='[REF(victim)]'>"
		design_html += "<input type='text' name='tattoo_artist' value='[html_encode(artist_name)]' "
		design_html += "style='width: 100%; padding: 8px; background: #2a2a2a; border: 1px solid #444; color: white; border-radius: 4px;' "
		design_html += "placeholder='Artist name (use %s for signature format)'>"
		design_html += "<div style='color: #888; font-size: 0.9em; margin-top: 5px;'>"
		design_html += "Use %s in name for signature formatting"
		design_html += "</div>"
		design_html += "</form>"
		design_html += "</div>"

		// Tattoo design
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Tattoo Design</div>"
		design_html += "<form action='byond://' method='GET' style='margin: 0;'>"
		design_html += "<input type='hidden' name='src' value='[REF(victim)]'>"
		design_html += "<textarea name='tattoo_design' "
		design_html += "style='width: 100%; height: 80px; padding: 8px; background: #2a2a2a; border: 1px solid #444; color: white; border-radius: 4px; resize: vertical;' "
		design_html += "placeholder='Describe the tattoo design (supports :emoji: and basic HTML)'>[html_encode(tattoo_design)]</textarea>"
		design_html += "</form>"
		design_html += "</div>"

		// Font selection
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Font Style</div>"
		design_html += "<div style='display: flex; gap: 8px; flex-wrap: wrap;'>"

		for(var/font_key in font_options)
			var/font_name = font_options[font_key]
			var/is_selected = (selected_font == font_key)
			design_html += "<a href='?src=[REF(victim)];tattoo_set_font=[font_key]' "
			design_html += "style='display: inline-block; background: [is_selected ? "#4CAF50" : "#444"]; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 0.9em;'>"
			design_html += "[font_name]"
			design_html += "</a>"

		design_html += "</div>"
		design_html += "</div>"

		// Layer selection
		design_html += "<div style='margin-bottom: 15px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Tattoo Layer</div>"
		design_html += "<div style='display: flex; gap: 8px;'>"

		var/list/layer_options = list(
			"1" = "Under (Bottom)",
			"2" = "Normal (Middle)",
			"3" = "Over (Top)"
		)

		for(var/layer_key in layer_options)
			var/layer_name = layer_options[layer_key]
			var/is_selected = (selected_layer == text2num(layer_key))
			design_html += "<a href='?src=[REF(victim)];tattoo_set_layer=[layer_key]' "
			design_html += "style='display: inline-block; background: [is_selected ? "#4CAF50" : "#444"]; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 0.9em;'>"
			design_html += "[layer_name]"
			design_html += "</a>"

		design_html += "</div>"
		design_html += "</div>"

		// Color selection
		design_html += "<div style='margin-bottom: 20px;'>"
		design_html += "<div style='color: #4CAF50; font-weight: bold; margin-bottom: 5px;'>Ink Color</div>"
		design_html += "<div style='display: flex; align-items: center; gap: 10px;'>"
		design_html += "<div style='width: 30px; height: 30px; background: [ink_color]; border: 2px solid white; border-radius: 4px;'></div>"
		design_html += "<a href='?src=[REF(victim)];tattoo_change_color=1' "
		design_html += "style='display: inline-block; background: #2196F3; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none;'>Change Color</a>"
		design_html += "<span style='color: #888;'>Current: [ink_color]</span>"
		design_html += "</div>"
		design_html += "</div>"

		// Action buttons
		var/can_apply = artist_name && tattoo_design && ink_uses > 0 && victim
		design_html += "<div style='display: flex; gap: 10px;'>"

		// Back button
		design_html += "<a href='?src=[REF(victim)];tattoo_back_to_parts=1' "
		design_html += "style='display: inline-block; background: #666; color: white; padding: 10px 20px; border-radius: 4px; text-decoration: none;'>← Back to Parts</a>"

		// Apply button - now properly checks both fields
		if(victim)
			design_html += "<a href='?src=[REF(victim)];tattoo_apply=1' "
			design_html += "style='display: inline-block; background: [can_apply ? "#4CAF50" : "#666"]; color: white; padding: 10px 20px; border-radius: 4px; text-decoration: none; flex-grow: 1; text-align: center;'"
			if(!can_apply)
				design_html += " onclick='alert(\"Cannot apply tattoo! Make sure both artist name and design are filled out and you have ink remaining.\"); return false;'"
			design_html += ">"
			design_html += "Apply Tattoo ([ink_uses] use[ink_uses != 1 ? "s" : ""] left)"
			design_html += "</a>"
		else
			design_html += "<a href='#' style='display: inline-block; background: #666; color: white; padding: 10px 20px; border-radius: 4px; text-decoration: none; flex-grow: 1; text-align: center;'>No Target</a>"

		design_html += "</div>"

		design_html += "</div>" // End design controls
		design_html += "</div>" // End design interface

		return design_html

	proc/generate_preview(mob/living/carbon/human/victim, mob/viewer)
		if(!victim || !zone)
			return "<div style='background: #1a1a1a; padding: 20px; border-radius: 6px; color: #666; text-align: center;'>Select a body part to begin designing</div>"

		var/list/existing_tattoos = victim.get_custom_tattoos(zone)
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
				preview_html += tattoo_html
				preview_html += "</div>"

			preview_html += "</div></div>"

		// Show new design preview in examine format
		if(artist_name && tattoo_design)
			preview_html += "<div style='border: 2px dashed [ink_color]; padding: 12px; border-radius: 6px; background: rgba([hex_to_rgb(ink_color)], 0.1);'>"
			preview_html += "<h4 style='color: [ink_color]; margin-top: 0;'>New Design Preview:</h4>"

			// Generate examine-style preview matching tattoo_datums.dm format
			var/display_design = tattoo_design
			var/display_artist = artist_name

			// Apply font styling to design
			if(selected_font && selected_font != PEN_FONT)
				display_design = "<font face='[selected_font]'>[display_design]</font>"

			// Automatically handle signature formatting based on %s
			if(findtext(display_artist, "%s"))
				display_artist = replacetext(display_artist, "%s", display_artist)
				display_artist = "<font face='[FOUNTAIN_PEN_FONT]'>[display_artist]</font>"

			// Use the same format as examine text
			var/body_part_desc = get_custom_tattoo_body_part_description(zone)
			preview_html += "<div style='color: [ink_color]; font-family: monospace;'>"
			preview_html += "- [body_part_desc]: \"[display_design]\" (by [display_artist])"
			preview_html += "</div>"

			preview_html += "<div style='color: #888; font-size: 0.9em; margin-top: 10px;'>"
			preview_html += "Layer: [selected_layer == 1 ? "Under" : selected_layer == 2 ? "Normal" : "Over"] | "
			preview_html += "Font: [font_options[selected_font] || selected_font] | "
			preview_html += "Color: <span style='color: [ink_color];'>[ink_color]</span>"
			preview_html += "</div>"
			preview_html += "</div>"
		else
			preview_html += "<div style='color: #666; text-align: center; padding: 20px; border: 1px dashed #333; border-radius: 4px;'>"
			if(!artist_name && !tattoo_design)
				preview_html += "Enter artist name and design description to see preview"
			else if(!artist_name)
				preview_html += "Enter artist name to see preview"
			else
				preview_html += "Enter design description to see preview"
			preview_html += "</div>"

		preview_html += "</div>"
		return preview_html

	// Handle UI interactions - FIXED to preserve text on font changes
	proc/handle_topic(href, href_list, mob/user, obj/item/custom_tattoo_kit/kit)
		if(!kit || !user)
			return

		// Handle form submissions FIRST to preserve text
		if(href_list["tattoo_artist"])
			var/new_artist = href_list["tattoo_artist"]
			artist_name = new_artist
			if(kit.current_target)
				kit.current_target.set_tattoo_ui_data("global", src)
			kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_design"])
			var/new_design = href_list["tattoo_design"]
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
				kit.current_target.set_tattoo_ui_data("global", src)
				kit.ui_interact(user)
			return TRUE

		if(href_list["tattoo_back_to_parts"])
			design_mode = FALSE
			if(kit.current_target)
				kit.current_target.set_tattoo_ui_data("global", src)
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
			if(kit.can_apply_tattoo())
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
		ink_color = "#000000"
		preview_cache = ""
		design_mode = FALSE

// Helper proc to convert hex color to RGB values for rgba()
/proc/hex_to_rgb(hex_color)
	if(!hex_color || length(hex_color) != 7) return "0,0,0"
	var/r = hex2num(copytext(hex_color, 2, 4))
	var/g = hex2num(copytext(hex_color, 4, 6))
	var/b = hex2num(copytext(hex_color, 6, 8))
	return "[r],[g],[b]"
