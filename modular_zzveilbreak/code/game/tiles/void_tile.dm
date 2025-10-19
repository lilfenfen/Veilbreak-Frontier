/turf/open/floor/void_tile
	name = "Void Floor"
	desc = "A tile made from the very fabric of void itself. How are you even standing on this..."
	icon = 'modular_zzveilbreak/icons/tiles/void_tile.dmi'
	icon_state = "void_tile-0" // Use -0 for smoothing
	base_icon_state = "void_tile" // Required for smoothing
	initial_gas_mix = VOID_ATMOS
	planetary_atmos = TRUE
	light_range = 2.0
	light_power = 0.9
	light_color = LIGHT_COLOR_DEFAULT
	thermal_conductivity = 0.1
	heat_capacity = INFINITY
	footstep = FOOTSTEP_PLATING
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	tiled_dirt = FALSE
	rcd_proof = TRUE
	rust_resistance = RUST_RESISTANCE_ABSOLUTE
	resistance_flags = FIRE

	// CRITICAL: Transparency and visibility properties
	layer = GLASS_FLOOR_LAYER // (12 + TOPDOWN_LAYER)
	underfloor_accessibility = UNDERFLOOR_VISIBLE // 1

	// Smoothing setup (if you want connected textures)
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = list(SMOOTH_GROUP_TURF_OPEN, SMOOTH_GROUP_FLOOR_TRANSPARENT_GLASS)
	canSmoothWith = list(SMOOTH_GROUP_FLOOR_TRANSPARENT_GLASS)

	// Optional: if you want the emissive glow like glass floors
	var/alpha_to_leave = 190 // Match your current alpha
	var/list/glow_stuff

/turf/open/floor/void_tile/Initialize(mapload)
	icon_state = "" // Prevent normal icon from appearing behind smooth overlays
	. = ..()
	return INITIALIZE_HINT_LATELOAD // This is CRITICAL for transparency

/turf/open/floor/void_tile/LateInitialize()
	// THIS IS THE MOST IMPORTANT LINE - enables multi-Z transparency
	// Uses: ADD_TURF_TRANSPARENCY(src, INNATE_TRAIT)
	ADD_TURF_TRANSPARENCY(src, INNATE_TRAIT)

	// Optional: If you want space/underlayer glow effects
	setup_glow()

// Optional: Space glow setup (copied from glass floors)
/turf/open/floor/void_tile/proc/setup_glow()
	// Uses: GET_TURF_PLANE_OFFSET(src) and GET_LOWEST_STACK_OFFSET(z)
	if(GET_TURF_PLANE_OFFSET(src) != GET_LOWEST_STACK_OFFSET(z))
		return
	if(SSmapping.level_trait(z, ZTRAIT_NOPARALLAX))
		return

	// Uses: partially_block_emissives(src, alpha_to_leave)
	glow_stuff = partially_block_emissives(src, alpha_to_leave)
	set_light(2, 1, light_color, l_height = LIGHTING_HEIGHT_SPACE)

/turf/open/floor/void_tile/Destroy()
	. = ..()
	QDEL_LIST(glow_stuff)

/turf/open/floor/void_tile/break_tile()
	return //unbreakable

/turf/open/floor/void_tile/burn_tile()
	return //unbreakable

/turf/open/floor/void_tile/make_plating(force = FALSE)
	if(force)
		return ..()
	return //unplateable
