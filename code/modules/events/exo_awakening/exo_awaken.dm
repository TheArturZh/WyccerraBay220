GLOBAL_LIST_INIT(exo_event_mob_count,list())// a list of all mobs currently spawned

/datum/event/exo_awakening
	announceWhen	= 45
	endWhen			= 75
	///set to true once we hit the target mob count of spawned mobs so we stop spawning
	var/stop_spawning = FALSE
	///total count of all spawned mobs by the event
	var/spawned_mobs
	///all possible exoplanet areas the event can take place on
	var/list/exoplanet_areas
	var/area/chosen_area
	var/obj/overmap/visitable/sector/chosen_planet
	///how many players we need present on the planet for the event to start
	var/required_players_count = 4
	var/list/players_on_site = list()
	///overall target mob count, set to nonzero during setup
	var/target_mob_count = 0
	///the chosen list of mobs we will pick from when spawning, also based on severity
	var/datum/mob_list/chosen_mob_list
	/// Amount of time between the event starting and mobs beginning spawns
	var/delay_time
	/// Set to TRUE once the initial delay passes
	var/spawning = FALSE
	///Set to TRUE when the event fails one or more of the start conditions
	var/failed = FALSE
	///Severity of the event. Used to calculate spawn rates and event length.
	var/event_severity

/datum/event/exo_awakening/setup()
	announceWhen = rand(15, 45)
	affecting_z = list()
	if (prob(25))
		event_severity = EVENT_LEVEL_MAJOR

		chosen_mob_list = pick(typesof(/datum/mob_list/major) - /datum/mob_list/major)
	else
		event_severity = EVENT_LEVEL_MODERATE
		chosen_mob_list = pick(typesof(/datum/mob_list/moderate) - /datum/mob_list/moderate)

	for (var/area/A in world)
		if (A.planetary_surface)
			LAZYADD(exoplanet_areas, A)

	chosen_mob_list = new chosen_mob_list
	target_mob_count = chosen_mob_list.limit
	endWhen = chosen_mob_list.length
	endWhen += event_severity*25

	apply_spawn_delay()

/datum/event/exo_awakening/proc/apply_spawn_delay()
	delay_time = chosen_mob_list.delay_time
	var/delay_mod = delay_time / 6
	var/delay_max = (EVENT_LEVEL_MAJOR - event_severity) * delay_mod
	var/delay_min = -1 * event_severity * delay_mod
	delay_mod = max(rand(delay_min, delay_max), 0)
	delay_time += delay_mod
	endWhen += delay_time
	log_debug("Exoplanet Awakening spawns delayed [delay_time / 10] seconds.")

/datum/event/exo_awakening/proc/count_mobs()
	var/total_mobs
	total_mobs = length(GLOB.exo_event_mob_count)

	if (total_mobs >= target_mob_count || SSmobs.ticks >= 10 || !living_observers_present(affecting_z))
		stop_spawning = TRUE
	else
		stop_spawning = FALSE

/datum/event/exo_awakening/start()

	find_suitable_planet()

	if (!chosen_area)
		return

	notify_players()
	adjust_to_planet_size()

	addtimer(CALLBACK(src, TYPE_PROC_REF(/datum/event/exo_awakening, start_spawning)), delay_time)

//Locates a planet with players on it and kills the event if there aren't enough present
/datum/event/exo_awakening/proc/find_suitable_planet()
	var/list/sites = list() //a list of sites that have players present

	for (var/area/A in exoplanet_areas)
		var/list/players = list()
		for (var/mob/M in GLOB.player_list)
			if (M.stat != DEAD && (get_z(M) in GetConnectedZlevels(A.z)))
				players += M
				chosen_area = A
				chosen_planet = map_sectors["[A.z]"]
				affecting_z = GetConnectedZlevels(A.z)

		if (length(players) >= required_players_count)
			sites += A
			players_on_site[A] = players

	if (!length(sites))
		log_debug("Exoplanet Awakening failed to run, not enough players on any planet. Aborting.")
		failed = TRUE
		kill()
		return

	chosen_area = pick(sites)
	chosen_planet = map_sectors["[chosen_area.z]"]
	affecting_z = GetConnectedZlevels(chosen_area.z)

	if (!chosen_area)
		log_debug("Exoplanet Awakening failed to start, could not find a planetary area.")
		failed = TRUE
		kill()

//Notify all players on the planet that the event is beginning.
/datum/event/exo_awakening/proc/notify_players()
	for (var/mob/M in players_on_site[chosen_area])
		if (event_severity > EVENT_LEVEL_MODERATE)
			to_chat(M, SPAN_DANGER(chosen_mob_list.arrival_message))
		else
			to_chat(M, SPAN_WARNING(chosen_mob_list.arrival_message))

		sound_to(M, chosen_mob_list.arrival_sound)

//Lowers the amount of spawned mobs if the planet is smaller than normal.
/datum/event/exo_awakening/proc/adjust_to_planet_size()
	var/list/dimensions = chosen_area.get_dimensions()
	if (dimensions["x"] <= 100)
		target_mob_count = round(target_mob_count / 3.5) //keep mob count lower in smaller areas.

/datum/event/exo_awakening/announce()
	var/announcement = ""
	if (event_severity > EVENT_LEVEL_MODERATE)
		announcement = "Extreme biological activity spike detected on [location_name()]."
	else
		announcement = "Anomalous biological activity detected on [location_name()]."

	for (var/obj/overmap/visitable/ship/S in range(chosen_planet,2)) //announce the event to ships in range of the planet
		command_announcement.Announce(announcement, "[S.name] Biological Sensor Array", zlevels = S.map_z)

	chosen_planet.add_scan_data("exo_awaken", SPAN_COLOR(COLOR_RED, announcement), null, SKILL_SCIENCE, SKILL_TRAINED)

/datum/event/exo_awakening/tick()
	count_mobs()
	if (!spawning || (stop_spawning && prob(99)))
		return

	spawn_mob()

/datum/event/exo_awakening/proc/start_spawning()
	spawning = TRUE
	log_debug("Exoplanet Awakening spawning initiated.")

/datum/event/exo_awakening/proc/spawn_mob()
	if (!living_observers_present(affecting_z))
		return

	var/list/area_turfs = get_area_turfs(chosen_area)
	var/n = rand(event_severity-1, event_severity*2)
	var/I = 0
	while (I < n)
		var/turf/T
		for (var/i = 1 to 5)

			if (prob(chosen_mob_list.spawn_near_chance))
				var/mob/M = pick(players_on_site[chosen_area])
				var/turf/MT = get_turf(M)
				if (MT)
					if (istype(chosen_planet, /obj/overmap/visitable/sector/exoplanet))
						T = CircularRandomTurfAround(MT, Frand(3, 5))
				else
					T = pick(area_turfs)
			else
				T = pick(area_turfs)

			if (!T || is_edge_turf(T) || T.is_wall() || T.density)
				T = null
				continue

			break

		if (!T)
			return


		var/list/mob_list = pick(chosen_mob_list.mobs)


		var/spawn_chance = mob_list[2]
		var/mob_to_spawn = mob_list[1]

		if (prob(spawn_chance))
			var/mob/living/simple_animal/hostile/M = new mob_to_spawn(T)
			if (istype(M))
				M.visible_message(SPAN_DANGER("\The [M] bursts forth from the ground!"))
				GLOB.death_event.register(M,src, TYPE_PROC_REF(/datum/event/exo_awakening, reduce_mob_count))
				GLOB.destroyed_event.register(M,src,  TYPE_PROC_REF(/datum/event/exo_awakening, reduce_mob_count))
				LAZYADD(GLOB.exo_event_mob_count, M)

				if (istype(chosen_planet, /obj/overmap/visitable/sector/exoplanet))
					var/obj/overmap/visitable/sector/exoplanet/E = chosen_planet
					E.adapt_animal(M, FALSE)

			spawned_mobs++
		I++
		if (stop_spawning)
			break

/datum/event/exo_awakening/proc/reduce_mob_count(mob/M)
	var/list/L = GLOB.exo_event_mob_count
	if (M in L)
		LAZYREMOVE(L,M)

	GLOB.death_event.unregister(M, src,  TYPE_PROC_REF(/datum/event/exo_awakening, reduce_mob_count))
	GLOB.destroyed_event.unregister(M, src,  TYPE_PROC_REF(/datum/event/exo_awakening, reduce_mob_count))

/datum/event/exo_awakening/end()
	if (!chosen_area)
		return

	chosen_planet.remove_scan_data("exo_awaken")
	chosen_planet.add_scan_data("exo_awaken_aftermath", SPAN_COLOR(COLOR_GREEN, "Biological and geological activity within tolerance, trace unknown lifeforms detected."), null, SKILL_SCIENCE, SKILL_TRAINED)

	QDEL_NULL(chosen_mob_list)
	log_debug("Exoplanet Awakening event spawned [spawned_mobs] mobs. It was a level [event_severity] out of 3 severity.")

	if (!failed)
		for (var/mob/M in GLOB.player_list)
			if (M && M.z == chosen_area.z)
				to_chat(M, SPAN_NOTICE("The planet grows calm, the ground no longer heaving its horrors to the surface."))
