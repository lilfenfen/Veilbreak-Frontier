//VENUS EDIT: Renamed from Default Andy to Balanced Barry
/datum/storyteller/default
	name = "Extended (No Chaos)"
	desc = "Peaceful station to enjoy projects or exploring. No harm expected other than crew-inflicted."
	welcome_text = "Parameters suggest that we are safe, unless we go and poke the..."
	antag_divisor = 0
	storyteller_type = STORYTELLER_TYPE_ALWAYS_AVAILABLE
	disable_distribution = TRUE
	guarantees_roundstart_crewset = FALSE

	tag_multipliers = list(
		TAG_CHAOTIC = 0
	)
