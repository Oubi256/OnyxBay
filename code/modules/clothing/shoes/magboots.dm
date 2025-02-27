//Note that despite the use of the NOSLIP flag, magboots are still hardcoded to prevent spaceslipping in Check_Shoegrip().
/obj/item/clothing/shoes/magboots
	desc = "Magnetic boots, often used during extravehicular activity to ensure the user remains safely attached to the vehicle. They're large enough to be worn over other footwear."
	name = "magboots"
	icon_state = "magboots0"
	can_hold_knife = 1
	species_restricted = null
	force = 3
	overshoes = 1
	var/magpulse = 0
	var/icon_base = "magboots"
	var/traction_system = "mag-pulse"
	action_button_name = "Toggle Magboots"
	var/obj/item/clothing/shoes/shoes = null	//Undershoes
	var/mob/living/carbon/human/wearer = null	//For shoe procs
	center_of_mass = null
	randpixel = 0

	armor = list(melee = 80, bullet = 60, laser = 60,energy = 25, bomb = 50, bio = 10)
	siemens_coefficient = 0.3
	rad_resist = list(
		RADIATION_ALPHA_PARTICLE = 33.8 MEGA ELECTRONVOLT,
		RADIATION_BETA_PARTICLE = 6.42 MEGA ELECTRONVOLT,
		RADIATION_HAWKING = 1 ELECTRONVOLT
	)

/obj/item/clothing/shoes/magboots/proc/set_slowdown()
	slowdown_per_slot[slot_shoes] = shoes? max(0, shoes.slowdown_per_slot[slot_shoes]): 0	//So you can't put on magboots to make you walk faster.
	if (magpulse)
		slowdown_per_slot[slot_shoes] += 3

/obj/item/clothing/shoes/magboots/attack_self(mob/user)
	if(magpulse)
		item_flags &= ~ITEM_FLAG_NOSLIP
		magpulse = 0
		set_slowdown()
		force = 3
		if(icon_base) icon_state = "[icon_base]0"
		to_chat(user, "You disable the [traction_system] traction system.")
	else
		item_flags |= ITEM_FLAG_NOSLIP
		magpulse = 1
		set_slowdown()
		force = 5
		if(icon_base) icon_state = "[icon_base]1"
		playsound(src, 'sound/effects/magnetclamp.ogg', 20)
		to_chat(user, "You enable the [traction_system] traction system.")
	user.update_inv_shoes()	//so our mob-overlays update
	user.update_action_buttons()
	user.update_floating()
	user.update_equipment_slowdown()

/obj/item/clothing/shoes/magboots/mob_can_equip(mob/user)
	var/mob/living/carbon/human/H = user

	if(H.shoes)
		shoes = H.shoes
		if(shoes.overshoes)
			to_chat(user, "You are unable to wear \the [src] as \the [H.shoes] are in the way.")
			shoes = null
			return 0
		H.drop_from_inventory(shoes)	//Remove the old shoes so you can put on the magboots.
		shoes.forceMove(src)

	if(!..())
		if(shoes) 	//Put the old shoes back on if the check fails.
			if(H.equip_to_slot_if_possible(shoes, slot_shoes))
				src.shoes = null
		return 0

	if (shoes)
		to_chat(user, "You slip \the [src] on over \the [shoes].")
	set_slowdown()
	wearer = H //TODO clean this up
	return 1

/obj/item/clothing/shoes/magboots/equipped()
	..()
	var/mob/M = src.loc
	if(istype(M))
		M.update_floating()

/obj/item/clothing/shoes/magboots/dropped()
	..()
	if(!wearer)
		return

	var/mob/living/carbon/human/H = wearer
	if(shoes && istype(H))
		if(!H.equip_to_slot_if_possible(shoes, slot_shoes))
			shoes.forceMove(get_turf(src))
		src.shoes = null
	wearer.update_floating()
	wearer = null

/obj/item/clothing/shoes/magboots/_examine_text(mob/user)
	. = ..()
	var/state = "disabled"
	if(item_flags & ITEM_FLAG_NOSLIP)
		state = "enabled"
	. += "\nIts [traction_system] traction system appears to be [state]."
