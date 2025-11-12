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
#include "portal_destinations_generation.dm"
#include "portal_destinations_cleanup.dm"

// Control systems
#include "portal_control_core.dm"
#include "portal_control_ui.dm"
#include "portal_control_generation.dm"

// HTTP and external systems
#include "portal_http.dm"

// Debug and admin tools
#include "portal_debug.dm"
