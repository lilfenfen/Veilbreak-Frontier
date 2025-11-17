// modular_zzveilbreak/code/modules/dungeons/portal_machinery_core.dm

/obj/effect/portal_bumper
	name = "portal energy field"
	desc = "A shimmering energy field that transports matter between dimensions."
	density = TRUE
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	var/obj/machinery/portal/parent_portal

/obj/effect/portal_bumper/Initialize(mapload, obj/machinery/portal/parent)
	. = ..()
	if(!parent)
		return INITIALIZE_HINT_QDEL
	parent_portal = parent

/obj/effect/portal_bumper/Destroy()
	parent_portal = null
	return ..()

/obj/effect/portal_bumper/Bumped(atom/movable/arriving_object)
	if(!parent_portal?.can_transfer(arriving_object))
		return

	if(get_dir(src, arriving_object) == parent_portal.dir)
		playsound(src, 'sound/machines/gateway/gateway_travel.ogg', 70, TRUE, PORTAL_TRAVEL_SOUND_RANGE)
		parent_portal.transfer(arriving_object)

/obj/machinery/portal
	name = "dimensional portal"
	desc = "A shimmering portal to unknown realms. This one seems to lead to dynamically generated Veilbreak dungeons."
	icon = 'icons/obj/machines/gateway.dmi'
	icon_state = "portal_frame"

	pixel_x = -32
	pixel_y = -32
	bound_height = 64
	bound_width = 96
	bound_x = -32
	bound_y = 0
	density = TRUE

	use_power = IDLE_POWER_USE
	active_power_usage = PORTAL_ACTIVE_POWER_USAGE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION

	circuit = /obj/item/circuitboard/machine/portal
	panel_open = FALSE

	resistance_flags = LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	var/datum/portal_destination/veilbreak/destination
	var/datum/portal_destination/target
	var/obj/effect/portal_bumper/bumper
	var/portal_possible = FALSE
	var/transport_active = FALSE
	var/list/generated_dungeon_data
	var/cleanup_in_progress = FALSE

/obj/machinery/portal/Initialize(mapload)
	. = ..()

	// Wait for subsystems to be ready before initializing
	if(!subsystems_ready_for_portals())
		addtimer(CALLBACK(src, .proc/delayed_initialize), 5 SECONDS)
	else
		delayed_initialize()

/obj/machinery/portal/proc/delayed_initialize()
	destination = new /datum/portal_destination/veilbreak()
	destination.connected_portal = src

	var/destination_id = "veilbreak_station_[world.time]_[rand(1000,9999)]"
	GLOB.portal_destinations[destination_id] = destination

	update_appearance()

/obj/machinery/portal/Destroy()
	if(target && transport_active)
		initiate_emergency_cleanup()

	if(destination)
		for(var/key in GLOB.portal_destinations)
			if(GLOB.portal_destinations[key] == destination)
				GLOB.portal_destinations -= key
				break
		QDEL_NULL(destination)

	if(target)
		deactivate()

	QDEL_NULL(bumper)

	return ..()

/obj/machinery/portal/proc/initiate_emergency_cleanup()
	if(cleanup_in_progress)
		return

	cleanup_in_progress = TRUE

	var/list/ejection_turfs = get_ejection_turfs()

	if(destination?.dungeon_z_level)
		for(var/turf/ejection_turf in ejection_turfs)
			destination.cleanup_z_level_completely(destination.dungeon_z_level, ejection_turf)
			break

	if(target && istype(target, /datum/portal_destination/veilbreak))
		var/datum/portal_destination/veilbreak/veil_dest = target
		if(veil_dest.dungeon_z_level)
			for(var/turf/ejection_turf in ejection_turfs)
				veil_dest.cleanup_z_level_completely(veil_dest.dungeon_z_level, ejection_turf)
				break

/obj/machinery/portal/proc/get_ejection_turfs()
	var/list/turfs = list()
	var/turf/primary_turf = get_step(src, SOUTH)

	if(primary_turf)
		turfs += primary_turf
		for(var/dir in list(EAST, WEST, SOUTHEAST, SOUTHWEST))
			var/turf/adjacent = get_step(primary_turf, dir)
			if(adjacent)
				turfs += adjacent

	if(!length(turfs))
		turfs += get_turf(src)

	return turfs

/obj/machinery/portal/proc/is_dungeon_portal()
	return z && (SSmapping.level_trait(z, ZTRAIT_AWAY) || SSmapping.level_trait(z, ZTRAIT_MINING))

/obj/machinery/portal/update_overlays()
	. = ..()

	if(portal_possible)
		. += "portal_light"

	if(transport_active)
		. += "portal_effect"

/obj/machinery/portal/proc/generate_bumper()
	if(bumper)
		QDEL_NULL(bumper)

	bumper = new(get_turf(src), src)

/obj/machinery/portal/on_construction()
	. = ..()

/obj/machinery/portal/on_deconstruction()
	. = ..()
	if(target)
		deactivate()

/obj/machinery/portal/default_deconstruction_crowbar(obj/item/crowbar)
	if(!panel_open)
		return FALSE
	return ..()

/obj/machinery/portal/RefreshParts()
	. = ..()

/obj/machinery/portal/screwdriver_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_screwdriver(user, "portal_frame_open", "portal_frame", tool))
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/portal/crowbar_act(mob/living/user, obj/item/tool)
	if(panel_open)
		return default_deconstruction_crowbar(tool) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	return ITEM_INTERACT_BLOCKING

/obj/machinery/portal/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	if(default_unfasten_wrench(user, tool))
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/portal/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()

	if(isnull(held_item))
		context[SCREENTIP_CONTEXT_LMB] = panel_open ? "Interact with components" : "Open UI"
		return CONTEXTUAL_SCREENTIP_SET

	if(held_item.tool_behaviour == TOOL_WRENCH)
		context[SCREENTIP_CONTEXT_LMB] = "[anchored ? "Una" : "A"]nchor"
		return CONTEXTUAL_SCREENTIP_SET
	if(held_item.tool_behaviour == TOOL_SCREWDRIVER)
		context[SCREENTIP_CONTEXT_LMB] = "[panel_open ? "Close" : "Open"] panel"
		return CONTEXTUAL_SCREENTIP_SET
	if(held_item.tool_behaviour == TOOL_CROWBAR && panel_open)
		context[SCREENTIP_CONTEXT_LMB] = "Deconstruct"
		return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/portal/examine(mob/user)
	. = ..()
	if(panel_open)
		. += span_notice("The maintenance panel is open.")

/obj/machinery/portal/power_change()
	. = ..()

	// NEW: Handle power loss while portal is active
	if(machine_stat & NOPOWER)
		if(target && transport_active && !cleanup_in_progress)
			handle_power_failure_cleanup()

/obj/item/circuitboard/machine/portal
	name = "Dimensional Portal"
	desc = "A circuit board for a dimensional portal."
	build_path = /obj/machinery/portal
	req_components = list(
		/obj/item/stack/ore/bluespace_crystal = 1,
		/obj/item/stock_parts/servo = 1,
		/obj/item/stack/cable_coil = 5
	)
	needs_anchored = TRUE
