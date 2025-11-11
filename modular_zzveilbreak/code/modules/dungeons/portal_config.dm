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
