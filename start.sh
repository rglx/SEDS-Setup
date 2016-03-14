#!/bin/bash

## Change these variables to what you want
# Location of the server
serverRoot=$HOME/spaceengineers

## DO NOT EDIT THESE VARIABLES
## (unless you know what you're doing)
service=spaceengineers
procname=SpaceEngineersDedicated.exe
export WINEDEBUG=-all
export WINEARCH=win32
whoami=`whoami`

# Before we do anything, make sure the root folder exists
if ! [[ -d "$serverRoot" ]]; then
	read -p "$serverRoot not found! Create it now? [y/n] " -n 1 -r
	echo

	if [[ $REPLY =~ ^[Yy] ]]; then
		mkdir -p $serverRoot
	else
		exit 0
	fi
fi

cd $serverRoot

# Simple wait-for-user-input function
function userWait
{
	read -p "Press any key to continue... " -n 1
	echo
	echo
}

case "$1" in
	dry-run)
		echo "Executing a dry-run of setting up the server."
		echo "Server root is set to $serverRoot"
		echo "WINEARCH is set to $WINEARCH"
		echo "We are user $whoami"
		echo 

		# Test to see if wine directory would be removed
		echo "Removing $HOME/.wine..."
		if [[ -f $HOME/.wine ]]; then
			echo "I just removed $HOME/.wine."
		fi

		# Test the creation of needed server directories
		echo "CDing into $serverRoot..."
		echo "Creating server directories..."
		mkdir -p {config/{backups,logs},client}
		echo "Server directories created."
		/bin/ls --color=auto -l

		echo "Done with initial directory setup."
		userWait

		# Do a trial run of steamcmd
		echo "Setting up steamcmd..."
		echo "Creating directory $serverRoot/steamcmd..."
		mkdir "$serverRoot/steamcmd" && cd "$serverRoot/steamcmd"
		echo "Downloading steamcmd..."
		wget --no-verbose -O steamcmd_linux.tar.gz 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'
		echo "Extracting steamcmd archive..."
		tar -xzf 'steamcmd_linux.tar.gz'
		echo "Installing / updating steamcmd"
		$serverRoot/steamcmd/steamcmd.sh +login anonymous +exit

		echo "steamcmd set up successfully!"
		userWait

		# Set up WINE
		echo "Configuring WINE..."
		winecfg > /dev/null
		echo "Downloading external dependencies..."
		mkdir -p "$HOME/.cache/winetricks/msxml3"
		mkdir -p "$HOME/.cache/winetricks/dotnet40"
		wget --no-verbose -O "$HOME/.cache/winetricks/msxml3/msxml3.msi" "https://github.com/RalphORama/SEDS-Setup/raw/master/bin/msxml3.msi"
		wget --no-verbose -O "$HOME/.cace/winetricks/dotnet40/gacutil-net40.tar.bz2" "https://github.com/RalphORama/SEDS-Setup/raw/master/bin/gacutil-net40.tar.bz2"
		echo "Setting up dependencies with winetricks..."
		winetricks -q msxml3 dotnet40 > /dev/null

		echo "WINE successfully set up."
		userWait

		# Create symlinks
		echo "Creating server symlinks..."
		ln -s "$serverRoot" "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers"
		ln -s "$serverRoot/config" "$HOME/.wine/drive_c/users/$whoami/Application Data/SpaceEngineersDedicated"

		echo "Symlinks created."
		userWait

		# Clean up from the dry run
		echo "Cleaning up..."
		echo "Remvoing server directories..."
		rm -rf "$serverRoot/config" "$serverRoot/client"
		echo "Uninstalling steamcmd..."
		rm -rf "$serverRoot/steamcmd"
		echo "Removing WINE symlinks..."
		rm -rf "$HOME/.wine/drive_c/users/$whoami/Application Data/SpaceEngineersDedicated"
		rm -rf "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers"

		echo "All done with the dry run! Check for errors to make sure the acutal setup will work."
		userWait
		exit 0
	;;

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
		cd $serverRoot
		mkdir -p {config/{backups,logs},client}

		# Set up steamcmd
		echo "Setting up steamcmd..."
		mkdir "$serverRoot/steamcmd" && cd "$serverRoot/steamcmd"
		wget -q -O steamcmd_linux.tar.gz 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'
		tar -xzf 'steamcmd_linux.tar.gz'

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
