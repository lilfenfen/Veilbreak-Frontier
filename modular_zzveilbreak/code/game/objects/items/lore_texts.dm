/**
 * /obj/item/paper/lore
 *
 * A base type for lore-related paper items.
 */
/obj/item/paper/lore
	name = "ancient document"
	icon_state = "paper_torn"

/obj/item/paper/lore/melos_story
	name = "water-stained note"
	desc = "A piece of parchment, stained and worn by water and time. The ink has bled in places, but the elegant script is still legible."

/obj/item/paper/lore/melos_story/Initialize(mapload)
	. = ..()
	add_raw_text({"
	I write this so that someone might remember her as she was, not the... thing she has become. Melos was of the sea, her heart a song that only one other could truly hear. When he was taken from her, she did not despair, not at first. She searched. Oh, how she searched. Across stars and through silent darkness, she called for him.
	<br><br>
	But the void answered instead. It found her in her loneliest moment and twisted that beautiful song of love into a dirge of sorrow. The ocean's heart within her turned black with cosmic tears.
	<br><br>
	I fled. May the stars forgive me.
	"})
	update_appearance()

/obj/item/paper/lore/advertisement
	name = "Electronic Mail"
	desc = "This paper feels like it's filled with static charge."

/obj/item/paper/lore/advertisement/Initialize(mapload)
	. = ..()
	add_raw_text({"
	Join us today in the Veilbreak Frontiers! Our doors are open for visitors to raise tankards and keep company with our brave heroes, who fight in the treacherous v̷͓̿͜e̷̜͋ḯ̸̧l̸̬͒͂ ̵̙͐̚ to keep v̸͕́̕ơ̷̠̩̑i̸͈̒d̷͍́ at bay.
	<br><br>
	If just sharing a drink is not enough for you, you can join in the glory by becoming a hero yourself! Warrior or not, we provide opportunities for any and all talents and skillsets. From soldiers, researchers, engineers to even janitors and more, all work tirelessly together so we can continue to do our mission. Keeping our galaxies safe. All while not forgetting to make time to enjoy ourselves and each other.
	<br><br>
	Do YOU want to make a difference? Join today to fight for our tomorrow!
	"})
	update_appearance()

/obj/item/paper/lore/whispers
	name = "hastily scribbled note"
	desc = "A piece of paper covered in frantic, barely legible writing. It looks like it was torn from a larger page."

/obj/item/paper/lore/whispers/Initialize(mapload)
	. = ..()
	add_raw_text({"
	The whispers... they don't stop. They promise power, but it's a lie. It's a cage. I found a way, a crack in the non-reality. A pattern. Its all about-
	<br><br>
	The rest of the note is torn away.
	"})
	update_appearance()
