// modular_zzveilbreak/code/modules/dungeons/portal_config.dm

// Configuration for the dungeon generator API
#define DUNGEON_GENERATOR_URL "http://localhost:8000"
#define DUNGEON_GENERATOR_TIMEOUT 300 // 30 seconds
#define DUNGEON_GENERATOR_POLL_INTERVAL 5 // Start with 0.5 seconds

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

// Maximum Z-levels to prevent server overload
#define MAX_Z_LEVELS 20

// Global instance of dungeon generator
GLOBAL_DATUM_INIT(dungeon_generator, /datum/http_dungeon_generator, new)
