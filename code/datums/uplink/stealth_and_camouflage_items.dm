/*******************************
* Stealth and Camouflage Items *
*******************************/
/datum/uplink_item/item/stealth_items
	category = /datum/uplink_category/stealth_items

/datum/uplink_item/item/stealth_items/syndigaloshes
	name = "No-Slip Shoes"
	item_cost = 4
	path = /obj/item/clothing/shoes/syndigaloshes

/datum/uplink_item/item/stealth_items/spy
	name = "Bug Kit"
	item_cost = 8
	path = /obj/item/storage/box/syndie_kit/spy

/datum/uplink_item/item/stealth_items/spy/special
	item_cost = 5
	is_special = TRUE
	antag_roles = list(MODE_EARTHGOV_AGENT)

/datum/uplink_item/item/stealth_items/id
	name = "Agent ID card"
	item_cost = 12
	path = /obj/item/card/id/syndicate

/datum/uplink_item/item/stealth_items/chameleon_kit
	name = "Chameleon Kit"
	item_cost = 20
	path = /obj/item/storage/backpack/chameleon/sydie_kit

/datum/uplink_item/item/stealth_items/voice
	name = "Chameleon Mask/Voice Changer"
	item_cost = 20
	path = /obj/item/clothing/mask/chameleon/voice

/datum/uplink_item/item/stealth_items/chameleon_projector
	name = "Chameleon-Projector"
	item_cost = 32
	path = /obj/item/chameleon

/datum/uplink_item/item/stealth_items/sneakies
	name = "Sneakies"
	item_cost = 4
	path = /obj/item/clothing/shoes/laceup/sneakies
