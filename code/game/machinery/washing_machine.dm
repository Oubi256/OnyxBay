/obj/machinery/washing_machine
	name = "Washing Machine"
	icon = 'icons/obj/machines/washing_machine.dmi'
	icon_state = "wm_10"
	density = 1
	anchored = 1.0
	var/state = 1
	//1 = empty, open door
	//2 = empty, closed door
	//3 = full, open door
	//4 = full, closed door
	//5 = running
	//6 = blood, open door
	//7 = blood, closed door
	//8 = blood, running
	var/panel = 0
	//0 = closed
	//1 = open
	var/hacked = 1 //Bleh, screw hacking, let's have it hacked by default.
	//0 = not hacked
	//1 = hacked
	var/gibs_ready = 0
	var/obj/crayon
	var/obj/item/reagent_containers/pill/detergent/detergent
	obj_flags = OBJ_FLAG_ANCHORABLE
	clicksound = SFX_USE_BUTTON
	clickvol = 40

	// Power
	idle_power_usage = 10 WATTS
	active_power_usage = 150 WATTS

/obj/machinery/washing_machine/Destroy()
	qdel(crayon)
	crayon = null
	. = ..()

/obj/machinery/washing_machine/verb/start()
	set name = "Start Washing"
	set category = "Object"
	set src in oview(1)

	if(!isliving(usr)) //ew ew ew usr, but it's the only way to check.
		return

	if( state != 4 )
		to_chat(usr, "The washing machine cannot run in this state.")
		return

	if( locate(/mob,contents) )
		state = 8
	else
		state = 5
	update_use_power(POWER_USE_ACTIVE)
	update_icon()
	sleep(200)
	for(var/atom/A in contents)
		A.clean_blood()
		if(isitem(A))
			var/obj/item/I = A
			I.decontaminate()
			if(crayon && iscolorablegloves(I))
				var/obj/item/clothing/gloves/C = I
				C.color = crayon.color

	//Tanning!
	for(var/obj/item/stack/material/hairlesshide/HH in contents)
		var/obj/item/stack/material/wetleather/WL = new(src)
		WL.amount = HH.amount
		qdel(HH)

	update_use_power(POWER_USE_IDLE)
	if( locate(/mob,contents) )
		state = 7
		gibs_ready = 1
	else
		state = 4
	update_icon()

/obj/machinery/washing_machine/verb/climb_out()
	set name = "Climb out"
	set category = "Object"
	set src in usr.loc

	sleep(20)
	if(state in list(1,3,6) )
		usr.loc = src.loc


/obj/machinery/washing_machine/update_icon()
	icon_state = "wm_[state][panel]"

/obj/machinery/washing_machine/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W,/obj/item/pen/crayon) || istype(W,/obj/item/stamp))
		if( state in list(	1, 3, 6 ) )
			if(!crayon)
				user.drop_item()
				crayon = W
				crayon.forceMove(src)
			else
				..()
		else
			..()
	else if(istype(W,/obj/item/grab))
		if( (state == 1) && hacked)
			var/obj/item/grab/G = W
			if(ishuman(G.assailant) && iscorgi(G.affecting))
				G.affecting.loc = src
				qdel(G)
				state = 3
		else
			..()
	else if(istype(W,/obj/item/stack/material/hairlesshide) || \
		istype(W,/obj/item/clothing/under) || \
		istype(W,/obj/item/clothing/mask) || \
		istype(W,/obj/item/clothing/head) || \
		istype(W,/obj/item/clothing/gloves) || \
		istype(W,/obj/item/clothing/shoes) || \
		istype(W,/obj/item/clothing/suit) || \
		istype(W,/obj/item/underwear) || \
		istype(W,/obj/item/bedsheet))

		//YES, it's hardcoded... saves a var/can_be_washed for every single clothing item.
		if ( istype(W,/obj/item/clothing/suit/space ) )
			to_chat(user, "This item does not fit.")
			return
		if ( istype(W,/obj/item/clothing/suit/syndicatefake ) )
			to_chat(user, "This item does not fit.")
			return
//		if ( istype(W,/obj/item/clothing/suit/powered ) )
//			to_chat(user, "This item does not fit.")
//			return
		if ( istype(W,/obj/item/clothing/suit/bomb_suit ) )
			to_chat(user, "This item does not fit.")
			return
		if ( istype(W,/obj/item/clothing/suit/armor ) )
			to_chat(user, "This item does not fit.")
			return
		if ( istype(W,/obj/item/clothing/suit/armor ) )
			to_chat(user, "This item does not fit.")
			return
		if ( istype(W,/obj/item/clothing/mask/gas ) )
			to_chat(user, "This item does not fit.")
			return
		if ( istype(W,/obj/item/clothing/mask/smokable/cigarette ) )
			to_chat(user, "This item does not fit.")
			return
		if ( istype(W,/obj/item/clothing/head/syndicatefake ) )
			to_chat(user, "This item does not fit.")
			return
//		if ( istype(W,/obj/item/clothing/head/powered ) )
//			to_chat(user, "This item does not fit.")
//			return
		if ( istype(W,/obj/item/clothing/head/helmet ) )
			to_chat(user, "This item does not fit.")
			return

		if(contents.len < 5)
			if ( state in list(1, 3) )
				user.drop_item()
				W.loc = src
				state = 3
			else
				to_chat(user, SPAN("notice", "You can't put the item in right now."))
		else
			to_chat(user, SPAN("notice", "The washing machine is full."))
	else
		..()
	update_icon()

/obj/machinery/washing_machine/attack_hand(mob/user as mob)
	switch(state)
		if(1)
			state = 2
		if(2)
			state = 1
			for(var/atom/movable/O in contents)
				O.forceMove(loc)
		if(3)
			state = 4
		if(4)
			state = 3
			for(var/atom/movable/O in contents)
				O.forceMove(loc)
			crayon = null
			state = 1
		if(5)
			to_chat(user, SPAN("warning", "The [src] is busy."))
		if(6)
			state = 7
		if(7)
			if(gibs_ready)
				gibs_ready = 0
				if(locate(/mob,contents))
					var/mob/M = locate(/mob,contents)
					M.gib()
			for(var/atom/movable/O in contents)
				O.forceMove(src.loc)
			crayon = null
			state = 1


	update_icon()
