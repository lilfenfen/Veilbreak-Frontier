// modular_zzveilbreak/code/modules/dungeons/portal_components.dm

/// Circuit board for the Dimensional Portal
/obj/item/circuitboard/portal
	name = "Dimensional Portal (Circuit Board)"
	desc = "A circuit board for a dimensional portal."
	build_path = /obj/machinery/portal
	board_type = "machine"
	origin_tech = list(TECH_BLUESPACE = 5, TECH_POWER = 5, TECH_MAGNET = 4)
	req_components = list(
		/obj/item/stock_parts/scanning_module = 5,
		/obj/item/stock_parts/laser_emitter = 5,
		/obj/item/stock_parts/capacitor = 5,
		/obj/item/stock_parts/servo = 5
	)

/// Set the board path for the portal machinery so it can be deconstructed correctly.
/obj/machinery/portal
	board_path = /obj/item/circuitboard/portal

/// Protolathe recipe for the portal circuit board
/datum/protolathe_recipe/circuit/portal
	name = "Dimensional Portal"
	desc = "A circuit board for a dimensional portal."
	result_path = /obj/item/circuitboard/portal
