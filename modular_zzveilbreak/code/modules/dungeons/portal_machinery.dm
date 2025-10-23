// modular_zzveilbreak/code/modules/dungeons/portal_machinery.dm

/obj/machinery/portal
	name = "dimensional portal"
	desc = "A shimmering portal to unknown realms. This one seems to lead to dynamically generated Veilbreak dungeons."
	icon = 'icons/obj/machines/gateway.dmi'
	icon_state = "portal_frame"
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	pixel_x = -32
	pixel_y = -32
	bound_height = 64
	bound_width = 96
	bound_x = -32
	bound_y = 0
	density = TRUE

	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 8

	var/calibrated = TRUE
	var/datum/portal_destination/veilbreak/destination
	var/datum/portal_destination/target
	var/obj/effect/portal_bumper/portal
	var/portal_possible = FALSE
	var/transport_active = FALSE
	var/list/generated_dungeon_data = null

// Helper proc for portal machinery logging
/proc/log_portal_machinery(text)
	log_game(text, list(), LOG_GAME)

/obj/machinery/portal/Initialize(mapload)
	. = ..()
	destination = new /datum/portal_destination/veilbreak()
	destination.connected_portal = src
	GLOB.portal_destinations += destination
	log_portal_machinery("Portal Machinery: Initialized new portal at [AREACOORD(src)] with destination [destination.name]")
	update_appearance()

/obj/machinery/portal/Destroy()
	log_portal_machinery("Portal Machinery: Destroying portal at [AREACOORD(src)]")
	if(destination)
		GLOB.portal_destinations -= destination
		QDEL_NULL(destination)
	if(target)
		deactivate()
	return ..()

/obj/machinery/portal/process()
	if((machine_stat & (NOPOWER)) && use_power)
		if(portal_possible)
			log_portal_machinery("Portal Machinery: Portal lost power at [AREACOORD(src)]")
		portal_possible = FALSE
		if(target)
			deactivate()
		return

	// Update portal possibility based on destination generation status
	var/was_possible = portal_possible
	portal_possible = FALSE

	for(var/datum/portal_destination/possible_destination in GLOB.portal_destinations)
		if(!valid_destination(possible_destination) || !possible_destination.is_available())
			continue
		portal_possible = TRUE
		break

	if(was_possible != portal_possible)
		log_portal_machinery("Portal Machinery: Portal possibility changed to [portal_possible] at [AREACOORD(src)]")
		update_appearance()

/obj/machinery/portal/proc/valid_destination(datum/portal_destination/possible_destination)
	if(possible_destination == destination)
		return FALSE
	return TRUE

/obj/machinery/portal/update_overlays()
	. = ..()
	if(portal_possible)
		. += "portal_light"
	if(transport_active)
		. += "portal_effect"

/obj/machinery/portal/proc/generate_bumper()
	portal = new(get_turf(src))
	portal.parent_portal = src
	log_portal_machinery("Portal Machinery: Generated portal bumper at [AREACOORD(portal)]")

/obj/machinery/portal/proc/activate(datum/portal_destination/D)
	if(!powered())
		log_portal_machinery("Portal Machinery: Activation failed - no power at [AREACOORD(src)]")
		return
	if(target)
		log_portal_machinery("Portal Machinery: Activation failed - already active to [target.name] at [AREACOORD(src)]")
		return

	target = D
	transport_active = TRUE

	if(istype(D, /datum/portal_destination/veilbreak))
		var/datum/portal_destination/veilbreak/veil_dest = D
		if(!veil_dest.generated && !veil_dest.generating)
			log_portal_machinery("Portal Machinery: Starting dungeon generation for [veil_dest.name] at [AREACOORD(src)]")
			veil_dest.start_generation()
			say("Initializing portal to [veil_dest.name]...")
			// Don't fully activate until generation is complete
			transport_active = FALSE
			target = null
			return
		else if(veil_dest.generating)
			log_portal_machinery("Portal Machinery: Activation delayed - [veil_dest.name] still generating at [AREACOORD(src)]")
			say("Portal to [veil_dest.name] still stabilizing...")
			transport_active = FALSE
			target = null
			return
		else if(veil_dest.generated)
			log_portal_machinery("Portal Machinery: Successfully activated portal to generated dungeon [veil_dest.name] at Z-level [veil_dest.dungeon_z_level]")
			generated_dungeon_data = veil_dest.last_generation_data

	// Only play sounds and create bumper if we're actually activating
	playsound(src, 'sound/machines/gateway/gateway_open.ogg', 140, TRUE, TRUE, SOUND_RANGE)
	generate_bumper()
	update_use_power(ACTIVE_POWER_USE)
	update_appearance()
	D.activate(src)

/obj/machinery/portal/proc/deactivate()
	if(!target)
		log_portal_machinery("Portal Machinery: Deactivation attempted but no target set at [AREACOORD(src)]")
		return

	var/datum/portal_destination/dest = target
	log_portal_machinery("Portal Machinery: Deactivating portal from [dest.name] at [AREACOORD(src)]")
	target = null
	transport_active = FALSE

	playsound(src, 'sound/machines/gateway/gateway_close.ogg', 140, TRUE, TRUE, SOUND_RANGE)
	dest.deactivate(src)
	QDEL_NULL(portal)
	update_use_power(IDLE_POWER_USE)
	update_appearance()

/obj/machinery/portal/proc/Transfer(atom/movable/AM)
	if(!target)
		log_portal_machinery("Portal Machinery: Transfer failed - no target destination at [AREACOORD(src)]")
		return
	if(!target.incoming_pass_check(AM))
		log_portal_machinery("Portal Machinery: Transfer failed - [AM] failed pass check at [AREACOORD(src)]")
		return

	var/turf/target_turf = target.get_target_turf()
	if(!target_turf)
		log_portal_machinery("Portal Machinery: Transfer failed - invalid target turf for [target.name]")
		say("Portal destination unstable. Transfer aborted.")
		return

	log_portal_machinery("Portal Machinery: Transferring [AM] from [AREACOORD(AM)] to [AREACOORD(target_turf)] via [target.name]")
	AM.forceMove(target_turf)
	target.post_transfer(AM)

	// Announce dungeon info if available
	if(istype(target, /datum/portal_destination/veilbreak) && generated_dungeon_data)
		var/dungeon_name = generated_dungeon_data["map_name"] || "Unknown Dungeon"
		to_chat(AM, span_notice("You enter the [dungeon_name]."))
		to_chat(AM, span_info("Size: [generated_dungeon_data["dimensions"]["width"]]x[generated_dungeon_data["dimensions"]["height"]] | Rooms: [generated_dungeon_data["statistics"]["rooms"]] | Threats: [generated_dungeon_data["statistics"]["mobs"]]"))

/obj/machinery/portal/attack_ghost(mob/user)
	. = ..()
	if(.)
		return

	var/turf/tar_turf = target?.get_target_turf()
	if(isnull(tar_turf))
		to_chat(user, span_warning("The portal destination is not yet stable..."))
		return

	log_portal_machinery("Portal Machinery: Ghost [key_name(user)] transferring through portal at [AREACOORD(src)]")
	Transfer(user)

/obj/machinery/portal/multitool_act(mob/living/user, obj/item/I)
	if(calibrated)
		to_chat(user, span_alert("The portal is already calibrated, there is no work for you to do here."))
	else
		log_portal_machinery("Portal Machinery: [key_name(user)] calibrated portal at [AREACOORD(src)]")
		to_chat(user, span_boldnotice("Recalibration successful!") + " Portal systems have been fine tuned.")
		calibrated = TRUE
	return TRUE

// Portal bumper for collision detection
/obj/effect/portal_bumper
	var/obj/machinery/portal/parent_portal
	density = TRUE
	invisibility = INVISIBILITY_ABSTRACT

/obj/effect/portal_bumper/Bumped(atom/movable/AM)
	if(get_dir(src, AM) == parent_portal?.dir)
		log_portal_machinery("Portal Machinery: Bumper at [AREACOORD(src)] triggered by [AM]")
		playsound(src, 'sound/machines/gateway/gateway_travel.ogg', 70, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		parent_portal.Transfer(AM)

/obj/effect/portal_bumper/Destroy(force)
	. = ..()
	parent_portal = null
