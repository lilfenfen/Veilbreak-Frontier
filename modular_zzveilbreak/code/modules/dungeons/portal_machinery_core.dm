// modular_zzveilbreak/code/modules/dungeons/portal_machinery_core.dm

// ===== PORTAL BUMPER =====
/// Invisible collision object that handles portal transfers
/obj/effect/portal_bumper
	name = "portal energy field"
	desc = "A shimmering energy field that transports matter between dimensions."
	density = TRUE
	invisibility = INVISIBILITY_ABSTRACT
	anchored = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	/// Reference to the parent portal machinery
	var/obj/machinery/portal/parent_portal

/obj/effect/portal_bumper/Initialize(mapload, obj/machinery/portal/parent)
	. = ..()
	if(!parent)
		log_portal("Bumper: Initialize failed - no parent")
		return INITIALIZE_HINT_QDEL
	parent_portal = parent
	log_portal("Bumper: Created at [AREACOORD(src)] for portal [AREACOORD(parent)]")

/obj/effect/portal_bumper/Destroy()
	log_portal("Bumper: Destroying at [AREACOORD(src)]")
	parent_portal = null
	return ..()

/obj/effect/portal_bumper/Bumped(atom/movable/arriving_object)
	if(!parent_portal?.can_transfer(arriving_object))
		return

	if(get_dir(src, arriving_object) == parent_portal.dir)
		log_portal("Bumper: Transfer initiated for [arriving_object] at [AREACOORD(src)]")
		playsound(src, 'sound/machines/gateway/gateway_travel.ogg', 70, TRUE, PORTAL_TRAVEL_SOUND_RANGE)
		parent_portal.transfer(arriving_object)

// ===== MAIN PORTAL MACHINERY =====
/obj/machinery/portal
	name = "dimensional portal"
	desc = "A shimmering portal to unknown realms. This one seems to lead to dynamically generated Veilbreak dungeons."
	icon = 'icons/obj/machines/gateway.dmi'
	icon_state = "portal_frame"

	// Positioning and collision
	pixel_x = -32
	pixel_y = -32
	bound_height = 64
	bound_width = 96
	bound_x = -32
	bound_y = 0
	density = TRUE

	// Power configuration
	use_power = IDLE_POWER_USE
	active_power_usage = PORTAL_ACTIVE_POWER_USAGE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION

	// Construction properties
	circuit = /obj/item/circuitboard/machine/portal
	panel_open = FALSE

	// Invulnerability
	resistance_flags = LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	// Portal state management
	/// The default Veilbreak destination this portal creates
	var/datum/portal_destination/veilbreak/destination
	/// The currently active destination for transfers
	var/datum/portal_destination/target
	/// The collision bumper that handles transfers
	var/obj/effect/portal_bumper/bumper
	/// Whether any valid destinations are available
	var/portal_possible = FALSE
	/// Whether the portal is actively transporting
	var/transport_active = FALSE
	/// Data about the generated dungeon for UI/feedback
	var/list/generated_dungeon_data
	/// Track if we're currently cleaning up to prevent double-starts
	var/cleanup_in_progress = FALSE

/obj/machinery/portal/Initialize(mapload)
	. = ..()

	// Create our default Veilbreak destination
	destination = new /datum/portal_destination/veilbreak()
	destination.connected_portal = src

	// Register destination with global list
	var/destination_id = "veilbreak_station_[world.time]_[rand(1000,9999)]"
	GLOB.portal_destinations[destination_id] = destination

	log_portal("Initialize: Created at [AREACOORD(src)] with destination [destination.name] (ID: [destination_id])")
	update_appearance()

/obj/machinery/portal/Destroy()
	log_portal("Destroy: Destroying portal at [AREACOORD(src)]")

	// Trigger cleanup if this portal is active
	if(target && transport_active)
		initiate_emergency_cleanup()

	// Clean up destination
	if(destination)
		for(var/key in GLOB.portal_destinations)
			if(GLOB.portal_destinations[key] == destination)
				GLOB.portal_destinations -= key
				log_portal("Destroy: Removed destination [key] from global list")
				break
		QDEL_NULL(destination)

	// Clean up active connection
	if(target)
		deactivate()

	// Clean up bumper
	QDEL_NULL(bumper)

	return ..()

/// Emergency cleanup when portal is destroyed
/obj/machinery/portal/proc/initiate_emergency_cleanup()
	if(cleanup_in_progress)
		return

	cleanup_in_progress = TRUE
	log_portal("Emergency: Portal destroyed while active, initiating emergency cleanup")

	// Get area in front of portal for mob ejection - use multiple turfs for distribution
	var/list/ejection_turfs = get_ejection_turfs()

	// If this is a dungeon portal, clean up its Z-level
	if(destination?.dungeon_z_level)
		// Use enhanced cleanup with ejection (now ejects corpses too)
		for(var/turf/ejection_turf in ejection_turfs)
			destination.cleanup_z_level_completely(destination.dungeon_z_level, ejection_turf)
			break // Only need one ejection point
		log_portal("Emergency: Cleaned up dungeon Z-level [destination.dungeon_z_level]")

	// If this is the station portal and has a target, clean up the target's Z-level too
	if(target && istype(target, /datum/portal_destination/veilbreak))
		var/datum/portal_destination/veilbreak/veil_dest = target
		if(veil_dest.dungeon_z_level)
			for(var/turf/ejection_turf in ejection_turfs)
				veil_dest.cleanup_z_level_completely(veil_dest.dungeon_z_level, ejection_turf)
				break // Only need one ejection point
			log_portal("Emergency: Cleaned up target dungeon Z-level [veil_dest.dungeon_z_level]")

/// Get turfs in front of portal for ejection
/obj/machinery/portal/proc/get_ejection_turfs()
	var/list/turfs = list()
	var/turf/primary_turf = get_step(src, SOUTH)

	if(primary_turf)
		turfs += primary_turf
		// Add adjacent turfs to spread out ejected mobs
		for(var/dir in list(EAST, WEST, SOUTHEAST, SOUTHWEST))
			var/turf/adjacent = get_step(primary_turf, dir)
			if(adjacent)
				turfs += adjacent

	// Fallback if no valid turfs found
	if(!length(turfs))
		turfs += get_turf(src)

	return turfs

/// Check if this portal is located in a dungeon (mining/away Z-level)
/obj/machinery/portal/proc/is_dungeon_portal()
	return z && (SSmapping.level_trait(z, ZTRAIT_AWAY) || SSmapping.level_trait(z, ZTRAIT_MINING))

/// Update visual state based on portal status
/obj/machinery/portal/update_overlays()
	. = ..()

	if(portal_possible)
		. += "portal_light"

	if(transport_active)
		. += "portal_effect"

/// Create the collision bumper for this portal
/obj/machinery/portal/proc/generate_bumper()
	if(bumper)
		QDEL_NULL(bumper)

	bumper = new(get_turf(src), src)
	log_portal("Bumper: Generated at [AREACOORD(bumper)]")

// Construction and deconstruction
/obj/machinery/portal/on_construction()
	. = ..()
	// Portal is ready to use when built

/obj/machinery/portal/on_deconstruction()
	. = ..()
	// Clean up any active connections when deconstructed
	if(target)
		deactivate()

/obj/machinery/portal/default_deconstruction_crowbar(obj/item/crowbar)
	if(!panel_open)
		return FALSE
	return ..()

/obj/machinery/portal/RefreshParts()
	. = ..()
	// Portal parts could affect power usage
	// No calibration needed

// Tool interactions following established patterns
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

// Add contextual screentips like other machines
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

// Update examine text to show construction status
/obj/machinery/portal/examine(mob/user)
	. = ..()
	if(panel_open)
		. += span_notice("The maintenance panel is open.")

// ===== PORTAL CIRCUIT BOARD =====
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
