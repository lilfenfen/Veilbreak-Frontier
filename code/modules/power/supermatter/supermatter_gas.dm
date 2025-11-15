// modular_zzveilbreak/code/modules/power/supermatter/supermatter_gas.dm

/proc/init_sm_gas()
	var/list/gas_list = list()
	for (var/sm_gas_path in subtypesof(/datum/sm_gas))
		var/datum/sm_gas/sm_gas = new sm_gas_path
		gas_list[sm_gas.gas_path] = sm_gas
	return gas_list

/// Return a list info of the SM gases.
/// Can only run after init_sm_gas
/proc/sm_gas_data()
	var/list/data = list()
	for (var/gas_path in GLOB.sm_gas_behavior)
		var/datum/sm_gas/sm_gas = GLOB.sm_gas_behavior[gas_path]
		var/list/singular_gas_data = list()
		singular_gas_data["desc"] = sm_gas.desc

		// Positive is true if more of the amount is a good thing.
		var/list/numeric_data = list()
		if(sm_gas.power_transmission)
			var/list/si_derived_data = siunit_isolated(sm_gas.power_transmission * BASE_POWER_TRANSMISSION_RATE, "W/MeV", 2)
			numeric_data += list(list(
				"name" = "Power Transmission Bonus",
				"amount" = si_derived_data["coefficient"],
				"unit" = si_derived_data["unit"],
				"positive" = TRUE,
			))
		if(sm_gas.heat_modifier)
			numeric_data += list(list(
				"name" = "Waste Multiplier",
				"amount" = 100 * sm_gas.heat_modifier,
				"unit" = "%",
				"positive" = FALSE,
			))
		if(sm_gas.heat_resistance)
			numeric_data += list(list(
				"name" = "Heat Resistance",
				"amount" = 100 * sm_gas.heat_resistance,
				"unit" = "%",
				"positive" = TRUE,
			))
		if(sm_gas.heat_power_generation)
			var/list/si_derived_data = siunit_isolated(sm_gas.heat_power_generation * GAS_HEAT_POWER_SCALING_COEFFICIENT MEGA SECONDS / SSair.wait, "eV/K/s", 2)
			numeric_data += list(list(
				"name" = "Heat Power Gain",
				"amount" = si_derived_data["coefficient"],
				"unit" = si_derived_data["unit"],
				"positive" = TRUE,
			))
		if(sm_gas.powerloss_inhibition)
			numeric_data += list(list(
				"name" = "Power Decay Negation",
				"amount" = 100 * sm_gas.powerloss_inhibition,
				"unit" = "%",
				"positive" = TRUE,
			))
		singular_gas_data["numeric_data"] = numeric_data
		data[gas_path] = singular_gas_data
	return data

/// Assoc of sm_gas_behavior[/datum/gas (path)] = datum/sm_gas (instance)
GLOBAL_LIST_INIT(sm_gas_behavior, init_sm_gas())

GLOBAL_LIST_EMPTY(void_tile_cooldowns)
/// Contains effects of gases when absorbed by the sm.
/// If the gas has no effects you do not need to add another sm_gas subtype,
/// We already guard for nulls in [/obj/machinery/power/supermatter_crystal/proc/calculate_gases]
/datum/sm_gas
	/// Path of the [/datum/gas] involved with this interaction.
	var/gas_path
	/// Influences zap power without interfering with the crystal's own energy. Gets scaled by [BASE_POWER_TRANSMISSION_RATE].
	var/power_transmission = 0
	/// How much more waste heat and gas the SM generates.
	var/heat_modifier = 0
	/// How extra hot the SM can run before taking damage
	var/heat_resistance = 0
	/// Lets the sm generate extra power from heat. Yeah...
	var/heat_power_generation = 0
	/// How much powerloss do we get rid of.
	var/powerloss_inhibition = 0
	/// Give a short description of the gas if needed. If the gas have extra effects describe it here.
	var/desc

/datum/sm_gas/proc/extra_effects(obj/machinery/power/supermatter_crystal/sm)
	return

/datum/sm_gas/oxygen
	gas_path = /datum/gas/oxygen
	power_transmission = 0.15
	heat_power_generation = 1

/datum/sm_gas/nitrogen
	gas_path = /datum/gas/nitrogen
	heat_modifier = -2.5
	heat_power_generation = -1

/datum/sm_gas/carbon_dioxide
	gas_path = /datum/gas/carbon_dioxide
	heat_modifier = 1
	heat_power_generation = 1
	powerloss_inhibition = 1
	desc = "When absorbed by the Supermatter and exposed to oxygen, Pluoxium will be generated."

/// Can be on Oxygen or CO2, but better lump it here since CO2 is rarer.
/datum/sm_gas/carbon_dioxide/extra_effects(obj/machinery/power/supermatter_crystal/sm)
	if(!sm.gas_percentage[/datum/gas/carbon_dioxide] || !sm.gas_percentage[/datum/gas/oxygen])
		return
	var/co2_pp = sm.absorbed_gasmix.return_pressure() * sm.gas_percentage[/datum/gas/carbon_dioxide]
	var/co2_ratio = clamp((1/2 * (co2_pp - CO2_CONSUMPTION_PP) / (co2_pp + CO2_PRESSURE_SCALING)), 0, 1)
	var/consumed_co2 = sm.absorbed_gasmix.gases[/datum/gas/carbon_dioxide][MOLES] * co2_ratio
	consumed_co2 = min(
		consumed_co2,
		sm.absorbed_gasmix.gases[/datum/gas/carbon_dioxide][MOLES],
		sm.absorbed_gasmix.gases[/datum/gas/oxygen][MOLES]
	)
	if(!consumed_co2)
		return
	sm.absorbed_gasmix.gases[/datum/gas/carbon_dioxide][MOLES] -= consumed_co2
	sm.absorbed_gasmix.gases[/datum/gas/oxygen][MOLES] -= consumed_co2
	ASSERT_GAS(/datum/gas/pluoxium, sm.absorbed_gasmix)
	sm.absorbed_gasmix.gases[/datum/gas/pluoxium][MOLES] += consumed_co2

/datum/sm_gas/plasma
	gas_path = /datum/gas/plasma
	heat_modifier = 14
	power_transmission = 0.4
	heat_power_generation = 1

/datum/sm_gas/water_vapor
	gas_path = /datum/gas/water_vapor
	heat_modifier = 11
	power_transmission = -0.25
	heat_power_generation = 1

/datum/sm_gas/hypernoblium
	gas_path = /datum/gas/hypernoblium
	heat_modifier = -14
	power_transmission = 0.3
	heat_power_generation = -1

/datum/sm_gas/nitrous_oxide
	gas_path = /datum/gas/nitrous_oxide
	heat_resistance = 5

/datum/sm_gas/tritium
	gas_path = /datum/gas/tritium
	heat_modifier = 9
	power_transmission = 3
	heat_power_generation = 1

/datum/sm_gas/bz
	gas_path = /datum/gas/bz
	heat_modifier = 4
	power_transmission = -0.2
	heat_power_generation = 1
	desc = "Will emit nuclear particles at compositions above 40%"

/// Start to emit radballs at a maximum of 30% chance per tick
/datum/sm_gas/bz/extra_effects(obj/machinery/power/supermatter_crystal/sm)
	if(sm.gas_percentage[/datum/gas/bz] > 0.4 && prob(30 * sm.gas_percentage[/datum/gas/bz]))
		sm.fire_nuclear_particle()

/datum/sm_gas/pluoxium
	gas_path = /datum/gas/pluoxium
	heat_modifier = -1.5
	power_transmission = -0.5
	heat_power_generation = -1

/datum/sm_gas/miasma
	gas_path = /datum/gas/miasma
	heat_power_generation = 0.5
	desc = "Will be consumed by the Supermatter to generate power."

///Miasma is really just microscopic particulate. It gets consumed like anything else that touches the crystal.
/datum/sm_gas/miasma/extra_effects(obj/machinery/power/supermatter_crystal/sm)
	if(!sm.gas_percentage[/datum/gas/miasma])
		return
	var/miasma_pp = sm.absorbed_gasmix.return_pressure() * sm.gas_percentage[/datum/gas/miasma]
	var/miasma_ratio = clamp(((miasma_pp - MIASMA_CONSUMPTION_PP) / (miasma_pp + MIASMA_PRESSURE_SCALING)) * (1 + (sm.gas_heat_power_generation * MIASMA_GASMIX_SCALING)), 0, 1)
	var/consumed_miasma = sm.absorbed_gasmix.gases[/datum/gas/miasma][MOLES] * miasma_ratio
	if(!consumed_miasma)
		return
	sm.absorbed_gasmix.gases[/datum/gas/miasma][MOLES] -= consumed_miasma
	sm.external_power_trickle += consumed_miasma * MIASMA_POWER_GAIN
	sm.log_activation("miasma absorption")

/datum/sm_gas/freon
	gas_path = /datum/gas/freon
	heat_modifier = -9
	power_transmission = -3
	heat_power_generation = -1

/datum/sm_gas/hydrogen
	gas_path = /datum/gas/hydrogen
	heat_modifier = 9
	power_transmission = 2.5
	heat_resistance = 1
	heat_power_generation = 1

/datum/sm_gas/healium
	gas_path = /datum/gas/healium
	heat_modifier = 3
	power_transmission = 0.24
	heat_power_generation = 1

/datum/sm_gas/proto_nitrate
	gas_path = /datum/gas/proto_nitrate
	heat_modifier = -4
	power_transmission = 1.5
	heat_resistance = 4
	heat_power_generation = 1

/datum/sm_gas/zauker
	gas_path = /datum/gas/zauker
	heat_modifier = 7
	power_transmission = 2
	heat_power_generation = 1
	desc = "Will generate electrical zaps."

/datum/sm_gas/zauker/extra_effects(obj/machinery/power/supermatter_crystal/sm)
	if(!prob(sm.gas_percentage[/datum/gas/zauker] * 100))
		return
	playsound(sm.loc, 'sound/items/weapons/emitter2.ogg', 100, TRUE, extrarange = 10)
	sm.supermatter_zap(
		sm,
		range = 6,
		zap_str = clamp(sm.internal_energy * 1.6 KILO JOULES, 3.2 MEGA JOULES, 16 MEGA JOULES),
		zap_flags = ZAP_MOB_STUN,
		zap_cutoff = sm.zap_cutoff,
		power_level = sm.internal_energy,
		zap_icon = sm.zap_icon
	)

/datum/sm_gas/antinoblium
	gas_path = /datum/gas/antinoblium
	heat_modifier = 14
	power_transmission = -0.5
	heat_power_generation = 1

/datum/sm_gas/delirium
	gas_path = /datum/gas/delirium
	heat_modifier = 15
	power_transmission = 6
	heat_power_generation = 1.7
	powerloss_inhibition = 2
	desc = "Strong fuel with unknown properties. Be extremely careful while testing."

GLOBAL_LIST_EMPTY(delirium_warnings)

/datum/sm_gas/delirium/proc/transform_and_summon(obj/machinery/power/supermatter_crystal/sm)
	if(QDELETED(sm) || sm.gas_percentage[/datum/gas/delirium] <= 0.1)
		return

	var/turf/open/floor/target_turf
	// Iterate from the closest distance outwards to the max range to find a tile to convert.
	for(var/dist in 4 to 8)
		var/list/possible_turfs_at_dist = list()
		for(var/turf/open/floor/floor in range(dist, sm))
			if(get_dist(floor, sm) == dist && !istype(floor, /turf/open/floor/void_tile))
				possible_turfs_at_dist += floor

		if(length(possible_turfs_at_dist))
			target_turf = pick(possible_turfs_at_dist)
			break // Found a tile at the closest possible distance, so we stop searching.

	if(target_turf)
		target_turf.ChangeTurf(/turf/open/floor/void_tile, flags = CHANGETURF_INHERIT_AIR)

		if(prob(25))
			// FIXED: Use new basic mob types instead of old simple_animal types
			var/mob_type = pick(
				/mob/living/basic/void_creature/voidling,
				/mob/living/basic/void_creature/consumed_pathfinder,
				/mob/living/basic/void_creature/voidbug,
				/mob/living/basic/void_creature/void_healer,
			)
			new mob_type(target_turf)

		// Schedule the next transformation and summon
		addtimer(CALLBACK(src, PROC_REF(transform_and_summon), sm), 5 SECONDS)

/datum/sm_gas/delirium/extra_effects(obj/machinery/power/supermatter_crystal/sm)
	if(sm.gas_percentage[/datum/gas/delirium] > 0.1)
		if(!GLOB.delirium_warnings[sm])
			for(var/mob/M in range(150, sm))  // Wide range warning
				to_chat(M, span_warning("The fabric of reality shudders as the Void begins to manifest around the supermatter!"))
			GLOB.delirium_warnings[sm] = world.time
			// Start the transformation and summoning loop
			INVOKE_ASYNC(src, PROC_REF(transform_and_summon), sm)
		if(!sm.get_filter("delirium_glow"))
			sm.add_filter("delirium_glow", 1, list("type" = "outline", "color" = "#8a2be2", "size" = 1))
			var/filter = sm.get_filter("delirium_glow")
			animate(filter, size = 3, time = 10, loop = -1)
			animate(size = 1, time = 10)
		visible_hallucination_pulse_delirium(sm, 150, 50 SECONDS)
	else
		if(GLOB.delirium_warnings[sm])
			GLOB.delirium_warnings -= sm
		sm.remove_filter("delirium_glow")
