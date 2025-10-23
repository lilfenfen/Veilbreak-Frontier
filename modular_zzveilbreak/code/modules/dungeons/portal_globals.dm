// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

// CORRECTED Forward declarations - only what we actually need
/datum/space_level
/datum/parsed_map

// Proc forward declarations
/proc/IS_LIST_OF_ATOMS(list/L)

#define DUNGEON_GENERATOR_URL "http://127.0.0.1:8000"
#define DUNGEON_GENERATE_ENDPOINT "/generate_dungeon"
#define DUNGEON_GENERATOR_TIMEOUT 300 // 30 seconds

// Global list for portal destinations (separate from gateways)
GLOBAL_LIST_EMPTY(portal_destinations)

// Helper proc for dungeon generator logging that's compatible with our log_game
/proc/log_dungeon(text)
	log_game(text, list(), LOG_GAME)

// HTTP request manager for dungeon generation
/datum/http_dungeon_generator
	var/current_request_id = 0
	var/list/active_requests = list()

/datum/http_dungeon_generator/proc/generate_dungeon(datum/portal_destination/veilbreak/destination, width = 80, height = 80)
	// Check if RUSTG HTTP is available
	var/datum/http_request/test_request = new()
	if(!test_request)
		destination.generation_failed("HTTP system not available")
		return 0

	var/request_id = ++current_request_id
	active_requests["[request_id]"] = destination

	var/datum/http_request/request = new()
	var/url = "[DUNGEON_GENERATOR_URL][DUNGEON_GENERATE_ENDPOINT]?width=[width]&height=[height]&seed=[rand(1,1000000)]"

	log_dungeon("Dungeon Generator: Starting HTTP request to [url]")

	request.prepare(RUSTG_HTTP_METHOD_GET, url, "", "")
	request.begin_async()

	// Store the request data
	active_requests["[request_id]_req"] = request
	active_requests["[request_id]_time"] = world.time

	return request_id

/datum/http_dungeon_generator/proc/check_request(request_id)
	var/datum/portal_destination/veilbreak/destination = active_requests["[request_id]"]
	if(!destination)
		return FALSE

	var/datum/http_request/request = active_requests["[request_id]_req"]
	if(!request)
		active_requests -= "[request_id]"
		return FALSE

	if(!request.is_complete())
		// Check for timeout
		var/start_time = active_requests["[request_id]_time"]
		if(world.time - start_time > DUNGEON_GENERATOR_TIMEOUT)
			destination.generation_failed("Request timeout after [DUNGEON_GENERATOR_TIMEOUT/10] seconds")
			active_requests -= "[request_id]"
			active_requests -= "[request_id]_req"
			active_requests -= "[request_id]_time"
			return FALSE
		return TRUE // Still processing

	var/datum/http_response/response = request.into_response()

	if(response.errored || !response.body)
		destination.generation_failed("HTTP error: [response.error]")
	else
		var/list/data = json_decode(response.body)
		if(data && data["status"] == "success")
			destination.generation_complete(data)
		else
			destination.generation_failed(data?["message"] || "Unknown error from generator")

	// Cleanup
	active_requests -= "[request_id]"
	active_requests -= "[request_id]_req"
	active_requests -= "[request_id]_time"

	return FALSE

// Global instance
GLOBAL_DATUM(dungeon_generator, /datum/http_dungeon_generator)

// Base portal destination type
/datum/portal_destination
	var/name = "Unknown Destination"
	var/wait = 0
	var/enabled = TRUE
	var/hidden = FALSE
	var/obj/machinery/portal/connected_portal

/datum/portal_destination/proc/is_available()
	return enabled && (world.time - SSticker.round_start_time >= wait)

/datum/portal_destination/proc/get_available_reason()
	. = "Unreachable"
	if(world.time - SSticker.round_start_time < wait)
		. = "Connection desynchronized. Recalibration in progress."

/datum/portal_destination/proc/incoming_pass_check(atom/movable/AM)
	return TRUE

/datum/portal_destination/proc/get_target_turf()
	CRASH("get_target_turf not implemented for this destination type")

/datum/portal_destination/proc/post_transfer(atom/movable/AM)
	if(ismob(AM))
		var/mob/M = AM
		if(M.client)
			M.client.move_delay = max(world.time + 5, M.client.move_delay)

/datum/portal_destination/proc/activate(obj/machinery/portal/activated)
	log_dungeon("Portal Destination: [name] activated by portal at [AREACOORD(activated)]")
	return

/datum/portal_destination/proc/deactivate(obj/machinery/portal/deactivated)
	return

/datum/portal_destination/proc/get_ui_data()
	. = list()
	.["ref"] = REF(src)
	.["name"] = name
	.["available"] = is_available()
	.["reason"] = get_available_reason()
	if(wait)
		.["timeout"] = max(1 - (wait - (world.time - SSticker.round_start_time)) / wait, 0)
	else
		.["timeout"] = 0

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

/datum/portal_destination/veilbreak/is_available()
	return ..() && generated && !generating

/datum/portal_destination/veilbreak/get_available_reason()
	if(generating)
		return "Dungeon generation in progress... [generation_progress]%"
	if(!generated)
		return "No dungeon generated yet"
	return ..()

/datum/portal_destination/veilbreak/get_target_turf()
	if(!dungeon_z_level || !last_generation_data)
		return null

	// Access metadata correctly from the nested structure
	var/list/metadata = last_generation_data["metadata"]
	if(metadata && metadata["key_positions"])
		var/list/key_positions = metadata["key_positions"]
		if(key_positions && key_positions["gateway"])
			var/list/gateway_pos = key_positions["gateway"]
			return locate(gateway_pos["x"], gateway_pos["y"], dungeon_z_level)

	// Fallback to center
	return locate(round(world.maxx/2), round(world.maxy/2), dungeon_z_level)

/datum/portal_destination/veilbreak/proc/start_generation()
	if(generating)
		log_dungeon("Dungeon Generator: Attempted to start generation while already generating")
		return

	// Verify mapping subsystem is ready
	if(!SSmapping || !SSmapping.initialized)
		generation_failed("Mapping subsystem not ready")
		return

	if(SSmapping.clearing_reserved_turfs)
		generation_failed("Mapping subsystem is currently clearing reservations")
		return

	if(SSmapping.adding_new_zlevel)
		generation_failed("Mapping subsystem is already adding a Z-level")
		return

	generating = TRUE
	generated = FALSE
	generation_progress = 0
	last_progress_update = world.time

	if(!GLOB.dungeon_generator)
		GLOB.dungeon_generator = new /datum/http_dungeon_generator()

	log_dungeon("Dungeon Generator: Starting generation for portal destination [name]")
	current_request_id = GLOB.dungeon_generator.generate_dungeon(src, 80, 80)

	if(!current_request_id)
		generation_failed("Failed to start generation request")
		return

	log_dungeon("Dungeon Generator: Started generation request [current_request_id]")

	// Start progress updates
	START_PROCESSING(SSobj, src)

/datum/portal_destination/veilbreak/process()
	if(!generating)
		STOP_PROCESSING(SSobj, src)
		return

	// Update progress for UI
	if(world.time - last_progress_update > 1 SECONDS)
		generation_progress = min(generation_progress + rand(5, 15), 90)
		last_progress_update = world.time

	// Check if request is complete
	if(current_request_id && GLOB.dungeon_generator.check_request(current_request_id))
		// Still processing
		return

	// Request completed or failed
	STOP_PROCESSING(SSobj, src)
	generation_progress = 100

/datum/portal_destination/veilbreak/proc/generation_complete(list/data)
	generating = FALSE
	last_generation_data = data

	log_dungeon("Dungeon Generator: Received successful generation response with [length(data["dmm_content"] || "")] bytes of DMM content")

	// Access dmm_content from top level
	if(data["dmm_content"])
		load_generated_dmm(data["dmm_content"], data["metadata"])
	else
		generation_failed("No DMM content in response")

/datum/portal_destination/veilbreak/proc/generation_failed(reason)
	generating = FALSE
	generated = FALSE
	generation_progress = 0

	log_dungeon("Dungeon Generator: Generation failed - [reason]")

	if(connected_portal)
		connected_portal.say("Dungeon generation failed: [reason]")
		connected_portal.generated_dungeon_data = null

// Add interface method for portal control
/datum/portal_destination/veilbreak/activate(obj/machinery/portal/activated)
	. = ..() // Call parent for logging
	log_dungeon("Dungeon Generator: Portal activated to [name] at Z-level [dungeon_z_level]")
	// Ensure portal connection is established when activated
	if(activated == connected_portal) // Only do this for the station portal, not the dungeon portal
		ensure_portal_connection()

/datum/portal_destination/veilbreak/deactivate(obj/machinery/portal/deactivated)
	log_dungeon("Dungeon Generator: Portal deactivated from [name]")

// CORRECTED: Complete dungeon loading implementation with proper atom initialization
/datum/portal_destination/veilbreak/proc/load_generated_dmm(dmm_content, list/metadata)
	if(!dmm_content)
		return generation_failed("No DMM content provided")
	if(SSatoms.initialized)
		SSatoms.InitializeAtoms()
	log_dungeon("Dungeon Generator: Starting DMM content load for Veilbreak dungeon")

	// Save original DMM for debugging
	text2file(dmm_content, "data/logs/dungeon_content_[world.time].dmm")

	// Verify mapping subsystem is ready
	if(!SSmapping.initialized)
		return generation_failed("Mapping subsystem not initialized")

	// Create new Z-level using mapping subsystem
	var/datum/space_level/dungeon_level = SSmapping.add_new_zlevel(
		name = "Veilbreak Dungeon [rand(1000,9999)]",
		traits = list(
			ZTRAIT_AWAY = TRUE,
			ZTRAIT_MINING = TRUE,
			ZTRAIT_BASETURF = /turf/open/space/basic
		),
		z_type = /datum/space_level
	)

	if(!dungeon_level)
		return generation_failed("Failed to create new Z-level")

	dungeon_z_level = dungeon_level.z_value
	log_dungeon("Dungeon Generator: Created new dungeon at Z-level [dungeon_z_level]")

	// Parse and load the DMM content
	var/datum/parsed_map/parsed = new(dmm_content)
	if(!parsed || !parsed.bounds)
		log_dungeon("Dungeon Generator: Failed to parse DMM content - invalid format or null bounds")
		return generation_failed("Failed to parse DMM content")

	log_dungeon("Dungeon Generator: Parsed map with bounds [json_encode(parsed.bounds)]")

	// CRITICAL: Tell SSatoms we're starting a map load
	SSatoms.map_loader_begin("dungeon_generator_[dungeon_z_level]")

	// Use SSair's map loading system if available
	if(SSair.initialized)
		SSair.StartLoadingMap()

	var/loaded_successfully = FALSE
	try
		loaded_successfully = parsed.load(
			z_offset = dungeon_z_level,
			no_changeturf = FALSE,
			place_on_top = FALSE,
			new_z = TRUE
		)
	catch(var/exception/e)
		log_dungeon("Dungeon Generator: Exception during map load: [e]")
		loaded_successfully = FALSE

	if(SSair.initialized)
		SSair.StopLoadingMap()

	// CRITICAL: Tell SSatoms we're done with map loading
	SSatoms.map_loader_stop("dungeon_generator_[dungeon_z_level]")

	if(!loaded_successfully)
		log_dungeon("Dungeon Generator: Map loading failed at Z-level [dungeon_z_level]")
		return generation_failed("Failed to load map into world")

	log_dungeon("Dungeon Generator: Map loaded successfully at Z-level [dungeon_z_level]")

	// Initialize all required subsystems - NOW WITH PROPER ATOM INITIALIZATION
	initialize_dungeon_subsystems(dungeon_z_level)

	// Mark as complete
	generated = TRUE
	generation_progress = 100
	last_generation_data = metadata

	if(connected_portal)
		connected_portal.generated_dungeon_data = metadata
		connected_portal.say("Dungeon generation complete. Portal stabilized.")
		ensure_portal_connection()

	log_dungeon("Dungeon Generator: Veilbreak dungeon fully initialized at Z-level [dungeon_z_level]")
	return TRUE

// NEW: Comprehensive subsystem initialization to fix red X's with proper atom initialization
/datum/portal_destination/veilbreak/proc/initialize_dungeon_subsystems(z_level)
	log_dungeon("Dungeon Generator: Starting subsystem initialization for Z-level [z_level]")

	// Track initialization results
	var/list/initialization_results = list()

	// 1. CRITICAL: Force Initialize all atoms on the new Z-level (this is what fixes red X's)
	initialization_results["atoms"] = initialize_dungeon_atoms(z_level)

	// 2. CRITICAL: Initialize area properties (fixes darkness)
	initialization_results["areas"] = initialize_dungeon_areas(z_level)

	// 3. CRITICAL: Initialize power systems
	initialization_results["power"] = initialize_dungeon_power(z_level)

	// 4. CRITICAL: Initialize lighting (visibility)
	initialization_results["lighting"] = initialize_dungeon_lighting(z_level)

	// 5. CRITICAL: Initialize atmospherics (air, pipenets)
	initialization_results["atmospherics"] = initialize_dungeon_atmospherics(z_level)

	// 6. IMPORTANT: Initialize machinery processing
	initialization_results["machinery"] = initialize_dungeon_machinery(z_level)

	// 7. Force immediate visual updates
	initialization_results["visuals"] = force_immediate_visual_updates(z_level)

	// Log summary
	var/success_count = 0
	var/total_count = length(initialization_results)
	for(var/subsystem in initialization_results)
		if(initialization_results[subsystem])
			success_count++

	log_dungeon("Dungeon Generator: Subsystem initialization complete - [success_count]/[total_count] successful for Z-level [z_level]")

	return success_count >= 3 // Return TRUE if at least critical systems initialized

// NEW: CRITICAL - Force initialization of all atoms on the Z-level
/datum/portal_destination/veilbreak/proc/initialize_dungeon_atoms(z_level)
	log_dungeon("Dungeon Generator: Initializing atoms for Z-level [z_level]")

	var/atoms_initialized = 0

	// Get all atoms on the Z-level that haven't been properly initialized
	for(var/atom/A in world)
		if(A.z != z_level)
			continue

		// Check if this atom needs initialization
		if(!(A.flags_1 & INITIALIZED_1))
			// Use SSatoms' InitAtom proc to properly initialize it
			// This will call Initialize() and set up smoothing, lighting, etc.
			SSatoms.InitAtom(A, FALSE, list(FALSE)) // FALSE for mapload since we're post-initial load
			atoms_initialized++

		if(atoms_initialized % 100 == 0)
			CHECK_TICK

	log_dungeon("Dungeon Generator: Initialized [atoms_initialized] atoms on Z-level [z_level]")
	return atoms_initialized > 0

// NEW: Area initialization - FIXED to handle area power and appearance
/datum/portal_destination/veilbreak/proc/initialize_dungeon_areas(z_level)
	log_dungeon("Dungeon Generator: Initializing area properties for Z-level [z_level]")

	var/areas_initialized = 0

	for(var/area/area as anything in GLOB.areas)
		// Check if this area has turfs on our Z-level
		var/has_turfs_on_z = FALSE
		for(var/turf/T in area.contents)
			if(T.z == z_level)
				has_turfs_on_z = TRUE
				break

		if(!has_turfs_on_z)
			continue

		areas_initialized++

		// Reset area to default power state
		area.power_equip = initial(area.power_equip)
		area.power_light = initial(area.power_light)
		area.power_environ = initial(area.power_environ)
		area.always_unpowered = initial(area.always_unpowered)

		// Force area to update its appearance (fixes darkness)
		area.power_change()
		area.update_icon()

		CHECK_TICK

	log_dungeon("Dungeon Generator: Initialized [areas_initialized] areas on Z-level [z_level]")
	return areas_initialized > 0

// NEW: Power initialization - FIXED to use world iteration instead of undefined globals
/datum/portal_destination/veilbreak/proc/initialize_dungeon_power(z_level)
	log_dungeon("Dungeon Generator: Initializing power systems for Z-level [z_level]")

	var/areas_powered = 0
	var/machines_powered = 0

	// Initialize area power
	for(var/area/area as anything in GLOB.areas)
		var/has_turfs_on_z = FALSE
		for(var/turf/T in area.contents)
			if(T.z == z_level)
				has_turfs_on_z = TRUE
				break

		if(!has_turfs_on_z)
			continue

		areas_powered++
		area.power_change() // This updates area lighting and equipment power

		CHECK_TICK

	// Initialize machinery power states - FIXED: Use world iteration
	for(var/obj/machinery/machine in world)
		if(machine.z == z_level)
			machines_powered++
			machine.power_change() // Ensure machinery power states are correct

		if(machines_powered % 50 == 0)
			CHECK_TICK

	log_dungeon("Dungeon Generator: Initialized power for [areas_powered] areas and [machines_powered] machines on Z-level [z_level]")
	return areas_powered > 0

// NEW: Lighting initialization - FIXED to properly set up lighting
/datum/portal_destination/veilbreak/proc/initialize_dungeon_lighting(z_level)
	log_dungeon("Dungeon Generator: Initializing lighting for Z-level [z_level]")

	if(!SSlighting || !SSlighting.initialized)
		log_dungeon("Dungeon Generator: Lighting subsystem not available for Z-level [z_level]")
		return FALSE

	var/lighting_objects_created = 0

	// Create lighting objects for all turfs that need them
	for(var/turf/iter_turf as anything in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		// Only create lighting objects for turfs that don't have them and aren't space lit
		if(!iter_turf.space_lit && !iter_turf.lighting_object)
			new /datum/lighting_object(iter_turf)
			lighting_objects_created++

		if(lighting_objects_created % 100 == 0)
			CHECK_TICK

	log_dungeon("Dungeon Generator: Created [lighting_objects_created] lighting objects on Z-level [z_level]")
	return TRUE

// NEW: Atmospherics initialization
/datum/portal_destination/veilbreak/proc/initialize_dungeon_atmospherics(z_level)
	log_dungeon("Dungeon Generator: Initializing atmospherics for Z-level [z_level]")

	if(!SSair || !SSair.initialized)
		log_dungeon("Dungeon Generator: Air subsystem not available for Z-level [z_level]")
		return FALSE

	var/atmos_machines_initialized = 0

	// Initialize atmos machinery on the new Z-level
	for(var/obj/machinery/atmospherics/AM as anything in SSair.atmos_machinery)
		if(AM.z == z_level)
			atmos_machines_initialized++
			// The atmos system will handle these in its next process cycle

		if(atmos_machines_initialized % 50 == 0)
			CHECK_TICK

	log_dungeon("Dungeon Generator: Found [atmos_machines_initialized] atmos machines on Z-level [z_level]")
	return TRUE

// NEW: Machinery initialization - FIXED to use world iteration instead of undefined globals
/datum/portal_destination/veilbreak/proc/initialize_dungeon_machinery(z_level)
	log_dungeon("Dungeon Generator: Initializing machinery for Z-level [z_level]")

	var/machines_processed = 0

	// Process all machinery on the new Z-level - FIXED: Use world iteration
	for(var/obj/machinery/machine in world)
		if(machine.z == z_level)
			machines_processed++
			// Ensure machinery is properly set up
			if(machine.use_power)
				machine.power_change()
			// Update appearance
			machine.update_icon()
			machine.update_appearance()

		if(machines_processed % 50 == 0)
			CHECK_TICK

	log_dungeon("Dungeon Generator: Processed [machines_processed] machines on Z-level [z_level]")
	return machines_processed > 0

// NEW: Force immediate visual updates - CRITICAL for fixing red X's
/datum/portal_destination/veilbreak/proc/force_immediate_visual_updates(z_level)
	log_dungeon("Dungeon Generator: Forcing immediate visual updates for Z-level [z_level]")

	var/turfs_updated = 0
	var/areas_updated = 0

	// Update all turfs immediately
	for(var/turf/iter_turf as anything in block(locate(1, 1, z_level), locate(world.maxx, world.maxy, z_level)))
		iter_turf.update_icon()
		iter_turf.update_appearance()
		turfs_updated++

		if(turfs_updated % 100 == 0)
			CHECK_TICK

	// Update all areas
	for(var/area/area as anything in GLOB.areas)
		var/has_turfs_on_z = FALSE
		for(var/turf/T in area.contents)
			if(T.z == z_level)
				has_turfs_on_z = TRUE
				break

		if(has_turfs_on_z)
			areas_updated++
			area.update_icon()

		CHECK_TICK

	log_dungeon("Dungeon Generator: Updated [turfs_updated] turfs and [areas_updated] areas on Z-level [z_level]")
	return TRUE

// Cleanup and utility procs
/datum/portal_destination/veilbreak/proc/cleanup_dungeon()
	if(dungeon_z_level && dungeon_z_level <= world.maxz)
		log_dungeon("Dungeon at Z-level [dungeon_z_level] marked for cleanup")

	dungeon_z_level = 0
	generated = FALSE
	last_generation_data = null

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

/datum/portal_destination/veilbreak/proc/validate_state()
	if(generating && generated)
		log_dungeon("Dungeon Generator: WARNING - Portal in invalid state (both generating and generated)")
		return FALSE
	if(dungeon_z_level > world.maxz)
		log_dungeon("Dungeon Generator: WARNING - Dungeon Z-level [dungeon_z_level] exceeds world maxz [world.maxz]")
		return FALSE
	return TRUE


/datum/portal_destination/veilbreak/proc/ensure_portal_connection()
	if(!dungeon_z_level || !last_generation_data)
		return FALSE

	var/list/metadata = last_generation_data["metadata"]
	if(!metadata || !metadata["key_positions"])
		return FALSE

	// Find the gateway position in the dungeon
	var/turf/gateway_turf = get_target_turf()
	if(!gateway_turf)
		log_dungeon("Dungeon Generator: No gateway position found in metadata")
		return FALSE

	// Look for existing portal or create one
	var/obj/machinery/portal/dungeon_portal = locate(/obj/machinery/portal) in gateway_turf
	if(!dungeon_portal)
		// Create a portal
		if(connected_portal)
			dungeon_portal = new connected_portal.type(gateway_turf)
		else
			dungeon_portal = new /obj/machinery/portal(gateway_turf)

		// Make it always powered
		dungeon_portal.use_power = NO_POWER_USE
		dungeon_portal.active_power_usage = 0
		dungeon_portal.idle_power_usage = 0

		log_dungeon("Dungeon Generator: Created always-powered dungeon portal at [gateway_turf.x],[gateway_turf.y],[gateway_turf.z]")

	// Force the portal to be active
	dungeon_portal.portal_possible = TRUE
	dungeon_portal.transport_active = TRUE

	// FIX: Use the correct variable name 'bumper' instead of 'portal'
	if(!dungeon_portal.bumper)
		dungeon_portal.generate_bumper()

	dungeon_portal.update_appearance()

	// Configure the dungeon portal to point back to station
	dungeon_portal.name = "Veilbreak Return Gateway"

	// Set up bidirectional connection using the actual portal system mechanics
	if(connected_portal)
		// Create a simple return destination that points to the station portal's location
		var/datum/portal_destination/return_destination = new /datum/portal_destination()
		return_destination.name = "Return to Station"
		return_destination.wait = 0
		return_destination.enabled = TRUE

		// Store the station portal's location for the return trip
		return_destination.connected_portal = connected_portal

		// Add to global list with unique ID
		var/return_id = "veilbreak_return_[dungeon_z_level]"
		GLOB.portal_destinations[return_id] = return_destination

		// Configure dungeon portal to use this return destination
		dungeon_portal.target = return_destination
		dungeon_portal.portal_possible = TRUE

		// CRITICAL: Activate the dungeon portal
		dungeon_portal.activate(return_destination)

		// Configure station portal to point to this dungeon destination
		connected_portal.target = src
		connected_portal.portal_possible = TRUE
		connected_portal.name = "Veilbreak Dungeon Gateway"

		// FIX: Use the correct variable name 'bumper' instead of 'portal'
		if(!connected_portal.bumper)
			connected_portal.generate_bumper()
		connected_portal.activate(src)

		// Update both portals
		connected_portal.update_appearance()
		dungeon_portal.update_appearance()

		log_dungeon("Dungeon Generator: Bidirectional portal connection established - station portal at [AREACOORD(connected_portal)] linked to dungeon portal at [AREACOORD(dungeon_portal)]")

	return TRUE
