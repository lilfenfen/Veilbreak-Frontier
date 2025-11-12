// modular_zzveilbreak/code/modules/dungeons/_veilbreak.dm

// Core configuration and globals
#include "portal_config.dm"
#include "portal_globals.dm"

// Subsystems
#include "background_process.dm"

// Core portal machinery
#include "portal_machinery_core.dm"
#include "portal_machinery_processing.dm"
#include "portal_machinery_interaction.dm"

// Portal destinations
#include "portal_destinations_base.dm"
#include "portal_destinations_veilbreak.dm"
// FIXED: Include cleanup BEFORE generation to ensure proc definitions are available
#include "portal_destinations_cleanup.dm"
#include "portal_destinations_generation.dm"

// Control systems
#include "portal_control_core.dm"
#include "portal_control_ui.dm"
#include "portal_control_generation.dm"

// HTTP and external systems
#include "portal_http.dm"

// Debug and admin tools
#include "portal_debug.dm"
