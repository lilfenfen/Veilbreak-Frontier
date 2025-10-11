
// Weighted loot table (e.g., for random drops with chances)
/var/list/voidling_loot_table = list(
    /obj/item/stack/sheet/bluespace_crystal = 10,
    /obj/item/stack/sheet/mineral/diamond = 10,
    /obj/item/stack/sheet/mineral/gold = 10,
    /obj/item/stack/sheet/mineral/silver = 10,
    /obj/item/stack/sheet/plasteel = 30,
    /obj/item/stack/sheet/glass = 30,
    /obj/item/clothing/neck/aether_pendant = 0.1,  // 0.1% chance
    /obj/item/clothing/neck/life_pendant = 0.1  // 0.1% chance
)

/var/list/inai_drops = list(
	/obj/item/voidshard = 33,
	/obj/item/clothing/neck/aether_pendant = 33,  // 33% chance
	/obj/item/clothing/neck/life_pendant = 33  // 33% chance
)

/var/list/consumed_pathfinder_drops = list(
	/obj/item/voidshard = 10,
	/obj/item/clothing/neck/aether_pendant = 10,
	/obj/item/clothing/neck/life_pendant = 10,
	/obj/item/clothing/gloves/ring/voidring = 10,
	/obj/item/stack/sheet/bluespace_crystal = 60
)
// Function to pick loot from a table (call this in mob death proc if needed)
/proc/pick_loot_from_table(list/loot_table)
    var/total_weight = 0
    for(var/item in loot_table)
        total_weight += loot_table[item]
    var/rand_val = rand(1, total_weight)
    for(var/item in loot_table)
        rand_val -= loot_table[item]
        if(rand_val <= 0)
            return item
    return null  // Fallback
