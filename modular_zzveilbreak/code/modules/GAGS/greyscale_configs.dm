/datum/greyscale_config/void_ring
	name = "Void Ring"
	icon_file = 'modular_zzveilbreak/icons/item_icons/voidring.dmi'
	json_config = 'modular_zzveilbreak/code/modules/GAGS/json_configs/items/void_ring.json'

/obj/item/clothing/head/void_ring
	name = "Void Ring"
	greyscale_config = /datum/greyscale_config/void_ring
	greyscale_colors = "#FF0000#00FF00" // Red base, green trim

/obj/item/clothing/head/void_ring/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/gags_recolorable)
