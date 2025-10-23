// modular_zzveilbreak/code/modules/dungeons/portal_machinery.dm

/// Dimensional portal machinery for Veilbreak dungeons
/// Handles portal creation, activation, and transfers between station and generated dungeons

// ===== CONFIGURATION =====
#define PORTAL_ACTIVE_POWER_USAGE (BASE_MACHINE_ACTIVE_CONSUMPTION * 8)
#define PORTAL_SOUND_RANGE 7
#define PORTAL_TRAVEL_SOUND_RANGE 3

// ===== LOGGING =====
/// Helper proc for portal machinery logging with consistent formatting
/proc/log_portal(text, list/data)
	log_game("PORTAL: [text]", data, LOG_GAME)

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
		return INITIALIZE_HINT_QDEL
	parent_portal = parent
	log_portal("Bumper created at [AREACOORD(src)] for portal [AREACOORD(parent)]")

/obj/effect/portal_bumper/Destroy()
	parent_portal = null
	log_portal("Bumper destroyed at [AREACOORD(src)]")
	return ..()

/obj/effect/portal_bumper/Bumped(atom/movable/arriving_object)
	if(!parent_portal?.can_transfer(arriving_object))
		return

	if(get_dir(src, arriving_object) == parent_portal.dir)
		log_portal("Transfer initiated for [arriving_object] at [AREACOORD(src)]")
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

	// FIX: Use a proper string key, not a raw reference
	var/destination_id = "veilbreak_station_[world.time]_[rand(1000,9999)]"
	GLOB.portal_destinations[destination_id] = destination

	log_portal("Initialized at [AREACOORD(src)] with destination [destination.name] (ID: [destination_id])")
	update_appearance()


/obj/machinery/portal/Destroy()
	log_portal("Destroying portal at [AREACOORD(src)]")

	// Clean up destination - find and remove it from global list
	if(destination)
		for(var/key in GLOB.portal_destinations)
			if(GLOB.portal_destinations[key] == destination)
				GLOB.portal_destinations -= key
				log_portal("Removed destination [key] from global list")
				break
		QDEL_NULL(destination)

	// Clean up active connection
	if(target)
		deactivate()

	// Clean up bumper
	QDEL_NULL(bumper)

	return ..()

/// Main processing - handles power state and destination availability
/obj/machinery/portal/process()
	if(is_dungeon_portal())
		handle_dungeon_portal_processing()
	else
		handle_station_portal_processing()

/// Check if this portal is located in a dungeon (mining/away Z-level)
/obj/machinery/portal/proc/is_dungeon_portal()
	return z && (SSmapping.level_trait(z, ZTRAIT_AWAY) || SSmapping.level_trait(z, ZTRAIT_MINING))

/// Processing logic for dungeon portals (always active, no power required)
/obj/machinery/portal/proc/handle_dungeon_portal_processing()
	portal_possible = TRUE
	if(target && !transport_active)
		transport_active = TRUE
		update_appearance()

/// Processing logic for station portals (power-dependent)
/obj/machinery/portal/proc/handle_station_portal_processing()
	// Check power state
	if((machine_stat & NOPOWER) && use_power)
		if(portal_possible)
			log_portal("Lost power at [AREACOORD(src)]")
		portal_possible = FALSE
		if(target)
			deactivate()
		return

	// Check destination availability
	var/was_possible = portal_possible
	portal_possible = check_destination_availability()

	if(was_possible != portal_possible)
		log_portal("Destination availability changed to [portal_possible] at [AREACOORD(src)]")
		update_appearance()

/// Check if any valid destinations are available
/obj/machinery/portal/proc/check_destination_availability()
	// FIX: Safely iterate through the associative list
	for(var/destination_key in GLOB.portal_destinations)
		var/datum/portal_destination/possible_destination = GLOB.portal_destinations[destination_key]
		if(!istype(possible_destination)) // Safety check
			log_portal("WARNING: Invalid destination found in global list: [destination_key]")
			continue
		if(valid_destination(possible_destination) && possible_destination.is_available())
			return TRUE
	return FALSE

/// Check if a destination is valid for this portal
/obj/machinery/portal/proc/valid_destination(datum/portal_destination/possible_destination)
	return possible_destination != destination

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
	log_portal("Generated bumper at [AREACOORD(bumper)]")

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
		log_portal("Activation failed - already active to [target.name] at [AREACOORD(src)]")
		return FALSE

	if(!is_dungeon_portal() && !powered())
		log_portal("Activation failed - no power at [AREACOORD(src)]")
		return FALSE

	return TRUE

/// Handle Veilbreak dungeon-specific activation logic
/obj/machinery/portal/proc/handle_veilbreak_activation(datum/portal_destination/veilbreak/veil_dest)
	if(!veil_dest.generated && !veil_dest.generating)
		log_portal("Starting dungeon generation for [veil_dest.name] at [AREACOORD(src)]")
		say("Initializing portal to [veil_dest.name]...")
		veil_dest.start_generation()
		reset_activation_state()
		return

	if(veil_dest.generating)
		log_portal("Activation delayed - [veil_dest.name] still generating at [AREACOORD(src)]")
		say("Portal to [veil_dest.name] still stabilizing...")
		reset_activation_state()
		return

	// Generation complete - proceed with activation
	log_portal("Successfully activated to generated dungeon [veil_dest.name] at Z-level [veil_dest.dungeon_z_level]")
	generated_dungeon_data = veil_dest.last_generation_data
	complete_activation(veil_dest)

/// Reset activation state after failed or delayed activation
/obj/machinery/portal/proc/reset_activation_state()
	transport_active = FALSE
	target = null

/// Complete the portal activation process
/obj/machinery/portal/proc/complete_activation(datum/portal_destination/dest)
	playsound(src, 'sound/machines/gateway/gateway_open.ogg', 140, TRUE, TRUE, PORTAL_SOUND_RANGE)
	generate_bumper()

	if(!is_dungeon_portal())
		update_use_power(ACTIVE_POWER_USE)

	update_appearance()
	dest.activate(src)

	log_portal("Activated to [dest.name] at [AREACOORD(src)]")

/// Deactivate the portal
/obj/machinery/portal/proc/deactivate()
	if(!target)
		log_portal("Deactivation attempted but no target set at [AREACOORD(src)]")
		return

	var/datum/portal_destination/old_target = target
	log_portal("Deactivating portal from [old_target.name] at [AREACOORD(src)]")

	target = null
	transport_active = FALSE

	playsound(src, 'sound/machines/gateway/gateway_close.ogg', 140, TRUE, TRUE, PORTAL_SOUND_RANGE)
	old_target.deactivate(src)

	QDEL_NULL(bumper)

	if(!is_dungeon_portal())
		update_use_power(IDLE_POWER_USE)

	update_appearance()

/// Check if an object can be transferred through the portal
/obj/machinery/portal/proc/can_transfer(atom/movable/transferring_object)
	if(!target)
		log_portal("Transfer failed - no target destination at [AREACOORD(src)]")
		return FALSE

	if(!target.incoming_pass_check(transferring_object))
		log_portal("Transfer failed - [transferring_object] failed pass check at [AREACOORD(src)]")
		return FALSE

	var/turf/target_turf = target.get_target_turf()
	if(!target_turf)
		log_portal("Transfer failed - invalid target turf for [target.name]")
		say("Portal destination unstable. Transfer aborted.")
		return FALSE

	return TRUE

/// Transfer an object through the portal
/obj/machinery/portal/proc/transfer(atom/movable/transferring_object)
	var/turf/target_turf = target.get_target_turf()

	log_portal("Transferring [transferring_object] from [AREACOORD(transferring_object)] to [AREACOORD(target_turf)] via [target.name]")

	transferring_object.forceMove(target_turf)
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

// ===== INTERACTION =====
/obj/machinery/portal/attack_ghost(mob/user)
	. = ..()
	if(.)
		return

	var/turf/target_turf = target?.get_target_turf()
	if(!target_turf)
		to_chat(user, span_warning("The portal destination is not yet stable..."))
		return

	log_portal("Ghost [key_name(user)] transferring through portal at [AREACOORD(src)]")
	transfer(user)

/obj/machinery/portal/multitool_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return TRUE

	if(calibrated)
		to_chat(user, span_alert("The portal is already calibrated, there is no work for you to do here."))
	else
		log_portal("[key_name(user)] calibrated portal at [AREACOORD(src)]")
		to_chat(user, span_boldnotice("Recalibration successful!") + " Portal systems have been fine tuned.")
		calibrated = TRUE

	return TRUE
