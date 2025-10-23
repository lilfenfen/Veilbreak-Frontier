// modular_zzveilbreak/code/modules/dungeons/portal_control.dm

/obj/machinery/computer/portal_control
	name = "portal control console"
	desc = "Used to control dimensional portals and generate new dungeon destinations."
	icon_screen = "gateway"
	icon_keyboard = "teleport_key"
	var/obj/machinery/portal/linked_portal

// Helper proc for portal control logging
/proc/log_portal_control(text)
	log_game(text, list(), LOG_GAME)

/obj/machinery/computer/portal_control/Initialize(mapload, obj/item/circuitboard/C)
	. = ..()
	try_to_linkup()

/obj/machinery/computer/portal_control/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PortalControl", name)
		ui.open()
	log_portal_control("Portal Control: [key_name(user)] opened UI at [AREACOORD(src)]")

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

	// FIX: This is the problem - GLOB.portal_destinations is an associative list, not a flat list
	var/list/destinations = list()
	if(linked_portal)
		// CORRECTED: Iterate through the associative list properly
		for(var/destination_key in GLOB.portal_destinations)
			var/datum/portal_destination/possible_destination = GLOB.portal_destinations[destination_key]
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

	var/mob/user = usr

	switch(action)
		if("linkup")
			log_portal_control("Portal Control: [key_name(user)] attempted linkup at [AREACOORD(src)]")
			try_to_linkup()
			if(linked_portal)
				log_portal_control("Portal Control: Successfully linked to portal at [AREACOORD(linked_portal)]")
			else
				log_portal_control("Portal Control: Linkup failed - no portal found")
			. = TRUE
		if("activate")
			var/datum/portal_destination/D = locate(params["destination"]) in GLOB.portal_destinations
			if(D)
				log_portal_control("Portal Control: [key_name(user)] activating portal to [D.name] at [AREACOORD(src)]")
				try_to_connect(D)
			else
				log_portal_control("Portal Control: [key_name(user)] attempted to activate invalid destination")
			. = TRUE
		if("deactivate")
			if(linked_portal?.target)
				log_portal_control("Portal Control: [key_name(user)] deactivating portal from [linked_portal.target.name] at [AREACOORD(src)]")
				linked_portal.deactivate()
			else
				log_portal_control("Portal Control: [key_name(user)] attempted to deactivate inactive portal")
			. = TRUE
		if("generate_new")
			if(linked_portal?.destination)
				var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
				log_portal_control("Portal Control: [key_name(user)] initiating new dungeon generation at [AREACOORD(src)]")
				veil_dest.start_generation()
				linked_portal.say("Initiating new dungeon generation...")
			else
				log_portal_control("Portal Control: [key_name(user)] attempted generation without valid portal destination")
			. = TRUE

/obj/machinery/computer/portal_control/proc/try_to_linkup()
	linked_portal = locate(/obj/machinery/portal) in view(7, get_turf(src))

/obj/machinery/computer/portal_control/proc/try_to_connect(datum/portal_destination/D)
	if(!D || !linked_portal)
		log_portal_control("Portal Control: Connection failed - no destination or linked portal")
		return
	if(!D.is_available())
		log_portal_control("Portal Control: Connection failed - destination [D.name] not available: [D.get_available_reason()]")
		return
	if(linked_portal.target)
		log_portal_control("Portal Control: Connection failed - portal already active to [linked_portal.target.name]")
		return

	log_portal_control("Portal Control: Successfully connecting to [D.name]")
	linked_portal.activate(D)


// Add to portal_control.dm for debugging
/obj/machinery/computer/portal_control/verb/debug_portal_info()
	set name = "Debug Portal Info"
	set category = "Debug"
	set src in view(1)

	usr << "=== PORTAL DEBUG INFO ==="
	usr << "Linked Portal: [linked_portal ? AREACOORD(linked_portal) : "NONE"]"
	usr << "Portal Powered: [linked_portal ? linked_portal.powered() : "N/A"]"
	usr << "Portal Possible: [linked_portal ? linked_portal.portal_possible : "N/A"]"
	usr << "Transport Active: [linked_portal ? linked_portal.transport_active : "N/A"]"
	usr << "Current Target: [linked_portal?.target ? linked_portal.target.name : "NONE"]"

	usr << "=== GLOBAL DESTINATIONS ==="
	var/count = 0
	for(var/key in GLOB.portal_destinations)
		var/datum/portal_destination/D = GLOB.portal_destinations[key]
		usr << "[key]: [D.name] - Available: [D.is_available()] - Reason: [D.get_available_reason()]"
		count++
	usr << "Total Destinations: [count]"

// Add to portal_globals.dm for destination debugging
/datum/portal_destination/veilbreak/verb/debug_dungeon_info()
	set name = "Debug Dungeon Info"
	set category = "Debug"
	set src in view(1)

	usr << "=== DUNGEON DESTINATION DEBUG ==="
	usr << "Name: [name]"
	usr << "Generating: [generating]"
	usr << "Generated: [generated]"
	usr << "Z-Level: [dungeon_z_level]"
	usr << "Connected Portal: [connected_portal ? AREACOORD(connected_portal) : "NONE"]"
	usr << "Last Data: [last_generation_data ? "Present" : "None"]"
