// modular_zzveilbreak/code/modules/dungeons/portal_globals.dm

/datum/space_level
/datum/parsed_map

GLOBAL_LIST_EMPTY(portal_destinations)
GLOBAL_VAR(portal_dungeon_z_level)

// Configuration for the dungeon generator API
#define DUNGEON_GENERATOR_URL "http://localhost:8000"
#define DUNGEON_GENERATOR_TIMEOUT 300

// API Endpoints
#define DUNGEON_GENERATE_ENDPOINT "/generate_dungeon"

// Portal states for TGUI
#define PORTAL_STATE_IDLE "idle"
#define PORTAL_STATE_GENERATING "generating"
#define PORTAL_STATE_READY "ready"
#define PORTAL_STATE_ERROR "error"

// Background processing constants
#define BG_PROCESSING_CONTINUE 1
#define BG_PROCESSING_FINISHED 2

// Power and sound configuration
#define PORTAL_ACTIVE_POWER_USAGE (BASE_MACHINE_ACTIVE_CONSUMPTION * 8)
#define PORTAL_SOUND_RANGE 7
#define PORTAL_TRAVEL_SOUND_RANGE 3

// Z-level traits for portal identification
#define PORTAL_TRAIT_DUNGEON list(ZTRAIT_AWAY, ZTRAIT_MINING)

// Dungeon generation constants
#define DUNGEON_WIDTH 100
#define DUNGEON_HEIGHT 100

// Maximum processing time per tick to prevent server lag
#define MAX_PROCESSING_TIME_PER_TICK 0.5 SECONDS

// Smoothing configuration
#define SMOOTHING_GROUP_CLOSED_TURFS SMOOTH_GROUP_CLOSED_TURFS
#define SMOOTHING_GROUP_WALLS SMOOTH_GROUP_WALLS
#define SMOOTHING_GROUP_MINERAL_WALLS SMOOTH_GROUP_MINERAL_WALLS

// Global instance of dungeon generator
GLOBAL_DATUM_INIT(dungeon_generator, /datum/http_dungeon_generator, new)

/proc/is_hostile_or_void(mob/living/mob)
	if(mob.stat == DEAD)
		return FALSE

	if(mob.faction == FACTION_VOID)
		return TRUE

	if(istype(mob, /mob/living/simple_animal/hostile))
		return TRUE

	if(istype(mob, /mob/living/carbon/alien))
		return TRUE

	if(istype(mob, /mob/living/simple_animal) && !mob.ckey)
		return TRUE

	return FALSE

// Check if the necessary subsystems are initialized and ready for portal operations.
/proc/subsystems_ready_for_portals()
	return (SSmapping.initialized && \
			SSatoms.initialized == INITIALIZATION_INNEW_REGULAR && \
			SSair.initialized && \
			SSmobs.initialized && \
			world.time > 30 SECONDS) // Give subsystems time to settle after round start.

// Initialize dungeon mobs for AI processing
/proc/initialize_dungeon_mobs(z_level)
	if(!SSmobs.initialized)
		return

	var/mobs_initialized = 0
	for(var/mob/living/mob in world)
		if(mob.z != z_level)
			continue

		// Add to mobs subsystem for AI processing if not already there
		if(!(mob in GLOB.mob_living_list))
			GLOB.mob_living_list += mob
			mobs_initialized++

		if(mobs_initialized % 25 == 0)
			CHECK_TICK
