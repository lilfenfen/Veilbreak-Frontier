// modular_zzveilbreak/code/modules/dungeons/portal_control_ui.dm

/obj/machinery/computer/portal_control/ui_data(mob/user)
	var/list/data = list()

	// Basic portal info
	data["portal_present"] = !!linked_portal
	data["portal_status"] = linked_portal ? linked_portal.powered() : FALSE
	data["portal_active"] = linked_portal?.transport_active ? TRUE : FALSE

	// Current target
	if(linked_portal?.target)
		data["current_target"] = list("name" = linked_portal.target.name)
	else
		data["current_target"] = null

	// Generation status
	data["generation_status"] = "idle"
	data["generation_progress"] = 0
	data["generation_in_progress"] = generation_in_progress

	if(linked_portal?.destination)
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		data["generation_status"] = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		data["generation_progress"] = veil_dest.generation_progress

	// Can generate check
	data["can_generate"] = !generation_in_progress && linked_portal?.destination && !linked_portal.transport_active

	// Portal name
	data["portal_name"] = cached_portal_name

	return data
