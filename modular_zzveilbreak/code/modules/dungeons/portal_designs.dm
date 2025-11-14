// modular_zzveilbreak/code/modules/dungeons/portal_designs.dm

/datum/design/board/portal
	name = "Machine Design (Dimensional Portal)"
	desc = "The circuit board for a Dimensional Portal."
	id = "portal"
	build_path = /obj/item/circuitboard/machine/portal
	category = list(RND_CATEGORY_MACHINE)
	departmental_flags = DEPARTMENT_ASSISTANT

/datum/design/board/portal_control
	name = "Computer Design (Portal Control Console)"
	desc = "The circuit board for a Portal Control Console."
	id = "portal_control"
	build_path = /obj/item/circuitboard/computer/portal_control
	category = list(RND_CATEGORY_COMPUTER)
	departmental_flags = DEPARTMENT_ASSISTANT
