// modular_zzveilbreak/code/modules/dungeons/portal_control_ui.dm

/obj/machinery/computer/portal_control/ui_data(mob/user)
	var/list/data = list()

	// Basic portal info with safety checks
	data["portal_present"] = !!linked_portal && !QDELETED(linked_portal)
	data["portal_status"] = data["portal_present"] ? linked_portal.powered() : FALSE
	data["portal_active"] = data["portal_present"] ? (linked_portal.transport_active ? TRUE : FALSE) : FALSE

	// Current target with safety checks
	if(data["portal_present"] && linked_portal.target && !QDELETED(linked_portal.target))
		data["current_target"] = list("name" = linked_portal.target.name)
	else
		data["current_target"] = null

	// Generation and cleanup status with safety checks
	data["generation_status"] = "idle"
	data["generation_progress"] = 0
	data["generation_in_progress"] = generation_in_progress
	data["cleanup_in_progress"] = cleanup_in_progress

	if(data["portal_present"] && linked_portal.destination && !QDELETED(linked_portal.destination))
		var/datum/portal_destination/veilbreak/veil_dest = linked_portal.destination
		// Ensure consistent state
		if(veil_dest.generating && !generation_in_progress)
			generation_in_progress = TRUE
			start_generation_monitoring()

		data["generation_status"] = veil_dest.generating ? "generating" : (veil_dest.generated ? "ready" : "idle")
		data["generation_progress"] = veil_dest.generation_progress

	// Can generate check - only when portal is not active, not generating, and not cleaning up
	data["can_generate"] = !generation_in_progress && !cleanup_in_progress && data["portal_present"] && linked_portal.destination && !data["portal_active"] && data["portal_status"]

	// Portal name - show when portal is active or has been generated
	data["portal_name"] = data["portal_active"] || (linked_portal?.destination?.generated) ? cached_portal_name : null

	return data
