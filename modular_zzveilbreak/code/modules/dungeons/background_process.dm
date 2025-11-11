// modular_zzveilbreak/code/modules/dungeons/background_process.dm

// Background processing system for heavy operations
/datum/background_process
	var/datum/callback/process_callback
	var/process_name = "background_process"
	var/active = FALSE
	var/list/metadata = list()

/datum/background_process/New(callback, name)
	process_callback = callback
	if(name)
		process_name = name

/datum/background_process/proc/start()
	active = TRUE
	SSbackground.processing += src
	log_dungeon("Background Process: Started [process_name]")

/datum/background_process/proc/stop()
	active = FALSE
	SSbackground.processing -= src
	log_dungeon("Background Process: Stopped [process_name]")

/datum/background_process/proc/execute()
	if(!active || QDELETED(src))
		stop()
		return

	if(!process_callback || QDELETED(process_callback))
		stop()
		return

	var/result = BG_PROCESSING_FINISHED
	try
		result = process_callback.Invoke()
	catch(var/exception/e)
		log_dungeon("Background Process: ERROR in [process_name]: [e]")
		stop()
		return

	switch(result)
		if(BG_PROCESSING_FINISHED)
			stop()
		if(BG_PROCESSING_CONTINUE)
			// Continue next tick
			return
		else
			// Assume finished on invalid response
			log_dungeon("Background Process: WARNING - Invalid result [result] from [process_name], stopping")
			stop()

// Background processing subsystem
SUBSYSTEM_DEF(background)
	name = "Background"
	priority = FIRE_PRIORITY_DEFAULT
	wait = 1 // Process every tick if possible
	flags = SS_BACKGROUND | SS_NO_INIT

	var/list/processing = list()

/datum/controller/subsystem/background/fire(resumed = FALSE)
	var/list/current_processing = processing.Copy()

	for(var/datum/background_process/process as anything in current_processing)
		if(MC_TICK_CHECK) // Respect tick budget
			return

		// Safety checks
		if(QDELETED(process))
			processing -= process
			continue

		if(!process.active)
			processing -= process
			continue

		// Execute with error handling
		try
			process.execute()
		catch(var/exception/e)
			log_dungeon("Background Process: ERROR in [process.process_name]: [e]")
			process.stop()
