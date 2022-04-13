#!/bin/bash

serverFiles="/home/spaceengineers/server-files" # needs to be exact- no ~s or variables that steamcmd won't understand.
serverData="/home/spaceengineers/.wine/drive_c/users/spaceengineers/AppData/Roaming/SpaceEngineersDedicated"
steamCmd="/home/spaceengineers/steamcmd/steamcmd.sh"
steamAppId=298740
restartDelay=-1
runAsUser="spaceengineers"
service="spaceengineers"

updateServerFiles(){
	$steamCmd +@sSteamCmdForcePlatformType windows +login anonymous +force_install_dir $serverFiles +app_update $steamAppId validate +quit
	rm -rf /tmp/dumps # multiple users running steamCMD can cause issues specifically regarding this folder
}

executeServer(){
	pushd $serverFiles/DedicatedServer64/
	DISPLAY=:0 WINEDEBUG=fixme-all wine SpaceEngineersDedicated.exe -console -IgnoreLastSession
	popd
}


cleanServer() {
	echo "cleanServer: beginning file cleanup..."

	echo "cleanServer: 	stashing logs..."
	mkdir -p $serverData/logs/
	xz -9 $serverData/*.log
	mv -n $serverData/*.log.xz $serverData/logs

	echo "cleanServer: 	flushing steam cached downloads..."
	rm -rf $serverData/cache
	rm -rf $serverData/downloads
	rm -rf $serverData/temp

	echo "cleanServer: file cleanup complete!"
}

deepCleanServer() {
	echo "deepCleanServer: beginning deep clean!"

	echo "deepCleanServer: 	completely flushing steam installation..."
	rm -rf ~/.steam ~/Steam

	echo "deepCleanServer: 	removing all mods for redownload..."
	rm -rf $serverData/Mods
	rm -rf $serverData/content

	echo "deepCleanServer: deep clean complete!"
}


countdown(){
	local OLD_IFS="${IFS}"
	IFS=":"
	local ARR=( $1 )
	local SECONDS=$((  (ARR[0] * 60 * 60) + (ARR[1] * 60) + ARR[2]  ))
	local START=$(date +%s)
	local END=$((START + SECONDS))
	local CUR=$START
	while [[ $CUR -lt $END ]]
	do
		CUR=$(date +%s)
		LEFT=$((END-CUR))
		printf "\r%02d:%02d:%02d" \
			$((LEFT/3600)) $(( (LEFT/60)%60)) $((LEFT%60))
		sleep 1
	done
	IFS="${OLD_IFS}"
	echo "        "
}



if [[ ! $(whoami) == $runAsUser ]]; then # prevent people from running stuff under the wrong users
	clear
	echo -e "`toilet "HEY!"`\nDon't run this script as the wrong user!"| /usr/games/lolcat
	exit 1
fi


case "$1" in
	start)
		while true; do
			echo "service: starting $service..."
			touch $serverData/running.lck
			toilet -F crop -F border -w 99999 "$service" | /usr/games/lolcat
			broadcastmessage "ℹ️ $service started." &

			cleanServer # clean server files
			updateServerFiles # update via steamcmd

			executeServer # run the server itself

			# executed after server stop.

			cleanServer # clean server files
			rm -f $serverData/running.lck # unlock server
			echo "service: $service stopped!"

			# now pick our restart warnings...
			if [[ $restartDelay == "0" ]]; then
				echo "service: not restarting! restart with $0"
				exit 0
			elif [[ $restartDelay == "-1" ]]; then
				echo "service: awaiting console input to restart service"
				read -p "service: [ enter to continue or Ctrl-C to abort ]" unused
			else
				echo "service: waiting $restartDelay seconds, then restarting!"
				echo "service: [ Ctrl-C to abort ]"
				countdown "00:00:$restartDelay"
			fi
		done
	;;
	tmux)
		echo "session: creating tmux session for $service..."
		tmux new-session -d -n $service -s $service bash
		echo "session: session created! attach to it with 'tmux a -t $service'"
	;;
	tmux-direct)
		echo "session: creating tmux session for $service with server starting within..."
		tmux new-session -d -n $service -s $service bash $0
		echo "session: session created & server starting! attach to it with 'tmux a -t $service'"
	;;
	update)
		if [[ -f $serverData/running.lck ]]; then
			echo "updateServerFiles: SERVER IS IN OPERATION! DO NOT DO THIS!"
			exit 1
		fi
		updateServerFiles
		cleanServer
	;;
	clean)
		if [[ -f $serverData/running.lck ]]; then
			echo "cleanServer: SERVER IS IN OPERATION! DO NOT DO THIS!"
			exit 1
		fi
		cleanServer
	;;
	deepclean)
		if [[ -f $serverData/running.lck ]]; then
			echo "deepCleanServer: SERVER IS IN OPERATION! DO NOT DO THIS!"
			exit 1
		fi
		echo "deepCleanServer: starting deep clean of server files!"
		echo "deepCleanServer: this is VERY destructive! (dissolves groups, white/blacklists)"
		read -p "deepCleanServer: [ enter to continue or Ctrl-C to abort ]" unused
		cleanServer
		deepCleanServer
		updateServerFiles
	;;
	send-tmux)
		if [[ -f $serverData/running.lck ]]; then
			echo "send-tmux: Attempting to send $2 to the server's console via tmux"
			tmux send-keys -t $service:$service Enter
			tmux send-keys -t $service:$service "${2}" Enter
		else
			echo "send-tmux: server doesn't appear to be running?"
			exit 1
		fi
	;;
	screen)
		echo "session: GNU screen is no longer supported. please install & configure tmux."
		exit 1
	;;
	unlock)
		echo "session: forcibly unlocking server! use with caution!"
		rm -f $serverData/running.lck
	;;
	help)
		echo "Usage: $0 [optional function]"
		echo " - tmux: creates a properly-named tmux session for the server to reside in."
		echo " - tmux-direct: starts the server directly under a tmux session"
		echo " - update: updates the server's files from steamcmd. run this before trying to start the server."
		echo " - clean: cleans some base files if they weren't already when the server stopped."
		echo " - deepclean: completely uninstalls the server, Steam, and mod files, then redownloads them all on the next server start. use only if something's broken."
		echo " - send-tmux: (presently unsupported by SEDS) sends a command to the server via tmux. wrap in quotes, and include leading /"
		echo " - unlock: removes stale running.lck, allowing the server to start."
		exit 0
	;;
	*)
		if [[ -f $serverData/running.lck ]]; then
			echo "service: server already running! Attach to the session with 'tmux a -t $service'"
			exit 1
		else
			echo "service: please select a function. use $0 help for a list."
		fi
	;;
esac
