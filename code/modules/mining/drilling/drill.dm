/obj/machinery/mining
	icon = 'icons/obj/mining_drill.dmi'
	anchored = 0
	use_power = POWER_USE_OFF //The drill takes power directly from a cell.
	density = 1

	layer = ABOVE_HUMAN_LAYER //So it draws over mobs in the tile north of it.

/obj/machinery/mining/drill
	name = "mining drill head"
	desc = "An enormous drill."
	icon_state = "mining_drill"
	var/braces_needed = 2
	var/list/supports = list()
	var/supported = 0
	var/base_power_usage = 10 KILO WATTS // Base power usage when the drill is running.
	var/actual_power_usage = 10 KILO WATTS // Actual power usage, with upgrades in mind.
	var/active = 0
	var/list/resource_field = list()

	var/ore_types = list(
		MATERIAL_IRON     = /obj/item/ore/iron,
		MATERIAL_URANIUM =  /obj/item/ore/uranium,
		MATERIAL_GOLD =     /obj/item/ore/gold,
		MATERIAL_SILVER =   /obj/item/ore/silver,
		MATERIAL_DIAMOND =  /obj/item/ore/diamond,
		MATERIAL_PLASMA =   /obj/item/ore/plasma,
		MATERIAL_OSMIUM =   /obj/item/ore/osmium,
		MATERIAL_HYDROGEN = /obj/item/ore/hydrogen,
		MATERIAL_SAND =     /obj/item/ore/glass,
		MATERIAL_GRAPHENE = /obj/item/ore/coal
		)

	//Upgrades
	var/harvest_speed
	var/capacity
	var/obj/item/cell/cell = null

	//Flags
	var/need_update_field = 0
	var/need_player_check = 0

/obj/machinery/mining/drill/New()

	..()

	component_parts = list()
	component_parts += new /obj/item/circuitboard/miningdrill(src)
	component_parts += new /obj/item/stock_parts/matter_bin(src)
	component_parts += new /obj/item/stock_parts/capacitor(src)
	component_parts += new /obj/item/stock_parts/micro_laser(src)
	component_parts += new /obj/item/cell/high(src)

	RefreshParts()

/obj/machinery/mining/drill/Process()

	if(need_player_check)
		return

	check_supports()

	if(!active) return

	if(!anchored || !use_cell_power())
		system_error("system configuration or charge error")
		return

	if(need_update_field)
		get_resource_field()

	if(world.time % 10 == 0)
		update_icon()

	if(!active)
		return

	//Drill through the flooring, if any.
	if(istype(get_turf(src), /turf/simulated/floor/asteroid))
		var/turf/simulated/floor/asteroid/T = get_turf(src)
		if(!T.dug)
			T.gets_dug()
	else if(istype(get_turf(src), /turf/simulated/floor))
		var/turf/simulated/floor/T = get_turf(src)
		T.ex_act(2.0)

	//Dig out the tasty ores.
	if(resource_field.len)
		var/turf/simulated/harvesting = pick(resource_field)

		while(resource_field.len && !harvesting.resources)
			harvesting.has_resources = 0
			harvesting.resources = null
			resource_field -= harvesting
			if(resource_field.len)
				harvesting = pick(resource_field)

		if(!harvesting || !harvesting.resources) return

		var/total_harvest = harvest_speed //Ore harvest-per-tick.
		var/found_resource = 0 //If this doesn't get set, the area is depleted and the drill errors out.

		for(var/metal in ore_types)

			if(contents.len >= capacity)
				system_error("insufficient storage space")
				active = 0
				need_player_check = 1
				update_icon()
				return

			if(contents.len + total_harvest >= capacity)
				total_harvest = capacity - contents.len

			if(total_harvest <= 0) break
			if(harvesting.resources[metal])

				found_resource  = 1

				var/create_ore = 0
				if(harvesting.resources[metal] >= total_harvest)
					harvesting.resources[metal] -= total_harvest
					create_ore = total_harvest
					total_harvest = 0
				else
					total_harvest -= harvesting.resources[metal]
					create_ore = harvesting.resources[metal]
					harvesting.resources[metal] = 0

				for(var/i=1, i <= create_ore, i++)
					var/oretype = ore_types[metal]
					new oretype(src)

		if(!found_resource)
			harvesting.has_resources = 0
			harvesting.resources = null
			resource_field -= harvesting
	else
		active = 0
		need_player_check = 1
		update_icon()

/obj/machinery/mining/drill/attack_ai(mob/user as mob)
	return src.attack_hand(user)

/obj/machinery/mining/drill/attackby(obj/item/O as obj, mob/user as mob)
	if(!active)
		if(default_deconstruction_screwdriver(user, O))
			return
		if(default_deconstruction_crowbar(user, O))
			return
		if(default_part_replacement(user, O))
			return
	if(!panel_open || active) return ..()

	if(istype(O, /obj/item/cell))
		if(cell)
			to_chat(user, "The drill already has a cell installed.")
		else
			user.drop_item()
			O.loc = src
			cell = O
			component_parts += O
			to_chat(user, "You install \the [O].")
		return
	..()

/obj/machinery/mining/drill/attack_hand(mob/user as mob)
	check_supports()

	if (panel_open && cell && user.Adjacent(src))
		to_chat(user, "You take out \the [cell].")
		cell.loc = get_turf(user)
		component_parts -= cell
		cell = null
		return
	else if(need_player_check)
		to_chat(user, "You hit the manual override and reset the drill's error checking.")
		need_player_check = 0
		if(anchored)
			get_resource_field()
		update_icon()
		return
	else if(supported && !panel_open)
		if(use_cell_power())
			active = !active
			if(active)
				visible_message("<span class='notice'>\The [src] lurches downwards, grinding noisily.</span>")
				need_update_field = 1
			else
				visible_message("<span class='notice'>\The [src] shudders to a grinding halt.</span>")
		else
			to_chat(user, "<span class='notice'>The drill is unpowered.</span>")
	else
		to_chat(user, "<span class='notice'>Turning on a piece of industrial machinery without sufficient bracing or wires exposed is a bad idea.</span>")

	update_icon()

/obj/machinery/mining/drill/update_icon()
	if(need_player_check)
		icon_state = "mining_drill_error"
	else if(active)
		icon_state = "mining_drill_active"
	else if(supported)
		icon_state = "mining_drill_braced"
	else
		icon_state = "mining_drill"
	return

/obj/machinery/mining/drill/RefreshParts()
	..()
	harvest_speed = 0
	capacity = 0
	var/charge_multiplier = 0

	for(var/obj/item/stock_parts/P in component_parts)
		if(istype(P, /obj/item/stock_parts/micro_laser))
			harvest_speed = P.rating
		if(istype(P, /obj/item/stock_parts/matter_bin))
			capacity = 200 * P.rating
		if(istype(P, /obj/item/stock_parts/capacitor))
			charge_multiplier += P.rating
	cell = locate(/obj/item/cell) in component_parts
	if(charge_multiplier)
		actual_power_usage = base_power_usage / charge_multiplier
	else
		actual_power_usage = base_power_usage

/obj/machinery/mining/drill/proc/check_supports()

	supported = 0

	if((!supports || !supports.len) && initial(anchored) == 0)
		icon_state = "mining_drill"
		anchored = 0
		active = 0
	else
		anchored = 1

	if(supports && supports.len >= braces_needed)
		supported = 1

	update_icon()

/obj/machinery/mining/drill/proc/system_error(error)

	if(error)
		src.visible_message("<span class='notice'>\The [src] flashes a '[error]' warning.</span>")
	need_player_check = 1
	active = 0
	update_icon()

/obj/machinery/mining/drill/proc/get_resource_field()

	resource_field = list()
	need_update_field = 0

	for(var/turf/simulated/S in range(2, src))
		if(S.has_resources)
			resource_field += S

	if(!length(resource_field))
		system_error("resources depleted")

/obj/machinery/mining/drill/proc/use_cell_power()
	return cell && cell.checked_use(actual_power_usage * CELLRATE)

/obj/machinery/mining/drill/verb/unload()
	set name = "Unload Drill"
	set category = "Object"
	set src in oview(1)

	if(usr.stat) return

	var/obj/structure/ore_box/B = locate() in orange(1)
	if(B)
		for(var/obj/item/ore/O in contents)
			O.loc = B
		to_chat(usr, "<span class='notice'>You unload the drill's storage cache into the ore box.</span>")
	else
		to_chat(usr, "<span class='notice'>You must move an ore box up to the drill before you can unload it.</span>")


/obj/machinery/mining/brace
	name = "mining drill brace"
	desc = "A machinery brace for an industrial drill. It looks easily two feet thick."
	icon_state = "mining_brace"
	var/obj/machinery/mining/drill/connected

/obj/machinery/mining/brace/New()
	..()

	component_parts = list()
	component_parts += new /obj/item/circuitboard/miningdrillbrace(src)

/obj/machinery/mining/brace/attackby(obj/item/W as obj, mob/user as mob)
	if(connected && connected.active)
		to_chat(user, "<span class='notice'>You can't work with the brace of a running drill!</span>")
		return

	if(default_deconstruction_screwdriver(user, W))
		return
	if(default_deconstruction_crowbar(user, W))
		return

	if(isWrench(W))

		if(istype(get_turf(src), /turf/space))
			to_chat(user, "<span class='notice'>You can't anchor something to empty space. Idiot.</span>")
			return

		playsound(src.loc, 'sound/items/Ratchet.ogg', 100, 1)
		to_chat(user, "<span class='notice'>You [anchored ? "un" : ""]anchor the brace.</span>")

		anchored = !anchored
		if(anchored)
			connect()
		else
			disconnect()

/obj/machinery/mining/brace/proc/connect()

	var/turf/T = get_step(get_turf(src), src.dir)

	for(var/thing in T.contents)
		if(istype(thing, /obj/machinery/mining/drill))
			connected = thing
			break

	if(!connected)
		return

	if(!connected.supports)
		connected.supports = list()

	icon_state = "mining_brace_active"

	connected.supports += src
	connected.check_supports()

/obj/machinery/mining/brace/proc/disconnect()

	if(!connected) return

	if(!connected.supports) connected.supports = list()

	icon_state = "mining_brace"

	connected.supports -= src
	connected.check_supports()
	connected = null

/obj/machinery/mining/brace/verb/rotate()
	set name = "Rotate"
	set category = "Object"
	set src in oview(1)

	if(usr.stat) return

	if (src.anchored)
		to_chat(usr, "It is anchored in place!")
		return 0

	src.set_dir(turn(src.dir, 90))
	return 1
