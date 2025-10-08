/mob/Initialize(mapload)
	set_thirst(rand(THIRST_LEVEL_START_MIN, THIRST_LEVEL_START_MAX))
	. = ..()
