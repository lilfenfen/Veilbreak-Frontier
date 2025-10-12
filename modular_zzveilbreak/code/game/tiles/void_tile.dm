/turf/open/floor/glass/void_tile
	name = "Void Floor"
	desc = "A tile made from the very fabric of void itself. How are you even standing on this..."
	icon = 'modular_zzveilbreak/icons/tiles/void_tile.dmi'
	icon_state = "void_tile"
	initial_gas_mix = VOID_ATMOS
	planetary_atmos = TRUE
	light_range = 2.0 //slightly less range than lava
	light_power = 0.65 //less bright, too
	light_color = LIGHT_COLOR_DEFAULT
	thermal_conductivity = 0.5
	heat_capacity = INFINITY
	footstep = FOOTSTEP_PLATING
	barefootstep = FOOTSTEP_HARD_BAREFOOT
	clawfootstep = FOOTSTEP_HARD_CLAW
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	tiled_dirt = FALSE
	rcd_proof = TRUE
	rust_resistance = RUST_RESISTANCE_ABSOLUTE
	resistance_flags = FIRE
	scrape_below = TRUE

/turf/open/floor/void_tile/break_tile()
	return //unbreakable

/turf/open/floor/void_tile/burn_tile()
	return //unbreakable

/turf/open/floor/void_tile/make_plating(force = FALSE)
	if(force)
		return ..()
	return //unplateable
