/datum/storyteller/default
	name = "Peaceful (Events Only)"
	desc = "A peaceful station to enjoy projects or exploring. Random events may occur, but no antagonists are expected."
	welcome_text = "Parameters suggest a peaceful round with anomalous events. Good luck exploring, Frontiers."
	antag_divisor = 0
	storyteller_type = STORYTELLER_TYPE_ALWAYS_AVAILABLE
	disable_distribution = FALSE
	guarantees_roundstart_crewset = FALSE

	tag_multipliers = list(
		TAG_CHAOTIC = 0,
		TAG_ANTAGONIST = 0
	)
