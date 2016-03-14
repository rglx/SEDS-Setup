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

# Display our output as bold for easy differentiation
function boldDisplay
{
	echo `tput smul`"$1"`tput rmul`
}

# Simple wait-for-user-input function
function userWait
{
	echo
	boldDisplay "$1"
	read -p "Press any key to continue... " -n 1
	echo
}

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

case "$1" in
	dry-run)
		boldDisplay "Executing a dry-run of setting up the server."
		boldDisplay "Server root is set to $serverRoot"
		boldDisplay "WINEARCH is set to $WINEARCH, WINEDEBUG is set to $WINEDEBUG"
		boldDisplay "We are user $whoami"
		echo 

		# Test to see if wine directory would be removed
		boldDisplay "Removing $HOME/.wine..."
		if [[ -f $HOME/.wine ]]; then
			mv "$HOME/.wine" "$HOME/.winebackup"
			boldDisplay "I just removed $HOME/.wine."
		fi

		# Test the creation of needed server directories
		boldDisplay "CDing into $serverRoot..."
		cd $serverRoot
		boldDisplay "Creating server directories..."
		mkdir -p {config/{backups,logs},client}
		boldDisplay "Server directories created."
		/bin/ls --color=auto -l

		userWait "Done with initial directory setup."

		# Do a trial run of steamcmd
		boldDisplay "Setting up steamcmd..."
		boldDisplay "Creating directory $serverRoot/steamcmd..."
		mkdir "$serverRoot/steamcmd" && cd "$serverRoot/steamcmd"
		boldDisplay "Downloading steamcmd..."
		wget --no-verbose -O steamcmd_linux.tar.gz 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'
		boldDisplay "Extracting steamcmd archive..."
		tar -xzf 'steamcmd_linux.tar.gz'
		boldDisplay "Installing / updating steamcmd"
		$serverRoot/steamcmd/steamcmd.sh +login anonymous +exit

		userWait "steamcmd set up successfully!"

		# Set up WINE
		boldDisplay "Configuring WINE..."
		winecfg > /dev/null
		boldDisplay "Downloading external dependencies..."
		mkdir -p "$HOME/.cache/winetricks/msxml3"
		mkdir -p "$HOME/.cache/winetricks/dotnet40"
		wget --no-verbose -O "$HOME/.cache/winetricks/msxml3/msxml3.msi" "https://github.com/RalphORama/SEDS-Setup/raw/master/bin/msxml3.msi"
		wget --no-verbose -O "$HOME/.cache/winetricks/dotnet40/gacutil-net40.tar.bz2" "https://github.com/RalphORama/SEDS-Setup/raw/master/bin/gacutil-net40.tar.bz2"
		boldDisplay "Setting up dependencies with winetricks..."
		winetricks -q msxml3 dotnet40 > /dev/null

		boldDisplay "WINE successfully set up."
		userWait

		# Create symlinks
		boldDisplay "Creating server symlinks..."
		ln -s "$serverRoot" "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers"
		ln -s "$serverRoot/config" "$HOME/.wine/drive_c/users/$whoami/Application Data/SpaceEngineersDedicated"

		boldDisplay "Symlinks created."
		userWait

		# Clean up from the dry run
		boldDisplay "Cleaning up..."
		boldDisplay "Remvoing server directories..."
		rm -rf "$serverRoot/config" "$serverRoot/client"
		boldDisplay "Uninstalling steamcmd..."
		rm -rf "$serverRoot/steamcmd"
		boldDisplay "Restoring WINE installation..."
		mv "$HOME/.winebackup" "$HOME/.wine"
		boldDisplay "Removing WINE symlinks..."
		rm -rf "$HOME/.wine/drive_c/users/$whoami/Application Data/SpaceEngineersDedicated"
		rm -rf "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers"

		boldDisplay "All done with the dry run! Check for errors to make sure the acutal setup will work."
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

		# Only remove the wine directory if it exists
		# This way we avoid some nasty bugs with `rm -rf`
		if [[ -f $HOME/.wine ]]; then
			rm -rf $HOME/.wine
		fi

		# Make directories for server use
		cd $serverRoot
		mkdir -p {config/{backups,logs},client}

		# Set up steamcmd
		mkdir "$serverRoot/steamcmd" && cd "$serverRoot/steamcmd"
		wget --no-verbose -O steamcmd_linux.tar.gz 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz'
		tar -xzf 'steamcmd_linux.tar.gz'
		$serverRoot/steamcmd/steamcmd.sh +login anonymous +exit > /dev/null

		echo # To keep output clean

		# configure WINE
		winecfg > /dev/null
		winetricks -q msxml3 dotnet40 > /dev/null

		echo # To keep output clean

		# Create server symlinks
		ln -s "$serverRoot" "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers"
		ln -s "$serverRoot/config" "$HOME/.wine/drive_c/users/$whoami/Application Data/SpaceEngineersDedicated"

		echo "Setup complete."
		echo "Please place your server's .cfg file in ~/spaceengineers/config/SpaceEngineers-Dedicated.cfg."
		echo "You'll need to edit it and change the <LoadWorld /> part to read:"
		echo "<LoadWorld>C:\users\\$whoami\Application Data\SpaceEngineersDedicated\Saves\SEDSWorld</LoadWorld>."

		exit 0
	;;

	start)
		read -p "Update Space Engineers now? [y/n]" -n 1 -p
		echo
		if [[ $REPLY =~ ^[Yy] ]]; then
			# login to steam and fetch the latest gamefiles
			$serverRoot/steamcmd/steamcmd.sh +force_install_dir "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers" +login anonymous +app_update 298740 -verify +quit

			# Clean all that crap up once we're done
			read -p "Press any key to continue... " -n 1
			clear
		fi

		# clear old binaries and get new ones
		# We'll just redownload the script every time in case of an update.
		wget -q -O "$serverRoot/config/worldcleaner.py" 'https://raw.githubusercontent.com/deltaflyer4747/SE_Cleaner/master/clean.py'
		python "$serverRoot/config/worldcleaner.py"

		# start the DS
		echo "Starting Space Engineers dedicated server..."
		cd "$HOME/.wine/drive_c/users/$whoami/Desktop/spaceengineers/DedicatedServer"
		wine SpaceEngineersDedicated.exe -console
		logstamper=`date +%s`

		# copy server world and log to backups and logs directories
		# TODO: Fix log backups
		cd "$serverRoot/config"
		#mv SpaceEngineersDedicated.log logs/server-$logstamper.log
		cp -rf "Saves/SEDSWorld" "backups/world-$logstampworld"
	;;

	backupworld) #put an entry in your crontab pointing to this script with the first argument being 'backupworld'.
		logstampworld=`date +%s`
		cd "$serverRoot/config"
		cp -rf "Saves/SEDSWorld" "backups/world-$logstampworld"

		exit 0
	;;

	*)
		if ps ax | grep -v grep | grep $procname > /dev/null
		then
			echo "$service is running, not starting"
			exit 0
		else
			read -p "$service is not running, start it now? " -n 1 -r
			if [[ $REPLY =~ ^[Yy] ]]; then
				screen -dmS $service -t $service $0 start
			fi
		fi
	;;
esac
