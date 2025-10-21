/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new dungeon destinations."
	icon_screen = "portal_control"
	icon_keyboard = "teleport_key"
	var/obj/machinery/portal/P

/obj/machinery/computer/portal_control/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	try_to_linkup()

/obj/machinery/computer/portal_control/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PortalControl", name)
		if(P)
			P.portal_visuals.display_to(user, ui.window)
		ui.open()

/obj/machinery/computer/portal_control/ui_data(mob/user)
	. = ..()
	.["portal_present"] = !!P
	.["portal_status"] = P ? P.powered() : FALSE
	.["current_target"] = P?.target?.get_ui_data()

	var/list/destinations = list()
	if(P)
		for(var/datum/portal_destination/possible_destination in GLOB.portal_destinations)
			if(!P.valid_destination(possible_destination))
				continue
			destinations += list(possible_destination.get_ui_data())
	.["destinations"] = destinations

	// Add generation-specific data
	if(P?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = P.destination
		.["generation_status"] = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		.["dungeon_data"] = P.generated_dungeon_data

/obj/machinery/computer/portal_control/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("linkup")
			try_to_linkup()
			return TRUE
		if("activate")
			var/datum/portal_destination/D = locate(params["destination"]) in GLOB.portal_destinations
			try_to_connect(D)
			return TRUE
		if("deactivate")
			if(P?.target)
				P.deactivate()
			return TRUE
		if("generate_new")
			if(P?.destination)
				var/datum/portal_destination/veilbreak/veil_dest = P.destination
				veil_dest.start_generation()
				P.say("Initiating new dungeon generation...")
			return TRUE

/obj/machinery/computer/portal_control/ui_close(mob/user)
	. = ..()
	if(P)
		P.portal_visuals.hide_from(user)

/obj/machinery/computer/portal_control/proc/try_to_linkup()
	P = locate(/obj/machinery/portal) in view(7, get_turf(src))

/obj/machinery/computer/portal_control/proc/try_to_connect(datum/portal_destination/D)
	if(!D || !P)
		return
	if(!D.is_available() || P.target)
		return
	P.activate(D)

/obj/machinery/computer/portal_control/tgui_state(mob/user)
	return GLOB.tgui_physical_state
