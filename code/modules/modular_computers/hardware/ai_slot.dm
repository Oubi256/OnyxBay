// A wrapper that allows the computer to contain an inteliCard.
/obj/item/computer_hardware/ai_slot
	name = "inteliCard slot"
	desc = "An IIS interlink with connection uplinks that allow the device to interface with most common inteliCard models. Too large to fit into tablets. Uses a lot of power when active."
	icon_state = "aislot"
	hardware_size = 1
	critical = 0
	power_usage = 100
	origin_tech = list(TECH_POWER = 2, TECH_DATA = 3)
	var/obj/item/aicard/stored_card
	var/power_usage_idle = 100
	var/power_usage_occupied = 2 KILO WATTS

/obj/item/computer_hardware/ai_slot/proc/update_power_usage()
	if(!stored_card || !stored_card.carded_ai)
		power_usage = power_usage_idle
		return
	power_usage = power_usage_occupied

/obj/item/computer_hardware/ai_slot/attackby(obj/item/W as obj, mob/user as mob)
	if(..())
		return 1
	if(istype(W, /obj/item/aicard))
		if(stored_card)
			to_chat(user, "\The [src] is already occupied.")
			return
		user.drop_from_inventory(W)
		stored_card = W
		W.forceMove(src)
		update_power_usage()
	if(isScrewdriver(W))
		to_chat(user, "You manually remove \the [stored_card] from \the [src].")
		stored_card.forceMove(get_turf(src))
		stored_card = null
		update_power_usage()

/obj/item/computer_hardware/ai_slot/Destroy()
	if(holder2 && (holder2.ai_slot == src))
		holder2.ai_slot = null
	if(stored_card)
		stored_card.forceMove(get_turf(holder2))
	holder2 = null
	return ..()
