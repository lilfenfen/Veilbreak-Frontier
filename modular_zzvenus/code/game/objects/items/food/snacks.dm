/obj/item/food/protein_bar

	name = "protein bar"
	icon_state = "protein_bar"
	icon = 'modular_zzvenus/icons/obj/food/food.dmi'
	w_class = WEIGHT_CLASS_TINY
	food_reagents = list(/datum/reagent/consumable/nutriment/protein = 10)
	bite_consumption = 3
	post_init_icon_state = "protein_bar"
	foodtypes = GRAIN
	greyscale_config = /datum/greyscale_config/protein_bar
	flags_1 = NO_NEW_GAGS_PREVIEW_1

/obj/item/food/protein_bar/one
	name = "protein bar"
	desc = "The fakest looking protein bar you have ever laid eyes on, covered in substitution chocolate. The powder used to make these is a substitute of a substitute of whey substitute."
	greyscale_colors = "#f37d43" //default colors
	tastes = list("chalk" = 1, "cocoa" = 1)

/obj/item/food/protein_bar/two
	name = "mint protein bar"
	desc = "A protein bar with an almost minty freshness to it, but not fresh enough."
	greyscale_colors = "#61b36e"
	tastes = list("minty protein" = 1)

/obj/item/food/protein_bar/three
	name = "grape protein bar"
	desc = "Not the good type of grape flavor, tastes like medicine. Fills you up just as well as any protein bar."
	greyscale_colors = "#9900ff"
	tastes = list("artificial grape" = 1)

/obj/item/food/protein_bar/four
	name = "mystery protein bar"
	desc = "Some say they have tasted one of these and tasted their favorite childhood meal, especially for squad marines. Most say this tastes like crayons, though it fills like any other protein bar you've seen."
	greyscale_colors = "#ffffff"
	tastes = list("crayons" = 1)

/obj/item/food/protein_bar/five
	name = "dark chocolate protein bar"
	desc = "The dark chocolate flavor helps it out a bit, but it's still a cheap protein bar."
	greyscale_colors = "#5a3b1d"
	tastes = list("bitter dark chocolate" = 1)

/obj/item/food/protein_bar/six
	name = "milk chocolate protein bar"
	desc = "A nice milky addition to an otherwise bland protein taste."
	greyscale_colors = "#efc296"
	tastes = list("off flavor milk chocolate" = 1)

/obj/item/food/protein_bar/seven
	name = "raspberry lime protein bar"
	desc = "A flavored protein bar, some might say a bit too strong for their tastes."
	greyscale_colors = "#ff0066"
	tastes = list("sour raspberry and lime" = 1)

/obj/item/food/protein_bar/eight
	name = "chicken powder protein bar"
	desc = "A protein bar covered with chicken powder one might find in ramen. Get some extra chicken with your protein."
	greyscale_colors = "#cccc00"
	tastes = list("powdered chicken" = 1)

/obj/item/food/protein_bar/nine
	name = "blueberry protein bar"
	desc = "A nice blueberry crunch into your otherwise chalky and boring protein bar."
	greyscale_colors = "#4e39c5"
	tastes = list("blueberry" = 1)

/obj/item/food/protein_bar/base
	name = "protein bar"
	desc = "A protein bar produced for the TerraGov Marine Corps. Comes in many flavors."// this text is only seen at the vending machine, the actual item should never exist.
	greyscale_colors = "#efc296"

/obj/item/food/protein_bar/base/Initialize(mapload)
	. = ..()
	var/protein_bar_type = pick( ///which protein bar gets picked to generated when a protein_bar is spawned.
		/obj/item/food/protein_bar/one,
		/obj/item/food/protein_bar/two,
		/obj/item/food/protein_bar/three,
		/obj/item/food/protein_bar/four,
		/obj/item/food/protein_bar/five,
		/obj/item/food/protein_bar/six,
		/obj/item/food/protein_bar/seven,
		/obj/item/food/protein_bar/eight,
		/obj/item/food/protein_bar/nine)
	new protein_bar_type(loc)
	return INITIALIZE_HINT_QDEL
