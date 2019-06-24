//Fired from the ripper, a sawblade deals constant damage to things it touches


//Totals for damaging objects.An ex_act call at the appropriate strength will be triggered every time the blade deals this much total damage to a dense object
#define EX3_TOTAL 45
#define EX2_TOTAL 90
#define EX1_TOTAL 170

#define SOUND_GRIND	'sound/weapons/sawblade_grind.ogg'
#define SOUND_NORMAL 'sound/weapons/sawblade_normal.ogg'

/obj/item/projectile/sawblade
	name = "sawblade"
	damage_type = BRUTE
	//The compile time damage var is only used for blade launch mode. It will be replaced with a calculated value in remote control mode
	damage = 20

	//How much Damage Per Second is dealt to targets the blade hits in remote control mode. This is broken up into many small hits based on tick interval
	var/dps	=	25
	check_armour = "melee" //Its a cutting blade, melee armor helps most
	dispersion = 0
	icon = 'icons/effects/projectiles.dmi'
	icon_state = "ripper_projectile"
	mouse_opacity = 1
	pass_flags = PASS_FLAG_TABLE
	density = 0 //It passes through mobs
	sharp = 1
	edge = 1

	var/mob/user

	var/obj/item/weapon/gun/projectile/ripper/launcher

	//The sawblade has three states
	//STATE_STABLE: The blade is exactly on the user's cursor and is remaining still
	//STATE_MOVING: The blade isnt on the cursor and is moving towards it
	//STATE_GRINDING: The blade ran into a solid object while moving and is now grinding up against it, unable to complete movement
	var/status = STATE_MOVING

	//When the sawblade runs out of health, it breaks
	health = 350

	//The turf we are currently attacking. This may be the same one we're in, or an adjacent one.
	//The sawblade will only damage things in the damage tile
	var/turf/damage_tile	= 	null

	//How quickly the blade moves towards the user's cursor. This is measured in pixels per second.
	var/tracking_speed	=	64
	var/tracking_per_tick



	//Time in seconds between ticks of damage and movement. The lower this is, the smoother and more granular things are
	var/tick_interval	=	0.2

	//These variables cache where the user's cursor is, and thusly where we are trying to get to.
	var/turf/target_turf	=	null

	//Our X/Y location expressed as pixels from world 0. Useful for interpolation
	var/vector2/global_pixel_loc = new /vector2(0,0)

	var/timer_handle //Used for tick timer

	//A list of atoms we are grinding against and their damage counters. Entries in this list are in the format:
	//list(atom, ex3counter, ex2counter, ex1counter)
	var/list/grind_atoms = list()

	//Used to handle the looping sawblade audio
	var/datum/sound_token/saw_sound
	var/current_loop //Which looped sound is currently playing


/obj/item/projectile/sawblade/Destroy()
	.=..()
	if (launcher && launcher.blade == src)
		launcher.stop_firing()

	//Stop the looping audio
	set_sound(null)

/obj/item/projectile/sawblade/Initialize()
	.=..()
	//When created, lets populate some initial variables


	tracking_per_tick = tracking_speed * tick_interval


//Called when a sawblade is launched in remote control mode
/obj/item/projectile/sawblade/proc/control_launched(var/obj/item/weapon/gun/projectile/ripper/gun)
	launcher = gun
	damage = dps * tick_interval
	animate_movement = 0
	damage_tile = get_turf(src) //Damage tile starts off as wherever we are
	set_sound(SOUND_NORMAL)
	tick()

/obj/item/projectile/sawblade/proc/tick()
	timer_handle = null //This has been successfully called, that handle is no use now
	if (!loc || QDELETED(src))
		return

	track_cursor()
	damage_turf()

	//Set the next timer handle
	timer_handle = addtimer(CALLBACK(src, .proc/tick, TRUE), tick_interval, TIMER_STOPPABLE)


//Move towards the cursor
/obj/item/projectile/sawblade/proc/track_cursor()

	global_pixel_loc = get_global_pixel_loc()




	//Ok now we're going to decide how much we can move towards the target point
	var/vector2/diff = pixel_click - global_pixel_loc //Get a vec2 that represents the difference between our current location and the target

	//If its farther than we can go in one tick...
	if (diff.Magnitude() > tracking_per_tick)
		diff = diff.ToMagnitude(tracking_per_tick)//We rescale the magnitude of the diff


	//Now before we do animating, lets check if this movement is going to put us into a different tile
	var/vector2/newpix = new /vector2((pixel_x + diff.x), (pixel_y + diff.y))
	if (is_outside_cell(newpix))
		//Yes it will, lets find that tile
		var/turf/newtile = get_turf_at_pixel_offset(newpix)

		//There's no tile there? We must be at the edge of the map, abort!
		if (!newtile)
			return

		damage_tile = newtile //Even if we don't get in, the tile we're about to enter becomes the new place we damage

		//Before going any farther, we must check if we're able to enter that new tile.
		//This function tests that and, if blocked, will return the first solid thing we would bump into
		var/atom/blocker = newtile.can_enter(src)



		//Something blocked us!
		if (blocker)
			status = STATE_GRINDING

			add_grind_atom(blocker)//We will start grinding against it

			//We can still animate a little towards it, up to 8 pixels into its tile
			if (is_far_outside_cell(newpix))
				//If we get here, we would intrude too far into that tile, so we cutoff this tracking and don't move towards it anymore
				return

			//If we get here, then we can still move a little closer, so proceed with animation as normal
		else
			//If nothing blocks us, then we're clear to just swooce right into that tile.
			//We want the animation to finish first though so lets spawn it
			spawn(tick_interval SECONDS)
				set_global_pixel_loc(get_global_pixel_loc()) //This will move us into the tile while maintaining our global pixel coords

	animate(src, pixel_x = newpix.x, pixel_y = newpix.y)


/obj/item/projectile/sawblade/proc/damage_turf()
	//Solid objects will block the blade first
	if (status == STATE_GRINDING)
		//We iterate through the grind atoms and see if we can hit any of them
		for (var/list/l in grind_atoms)
			var/atom/A = l[1]
			//If the atom is gone, remove from this list
			if (QDELETED(A))
				grind_atoms.Remove(l)
				continue

			//The atom must be in the damage tile
			//Or BE the damage tile
			if (A.loc == damage_tile || A == damage_tile)

				//A destroyed wall turns into a floor with no density, but its still the same memory address.
				//We want to detect that and stop cutting into a floor
				if (A == damage_tile && !A.density)
					grind_atoms.Remove(l)
					continue

				//Sometimes bullet_act modifies a projectile's damage. To workaround that, we'll cache it here and restore it afterwards
				var/cache_damage = damage

				//We call bullet act, maybe the object has a built in reaction to this. But we'll also build towards our fallback method
				A.bullet_act(src)
				damage = cache_damage

				health -= damage

				A.pixel_x += rand(-1,1)
				A.pixel_y += rand(-1,1)
				//Explosion counters for a blocker decrease by the damage amount each tick.
				//The ripper can cut through almost anything if the blade lasts long enough. Low quality blades generally won't though
				l[2] -= damage
				if (l[2] <= 0)
					l[2] = EX3_TOTAL
					A.shake_animation(2)
					A.ex_act(3)


				l[3] -= damage
				if (l[3] <= 0)
					l[3] = EX2_TOTAL
					A.shake_animation(4)
					A.ex_act(2)

				l[4] -= damage
				if (l[4] <= 0)
					l[4] = EX1_TOTAL
					A.shake_animation(8)
					A.ex_act(1)

				updatehealth()
				set_sound(SOUND_GRIND)//We're grinding, play the grind sound
				return //After dealing damage to a single hard target, we return. It prevents us from damaging anything else this tick.
				//Mobs hiding behind something sturdy are safe, temporarily at least


	//If we manage to get here, we aren't grinding on anything, play the normal non-grind sound
	set_sound(SOUND_NORMAL)

	//Deals damage to mobs in the damage tile
	for (var/mob/living/L in damage_tile)
		var/cache_damage = damage
		attack_mob(L, 0, 0)
		damage = cache_damage
		health -= damage
		updatehealth()


/obj/item/projectile/sawblade/proc/add_grind_atom(var/atom/A)
	//Adds an atom to our list of grind items. this is stored indefinitely (until this sawblade is deleted)
	if (!QDELETED(A))
		grind_atoms += list(list(A, EX3_TOTAL, EX2_TOTAL, EX1_TOTAL))

/obj/item/projectile/sawblade/proc/updatehealth()
	if (health <= 0)
		if (launcher && launcher.blade == src)
			launcher.stop_firing()

//Override this so it doesn't delete itself when touching anything
/obj/item/projectile/sawblade/Bump(atom/A as mob|obj|turf|area, forced=0)
	return 0

//If the blade has health left, this will drop a reuseable sawblade casing on the floor and delete ourself
//Otherwise, it will drop either a broken sawblade or shrapnel, which has no purpose except to recycle for metal
/obj/item/projectile/sawblade/proc/drop()
	if (QDELETED(src))
		return

	//If health remains, the sawblade drops on the floor
	if (health > 0)
		playsound(get_turf(src),'sound/effects/weightdrop.ogg', 70, 1, 1)
	qdel(src)



/obj/item/projectile/sawblade/proc/set_sound(var/soundin)

	//Null is passed in when the sawblade is deleted. This will stop the sound
	if (!soundin)
		QDEL_NULL(saw_sound)
		return

	if (soundin == current_loop)
		return //Dont restart the sound we're already playing

	//If a sound is already playing, we'll stop it to start the new one, but not immediately
	if (saw_sound)
		qdel(saw_sound)
		//var/datum/sound_token/copied = saw_sound
		//spawn(3)//Let it overlap with the new one for just a little bit, to prevent having any silence
			//qdel(copied)

	var/volume = 15
	var/range = 9
	//The sound is lounder when grinding against objects
	if (soundin == SOUND_GRIND)
		volume = 50
		range = 15

	//And start the new sound
	//This random field is an ID, i assume it has to be unique
	saw_sound = GLOB.sound_player.PlayLoopingSound(src, /obj/item/projectile/sawblade, soundin, volume, range)
	current_loop = soundin

//Ammo version for picking up and loading
/obj/item/ammo_casing/sawblade
	desc = "sawblade"
	caliber = "saw"
	projectile_type = /obj/item/projectile/sawblade



#undef EX3_TOTAL
#undef EX2_TOTAL
#undef EX1_TOTAL

#undef SOUND_GRIND
#undef SOUND_NORMAL