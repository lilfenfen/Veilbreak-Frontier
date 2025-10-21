/obj/machinery/portal
	name = "dimensional portal"
	desc = "A shimmering portal to unknown realms. This one seems to lead to dynamically generated Veilbreak dungeons."
	icon = 'icons/obj/machines/portal.dmi'
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
	var/atom/movable/screen/map_view/portal_view/portal_visuals
	var/portal_possible = FALSE
	var/transport_active = FALSE
	var/list/generated_dungeon_data = null

/obj/machinery/portal/Initialize(mapload)
	. = ..()
	destination = new()
	destination.connected_portal = src
	GLOB.portal_destinations += destination
	portal_visuals = new
	portal_visuals.generate_view("portal_popup_[REF(src)]")
	update_appearance()

/obj/machinery/portal/Destroy()
	QDEL_NULL(portal_visuals)
	if(destination)
		GLOB.portal_destinations -= destination
		QDEL_NULL(destination)
	return ..()

/obj/machinery/portal/process()
	if((machine_stat & (NOPOWER)) && use_power)
		portal_possible = FALSE
		if(target)
			deactivate()
		return

	if(portal_possible)
		return

	// Check if we can connect to any destinations
	for(var/datum/portal_destination/possible_destination in GLOB.portal_destinations)
		if(!valid_destination(possible_destination) || !possible_destination.is_available())
			continue
		portal_possible = TRUE
		update_appearance()
		break

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

/obj/machinery/portal/proc/activate(datum/portal_destination/D)
	if(!powered() || target)
		return

	target = D
	transport_active = TRUE

	if(istype(D, /datum/portal_destination/veilbreak))
		var/datum/portal_destination/veilbreak/veil_dest = D
		if(!veil_dest.generated && !veil_dest.generating)
			veil_dest.start_generation()
			say("Initializing portal to [veil_dest.name]...")
		else if(veil_dest.generating)
			say("Portal to [veil_dest.name] still stabilizing...")
			return

	playsound(src, 'sound/machines/portal/portal_open.ogg', 140, TRUE, TRUE, SOUND_RANGE)
	generate_bumper()
	update_use_power(ACTIVE_POWER_USE)
	update_appearance()

/obj/machinery/portal/proc/deactivate()
	var/datum/portal_destination/dest = target
	target = null
	playsound(src, 'sound/machines/portal/portal_close.ogg', 140, TRUE, TRUE, SOUND_RANGE)
	dest.deactivate(src)
	QDEL_NULL(portal)
	update_use_power(IDLE_POWER_USE)
	transport_active = FALSE
	update_appearance()

/obj/machinery/portal/proc/Transfer(atom/movable/AM)
	if(!target || !target.incoming_pass_check(AM))
		return

	var/turf/target_turf = target.get_target_turf()
	if(!target_turf)
		say("Portal destination unstable. Transfer aborted.")
		return

	AM.forceMove(target_turf)
	target.post_transfer(AM)

	// Announce dungeon info if available
	if(istype(target, /datum/portal_destination/veilbreak) && generated_dungeon_data)
		var/datum/portal_destination/veilbreak/veil_dest = target
		var/dungeon_name = generated_dungeon_data["map_name"] || "Unknown Dungeon"
		to_chat(AM, span_notice("You enter [dungeon_name]."))

/obj/machinery/portal/attack_ghost(mob/user)
	. = ..()
	if(.)
		return

	var/turf/tar_turf = target?.get_target_turf()
	if(isnull(tar_turf))
		to_chat(user, span_warning("The portal destination is not yet stable..."))
		return

	Transfer(user)

// Portal bumper for collision detection
/obj/effect/portal_bumper
	var/obj/machinery/portal/parent_portal
	density = TRUE
	invisibility = INVISIBILITY_ABSTRACT

/obj/effect/portal_bumper/Bumped(atom/movable/AM)
	if(get_dir(src, AM) == parent_portal?.dir)
		playsound(src, 'sound/machines/portal/portal_travel.ogg', 70, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
		parent_portal.Transfer(AM)

/obj/effect/portal_bumper/Destroy(force)
	. = ..()
	parent_portal = null
