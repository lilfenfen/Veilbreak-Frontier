GLOBAL_LIST_EMPTY(vetted_list_legacy)
GLOBAL_PROTECT(vetted_list_legacy)
GLOBAL_LIST_EMPTY(vetted_list)
GLOBAL_PROTECT(vetted_list)

/datum/player_rank_controller/vetted
	rank_title = "vetted user"

/client/
	var/is_vetted = null

/datum/controller/subsystem/player_ranks/proc/is_vetted(client/user, admin_bypass = TRUE)
	if(!istype(user))
		CRASH("Invalid user type provided to is_vetted(), expected 'client' and obtained '[user ? user.type : "null"]'.")
	if(!isnull(user.is_vetted))
		return user.is_vetted
	if(get_user_vetted_status_hot(user.ckey))
		user.is_vetted = TRUE
		return user.is_vetted
	else
		user.is_vetted = FALSE
		return user.is_vetted



/datum/controller/subsystem/player_ranks/proc/get_user_vetted_status_hot(ckey)
	if(IsAdminAdvancedProcCall())
		return
	if(!SSdbcore.Connect())
		return
	var/datum/db_query/query_load_player_rank = SSdbcore.NewQuery("SELECT ckey FROM whitelist WHERE LOWER(ckey) = LOWER(:ckey)", list("ckey" = ckey))
	if(!query_load_player_rank.warn_execute())
		qdel(query_load_player_rank)
		return
	while(query_load_player_rank.NextRow())
		var/ckey2 = ckey(query_load_player_rank.item[1])
		. = ckey2
	qdel(query_load_player_rank)
