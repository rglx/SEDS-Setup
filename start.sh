#!/bin/bash

# this script assumes you have:
# - configured a 64-bit Windows 7 wine prefix on Debian 11
# - the Linux version of SteamCMD and winetricks installed
# - having already run the following with X11 forwarding on display 10:
#     `DISPLAY=:10 WINEDEBUG=fixme-all winetricks corefonts vcrun6 vcrun2013 vcrun2017 dotnet48`
# - you will also want Xvfb installed and running under display 0 afterwards.

serverFiles="/home/spaceengineers/server-files" # needs to be exact- no ~s or variables that steamcmd won't understand.
serverData="/home/spaceengineers/server-data" # must be the same effective path used in the server's -path argument.
steamCmd="/srv/software/steamcmd/steamcmd.sh" # location of your linux install of steamcmd
steamAppId=298740 # steam appid of the dedicated server
restartDelay=60 # ideally, have this pretty high so nothing bad happens if the server can't start or Steam tells the server to go away
runAsUser="spaceengineers"
service="spaceengineers"

broadcastmessageShim(){
	echo "session: $1"
	broadcastmessage "$1" > /dev/null 2>&1
}

updateServerFiles(){
	$steamCmd +@sSteamCmdForcePlatformType windows +force_install_dir $serverFiles +login anonymous +app_update $steamAppId validate +quit
	rm -rf /tmp/dumps # crashdumps from steamcmd
}

executeServer(){
	pushd $serverFiles/DedicatedServer64/ > /dev/null
	DISPLAY=:0 WINEDEBUG=fixme-all wine SpaceEngineersDedicated.exe -noconsole -IgnoreLastSession -path "Z:\\home\\spaceengineers\\server-data\\"
	popd > /dev/null
}


cleanServer() {
	echo "cleanServer: beginning file cleanup..."

	echo "cleanServer: 	stashing logs..."
	mkdir -p $serverData/Logs/ > /dev/null 2>&1
	xz -9 $serverData/*.log > /dev/null 2>&1
	xz -9 $serverData/Logs/*.log > /dev/null 2>&1
	mv -n $serverData/*.log.xz $serverData/Logs > /dev/null 2>&1

	echo "cleanServer:	removing unused server directories..."
	rmdir $serverData/cache
	rmdir $serverData/downloads
	rmdir $serverData/temp
	rmdir $serverData/Mods

	echo "cleanServer:	removing stale/unused files..."
	rm -f $serverData/Saves/LastSession.sbl
	rm -f $serverData/Saves/*/thumb.jpg
	rm -f $serverData/Minidump.dmp

	echo "cleanServer: file cleanup complete!"
}

deepCleanServer() {
	echo "deepCleanServer: beginning deep clean!"

	echo "deepCleanServer:	removing cached steam login information..."
	rm -rf ~/.steam ~/Steam

	echo "deepCleanServer:	removing dedicated server..."
	rm -rf $serverFiles
	mkdir -p $serverFiles

	echo "deepCleanServer:	removing downloaded mods..."
	rm -f $serverData/appworkshop_*.acf
	rm -rf $serverData/content

	echo "deepCleanServer:	removing unused SEDS auto-updater files..."
	rm -rf $serverData/Updater

	echo "deepCleanServer: deep clean complete!"
	echo "deepCleanServer: for a truly clean experience, back up the Saves and Storage and Logs folders from your server-data folder, remove ~/.wine, reinitialize your wineprefix, then reinstall .NET and the DS's other dependencies."
	echo "deepCleanServer: this is of course, optional, but recommended if you're encountering issues."
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
	echo -e "`toilet "HEY!"`\nDon't run this script as the wrong user!"| lolcat
	exit 1
fi


case "$1" in
	start)
		while true; do
			echo "service: starting $service..."
			touch $serverData/running.lck
			toilet -F crop -F border -w 99999 "$service" | lolcat
			broadcastmessageShim "ℹ️ $service restarted." &

			cleanServer # clean server files
			#updateServerFiles # update via steamcmd

			executeServer # run the server itself

			# executed after server stop.

			cleanServer # clean server files
			rm -f $serverData/running.lck # unlock server
			echo "service: $service stopped!"

			# now pick our restart warnings...
			if [[ $restartDelay == "0" ]]; then
				echo "service: not restarting! restart with $0"
				#broadcastmessageShim "🛑 $service stopped! NOT RESTARTING!!" &
				exit 0
			elif [[ $restartDelay == "-1" ]]; then
				echo "service: awaiting console input to restart service"
				#broadcastmessageShim "⚠️ $service stopped! NOT RESTARTING!!" &
				sleep 5
				read -p "service: [ enter to continue or Ctrl-C to abort ]" unused
			else
				echo "service: waiting $restartDelay seconds, then restarting!"
				echo "service: [ Ctrl-C to abort ]"
				#broadcastmessageShim "⚠️ $service stopped! Restarting!" &
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
		tmux new-session -d -n $service -s $service "bash $0 start"
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
		echo "deepCleanServer: this is VERY destructive!"
		echo "deepCleanServer: it will force a full reinstall of the dedicated server AND your mods!"
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
		echo " - update: updates the server's files from steamcmd"
		echo " - clean: cleans some base files if they weren't already when the server stopped."
		echo " - deepclean: completely uninstalls the server, Steam, and mod files, then redownloads them all. use only if something's broken."
		echo " - send-tmux: sends a command to the server via tmux. wrap in quotes, and include leading /"
		echo " - unlock: removes stale running.lck file, allowing the server to start."
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
