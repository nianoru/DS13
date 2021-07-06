
/*
	This ambiguous proc attempts to fetch a character's ID.

	Or, if they have none, it will register them and create one

	The input it takes is a representation of a character, this can be one of a few things:
		/datum/mind: A mind for a character who has been instantiated in the current round and probably controlled a mob. They may or may not have had a client

		/datum/preferences:	A client's savefile containing all their characters in an abstract data state. Typically a player can have ten characters, each a discrete copy of the preference data
			Only one of them, the currently selected selected one, will be extracted and used here


	Both of these datatypes will store the ID if they've previously been assigned one. And if one is assigned we'll just return that

	If none is assigned it means this character has never been registered, we will contact the database to insert them, and then query it again to get the newly autogenerated ID
	That ID will be stored in the data, and also returned
*/
/proc/get_character_id(var/data)

	//Data used for registering, if we need to
	var/name
	var/ckey

	if (istype(data, /datum/preferences))
		var/datum/preferences/P = data
		if (P.character_id)
			return P.character_id
		name = P.real_name
		ckey = P.client_ckey
	else if (istype(data, /datum/mind))
		var/datum/mind/M = data
		if (M.character_id)
			return M.character_id
		name = M.name
		ckey = ckey(M.key)
	else
		//Invalid type, no good
		return null


	//If we get here, the character isn't registered, do so
	return register_character(ckey, name, data)

/*
	This creates a record for a character with this name, use sparingly
	Do other checks to ensure it doesn't already exist first

	Name is the real name of the character
	Output is an optional datum with a character_id var which we'll populate with our result
*/
/proc/register_character(var/ckey, var/name, var/output)
	crash_with("Register character [ckey]	[name]	[output]")
	var/DBQuery/query = dbcon.NewQuery("INSERT INTO characters (ckey, character_name) VALUES('[ckey]','[name]');")
	var/query_result = query.Execute()

	query = dbcon.NewQuery("SELECT LAST_INSERT_ID();")
	query_result = query.Execute()

	world << "Query executed, result [query_result]"

	if(query.NextRow())
		world << "Query: [dump_list(query.item)]"
		if (output)
			var/id = query.item[1]
			output:character_id = id
			world << "set character ID to [output:character_id]"
			query = dbcon.NewQuery("INSERT INTO credit_records (character_id)\
			VALUES('[id]');")
			query.Execute()




/*
	Called when a character loads into the world, to populate their employee checking account

	Returns the number of credits this character should have

	the input is either a preferences or a mind
*/
//TODO: Insert in preferences menu
/proc/get_character_credits(var/character_data)
	var/id = get_character_id(character_data)

	//Get the number of credits from the database record associated with our ID
	var/DBQuery/query = dbcon.NewQuery("SELECT (credits) FROM (credit_records)	WHERE (character_id = [id]);")
	query.Execute()

	if(query.NextRow())
		world << "Query: [dump_list(query.item)]"
		return query.item[1]

	return 0

/*
	Called when a character enters a round, or is revived by an admin to negate a death
	This updates the last seen time for them in the characters table
	and creates an entry for them in the credits_lastround table.
		The latter makes them eligible for end of round fees depending on their status
*/
/proc/character_spawned(var/datum/mind/M)
	world << "Character spawned [M]"
	//Get their id, registering them in the process if needed
	var/id = get_character_id(M)

	//Now lets update the characters table first
	//Update the last seen var
	var/DBQuery/query = dbcon.NewQuery("UPDATE characters	 SET	last_seen = CURRENT_TIMESTAMP()	 WHERE	 (character_id = [id]);")
	query.Execute()

	//Force living status on spawning.
	//This accounts for situations where someone is killed by griefing and admins let them respawn to fix it
	update_lastround_credits(M, STATUS_LIVING)


/*
	Creates or updates an entry in the lastround_credits table, which is used at the end or beginning of the round to handle changes in persistent credits
	A status can optionally be passed in, if not we'll call a proc to get status
*/
/proc/update_lastround_credits(var/datum/mind/M, var/status)

	world << "Updating lastround credits [M]"
	if (!status)
		status = M.get_round_status()

	var/list/credits = M.get_owned_credits()
	if (credits == null)
		return	//No account setup

	var/id = get_character_id(M)
	var/credits_stored = credits["stored"]
	var/credits_carried = credits["carried"]
	var/character_status = status
	//And lets set their status in the lastround table to living
	var/DBQuery/query = dbcon.NewQuery(
	"INSERT INTO credit_lastround	\
		(character_id, credits_stored, credits_carried, character_status)	\
	VALUES	\
		([id], [credits_stored], [credits_carried], [character_status])	\
	ON DUPLICATE KEY UPDATE	\
		credits_stored = [credits_stored],\
		credits_carried = [credits_carried],\
		character_status = [character_status];")
	query.Execute()


/*
	Called when a character dies

	any deaths in a designated escape zone are noncanon, so we'll check for that here
	The input is always a mind because someone must first exist in order to die
*/
/proc/character_died(var/datum/mind/M)

	//TODO: Check for escape zone
	//TODO: Check if they were already dead to prevent duplication
	M.get_final_credits()
	update_lastround_credits(M)


/*
	Called when a character escapes

	any deaths in a designated escape zone are noncanon, so we'll check for that here
*/
//TODO: Insert on character entering an escape zone, or end of round if theyre on a shuttle
/proc/character_escaped(var/datum/mind/M)


//Takes an ID or a mind. Delivers a string message to a client who is associated with it
/proc/message_character(var/target, var/message)
	//Lets get the mind first
	var/datum/mind/M = target
	if (isnum(target))
		M = GLOB.characters["[target]"]

	//We need a client to talk to, no point if there's no human player reading this
	var/client/C
	if (!C)
		//Mind didn't have a client?
		C = M.original?.client || M.current?.client || M.ghost?.client

	if (C)
		to_chat(C, message)
