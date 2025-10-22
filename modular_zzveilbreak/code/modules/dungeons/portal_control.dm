// modular_zzveilbreak/code/modules/dungeons/portal_control.dm

/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new dungeon destinations."
	icon_screen = "gateway"
	icon_keyboard = "teleport_key"
	var/obj/machinery/portal/linked_portal

/obj/machinery/computer/portal_control/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	try_to_linkup()

/obj/machinery/computer/portal_control/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PortalControl", name)
		ui.open()

/obj/machinery/computer/portal_control/ui_data(mob/user)
	. = list()

	// Basic portal info
	.["portal_present"] = !!linked_portal
	.["portal_status"] = linked_portal ? linked_portal.powered() : FALSE

	// Current target info
	if(linked_portal?.target)
		.["current_target"] = linked_portal.target.get_ui_data()
	else
		.["current_target"] = null

	// Available destinations
	var/list/destinations = list()
	if(linked_portal)
		for(var/datum/portal_destination/possible_destination in GLOB.portal_destinations)
			if(!linked_portal.valid_destination(possible_destination))
				continue
			destinations += list(possible_destination.get_ui_data())
	.["destinations"] = destinations

	// Generation status
	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		.["generation_status"] = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		.["generation_progress"] = veil_dest.generation_progress
		.["dungeon_data"] = linked_portal.generated_dungeon_data
	else
		.["generation_status"] = "idle"
		.["generation_progress"] = 0
		.["dungeon_data"] = null

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("linkup")
			try_to_linkup()
			. = TRUE
		if("activate")
			var/datum/portal_destination/D = locate(params["destination"]) in GLOB.portal_destinations
			try_to_connect(D)
			. = TRUE
		if("deactivate")
			if(linked_portal?.target)
				linked_portal.deactivate()
			. = TRUE
		if("generate_new")
			if(linked_portal?.destination)
				var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
				veil_dest.start_generation()
				linked_portal.say("Initiating new dungeon generation...")
			. = TRUE

/obj/machinery/computer/portal_control/proc/try_to_linkup()
	linked_portal = locate(/obj/machinery/portal) in view(7, get_turf(src))

/obj/machinery/computer/portal_control/proc/try_to_connect(datum/portal_destination/D)
	if(!D || !linked_portal)
		return
	if(!D.is_available() || linked_portal.target)
		return
	linked_portal.activate(D)

// Remove the tgui_state override - use default state
