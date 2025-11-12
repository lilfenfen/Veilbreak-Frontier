// modular_zzveilbreak/code/modules/dungeons/portal_destinations_veilbreak.dm

// Veilbreak-specific destination
/datum/portal_destination/veilbreak
	name = "Veilbreak Dungeon"
	var/generating = FALSE
	var/generated = FALSE
	var/dungeon_z_level = 0
	var/last_generation_data = null
	var/current_request_id = 0
	var/generation_progress = 0
	var/last_progress_update = 0
	/// Reference to the control computer for callbacks
	var/obj/machinery/computer/portal_control/connected_control_computer
	/// Background processing for heavy operations
	var/datum/background_process/cleanup_process
	var/datum/background_process/init_process
	var/datum/background_process/load_process
	/// Prevent multiple simultaneous cleanups
	var/cleanup_in_progress = FALSE
	/// Prevent processing during cleanup
	var/processing_disabled = FALSE

/datum/portal_destination/veilbreak/is_available()
	return ..() && generated && !generating

/datum/portal_destination/veilbreak/get_available_reason()
	if(generating)
		return "Dungeon generation in progress... [generation_progress]%"
	if(!generated)
		return "No dungeon generated yet"
	return ..()

/datum/portal_destination/veilbreak/get_target_turf()
	if(!dungeon_z_level)
		log_dungeon("TargetTurf: No dungeon Z-level assigned")
		return null

	// Use the gateway location from JSON metadata
	var/turf/gateway_turf = get_gateway_turf_from_metadata()
	if(gateway_turf)
		log_dungeon("TargetTurf: Using gateway location from JSON at [AREACOORD(gateway_turf)]")
		return gateway_turf

	// Fallback to center if no gateway found
	log_dungeon("TargetTurf: No gateway location, using center as fallback")
	return locate(round(world.maxx/2), round(world.maxy/2), dungeon_z_level)

/// Get the gateway turf from JSON metadata
/datum/portal_destination/veilbreak/proc/get_gateway_turf_from_metadata()
	if(!last_generation_data || !last_generation_data["metadata"])
		log_dungeon("Gateway: No generation data available")
		return null

	var/list/metadata = last_generation_data["metadata"]
	var/list/key_positions = metadata["key_positions"]

	if(!key_positions || !key_positions["gateway"])
		log_dungeon("Gateway: No gateway position in metadata")
		return null

	var/list/gateway_pos = key_positions["gateway"]
	var/gateway_x = gateway_pos["x"]
	var/gateway_y = gateway_pos["y"]

	if(!gateway_x || !gateway_y)
		log_dungeon("Gateway: Invalid gateway coordinates: x=[gateway_x], y=[gateway_y]")
		return null

	var/turf/gateway_turf = locate(gateway_x, gateway_y, dungeon_z_level)
	if(!gateway_turf)
		log_dungeon("Gateway: Invalid gateway turf at [gateway_x],[gateway_y],[dungeon_z_level]")
		return null

	log_dungeon("Gateway: Using pre-determined gateway location at [AREACOORD(gateway_turf)]")
	return gateway_turf

/// Initialize the fixed portal Z-level on first use - FIXED: Use world.maxz
/datum/portal_destination/veilbreak/proc/initialize_portal_z_level()
	log_dungeon("DUNGEON DEBUG: initialize_portal_z_level() called - current world.maxz: [world.maxz]")

	if(GLOB.portal_dungeon_z_level)
		dungeon_z_level = GLOB.portal_dungeon_z_level
		log_dungeon("ZLevel: Using existing portal Z-level [dungeon_z_level]")
		return TRUE

	// FIXED: Use the highest existing Z-level (world.maxz) for portal dungeons
	var/target_z = world.maxz

	GLOB.portal_dungeon_z_level = target_z
	dungeon_z_level = GLOB.portal_dungeon_z_level
	log_dungeon("ZLevel: Set portal Z-level to world.maxz [dungeon_z_level] for reuse")
	return TRUE

/// Get dungeon statistics for UI display
/datum/portal_destination/veilbreak/proc/get_dungeon_stats()
	if(!last_generation_data || !last_generation_data["metadata"])
		return null

	var/list/metadata = last_generation_data["metadata"]
	var/list/stats = list()

	stats["z_level"] = dungeon_z_level
	stats["name"] = metadata["map_name"]
	stats["technical_name"] = metadata["technical_name"]
	stats["seed"] = metadata["seed"]
	stats["dimensions"] = metadata["dimensions"]
	stats["statistics"] = metadata["statistics"]
	stats["generation_info"] = metadata["generation_info"]

	return stats

/// Validate destination state
/datum/portal_destination/veilbreak/proc/validate_state()
	if(generating && generated)
		log_dungeon("State: WARNING - Portal in invalid state (both generating and generated)")
		return FALSE
	if(dungeon_z_level > world.maxz)
		log_dungeon("State: WARNING - Dungeon Z-level [dungeon_z_level] exceeds world maxz [world.maxz]")
		return FALSE
	return TRUE

// FIXED: Improved process proc with better state management
/datum/portal_destination/veilbreak/process()
	if(processing_disabled)
		STOP_PROCESSING(SSobj, src)
		return

	if(!generating)
		STOP_PROCESSING(SSobj, src)
		return

	// Update progress for UI
	if(world.time - last_progress_update > 1 SECONDS)
		generation_progress = min(generation_progress + rand(5, 15), 90)
		last_progress_update = world.time

	// Check if request is complete
	if(current_request_id)
		var/still_processing = GLOB.dungeon_generator.check_request(current_request_id)
		if(!still_processing)
			// Request completed or failed
			STOP_PROCESSING(SSobj, src)
			generation_progress = 100
			return

	// Safety timeout - if we're still here but shouldn't be
	STOP_PROCESSING(SSobj, src)
	generation_failed("Generation process stuck in invalid state")
