# SEDS-Setup

## Description    
SEDS-Setup is a bash script for creating and running a Space Engineers server on an optionally headless Linux machine.

## Issues    
Please report issues on the [issues page][1]. Many solutions for known bugs already exist, so please read through present issues first.

**Make sure `wine --version` returns a value of `1.7.30` or greater before posting an issue!**

## Requirements
It is recommended to use a Debian- or Ubuntu-based OS. Others are untested, but feel free to use them at your own risk. Please report any successes/failures/tweaks on the [issues page][1].

In order for this script to function properly, you must install the following packages:

* WINE 1.7.30 or higher
    - 64-bit OSes will need to use 32-bit WINE!
    - .NET 4 is not yet supported under WINE.
* winetricks
* Python 2.7
* unzip 
* wget 
* GNU Screen

To install these dependencies, run the commands for your OS.

Ubuntu:

```bash
sudo add-apt-repository ppa:ubuntu-wine/ppa
sudo apt-get update
sudo apt-get install wine1.8 winetricks
```

## Usage
1. Download the script:

    ```bash
    mkdir ~/spaceengineers
    cd ~/spaceengineers
    wget -O start.sh https://raw.githubusercontent.com/ArghArgh200/SEDS-Setup/master/start.sh
    chmod +x start.sh
    ```

2. Set up the server:

    ```bash
    # Optional: edit start.sh to provide a location to install the server
    cd ~/spaceengineers
    ./start.sh setup
    ```

3. Upload your configuration and start the server:

    - Place your configuration in `~/spaceengineers/config/SpaceEngineers-Dedicated.cfg`
    - Place your world in the `~/spaceengineers/config/Saves/SEDSWorld` folder
    - Set your configuration's `LoadWorld` directive to point to `C:\users\<your username>\Application Data\SpaceEngineersDedicated\Saves\SEDSWorld`

    - Alternatively put `SpaceEngineers-Dedicated.cfg` on the server and have the server generate a world.

    - For mor information on creating the needed configuration files, see [this forum post][2]

## Automated backups using crontab
Add one of the following line in your crontab file:

```bash
# Back up the world every 30 minutes
# Change 30 to however many minutes you want (1 - 59)
*/30 * * * * /home/YOUR USERNAME/spaceengineers/start.sh backupworld

# Back up the world every 6 hours
# Change 6 to however many hours you want (1 - 23)
0 */6 * * * /home/YOUR USERNAME/spaceengineers/start.sh backupworld

# Back up the world once a day
0 0 * * * /home/YOUR USERNAME/spaceengineers/start.sh backupworld
```

## Changing server settings after generating a world
All server settings are overridden by the world's specific settings. The server name is one of the only things that isn't. If you want to add or remove mods, change the world's name or description, or refining speed/inventory sizes, you **need** to do it in the world! Use WinSCP or Filezilla to download the world folder to your local worlds, and edit the world via the game. If you have custom inventory limits or assembler speeds etc you'll have to open your Sandbox.sbc and edit them that way. **BE CAREFUL! MAKE BACKUPS!** Reckless editing of world files can and in most cases **will** break your world!

## Planned features
- [ ] Restarting the server safely every day
- [ ] Complete reinstall once per month
    - (This can be done already by manually removing all but the .cfg, the world, and the script and running `./start.sh setup` again.)

# Credits
* Andy_S and NolanSyKinsley of #space-engineers on Esper for their tidbits
* Andy_S for his wonderful [NPC identity cleaner][3]
* RalphORama for refactoring start.sh and README.md

[1]: https://github.com/ArghArgh200/SEDS-Setup/issues "Issues"
[2]: http://forums.keenswh.com/post/6922069 "Server CFG Tutorial"
[3]: http://forums.keenswh.com/post/7308307 "NPC Identity Cleaner"
