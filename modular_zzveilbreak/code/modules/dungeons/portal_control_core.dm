// modular_zzveilbreak/code/modules/dungeons/portal_control_core.dm

/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new destinations beyond the veil."
	icon_screen = "gateway"
	icon_keyboard = "teleport_key"
	circuit = /obj/item/circuitboard/computer/portal_control

	var/obj/machinery/portal/linked_portal
	var/generation_in_progress = FALSE
	var/cleanup_in_progress = FALSE
	var/list/last_ui_data = list()
	var/generation_progress_timer
	var/cached_portal_name = null
	var/last_ui_update = 0
	var/ui_update_cooldown = 5

/obj/machinery/computer/portal_control/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()

	// Wait for subsystems to be ready before attempting linkup
	if(!subsystems_ready_for_portals())
		addtimer(CALLBACK(src, .proc/delayed_linkup), 5 SECONDS)
	else
		delayed_linkup()

/obj/machinery/computer/portal_control/proc/delayed_linkup()
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

	return TRUE

/obj/machinery/computer/portal_control/proc/try_to_linkup()
	var/turf/center_turf = get_turf(src)
	linked_portal = null

	for(var/turf/T in block(
		locate(max(1, center_turf.x-7), max(1, center_turf.y-7), center_turf.z),
		locate(min(world.maxx, center_turf.x+7), min(world.maxy, center_turf.y+7), center_turf.z)
	))
		var/obj/machinery/portal/found_portal = locate(/obj/machinery/portal) in T
		if(found_portal)
			linked_portal = found_portal

			if(found_portal.target)
				var/datum/portal_destination/veilbreak/veil_dest = found_portal.target
				if(veil_dest.generating)
					generation_in_progress = TRUE
					start_generation_monitoring()
				else if(veil_dest.generated)
					cached_portal_name = get_portal_name(veil_dest)
				else if(found_portal.transport_active)
					// Also get name when portal is active but destination might not be marked generated yet
					cached_portal_name = get_portal_name(veil_dest)
			break

	// Force UI update after linkup to show current state
	force_ui_update()

/obj/machinery/computer/portal_control/proc/force_ui_update()
	if(world.time < last_ui_update + ui_update_cooldown)
		return
	last_ui_update = world.time
	last_ui_data = list()
	SStgui.update_uis(src)

/obj/machinery/computer/portal_control/proc/start_generation_monitoring()
	if(generation_progress_timer)
		deltimer(generation_progress_timer)

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
		force_ui_update()
		start_generation_monitoring()
	else
		force_ui_update()
		stop_generation_monitoring()

/obj/machinery/computer/portal_control/proc/register_generation_callbacks(datum/portal_destination/veilbreak/veil_dest)
	veil_dest.connected_control_computer = src

/obj/machinery/computer/portal_control/proc/on_generation_completed()
	generation_in_progress = FALSE
	cleanup_in_progress = FALSE

	if(linked_portal?.destination && !cached_portal_name)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		cached_portal_name = get_portal_name(veil_dest)

	stop_generation_monitoring()
	force_ui_update()

	if(linked_portal && !QDELETED(linked_portal))
		linked_portal.say("Portal stabilization complete. Destination secured.")

/obj/machinery/computer/portal_control/proc/on_generation_failed(reason)
	generation_in_progress = FALSE
	cleanup_in_progress = FALSE

	stop_generation_monitoring()
	force_ui_update()

	if(linked_portal && !QDELETED(linked_portal))
		linked_portal.say("Portal stabilization failed: [reason]")

/obj/machinery/computer/portal_control/proc/on_portal_activated(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest || QDELETED(veil_dest))
		return

	// Force immediate name update and UI refresh
	cached_portal_name = get_portal_name(veil_dest)
	// Double-check we have the actual map_name, not just default
	if(veil_dest.last_generation_data)
		var/list/metadata = veil_dest.last_generation_data["metadata"]
		if(metadata && metadata["map_name"])
			var/map_name = metadata["map_name"]
			if(map_name && map_name != "0" && map_name != "")
				cached_portal_name = map_name
		else if(veil_dest.last_generation_data["map_name"])
			var/map_name = veil_dest.last_generation_data["map_name"]
			if(map_name && map_name != "0" && map_name != "")
				cached_portal_name = map_name

	force_ui_update()

/obj/machinery/computer/portal_control/proc/cleanup_portal_simple(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest || QDELETED(veil_dest))
		return

	if(!veil_dest.dungeon_z_level)
		return

	cleanup_in_progress = TRUE
	force_ui_update()

	// CRITICAL: Get ejection turf from STATION side, not dungeon side
	var/turf/ejection_turf = find_station_ejection_turf()
	if(!ejection_turf && linked_portal && !QDELETED(linked_portal))
		ejection_turf = get_step(linked_portal, SOUTH)
		if(!ejection_turf)
			ejection_turf = get_turf(linked_portal)

	veil_dest.cleanup_z_level_completely(veil_dest.dungeon_z_level, ejection_turf)

	addtimer(CALLBACK(src, .proc/on_cleanup_completed), 5 SECONDS)

/obj/machinery/computer/portal_control/proc/find_station_ejection_turf()
	if(linked_portal && !QDELETED(linked_portal))
		var/turf/portal_turf = get_turf(linked_portal)
		if(portal_turf)
			var/turf/ejection_turf = get_step(portal_turf, SOUTH)
			if(!ejection_turf || !isfloorturf(ejection_turf))
				ejection_turf = portal_turf
			return ejection_turf
	return null

/obj/machinery/computer/portal_control/proc/on_cleanup_completed()
	cleanup_in_progress = FALSE
	force_ui_update()

/obj/machinery/computer/portal_control/proc/get_portal_name(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest || !veil_dest.generated)
		return "Quantum Pocket Space" // Default name

	// Prioritize the actual map_name from generation data
	if(veil_dest.last_generation_data)
		var/list/metadata = veil_dest.last_generation_data["metadata"]
		if(metadata && metadata["map_name"])
			var/map_name = metadata["map_name"]
			if(map_name && map_name != "0" && map_name != "")
				return map_name

	// Also check if there's a specific name in the main data
	if(veil_dest.last_generation_data && veil_dest.last_generation_data["map_name"])
		var/map_name = veil_dest.last_generation_data["map_name"]
		if(map_name && map_name != "0" && map_name != "")
			return map_name

	return "Quantum Pocket Space" // Fallback name

/obj/machinery/computer/portal_control/proc/generate_fallback_name()
	return "Quantum Pocket Space [rand(1000,9999)]"

/obj/machinery/computer/portal_control/proc/on_power_failure()
	if(!linked_portal)
		return

	// Update UI to reflect power loss
	force_ui_update()

	// Notify users
	say("Warning: Portal power failure detected. Emergency shutdown initiated.")

	// If generation was in progress, cancel it
	if(generation_in_progress)
		generation_in_progress = FALSE
		stop_generation_monitoring()
		say("Portal stabilization cancelled due to power failure.")

/obj/machinery/computer/portal_control/on_construction()
	. = ..()
	linked_portal = null

/obj/machinery/computer/portal_control/on_deconstruction()
	. = ..()
	stop_generation_monitoring()

/obj/machinery/computer/portal_control/screwdriver_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, tool))
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/computer/portal_control/crowbar_act(mob/living/user, obj/item/tool)
	return default_deconstruction_crowbar(tool) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING

/obj/machinery/computer/portal_control/examine(mob/user)
	. = ..()
	if(!linked_portal)
		. += span_notice("No portal linked. Use the linkup function in the UI.")
	else if(linked_portal.target)
		. += span_notice("Linked to active portal destination: [cached_portal_name || linked_portal.target.name]")

/obj/item/circuitboard/computer/portal_control
	name = "Portal Control Console"
	desc = "A circuit board for a portal control console."
	build_path = /obj/machinery/computer/portal_control
