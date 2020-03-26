/obj/machinery/ship_weapon/flak
	name = "Flak loading rack"
	icon = 'nsv13/icons/obj/munitions.dmi'
	icon_state = "pdc"
	desc = "Seegson's all-in-one PDC targeting computer, ammunition loader, and human interface has proven extremely popular in recent times. It's rare to see a ship without one of these."
	anchored = TRUE
	density = FALSE
	pixel_y = 26

	circuit = /obj/item/circuitboard/machine/pdc_mount

	fire_mode = FIRE_MODE_FLAK
	weapon_type = new/datum/ship_weapon/flak

/obj/machinery/ship_weapon/flak/animate_projectile(atom/target)
	linked.fire_flak(target)

/obj/machinery/ship_weapon/flak/can_fire(shots)
	return TRUE //Placeholder
/**
 * Handles automatic firing of the PDCs to shoot down torpedoes
 */
/obj/structure/overmap/proc/handle_pdcs()
	if(fire_mode == FIRE_MODE_FLAK) //If theyre aiming the PDCs manually, don't automatically flak.
		return
	if(mass <= MASS_TINY && !ai_controlled) //Small ships don't get to use PDCs. AIs still need to aim like this, though
		return
	if(!last_target || QDELETED(last_target))
		last_target = null
	for(var/obj/structure/overmap/ship in GLOB.overmap_objects)
		if(!ship || !istype(ship, /obj/structure/overmap))
			continue
		if(ship == src || ship.faction == faction || ship.wrecked) //No friendly fire, don't blow up wrecks that the crew may wish to loot.
			continue
		var/target_range = get_dist(ship,src)
	//	if(target_range > initial(weapon_range)) //If the target is out of PDC range, don't shoot. This prevents OP shit like spamming torps AND PDC flak all over a target.
	//		continue
		if(!QDELETED(ship) && isovermap(ship))
			fire_weapon(ship, mode=FIRE_MODE_FLAK, lateral=TRUE)
			break

/obj/structure/overmap/proc/get_flak_range(atom/target)
	if(!target)
		target = src
	var/dist = get_dist(src, target) / 2
	dist = (dist >= 5) ? dist : dist+5 //Stops you flak-ing yourself
	return (flak_range_override <= 0) ? dist : flak_range_override //By default, we like to create a flak deadzone halfway inbetween both ships

/obj/structure/overmap/proc/fire_flak(target,speed=null)
	var/turf/T = get_turf(src)
	var/flak_range = get_flak_range(target)
	to_chat(world, "[flak_range]")
	var/obj/item/projectile/proj = new /obj/item/projectile/bullet/flak(T, flak_range)
	proj.starting = T
	if(gunner)
		proj.firer = gunner
	proj.def_zone = "chest"
	proj.original = target
	proj.pixel_x = round(pixel_x)
	proj.pixel_y = round(pixel_y)
	var/theangle = Get_Angle(src,target)
	spawn()
		proj.fire(theangle)
		if(speed)
			proj.set_pixel_speed(speed)

/obj/structure/overmap/proc/handle_flak()
	if(mass <= MASS_MEDIUM) //This is for big boys only.
		return


/obj/effect/temp_visual/flak
	icon = 'nsv13/goonstation/icons/effects/explosions/80x80.dmi'
	icon_state = "explosion"
	duration = 2 SECONDS
	pixel_x = -32
	pixel_y = -32
	var/flak_range = 2 //AOE where flak hits torpedoes. May need to buff this a bit.

/obj/item/projectile/bullet/flak
	icon_state = "flak"
	name = "flak round"
	damage = 2
	mouse_opacity = TRUE
	var/steps_left = 0 //Flak range, AKA how many tiles can we move before we go kaboom

/obj/item/projectile/bullet/flak/Initialize(mapload, range=10)
	. = ..()
	steps_left = range
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, .proc/check_range)

/obj/item/projectile/bullet/flak/proc/explode()
	new /obj/effect/temp_visual/flak(get_turf(src))
	var/mob/checking = firer
	if(checking && checking.overmap_ship)
		checking.overmap_ship.relay_to_nearby(pick('nsv13/sound/effects/ship/flak/flakhit1.ogg','nsv13/sound/effects/ship/flak/flakhit2.ogg','nsv13/sound/effects/ship/flak/flakhit3.ogg'))
	qdel(src)

/obj/effect/temp_visual/flak/Initialize()
	if(prob(50))
		icon = 'nsv13/goonstation/icons/effects/explosions/96x96.dmi'
	for(var/atom/movable/X in view(flak_range, src))
		var/severity = flak_range-get_dist(X, src)
		X.ex_act(severity)
	. = ..()

/obj/item/projectile/bullet/flak/on_hit(atom/target, blocked = 0)
	explode()
	. = ..()

/obj/item/projectile/bullet/flak/proc/check_range()
	steps_left --
	if(steps_left <= 0)
		explode()

/obj/item/projectile/bullet/torpedo/Crossed(atom/movable/AM) //Here, we check if the bullet that hit us is from a friendly ship. If it's from an enemy ship, we explode as we've been flak'd down.
	. = ..()
	if(istype(AM, /obj/item/projectile))
		var/obj/item/projectile/proj = AM
		if(!ismob(firer) || !ismob(proj.firer)) //Unlikely to ever happen but if it does, ignore.
			return
		var/mob/checking = firer
		var/mob/enemy = proj.firer
		if(checking.overmap_ship && enemy.overmap_ship) //Firer is a mob, so check the faction of their ship
			var/obj/structure/overmap/OM = checking.overmap_ship
			var/obj/structure/overmap/our_ship = enemy.overmap_ship
			if(OM.faction != our_ship.faction)
				explode()
				return FALSE

/obj/item/projectile/bullet/torpedo/ex_act(severity)
	explode()

/obj/item/projectile/bullet/torpedo/proc/explode()
	if(firer)
		var/mob/checking = firer
		var/obj/structure/overmap/OM = checking.overmap_ship
		var/sound/chosen = pick('nsv13/sound/effects/ship/torpedo_detonate.ogg','nsv13/sound/effects/ship/freespace2/impacts/boom_2.wav','nsv13/sound/effects/ship/freespace2/impacts/boom_3.wav','nsv13/sound/effects/ship/freespace2/impacts/subhit.wav','nsv13/sound/effects/ship/freespace2/impacts/subhit2.wav','nsv13/sound/effects/ship/freespace2/impacts/m_hit.wav','nsv13/sound/effects/ship/freespace2/impacts/hit_1.wav')
		OM.relay_to_nearby(chosen)
	new shotdown_effect_type(get_turf(src)) //Exploding effect
	qdel(src)
	return FALSE
/*
	var/found_target = FALSE //Have we found a torpedo to shoot down? If we can't find a torpedo to shoot, look for enemy ships in range.
	if(torpedoes_to_target.len)  //Are there any torpedoes we need to worry about? Torpedoes enter this list as theyre shot (when they target us).
		for(var/atom/target in torpedoes_to_target) //Check through the torpedoes that our PDCs need to target
			if(!target || QDELETED(target)) //Clear null bullets that may have runtimed
				torpedoes_to_target -= target
				continue
			var/target_range = get_dist(target,src)
			if(target_range <= initial(weapon_range)) //The torpedo is in range, let's target it!
				found_target = TRUE
				if(prob(pdc_miss_chance)) //Gives them a chance to actually hit a torpedo, so it's not a perfect smokescreen.
					var/turf/T = get_turf(pick(orange(4,target))) //Pick a random tile within 6 turfs, this isn't a flat out miss 100% of the time though
					fire_weapon(T, mode=FIRE_MODE_PDC, lateral=TRUE)
				else
					if(!target || QDELETED(target))
						continue
					fire_weapon(target, mode=FIRE_MODE_PDC, lateral=TRUE)
	if(!found_target) //Can't see a torpedo to shoot, try find an enemy ship to shoot
		for(var/obj/structure/overmap/ship in GLOB.overmap_objects)
			if(!ship || !istype(ship, /obj/structure/overmap))
				continue
			if(ship == src || ship.faction == faction || ship.wrecked) //No friendly fire, don't blow up wrecks that the crew may wish to loot.
				continue
			var/target_range = get_dist(ship,src)
			if(target_range > initial(weapon_range)) //If the target is out of PDC range, don't shoot. This prevents OP shit like spamming torps AND PDC flak all over a target.
				continue
			if(!QDELETED(ship) && isovermap(ship))
				fire_weapon(ship, mode=FIRE_MODE_PDC, lateral=TRUE)

*/