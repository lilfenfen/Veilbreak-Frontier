// modular_zzveilbreak/code/modules/dungeons/portal_control_core.dm

/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new destinations beyond the veil."
	icon_screen = "gateway"
	icon_keyboard = "teleport_key"

	// Construction properties
	circuit = /obj/item/circuitboard/machine/portal_control
	panel_open = FALSE

	var/obj/machinery/portal/linked_portal
	/// Track if we're currently generating to prevent double-starts
	var/generation_in_progress = FALSE
	/// Last known UI data state for change detection
	var/list/last_ui_data = list()
	/// Timer for generation progress updates
	var/generation_progress_timer
	/// Portal name cache - set once when generation completes
	var/cached_portal_name = null
	/// Prevent UI spam during generation
	var/last_ui_update = 0
	/// Minimum time between UI updates during generation (0.5 seconds)
	var/ui_update_cooldown = 5

/obj/machinery/computer/portal_control/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	try_to_linkup()

/obj/machinery/computer/portal_control/CanAllowThrough(atom/movable/mover, border_dir)
	return TRUE

/obj/machinery/computer/portal_control/can_interact(mob/user)
	if(!user)
		return FALSE
	if(!isliving(user) && !isobserver(user))
		return FALSE
	if(!in_range(src, user) && !isobserver(user))
		return FALSE
	return TRUE

/obj/machinery/computer/portal_control/ui_interact(mob/user, datum/tgui/ui)
	if(!can_interact(user))
		return FALSE

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PortalControl", name)
		ui.open()

	log_portal_control("UI: [key_name(user)] opened UI at [AREACOORD(src)]")
	return TRUE

/obj/machinery/computer/portal_control/proc/try_to_linkup()
	// Scan for portal in a 7-tile radius (improved from view(7))
	var/turf/center_turf = get_turf(src)
	linked_portal = null

	// Scan in a 15x15 area (7 tiles in each direction)
	for(var/turf/T in block(
		locate(max(1, center_turf.x-7), max(1, center_turf.y-7), center_turf.z),
		locate(min(world.maxx, center_turf.x+7), min(world.maxy, center_turf.y+7), center_turf.z)
	))
		var/obj/machinery/portal/found_portal = locate(/obj/machinery/portal) in T
		if(found_portal)
			linked_portal = found_portal
			log_portal_control("Linkup: Found portal at [AREACOORD(found_portal)]")
			break

	if(!linked_portal)
		log_portal_control("Linkup: No portal found in scanning area")

/obj/machinery/computer/portal_control/proc/force_ui_update()
	if(world.time < last_ui_update + ui_update_cooldown)
		return
	last_ui_update = world.time
	last_ui_data = list() // Force update by clearing last state
	SStgui.update_uis(src)

/obj/machinery/computer/portal_control/proc/start_generation_monitoring()
	if(generation_progress_timer)
		deltimer(generation_progress_timer)

	// Update every 0.5 seconds during generation for progress bar
	generation_progress_timer = addtimer(CALLBACK(src, .proc/update_generation_progress), 0.5 SECONDS, TIMER_STOPPABLE)

/obj/machinery/computer/portal_control/proc/stop_generation_monitoring()
	if(generation_progress_timer)
		deltimer(generation_progress_timer)
		generation_progress_timer = null

/obj/machinery/computer/portal_control/proc/update_generation_progress()
	if(!linked_portal?.destination)
		stop_generation_monitoring()
		return

	var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
	if(veil_dest.generating)
		// Force UI update to show progress (with cooldown)
		force_ui_update()
		// Continue monitoring
		start_generation_monitoring()
	else
		// Generation finished, do final update
		force_ui_update()
		stop_generation_monitoring()

/obj/machinery/computer/portal_control/proc/register_generation_callbacks(datum/portal_destination/veilbreak/veil_dest)
	// Store a reference to this computer in the destination for callbacks
	veil_dest.connected_control_computer = src

/obj/machinery/computer/portal_control/proc/on_generation_completed()
	generation_in_progress = FALSE

	// Set the portal name once when generation completes
	if(linked_portal?.destination && !cached_portal_name)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		cached_portal_name = get_portal_name(veil_dest)

	log_portal_control("Callback: Generation completed successfully with name: [cached_portal_name]")

	// Stop monitoring and force final update
	stop_generation_monitoring()
	force_ui_update()

	// Provide user feedback
	if(linked_portal && !QDELETED(linked_portal))
		linked_portal.say("Portal stabilization complete. Destination secured.")

/obj/machinery/computer/portal_control/proc/on_generation_failed(reason)
	generation_in_progress = FALSE
	log_portal_control("Callback: Generation failed - [reason]")

	// Stop monitoring and force final update
	stop_generation_monitoring()
	force_ui_update()

	// Provide user feedback
	if(linked_portal && !QDELETED(linked_portal))
		linked_portal.say("Portal stabilization failed: [reason]")

/obj/machinery/computer/portal_control/proc/get_portal_name(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest || !veil_dest.generated)
		return generate_fallback_name()

	// Use the map name directly from JSON metadata
	if(veil_dest.last_generation_data)
		var/list/metadata = veil_dest.last_generation_data["metadata"]
		if(metadata && metadata["map_name"])
			var/map_name = metadata["map_name"]
			log_portal_control("Portal Name: Using map name from JSON: [map_name]")
			return map_name

	// Fallback if no map name in metadata
	return generate_fallback_name()

/obj/machinery/computer/portal_control/proc/generate_fallback_name()
	return "Veilbreak Dungeon [rand(1000,9999)]"

// Construction and deconstruction
/obj/machinery/computer/portal_control/on_construction()
	. = ..()
	// Computer starts with no linked portal when built
	linked_portal = null

/obj/machinery/computer/portal_control/on_deconstruction()
	. = ..()
	// Clean up any monitoring timers when deconstructed
	stop_generation_monitoring()

// Tool interactions following established patterns
/obj/machinery/computer/portal_control/screwdriver_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, tool))
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/computer/portal_control/crowbar_act(mob/living/user, obj/item/tool)
	if(panel_open)
		return default_deconstruction_crowbar(tool) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	return ITEM_INTERACT_BLOCKING

/obj/machinery/computer/portal_control/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(default_unfasten_wrench(user, tool))
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

// Add contextual screentips like other machines
/obj/machinery/computer/portal_control/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()

	if(isnull(held_item))
		context[SCREENTIP_CONTEXT_LMB] = panel_open ? "Interact with components" : "Open UI"
		return CONTEXTUAL_SCREENTIP_SET

	if(held_item.tool_behaviour == TOOL_WRENCH)
		context[SCREENTIP_CONTEXT_LMB] = "[anchored ? "Una" : "A"]nchor"
		return CONTEXTUAL_SCREENTIP_SET
	if(held_item.tool_behaviour == TOOL_SCREWDRIVER)
		context[SCREENTIP_CONTEXT_LMB] = "[panel_open ? "Close" : "Open"] panel"
		return CONTEXTUAL_SCREENTIP_SET
	if(held_item.tool_behaviour == TOOL_CROWBAR && panel_open)
		context[SCREENTIP_CONTEXT_LMB] = "Deconstruct"
		return CONTEXTUAL_SCREENTIP_SET

// Update examine text to show construction status
/obj/machinery/computer/portal_control/examine(mob/user)
	. = ..()
	if(!linked_portal)
		. += span_notice("No portal linked. Use the linkup function in the UI.")
	if(panel_open)
		. += span_notice("The maintenance panel is open.")

// ===== PORTAL CONTROL CIRCUIT BOARD =====
/obj/item/circuitboard/machine/portal_control
	name = "Portal Control Console (Machine Board)"
	desc = "A circuit board for a portal control console."
	build_path = /obj/machinery/computer/portal_control
	req_components = list(
		/obj/item/stock_parts/scanning_module = 1,
		/obj/item/stock_parts/micro_laser = 1,
		/obj/item/stack/cable_coil = 2
	)
	needs_anchored = TRUE
