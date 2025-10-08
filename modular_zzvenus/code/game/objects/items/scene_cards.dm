//VENUS - BAYSTATION PORT
/obj/item/storage/csi_markers
	name = "crime scene markers box"
	desc = "A cardboard box for crime scene marker cards."
	icon = 'modular_zzvenus/icons/obj/forensics/forensics.dmi'
	icon_state = "cards"
	w_class = WEIGHT_CLASS_TINY

/obj/item/storage/csi_markers/PopulateContents()
	new /obj/item/csi_marker/n1(src)
	new /obj/item/csi_marker/n2(src)
	new /obj/item/csi_marker/n3(src)
	new /obj/item/csi_marker/n4(src)
	new /obj/item/csi_marker/n5(src)
	new /obj/item/csi_marker/n6(src)
	new /obj/item/csi_marker/n7(src)

/obj/item/csi_marker
	name = "crime scene marker"
	desc = "Plastic cards used to mark points of interests on the scene. Just like in the holoshows!"
	icon = 'modular_zzvenus/icons/obj/forensics/forensics.dmi'
	icon_state = "card1"
	w_class = WEIGHT_CLASS_TINY
	layer = ABOVE_MOB_LAYER  //so you can mark bodies
	var/number = 1
	custom_materials = list(/datum/material/plastic = 1)

/obj/item/csi_marker/examine(mob/user)
	. = ..()
	. += ("This one is marked with number [number].")

/obj/item/csi_marker/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/floor_placeable)
	icon_state = "card[clamp(number,1,7)]"

/obj/item/csi_marker/n1
	number = 1
/obj/item/csi_marker/n2
	number = 2
/obj/item/csi_marker/n3
	number = 3
/obj/item/csi_marker/n4
	number = 4
/obj/item/csi_marker/n5
	number = 5
/obj/item/csi_marker/n6
	number = 6
/obj/item/csi_marker/n7
	number = 7
