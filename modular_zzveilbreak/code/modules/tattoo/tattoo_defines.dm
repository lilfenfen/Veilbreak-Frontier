// Custom Tattoo System Defines - COMPLETELY SEPARATE from prison/memory tattoos

// Tattoo layer defines
#define CUSTOM_TATTOO_LAYER_UNDER 1
#define CUSTOM_TATTOO_LAYER_NORMAL 2
#define CUSTOM_TATTOO_LAYER_OVER 3

// Tattoo preference path
#define CUSTOM_TATTOO_PREFERENCE_PATH /datum/preference/toggle/allow_bodywriting

// Maximum tattoos per body part
#define CUSTOM_MAX_TATTOOS_PER_PART 5

// Default tattoo application time
#define CUSTOM_TATTOO_APPLICATION_TIME (8 SECONDS)

// Tattooable organ slots
#define CUSTOM_TATTOOABLE_ORGAN_SLOTS list(\
	ORGAN_SLOT_PENIS,\
	ORGAN_SLOT_WOMB,\
	ORGAN_SLOT_VAGINA,\
	ORGAN_SLOT_TESTICLES,\
	ORGAN_SLOT_BREASTS,\
	ORGAN_SLOT_ANUS,\
	ORGAN_SLOT_NIPPLES,\
	ORGAN_SLOT_TAIL,\
	ORGAN_SLOT_SLIT,\
	ORGAN_SLOT_SHEATH,\
	ORGAN_SLOT_WINGS\
)

// Custom tattoo fonts
GLOBAL_LIST_INIT(custom_tattoo_fonts, list(
	PEN_FONT,
	FOUNTAIN_PEN_FONT,
	CRAYON_FONT,
	PRINTER_FONT,
	CHARCOAL_FONT
))
