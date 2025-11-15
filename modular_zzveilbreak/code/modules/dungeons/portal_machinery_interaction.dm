// modular_zzveilbreak/code/modules/dungeons/portal_machinery_interaction.dm

/obj/machinery/portal/proc/activate(datum/portal_destination/new_target)
	if(!can_activate(new_target))
		return FALSE

	target = new_target
	transport_active = TRUE

	if(istype(new_target, /datum/portal_destination/veilbreak))
		handle_veilbreak_activation(new_target)
		return TRUE

	complete_activation(new_target)
	return TRUE

/obj/machinery/portal/proc/can_activate(datum/portal_destination/new_target)
	if(target)
		return FALSE

	if(!is_dungeon_portal() && !powered())
		return FALSE

	return TRUE

/obj/machinery/portal/proc/handle_veilbreak_activation(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest.generated && !veil_dest.generating)
		say("Initializing portal to [veil_dest.name]...")
		veil_dest.start_generation()
		reset_activation_state()
		return

	if(veil_dest.generating)
		say("Portal to [veil_dest.name] still stabilizing...")
		reset_activation_state()
		return

	generated_dungeon_data = veil_dest.last_generation_data
	complete_activation(veil_dest)

/obj/machinery/portal/proc/reset_activation_state()
	transport_active = FALSE
	target = null

/obj/machinery/portal/proc/complete_activation(datum/portal_destination/dest)
	playsound(src, 'sound/machines/gateway/gateway_open.ogg', 140, TRUE, TRUE, PORTAL_SOUND_RANGE)
	generate_bumper()

	if(!is_dungeon_portal())
		update_use_power(ACTIVE_POWER_USE)

	update_appearance()

	// Enhanced notification to ensure name is updated immediately
	if(!is_dungeon_portal() && dest && istype(dest, /datum/portal_destination/veilbreak))
		var/datum/portal_destination/veilbreak/veil_dest = dest
		if(veil_dest.connected_control_computer && !QDELETED(veil_dest.connected_control_computer))
			veil_dest.connected_control_computer.on_portal_activated(veil_dest)
			// Force immediate UI update with the correct name
			veil_dest.connected_control_computer.force_ui_update()

	if(!QDELETED(dest))
		dest.activate(src)

/obj/machinery/portal/proc/deactivate()
	if(!target || transport_active == FALSE)
		return

	var/datum/portal_destination/old_target = target

	target = null
	transport_active = FALSE

	playsound(src, 'sound/machines/gateway/gateway_close.ogg', 140, TRUE, TRUE, PORTAL_SOUND_RANGE)

	if(!QDELETED(old_target))
		old_target.deactivate(src)

	QDEL_NULL(bumper)

	if(!is_dungeon_portal())
		update_use_power(IDLE_POWER_USE)

	update_appearance()

/obj/machinery/portal/proc/can_transfer(atom/movable/transferring_object)
	if(!target)
		return FALSE

	if(!target.incoming_pass_check(transferring_object))
		return FALSE

	var/turf/target_turf = target.get_target_turf()
	if(!target_turf)
		say("Portal destination unstable. Transfer aborted.")
		return FALSE

	return TRUE

/obj/machinery/portal/proc/transfer(atom/movable/transferring_object)
	var/turf/target_turf = target.get_target_turf()

	transferring_object.forceMove(target_turf)

	if(!QDELETED(target))
		target.post_transfer(transferring_object)

	provide_dungeon_feedback(transferring_object)

/obj/machinery/portal/proc/provide_dungeon_feedback(atom/movable/transferred_object)
	if(!istype(target, /datum/portal_destination/veilbreak) || !generated_dungeon_data)
		return

	var/dungeon_name = generated_dungeon_data["map_name"] || "Quantum Pocket Space"
	var/width = generated_dungeon_data["dimensions"]?["width"] || "?"
	var/height = generated_dungeon_data["dimensions"]?["height"] || "?"
	var/rooms = generated_dungeon_data["statistics"]?["rooms"] || "?"
	var/mobs = generated_dungeon_data["statistics"]?["mobs"] || "?"

	to_chat(transferred_object, span_notice("You enter the [dungeon_name]."))
	to_chat(transferred_object, span_info("Size: [width]x[height] | Rooms: [rooms] | Threats: [mobs]"))

/obj/machinery/portal/attack_ghost(mob/user)
	. = ..()
	if(.)
		return

	var/turf/target_turf = target?.get_target_turf()
	if(!target_turf)
		to_chat(user, span_warning("The portal destination is not yet stable..."))
		return

	transfer(user)
