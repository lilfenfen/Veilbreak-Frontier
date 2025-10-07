// Veilbreak modular item: Voidshard
/obj/item/voidshard
	name = "Voidshard"
	desc = "One of the big reasons why the company is here. You can feel that it both sucks the light around and glows faintly. Wonder why they want it?"
	icon = 'modular_zzveilbreak/icons/item_icons/voidshard.dmi'
	icon_state = "voidshard"
	w_class = WEIGHT_CLASS_TINY // Small item
	light_range = 1.5 // Faint glow radius
	light_power = 0.5 // Faint glow intensity
	light_color = "#8a2be2" // Soft purple glow

var/bomb_primed = FALSE

verb/prime_bomb()
    set name = "Prime Voidshard Bomb"
    set desc = "Begin the unstable void reaction. Detonates after a short delay."
    if(bomb_primed)
        to_chat(usr, "<span class='danger'>The voidshard is already primed!</span>")
        return
    bomb_primed = TRUE
    to_chat(usr, "<span class='warning'>You feel the voidshard vibrate ominously...")
    spawn(100)
        if(src && bomb_primed)
            bomb_primed = FALSE
            // Use standard bomb explosion proc
            explosion(get_turf(src), 2, 4, 6, 0)
            qdel(src)

// Explode if hit by anything
/obj/item/voidshard/attackby(obj/item/W, mob/living/user)
    if(!bomb_primed)
        bomb_primed = TRUE
        to_chat(user, "<span class='warning'>The voidshard vibrates violently as it's struck!")
        spawn(100)
            if(src && bomb_primed)
                bomb_primed = FALSE
                explosion(get_turf(src), 2, 4, 6, 0)
                qdel(src)

// Activate in-hand with use item action
/obj/item/voidshard/attack_self(mob/living/user)
    if(bomb_primed)
        bomb_primed = FALSE
        to_chat(user, "<span class='notice'>You stabilize the voidshard. It stops vibrating.</span>")
    else
        bomb_primed = TRUE
        to_chat(user, "<span class='warning'>You feel the voidshard vibrate ominously in your hand...")
        spawn(100)
            if(src && bomb_primed)
                bomb_primed = FALSE
                explosion(get_turf(src), 2, 4, 6, 0)
                qdel(src)
