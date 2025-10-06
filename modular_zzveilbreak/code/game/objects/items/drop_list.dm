// Example loot drop lists for mobs, inspired by existing SS13 patterns (e.g., megafauna or hostile animals).
// These can be used in mob definitions like loot = list(/obj/item/your_loot) or with probabilities.


// Weighted loot table (e.g., for random drops with chances)
/var/list/voidling_loot_table = list(
    /obj/item/stack/sheet/bluespace_crystal = 10,
    /obj/item/stack/sheet/mineral/diamond = 10,
    /obj/item/stack/sheet/mineral/gold = 10,
    /obj/item/stack/sheet/mineral/silver = 10,
    /obj/item/stack/sheet/plasteel = 30,
    /obj/item/stack/sheet/glass = 30,
    /obj/item/clothing/neck/petcollar/aether_pendant = 0.1,  // 0.1% chance
    /obj/item/clothing/neck/petcollar/life_pendant = 0.1  // 0.1% chance
)

/var/list/inai_drops = list(
	/obj/item/voidshard = 100,
	/obj/item/clothing/neck/petcollar/aether_pendant = 33,  // 33% chance
	/obj/item/clothing/neck/petcollar/life_pendant = 33  // 33% chance
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
