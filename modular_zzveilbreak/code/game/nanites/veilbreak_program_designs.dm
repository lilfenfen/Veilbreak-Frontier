//This file is for nanite program designs that are unique to veilbreak

/datum/design/nanites/veilbreak_quantum
	name = "Quantum Replication"
	desc = "A nanite program that takes advantage of the void to replicate faster."
	id = "nanite_veilbreak_quantum"
	program_type = /datum/nanite_program/protocol/quantum
	category = list(NANITE_CATEGORY_PROTOCOLS)
	department_tech = list(TECHWEB_NANITE_PROTOCOLS)

/datum/design/nanites/veilbreak_e_regen
	name = "Efficient Regeneration"
	desc = "A nanite program that provides slow but highly efficient healing."
	id = "nanite_veilbreak_e_regen"
	program_type = /datum/nanite_program/regenerative/e_regen
	category = list(NANITE_CATEGORY_MEDICAL)
	department_tech = list(TECHWEB_NANITE_HARMONIC)

/datum/design/nanites/veilbreak_f_regen
	name = "Fast Regeneration"
	desc = "A nanite program that provides rapid healing at a high energy cost."
	id = "nanite_veilbreak_f_regen"
	program_type = /datum/nanite_program/regenerative/f_regen
	category = list(NANITE_CATEGORY_MEDICAL)
	department_tech = list(TECHWEB_NANITE_HARMONIC)
