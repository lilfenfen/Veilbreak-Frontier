//VENUS - BAYSTATION PORT
/obj/item/taperoll
	name = "tape roll"
	icon = 'modular_zzvenus/icons/obj/forensics/policetape.dmi'
	icon_state = "tape"
	w_class = WEIGHT_CLASS_SMALL
	var/turf/start
	var/turf/end
	var/tape_type = /obj/item/tape_barrier
	var/icon_base = "tape"

	var/apply_tape = FALSE
	var/uses_remaining = 30
	var/max_uses = 30
	custom_materials = list(/datum/material/plastic = 1)

/obj/item/taperoll/proc/consume_tape(count = 1)
	if(uses_remaining <= 0)
		return FALSE
	uses_remaining = max(0, uses_remaining - count)
	var/now_empty = (uses_remaining <= 0)
	update_appearance()
	if(now_empty)
		qdel(src)
	return TRUE

/obj/item/taperoll/Initialize()
	. = ..()
	update_appearance()
	if(apply_tape)
		var/turf/T = get_turf(src)
		if(!T)
			return
		var/obj/machinery/door/airlock/airlock = locate(/obj/machinery/door/airlock) in T
		if(airlock)
			place_tape_on_airlock(airlock, null)
		return INITIALIZE_HINT_QDEL

var/global/list/tape_roll_applications = list()

/obj/item/taperoll/examine(mob/user)
	. = ..()
	. += "It has [uses_remaining] uses remaining."
	. += "[span_notice("Use in-hand to begin placing tape.")]"
	. += "[span_notice("Use it on an airlock to place tape on it.")]"

/obj/item/tape_barrier
	name = "tape"
	icon = 'modular_zzvenus/icons/obj/forensics/policetape.dmi'
	icon_state = "tape"
	layer = ABOVE_OBJ_LAYER
	anchored = TRUE
	var/lifted = FALSE
	var/crumpled = FALSE
	var/tape_dir = 0
	var/icon_base = "tape"
	var/detail_overlay
	var/detail_color
	var/roll_type = /obj/item/taperoll
	custom_materials = list(/datum/material/plastic = 1)

/obj/item/tape_barrier/Initialize(mapload)
	. = ..()
	// Enable contextual screentips (Type-B) for hover hints
	register_context()

/obj/item/tape_barrier/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	context[SCREENTIP_CONTEXT_LMB] = "Lift temporarily (Help intent) - Break (Harm intent)"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/tape_barrier/update_icon()
	. = ..()
	//Possible directional bitflags: 0 (AIRLOCK), 1 (NORTH), 2 (SOUTH), 4 (EAST), 8 (WEST), 3 (VERTICAL), 12 (HORIZONTAL)
	cut_overlays()
	var/new_state
	switch (tape_dir)
		if(0)  // AIRLOCK
			new_state = "[icon_base]_door"
		if(3)  // VERTICAL
			new_state = "[icon_base]_v"
		if(12) // HORIZONTAL
			new_state = "[icon_base]_h"
		else   // END POINT (1|2|4|8)
			new_state = "[icon_base]_dir"
			dir = tape_dir
	icon_state = "[new_state]_[crumpled]"
	if(detail_overlay)
		var/mutable_appearance/I = mutable_appearance(icon, "[new_state]_[detail_overlay]", appearance_flags = RESET_COLOR)
		I.color = detail_color
		add_overlay(I)

/obj/item/tape_barrier/examine(mob/user)
	. = ..()
	. += span_notice("Running into this Harmfully will crumple it.")

/obj/item/taperoll/police
	name = "police tape"
	desc = "A roll of police tape used to block off crime scenes from the public."
	tape_type = /obj/item/tape_barrier/police
	color = COLOR_RED

/obj/item/tape_barrier/police
	name = "police tape"
	desc = "A length of police tape. Do not cross. Can only be passed by lifting it."
	req_access = list(ACCESS_BRIG)
	color = COLOR_RED
	roll_type = /obj/item/taperoll/police

/obj/item/taperoll/engineering
	name = "engineering tape"
	desc = "A roll of engineering tape used to block off working areas from the public."
	tape_type = /obj/item/tape_barrier/engineering
	color = COLOR_ENGINEERING_ORANGE

/obj/item/tape_barrier/engineering
	name = "engineering tape"
	desc = "A length of engineering tape. Better not cross it. Can only be passed by lifting it."
	req_access = list(list(ACCESS_ENGINEERING,ACCESS_ATMOSPHERICS))
	color = COLOR_ENGINEERING_ORANGE
	roll_type = /obj/item/taperoll/engineering

/obj/item/taperoll/atmos
	name = "atmospherics tape"
	desc = "A roll of atmospherics tape used to block off working areas from the public."
	tape_type = /obj/item/tape_barrier/atmos
	color = COLOR_YELLOW

/obj/item/tape_barrier/atmos
	name = "atmospherics tape"
	desc = "A length of atmospherics tape. Better not cross it. Can only be passed by lifting it."
	req_access = list(list(ACCESS_ENGINEERING,ACCESS_ATMOSPHERICS))
	color = COLOR_YELLOW
	icon_base = "stripetape"
	detail_overlay = "stripes"
	detail_color = COLOR_BLUE_LIGHT
	roll_type = /obj/item/taperoll/atmos

/obj/item/taperoll/research
	name = "research tape"
	desc = "A roll of research tape used to block off working areas from the public."
	tape_type = /obj/item/tape_barrier/research
	color = COLOR_SCIENCE_PINK

/obj/item/tape_barrier/research
	name = "research tape"
	desc = "A length of research tape. Better not cross it. Can only be passed by lifting it."
	req_access = list(ACCESS_RESEARCH)
	color = COLOR_SCIENCE_PINK
	roll_type = /obj/item/taperoll/research

/obj/item/taperoll/medical
	name = "medical tape"
	desc = "A roll of medical tape used to block off working areas from the public."
	tape_type = /obj/item/tape_barrier/medical
	color = COLOR_MEDICAL_BLUE

/obj/item/tape_barrier/medical
	name = "medical tape"
	desc = "A length of medical tape. Better not cross it. Can only be passed by lifting it."
	req_access = list(ACCESS_MEDICAL)
	icon_base = "stripetape"
	detail_overlay = "stripes"
	detail_color = COLOR_MEDICAL_BLUE
	roll_type = /obj/item/taperoll/medical

/obj/item/taperoll/bureaucracy
	name = "red tape"
	desc = "A roll of bureaucratic red tape used to block any meaningful work from being done."
	tape_type = /obj/item/tape_barrier/bureaucracy
	color = COLOR_RED

/obj/item/tape_barrier/bureaucracy
	name = "red tape"
	desc = "A length of bureaucratic red tape. Safely ignored, but darn obstructive sometimes. Can only be passed by lifting it."
	icon_base = "stripetape"
	color = COLOR_RED
	detail_overlay = "stripes"
	detail_color = COLOR_RED
	roll_type = /obj/item/taperoll/bureaucracy

/obj/item/taperoll/update_icon()
	. = ..()
	cut_overlays()
	var/mutable_appearance/overlay = mutable_appearance(icon)
	overlay.appearance_flags = RESET_COLOR
	if(ismob(loc))
		if(!start)
			overlay.icon_state = "start"
		else
			overlay.icon_state = "stop"
		add_overlay(overlay)

/obj/item/taperoll/dropped(mob/user)
	. = ..()
	update_appearance(UPDATE_ICON)
	return .

/obj/item/taperoll/pickup(mob/user)
	. = ..()
	update_appearance(UPDATE_ICON)
	return .

/obj/item/taperoll/attack_hand()
	. = ..()
	update_appearance(UPDATE_ICON)
	return .

/obj/item/taperoll/attack_self(mob/user as mob)
	if(!start)
		if(uses_remaining <= 0)
			to_chat(user, span_warning("You're out of tape!"))
			return
		start = get_turf(src)
		to_chat(user, span_notice("You place the first end of \the [src]."))
		playsound(src, SFX_RUSTLE, 50, TRUE)
		update_icon()
	else
		end = get_turf(src)
		if(start.y != end.y && start.x != end.x || start.z != end.z)
			start = null
			update_icon()
			to_chat(user, span_notice("\The [src] can only be laid horizontally or vertically."))
			return

		if(start == end)
			var/turf/T
			var/possible_dirs = 0
			for(var/dir in GLOB.cardinals)
				T = get_step(start, dir)
				if(T && T.density)
					possible_dirs += dir
				else
					for(var/obj/structure/window/W in T)
						if(W.fulltile || W.dir == REVERSE_DIR(dir))
							possible_dirs += dir
			if(!possible_dirs)
				start = null
				update_icon()
				to_chat(user, span_notice("You can't place \the [src] here."))
				return
			if(possible_dirs & (NORTH|SOUTH))
				if(!consume_tape())
					to_chat(user, span_warning("You're out of tape!"))
					start = null
					update_icon()
					return
				var/obj/item/tape_barrier/TP = new tape_type(start)
				for(var/dir in list(NORTH, SOUTH))
					if (possible_dirs & dir)
						TP.tape_dir += dir
				TP.add_fingerprint(user)
				TP.update_icon()
			if(possible_dirs & (EAST|WEST))
				if(!consume_tape())
					to_chat(user, span_warning("You're out of tape!"))
					start = null
					update_icon()
					return
				var/obj/item/tape_barrier/TP = new tape_type(start)
				for(var/dir in list(EAST, WEST))
					if (possible_dirs & dir)
						TP.tape_dir += dir
				TP.add_fingerprint(user)
				TP.update_icon()
			start = null
			update_icon()
			to_chat(user, span_notice("You finish placing \the [src]."))
			playsound(src, SFX_RUSTLE, 50, TRUE)
			return

		var/turf/cur = start
		var/orientation = get_dir(start, end)
		var/dir = 0
		switch(orientation)
			if(NORTH, SOUTH)	dir = NORTH|SOUTH	// North-South taping
			if(EAST,   WEST)	dir =  EAST|WEST	// East-West taping

		var/can_place = 1
		while (can_place)
			if(cur.density)
				can_place = 0
			else if (istype(cur, /turf/open/space))
				can_place = 0
			else
				for(var/obj/O in cur)
					if(O.density)
						can_place = 0
						break
			if(cur == end)
				break
			cur = get_step_towards(cur,end)
		if (!can_place)
			start = null
			update_icon()
			to_chat(usr, span_warning("You can't run \the [src] through that!"))
			return

		cur = start
		var/tapetest
		var/tape_dir
		while (1)
			tapetest = 0
			tape_dir = dir
			if(cur == start)
				var/turf/T = get_step(start, REVERSE_DIR(orientation))
				if(T && !T.density)
					tape_dir = orientation
					for(var/obj/structure/window/W in T)
						if(W.fulltile || W.dir == orientation)
							tape_dir = dir
			else if(cur == end)
				var/turf/T = get_step(end, orientation)
				if(T && !T.density)
					tape_dir = REVERSE_DIR(orientation)
					for(var/obj/structure/window/W in T)
						if(W.fulltile || W.dir == REVERSE_DIR(orientation))
							tape_dir = dir
			for(var/obj/item/tape_barrier/T in cur)
				if((T.tape_dir == tape_dir) && (T.icon_base == icon_base))
					tapetest = 1
					break
			if(!tapetest)
				if(!consume_tape())
					to_chat(user, span_warning("You're out of tape!"))
					break
				var/obj/item/tape_barrier/T = new tape_type(cur)
				T.add_fingerprint(user)
				T.tape_dir = tape_dir
				T.update_icon()
				if(tape_dir & SOUTH)
					T.layer += 0.1 // Must always show above other tapes
			if(cur == end)
				break
			cur = get_step_towards(cur,end)
		start = null
		update_icon()
		to_chat(user, span_notice("You finish placing \the [src]."))
		playsound(src, SFX_RUSTLE, 50, TRUE)
		return

/obj/item/taperoll/proc/place_tape_on_airlock(obj/machinery/door/airlock/A, mob/living/user)
	var/turf/T = get_turf(A)
	if(locate(/obj/item/tape_barrier) in T)
		to_chat(user, span_warning("There is already tape on the [A.name]!"))
		return FALSE
	if(user)
		if(!consume_tape())
			to_chat(user, span_warning("You're out of tape!"))
			return FALSE
	var/obj/item/tape_barrier/P = new tape_type(T)
	if(user)
		P.add_fingerprint(user)
	P.update_icon()
	P.layer = ABOVE_MOB_LAYER
	if(user)
		to_chat(user, span_notice("You finish placing \the [src] on \the [A]."))
		playsound(A, SFX_RUSTLE, 50, TRUE)
	return TRUE

/// Allow placing tape on airlocks via non-combat interaction as well
/obj/item/taperoll/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(istype(interacting_with, /obj/machinery/door/airlock))
		place_tape_on_airlock(interacting_with, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/obj/item/tape_barrier/proc/crumple()
	if(!crumpled)
		crumpled = TRUE
		playsound(src, SFX_RUSTLE, 50, TRUE)
		update_icon()
		name = "crumpled [name]"

/obj/item/tape_barrier/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(!lifted && !crumpled && ismob(mover))
		return FALSE
	return ..(mover)

/obj/item/tape_barrier/Bumped(atom/movable/AM)
	. = ..()
	if(!lifted && ismob(AM))
		var/mob/living/L = AM
		// On harm intent, crumple (also leave forensics). Non-harm (help/disarm/grab or combat off) will not crumple.
		var/is_harm = FALSE
		if(isnum(L.combat_mode))
			is_harm = (L.combat_mode == INTENT_HARM)
		else
			is_harm = !!L.combat_mode
		if(is_harm)
			add_fingerprint(L)
			crumple()

/obj/item/tape_barrier/use_tool(atom/target, mob/living/user, delay, amount=0, volume=0, datum/callback/extra_checks)
	if (isliving(user))
		var/mob/living/L = user
		var/is_harm = FALSE
		if(isnum(L.combat_mode))
			is_harm = (L.combat_mode == INTENT_HARM)
		else
			is_harm = !!L.combat_mode
		if(!is_harm)
			return ..()
	breaktape(user)

/obj/item/tape_barrier/attack_hand(mob/user as mob)
	if (isliving(user))
		var/mob/living/L = user
		var/is_harm = FALSE
		if(isnum(L.combat_mode))
			is_harm = (L.combat_mode == INTENT_HARM)
		else
			is_harm = !!L.combat_mode
		if(!is_harm)
			user.visible_message(span_notice("\the [user] lifts \the [src], allowing passage."), span_notice("You lift \the [src], allowing passage."))
			for(var/obj/item/tape_barrier/T in gettapeline())
				T.lift(10 SECONDS)
			return
	breaktape(user)

/obj/item/tape_barrier/proc/lift(time)
	lifted = TRUE
	layer = ABOVE_MOB_LAYER
	addtimer(CALLBACK(src, PROC_REF(lift_timer), time), time)

/obj/item/tape_barrier/proc/lift_timer(time)
	lifted = FALSE
	layer = initial(layer)

// Returns a list of all tape objects connected to src, including itself.
/obj/item/tape_barrier/proc/gettapeline()
	var/list/dirs = list()
	if(tape_dir & NORTH)
		dirs += NORTH
	if(tape_dir & SOUTH)
		dirs += SOUTH
	if(tape_dir & WEST)
		dirs += WEST
	if(tape_dir & EAST)
		dirs += EAST

	var/list/obj/item/tape_barrier/tapeline = list()
	for (var/obj/item/tape_barrier/T in get_turf(src))
		tapeline += T
	for(var/dir in dirs)
		var/turf/cur = get_step(src, dir)
		var/not_found = FALSE
		while (!not_found)
			not_found = TRUE
			for (var/obj/item/tape_barrier/T in cur)
				tapeline += T
				not_found = FALSE
			cur = get_step(cur, dir)
	return tapeline


/obj/item/tape_barrier/proc/breaktape(mob/user)
	if(isliving(user))
		var/mob/living/L = user
		if(L.combat_mode == INTENT_HELP)
			to_chat(user, span_warning("You refrain from breaking \the [src]."))
			return
	user.visible_message(span_notice("\The [user] breaks \the [src]!"),span_notice("You break \the [src]."))
	playsound(src, SFX_RUSTLE, 50, TRUE)

	var/recovered = 0
	for (var/obj/item/tape_barrier/T in gettapeline())
		if(T == src)
			continue
		if(T.tape_dir & get_dir(T, src))
			if(!T.crumpled)
				recovered++
			qdel(T)
	if(!crumpled)
		recovered++

	if(recovered > 0)
		var/turf/drop_loc = user ? get_turf(user) : get_turf(src)
		var/obj/item/taperoll/new_roll = new roll_type(drop_loc)
		// uses_remaining must be set last, since some subtypes may modify appearance
		new_roll.uses_remaining = min(new_roll.max_uses, recovered)
		new_roll.update_appearance()

	qdel(src) //TODO: Dropping a trash item holding fibers/fingerprints of all broken tape parts
	return

/obj/item/taperoll/attackby(obj/item/I, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(I, /obj/item/taperoll))
		var/obj/item/taperoll/R = I
		if(R.tape_type != tape_type)
			return ..()
		var/space_left = max_uses - uses_remaining
		if(space_left <= 0)
			balloon_alert(user, "full")
			return TRUE
		var/to_transfer = min(space_left, R.uses_remaining)
		if(to_transfer <= 0)
			return TRUE
		uses_remaining += to_transfer
		R.uses_remaining -= to_transfer
		update_appearance()
		R.update_appearance()
		playsound(src, SFX_RUSTLE, 50, TRUE)
		if(user)
			to_chat(user, span_notice("Your tape roll now contains [uses_remaining] tapes."))
		if(R.uses_remaining <= 0)
			qdel(R)
		else
			balloon_alert(user, "+[to_transfer]")
		return TRUE
	return ..()
