#!/bin/bash

## Change these variables to what you want
# Location of the server
serverRoot=$HOME/spaceengineers

## DO NOT EDIT THESE VARIABLES
## (unless you know what you're doing)
service=spaceengineers
procname=SpaceEngineersDedicated.exe
WINEDEBUG=-all
whoami=`whoami`

cd $serverRoot

case "$1" in
	setup)
		# Wipe the wine directory
		echo "In order for this script to work, you must wipe your wine directory."
		read -p "Wipe your wine directory now? [y/n] " -n 1 -r
		echo #newline for cleanliness

		# Just quit out if they didn't say yes
		if ! [[ $REPLY =~ ^[Yy] ]]; then exit 0; fi

		echo "Removing $HOME/.wine..."
		# Only remove the wine directory if it exists
		# This way we avoid some nasty bugs with `rm -rf`
		if [[ -f $HOME/.wine ]]; then
			rm -rf $HOME/.wine
		fi

		# Make directories for server use
		mkdir -p "$serverRoot/{config/{backups,logs},client}"

		# Set up steamcmd
		echo "Setting up steamcmd..."
		mkdir "$serverRoot/steamcmd" && cd "$serverRoot/steamcmd"
		wget -q -O steamcmd_linux.tar.gz 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'
		tar -xzf steamcmd_linux.tar.gz

		# configure our wine directory and make some symlinks
		cd $HOME
		echo "Configuring WINE and installing dependencies."
		WINEDEBUG=-all WINEARCH=win32 winecfg > /dev/null
		WINEDEBUG=-all winetricks -q msxml3 > /dev/null
		WINEDEBUG=-all winetricks -q dotnet40 > /dev/null
		ln -s "$serverRoot" "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers"
		ln -s "$serverRoot/config" "$HOME/.wine/drive_c/users/$whoami/Application Data/SpaceEngineersDedicated"
		echo "Initial setup complete."

		# install and update steamcmd
		echo "Installing and updating SteamCMD"
		$serverRoot/steamcmd/steamcmd.sh +login anonymous +exit

		echo "Setup complete."
		echo "Please place your server's .cfg file in ~/spaceengineers/config/SpaceEngineers-Dedicated.cfg."
		echo "You'll need to edit it and change the <LoadWorld /> part to read:"
		echo "<LoadWorld>C:\users\\$whoami\Application Data\SpaceEngineersDedicated\Saves\SEDSWorld</LoadWorld>."
	;;

	start)
		read -p "Update Space Engineers now? [y/n]"
		echo
		if [[ $REPLY =~ ^[Yy] ]]; then
			# login to steam and fetch the latest gamefiles
			$serverRoot/steamcmd/steamcmd.sh +force_install_dir "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers" +login anonymous +app_update 298740 -verify +quit
		fi

		# clear old binaries and get new ones
		cd "$serverRoot/config/Saves/SEDSWorld"
		echo "Cleaning world of dead NPC entries - Credits to Andy_S of #space-engineers"
		wget -q -O $serverRoot/config/worldcleaner.py 'https://raw.githubusercontent.com/deltaflyer4747/SE_Cleaner/master/clean.py'
		python $serverRoot/config/worldcleaner.py

		# start the DS
		echo "Starting Space Engineers dedicated server..."
		cd "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers/DedicatedServer"
		WINEDEBUG=-all wine SpaceEngineersDedicated.exe -console
		logstamper=`date +%s`

		# copy server world and log to backups and logs directories
		cd ../config
		mv SpaceEngineersDedicated.log logs/server-$logstamper.log
		cp -rf Saves/SEDSWorld backups/world-$logstamper-svhalt
	;;

	backupworld) #put an entry in your crontab pointing to this script with the first argument being 'backupworld'.
		logstampworld=`date +%s`
		cd $HOME/spaceengineers/config
		cp -rf Saves/SEDSWorld backups/world-$logstampworld
	;;

	*)
		if ps ax | grep -v grep | grep $procname > /dev/null
		then
			echo "$service is running, not starting"
			exit
		else
			echo "$service is not running, starting"
			screen -dmS $service -t $service $0 start
		fi
	;;
esac
