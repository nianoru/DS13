/obj/item/grab/nab

	type_name = GRAB_NAB
	start_grab_name = NAB_PASSIVE

/obj/item/grab/nab/init()
	..()
	/* //Commented out by nanako, too much work to support these while transitioning to allowing simple animals to be grabbed. We dont even use nabbers
	if(affecting.w_uniform)
		affecting.w_uniform.add_fingerprint(assailant)

	if(assailant.l_hand) assailant.unEquip(assailant.l_hand)
	if(assailant.r_hand) assailant.unEquip(assailant.r_hand)
	*/
	assailant.put_in_active_hand(src)
	assailant.do_attack_animation(affecting)
	playsound(affecting.loc, 'sound/weapons/thudswoosh.ogg', 50, 1, -1)
	visible_message("<span class='warning'>[assailant] has nabbed [affecting] passively!</span>")
	affecting.grabbed_by += src


/datum/grab/nab

	type_name = GRAB_NAB

	icon = 'icons/hud/screen1.dmi'

	stop_move = 1
	force_stand = 1
	reverse_facing = 1
	can_absorb = 1
	shield_assailant = 1
	point_blank_mult = 1
	same_tile = 1
	ladder_carry = 1
	force_danger = 1

/datum/grab/nab/on_hit_grab(var/obj/item/grab/G)
	var/mob/living/carbon/human/affecting = G.affecting
	var/mob/living/carbon/human/assailant = G.assailant

	var/crush_damage = rand(8,14)

	affecting.visible_message("<span class='danger'>[assailant] begins crushing [affecting]!</span>")
	G.attacking = 1
	if(do_mob(assailant, affecting, action_cooldown - 1))
		G.attacking = 0
		G.action_used()
		crush(G, crush_damage)
		return 1
	else
		G.attacking = 0
		affecting.visible_message("<span class='notice'>[assailant] stops crushing [affecting]!</span>")
		return 0

/datum/grab/nab/on_hit_harm(var/obj/item/grab/G)
	var/mob/living/carbon/human/affecting = G.affecting
	var/mob/living/carbon/human/assailant = G.assailant

	var/masticate_damage = rand(15,20)

	affecting.visible_message("<span class='danger'>[assailant] begins chewing on [affecting]!</span>")
	G.attacking = 1

	if(do_mob(assailant, affecting, action_cooldown - 1))
		G.attacking = 0
		G.action_used()
		masticate(G, masticate_damage)
		return 1
	else
		G.attacking = 0
		affecting.visible_message("<span class='notice'>[assailant] stops chewing on [affecting].</span>")
		return 0

// This causes the assailant to crush the affecting mob. There is a chance that the crush will cause the
// forelimb spikes to dig into the affecting mob, doing extra damage and likely causing them to bleed.
/datum/grab/nab/proc/crush(var/obj/item/grab/G, var/attack_damage)
	var/obj/item/organ/external/damaging = G.get_targeted_organ()
	var/hit_zone = G.target_zone

	var/armor = G.affecting.run_armor_check(hit_zone, "melee")

	G.affecting.visible_message("<span class='danger'>[G.assailant] crushes [G.affecting]'s [damaging.name]!</span>")

	if(prob(30))
		G.affecting.apply_damage(max(attack_damage + 10, 15), BRUTE, hit_zone, armor, DAM_SHARP, "organic punctures")
		G.affecting.apply_effect(attack_damage, PAIN, armor)
		G.affecting.visible_message("<span class='danger'>[G.assailant]'s spikes dig in PAINFULY!</span>")
	else
		G.affecting.apply_damage(attack_damage, BRUTE, hit_zone, armor,, "crushing")
	playsound(get_turf(G.assailant), 'sound/weapons/bite.ogg', 25, 1, -1)

	admin_attack_log(G.assailant, G.affecting, "Crushed their victim.", "Was crushed.", "crushed")

// This causes the assailant to chew on the affecting mob.
/datum/grab/nab/proc/masticate(var/obj/item/grab/G, var/attack_damage)
	var/hit_zone = G.assailant.hud_used.zone_sel.selecting
	var/obj/item/organ/external/damaging = G.affecting.get_organ(hit_zone)

	var/armor = G.affecting.run_armor_check(hit_zone, "melee")

	G.affecting.apply_damage(attack_damage, BRUTE, hit_zone, armor, DAM_SHARP|DAM_EDGE, "mandibles")
	G.affecting.visible_message("<span class='danger'>[G.assailant] chews on [G.affecting]'s [damaging.name]!</span>")
	playsound(get_turf(G.assailant), 'sound/weapons/bite.ogg', 25, 1, -1)

	admin_attack_log(G.assailant, G.affecting, "Chews their victim.", "Was chewed.", "chewed")
