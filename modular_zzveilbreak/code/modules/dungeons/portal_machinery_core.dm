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

	// Invulnerability
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

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
