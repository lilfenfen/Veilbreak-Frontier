// modular_zzveilbreak/code/modules/dungeons/portal_control_core.dm

/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new destinations beyond the veil."
	icon_screen = "gateway"
	icon_keyboard = "teleport_key"
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
	linked_portal = locate(/obj/machinery/portal) in view(7, get_turf(src))

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
