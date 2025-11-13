// modular_zzveilbreak/code/modules/dungeons/portal_machinery_interaction.dm

/// Activate the portal to a specific destination
/obj/machinery/portal/proc/activate(datum/portal_destination/new_target)
	if(!can_activate(new_target))
		return FALSE

	target = new_target
	transport_active = TRUE

	// Handle Veilbreak-specific activation logic
	if(istype(new_target, /datum/portal_destination/veilbreak))
		handle_veilbreak_activation(new_target)
		return TRUE

	// Standard activation
	complete_activation(new_target)
	return TRUE

/// Check if the portal can be activated
/obj/machinery/portal/proc/can_activate(datum/portal_destination/new_target)
	if(target)
		log_portal("Activate: Failed - already active to [target.name] at [AREACOORD(src)]")
		return FALSE

	if(!is_dungeon_portal() && !powered())
		log_portal("Activate: Failed - no power at [AREACOORD(src)]")
		return FALSE

	return TRUE

/// Handle Veilbreak dungeon-specific activation logic
/obj/machinery/portal/proc/handle_veilbreak_activation(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest.generated && !veil_dest.generating)
		log_portal("Activate: Starting dungeon generation for [veil_dest.name] at [AREACOORD(src)]")
		say("Initializing portal to [veil_dest.name]...")
		veil_dest.start_generation()
		reset_activation_state()
		return

	if(veil_dest.generating)
		log_portal("Activate: Delayed - [veil_dest.name] still generating at [AREACOORD(src)]")
		say("Portal to [veil_dest.name] still stabilizing...")
		reset_activation_state()
		return

	// Generation complete - proceed with activation
	log_portal("Activate: Successfully activated to generated dungeon [veil_dest.name] at Z-level [veil_dest.dungeon_z_level]")
	generated_dungeon_data = veil_dest.last_generation_data
	complete_activation(veil_dest)

/// Reset activation state after failed or delayed activation
/obj/machinery/portal/proc/reset_activation_state()
	log_portal("Activate: Resetting activation state at [AREACOORD(src)]")
	transport_active = FALSE
	target = null

/// Complete the portal activation process
/obj/machinery/portal/proc/complete_activation(datum/portal_destination/dest)
	playsound(src, 'sound/machines/gateway/gateway_open.ogg', 140, TRUE, TRUE, PORTAL_SOUND_RANGE)
	generate_bumper()

	if(!is_dungeon_portal())
		update_use_power(ACTIVE_POWER_USE)

	update_appearance()

	if(!QDELETED(dest))
		dest.activate(src)

	log_portal("Activate: Activated to [dest.name] at [AREACOORD(src)]")

/// Deactivate the portal - enhanced to handle cleanup properly
/obj/machinery/portal/proc/deactivate()
	if(!target || transport_active == FALSE)
		log_portal("Deactivate: No active target at [AREACOORD(src)]")
		return

	// Store reference before clearing
	var/datum/portal_destination/old_target = target
	log_portal("Deactivate: Deactivating portal from [old_target.name] at [AREACOORD(src)]")

	// Clear references first to prevent circular calls
	target = null
	transport_active = FALSE
	generated_dungeon_data = null  // Clear dungeon data

	// Safe sound play
	playsound(src, 'sound/machines/gateway/gateway_close.ogg', 140, TRUE, TRUE, PORTAL_SOUND_RANGE)

	// Safe callback to old target
	if(!QDELETED(old_target))
		old_target.deactivate(src)

	// Safe bumper cleanup
	QDEL_NULL(bumper)

	if(!is_dungeon_portal())
		update_use_power(IDLE_POWER_USE)

	update_appearance()
	log_portal("Deactivate: Successfully deactivated portal at [AREACOORD(src)]")

/// Check if an object can be transferred through the portal
/obj/machinery/portal/proc/can_transfer(atom/movable/transferring_object)
	if(!target)
		log_portal("Transfer: Failed - no target destination at [AREACOORD(src)]")
		return FALSE

	if(!target.incoming_pass_check(transferring_object))
		log_portal("Transfer: Failed - [transferring_object] failed pass check at [AREACOORD(src)]")
		return FALSE

	var/turf/target_turf = target.get_target_turf()
	if(!target_turf)
		log_portal("Transfer: Failed - invalid target turf for [target.name]")
		say("Portal destination unstable. Transfer aborted.")
		return FALSE

	return TRUE

/// Transfer an object through the portal
/obj/machinery/portal/proc/transfer(atom/movable/transferring_object)
	var/turf/target_turf = target.get_target_turf()

	log_portal("Transfer: Transferring [transferring_object] from [AREACOORD(transferring_object)] to [AREACOORD(target_turf)] via [target.name]")

	transferring_object.forceMove(target_turf)

	if(!QDELETED(target))
		target.post_transfer(transferring_object)

	provide_dungeon_feedback(transferring_object)

/// Provide feedback about the dungeon to transferred objects
/obj/machinery/portal/proc/provide_dungeon_feedback(atom/movable/transferred_object)
	if(!istype(target, /datum/portal_destination/veilbreak) || !generated_dungeon_data)
		return

	var/dungeon_name = generated_dungeon_data["map_name"] || "Unknown Dungeon"
	var/width = generated_dungeon_data["dimensions"]?["width"] || "?"
	var/height = generated_dungeon_data["dimensions"]?["height"] || "?"
	var/rooms = generated_dungeon_data["statistics"]?["rooms"] || "?"
	var/mobs = generated_dungeon_data["statistics"]?["mobs"] || "?"

	to_chat(transferred_object, span_notice("You enter the [dungeon_name]."))
	to_chat(transferred_object, span_info("Size: [width]x[height] | Rooms: [rooms] | Threats: [mobs]"))

// ===== USER INTERACTION =====
/obj/machinery/portal/attack_ghost(mob/user)
	. = ..()
	if(.)
		return

	var/turf/target_turf = target?.get_target_turf()
	if(!target_turf)
		to_chat(user, span_warning("The portal destination is not yet stable..."))
		return

	log_portal("Ghost: [key_name(user)] transferring through portal at [AREACOORD(src)]")
	transfer(user)
