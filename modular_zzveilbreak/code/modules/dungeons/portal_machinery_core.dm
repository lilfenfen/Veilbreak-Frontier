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
	/// Whether this portal has been calibrated for stable operation
	var/calibrated = TRUE
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
	// Portal starts uncalibrated when built
	calibrated = FALSE

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
	// Portal parts could affect power usage or calibration time
	// For now, just ensure calibration is maintained
	if(!calibrated)
		calibrated = TRUE
		log_portal("RefreshParts: Portal auto-calibrated with new parts")

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
	if(istype(held_item, /obj/item/multitool))
		context[SCREENTIP_CONTEXT_LMB] = "Calibrate portal"
		return CONTEXTUAL_SCREENTIP_SET

// Update examine text to show construction status
/obj/machinery/portal/examine(mob/user)
	. = ..()
	if(!calibrated)
		. += span_warning("The portal appears uncalibrated. Use a multitool to calibrate it.")
	if(panel_open)
		. += span_notice("The maintenance panel is open.")

// ===== PORTAL CIRCUIT BOARD =====
/obj/item/circuitboard/machine/portal
	name = "Dimensional Portal (Machine Board)"
	desc = "A circuit board for a dimensional portal."
	build_path = /obj/machinery/portal
	req_components = list(
		/obj/item/stock_parts/scanning_module = 2,
		/obj/item/stock_parts/micro_laser = 2,
		/obj/item/stock_parts/capacitor = 2,
		/obj/item/stack/cable_coil = 5
	)
	needs_anchored = TRUE

// Protolathe recipe following the same pattern as other machines
/datum/design/board/portal
	name = "Machine Design (Dimensional Portal)"
	desc = "The circuit board for a Dimensional Portal."
	id = "portal"
	build_path = /obj/item/circuitboard/machine/portal
	category = list(RND_CATEGORY_MACHINE)
	departmental_flags = DEPARTMENT_BITFLAG_ASSISTANT

/obj/item/circuitboard/machine/portal_control
	name = "Portal Control Console (Machine Board)"
	desc = "A circuit board for a portal control console."
	build_path = /obj/machinery/computer/portal_control
	req_components = list(
		/obj/item/stock_parts/scanning_module = 1,
		/obj/item/stock_parts/micro_laser = 1,
		/obj/item/stack/cable_coil = 2
	)
