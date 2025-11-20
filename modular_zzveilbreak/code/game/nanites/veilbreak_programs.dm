/datum/nanite_program/protocol/quantum
	name = "Quantum Replication"
	desc = "Borrows replication power while inside the void. Pays the debt later on by slowing down the production on outside of the void. Increases replication speed by 3.5 per cycle"
	use_rate = 0.1
	rogue_types = list(/datum/nanite_program/necrotic)
	protocol_class = NANITE_PROTOCOL_REPLICATION
	var/in_void = FALSE

/datum/nanite_program/protocol/quantum/check_conditions()
	var/turf/T = get_turf(host_mob)
	in_void = istype(T, /turf/open/floor/void_tile)
	return ..()

/datum/nanite_program/protocol/quantum/active_effect()
	. = ..()
	if(in_void)
		nanites.adjust_nanites(null, 3.6)

/datum/nanite_program/regenerative/e_regen
	name = "Efficient Regenation"
	desc = "Programs the nanites to regen slowly but very efficiently compared to other regens."
	use_rate = 0.2
	healing_rate = 0.4
	rogue_types = list(/datum/nanite_program/necrotic)
	always_active = TRUE

/datum/nanite_program/regenerative/f_regen
	name = "Fast Regeneration"
	desc = "Programs the nanites to regenerate the host's wounds at a fast pace, but at the cost of efficiency."
	use_rate = 8
	healing_rate = 10
	rogue_types = list(/datum/nanite_program/necrotic)
	always_active = TRUE
