// modular_zzveilbreak/code/modules/dungeons/portal_designs.dm

// Protolathe designs for portal system
/datum/design/board/portal
	name = "Machine Design (Dimensional Portal)"
	desc = "The circuit board for a Dimensional Portal."
	id = "portal"
	build_path = /obj/item/circuitboard/machine/portal
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/portal_control
	name = "Machine Design (Portal Control Console)"
	desc = "The circuit board for a Portal Control Console."
	id = "portal_control"
	build_path = /obj/item/circuitboard/machine/portal_control
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
