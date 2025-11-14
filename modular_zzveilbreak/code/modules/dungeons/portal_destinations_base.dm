// modular_zzveilbreak/code/modules/dungeons/portal_destinations_base.dm

/datum/portal_destination
	var/name = "Unknown Destination"
	var/wait = 0
	var/enabled = TRUE
	var/hidden = FALSE
	var/obj/machinery/portal/connected_portal

/datum/portal_destination/proc/is_available()
	return enabled && (world.time - SSticker.round_start_time >= wait)

/datum/portal_destination/proc/get_available_reason()
	. = "Unreachable"
	if(world.time - SSticker.round_start_time < wait)
		. = "Connection desynchronized. Recalibration in progress."

/datum/portal_destination/proc/incoming_pass_check(atom/movable/AM)
	return TRUE

/datum/portal_destination/proc/get_target_turf()
	CRASH("get_target_turf not implemented for this destination type")

/datum/portal_destination/proc/post_transfer(atom/movable/AM)
	if(ismob(AM))
		var/mob/M = AM
		if(M.client)
			M.client.move_delay = max(world.time + 5, M.client.move_delay)

/datum/portal_destination/proc/activate(obj/machinery/portal/activated)
	return

/datum/portal_destination/proc/deactivate(obj/machinery/portal/deactivated)
	return

/datum/portal_destination/proc/get_ui_data()
	. = list()
	.["name"] = name
	.["description"] = "Dimensional portal destination"
	.["key"] = get_global_key()
	.["available"] = is_available()
	.["available_reason"] = get_available_reason()
	if(wait)
		.["timeout"] = max(1 - (wait - (world.time - SSticker.round_start_time)) / wait, 0)
	else
		.["timeout"] = 0
	.["connected"] = !!connected_portal

/datum/portal_destination/proc/get_global_key()
	for(var/key in GLOB.portal_destinations)
		if(GLOB.portal_destinations[key] == src)
			return key
	return null

/datum/portal_destination/simple
	name = "Simple Destination"
	var/obj/machinery/portal/return_portal

/datum/portal_destination/simple/get_target_turf()
	if(return_portal)
		return get_turf(return_portal)
	return null

/datum/portal_destination/simple/is_available()
	return return_portal && !QDELETED(return_portal)

/datum/portal_destination/simple/get_available_reason()
	if(!return_portal || QDELETED(return_portal))
		return "Return portal not available"
	return "Available for return"
