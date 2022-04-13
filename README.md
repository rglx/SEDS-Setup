# SEDS-Setup

## description
SEDS-Setup - previously known and used as a bash script that handled the deployment of a Space Engineers dedicated server, now it is documentation that should serve the same purpose in competent hands.

## foreword
space engineers as a whole has been out for just shy of ten years, and in that time has spanned several major versions of .NET, which has caused server administrators and players and modders alike plenty of grief. these instructions should not be followed as a be-all, end-all, but instead taken as sort of a journal of one girl's failings to properly set a server up and getting tired of all the fragmented and outdated documentation around all of it, and writing her own guide. 

## requirements
- a machine with at the absolute least 8 cores with more than 3GHz apiece, and 16GB of RAM, along with PLENTY of storage space. north of 300GB is a good starting point but depending on how big your server is you'll want more. most of it is gonna be in asteroids/planets and server backups.
- the most recently-supported version of debian by WineHQ. at time of writing this is debian 11 "bullseye", but again, anything supported as "recent" by them will work fine.
- a brain (although i did most of this without one, it still helped in the end)

------------------

## part one: base setup of the OS

### install and configure a firewall:
```bash
apt install ufw
ufw allow 22/tcp # obviously, if your ssh port is different, adjust this
ufw allow 27016
ufw allow 8766
ufw enable
```
presently the only ports used by the game by default are the following:
- `8080` - vRage remote management interface - you can leave this firewalled and access it via SSH tunnel
- `27016` - main game port. if clients can't initiate UDP "connections" to it, they will simply fail to connect with no errors in the log.
- `8766` - steam outgoing communications port - this is used to talk to steam to get the server listed.

### install wine
this isn't gonna be covered here. you'll want to follow the latest instructions off of here for that:
#### https://wiki.winehq.org/Debian

### install other dependencies
some other dependencies that're required:
- `cabextract` - used by winetricks for installing our windows dependencies.
- `tmux` - terminal multiplexer. when the server's run inside it, you can detach from the server safely without breaking anything, and you'll be able to login and see the console directly, even though you can't really run commands through it.
- `iotop` - disk i/o usage monitor. sorta advanced. helps you track if your server's slowing down due to lots of disk reads/writes
- `htop` - system resource usage monitor. fairly easy to understand once you familiarize yourself. also, it's very colorful. very important feature.

### ensure your X display is working properly

#### X display forwarding
currently the most reliable and simple way to do X11 forwarding on windows is with PuTTY and Xming, with your server forwarding display offset 10 to you:
- install Xming display server on your windows client from here: https://sourceforge.net/projects/xming/
- install PuTTY on your windows client- you should already be using it to access stuff but in case you aren't: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
- start Xming display server:
	- use Multiple Windows mode
	- set Display number to 10
- start PuTTY, but don't login just yet:
	- load your session profile for your server
	- go down to Connection > SSH > X11 in the settings
	- Check the box that says "Enable X11 forwarding"
	- set "X display location" to `localhost:10`
	- hit Next & Finish until the icon shows up in your system tray.
- login to your server as root (this time) and edit file `/etc/ssh/sshd_config`:
	- scroll all the way to the bottom and add the following (or uncomment the ones already there): 
```
X11Forwarding yes
X11DisplayOffset 10
```
- after that:
	- restart sshd (`service sshd restart`)
	- log out
- login to your server as your game server user (and make sure no other SSH or PuTTY sessions are open on your local machine)
	- run xeyes to see if it worked:

```bash
DISPLAY=:10 xeyes
```
it should pop up some really BIG googly eyes that look like they're straight out of 1995 that follow your mouse around. this means it's working.

**sshd_config's `X11DisplayOffset`, Xming's display number, and PuTTY's X display location ALL MUST MATCH. further parts of this tutorial will assume you kept display offset `10` and didn't deviate.**


#### KVM from your virtualizer
if you're virtualizing with Proxmox or another reasonably modern solution, you should be able to just outright install a window manager of your choice and complete part two through noVNC or whatever solution your virtualization solution offers for KVM without display forwarding. it'll also be quite a bit faster as wine won't hang the installer waiting for your connection to sync up with your locally-running X server.

------------------
## part two: .NET, WINE, and winetricks
this part will cover more of the finicky parts of the setup, but it's also the most critical part. **if any step of this fails, the server won't run. at all.**

### switch to the right user
up until now, all of this has assumed you're either `root` or running all of these commands with `sudo`- now is the time to switch to the user that'll be running the server.

in my case i chose a very inventive username: `spaceengineers`

log out of PuTTY completely and back in as `spaceengineers` or whatever you chose, and try to run `DISPLAY=:10 xeyes` and make sure it works alright. gotta love those googly eyes. 👀

moving on.

### 'install' winetricks
(it's a very cool bash script with years and years of love and work, but it's not an actual install, per se.)
#### (more in-depth here: https://wiki.winehq.org/Winetricks )
in essence, download this someplace rewritable, because it may need to be updated as the game's requirements change, or if you need to redo your entire wine prefix:
```bash 
wget -O ~/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x ~/winetricks
```

### ensure your wine prefix is set up properly
this will be really simple: in essence we want to have wine create the directories it needs to run, and also allow us to make sure that we're pretending to be the right version of windows:
```bash
DISPLAY=:10 winecfg
```
it'll take a few seconds to show up and flood the living daylights out of your SSH terminal, but once it shows up, at the bottom of the window it should say `Windows Version:` and then a dropdown. Even if it already says "Windows 7", click it, select "Windows 7" again, and hit "OK".

### (optional) make a symlink to your server's data directory
when you're taking backups or accessing it later in this tutorial, it's a lot easier to have a shortcut in place so you don't have to click so many times:
```bash
ln -s ~/server-data ~/.wine/drive_c/users/spaceengineers/AppData/Roaming/SpaceEngineersDedicated/
```
(currently this will appear as a "broken link" in your home directory until the server is started once, just ignore it.)

### use winetricks to install the game's dependencies
this is gonna be the most critical part. if it fails at any step or can't install something, you're screwed.
```bash
cd ~
DISPLAY=:10 WINEDEBUG=fixme-all ./winetricks -q corefonts vcrun6 vcrun2013 vcrun2017 dotnet48
```
this will sit in your console for a bit and spam various downloads and silent installs, then for some it may present you an actual install wizard to click through.

------------------
## part three: steamcmd setup and download of the DS

### install the linux version of steamcmd, and run it once to get it working
```bash
mkdir ~/steamcmd
cd ~/steamcmd
wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
tar -zxvf steamcmd_linux.tar.gz
./steamcmd.sh +quit
```
this should cause it to update itself once, then quit. if it drops you at a prompt that looks like this:
```
Steam>
```
just type `quit` and hit enter and move on to the next step.

### install SEDS into a specific folder
```bash
mkdir ~/server-files
# this next part assumes your spaceengineers userfolder is /home/spaceengineers/ - if this isn't the case, adjust to match your setup- steamcmd doesn't understand ~ equalling your userfolder!
~/steamcmd/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir /home/spaceengineers/server-files/ +login anonymous +app_update 298740 validate +quit
```
this will take some time. it will download and validate that the dedicated server downloaded properly afterwards. run it twice if you're extra paranoid.

------------------
## part four: dry run

### test run SEDS
spoiler alert: it will crash. that's expected. the GUI for SEDS presently does NOT function under WINE and i do not expect it to get better. if you're having different results, great! but when i tried to use the GUI through X11 forwarding it freaked out and flew off the upper right of my screen, never to return, then crashed.
```bash
cd ~/server-files/DedicatedServer64/
DISPLAY=:10 WINEDEBUG=fixme-all wine SpaceEngineersDedicated.exe -console
```
the server will sort-of start, then just crash saying it can't find a world, and then sit there at "Press Enter to continue" - hit Enter a few times and give it a minute- this is truly some foolish behavior on Keen's part but it will lock your whole terminal up completely for several seconds while it thinks about dying. just let it, and hope this bug gets patched while you wait for it to drop you back to your shell. that's what i do.

### world and configuration creation
you'll want to do this by installing the dedicated server on your local machine, then using the configurator to create a world and a SpaceEngineers-Dedicated.cfg that we'll modify and upload.

**presently, the server won't work with its GUI properly, and instead crash! you have to install the DS on your windows machine and do it that way!**

#### *a note about access control and allow/blocklists in SEDS*
presently the two current ways to limit access to a server from the game is to tell the server to use a Steam Group or to password it, with offenders to your rules (if you have any) being removed from the group or the password changed - i think recently the `/ban` command was added.

if you choose to tie the server to a steam group, and manage access that way, here's a way to get the Steam64 ID of your steam group (which is required for SEDS to understand your group's membership)
```
https://steamcommunity.com/groups/[your group's custom URL]/memberslistxml/?xml=1
```
it will be right at the top, in `<GroupID64>` tags

if you choose to password it, obviously, write the password down somewhere, because it is now encrypted and unretrievable (without significant work) in the configuration

### linux-specific SEDS changes (required!)

once you've created and saved your world and configuration you'll need to make a few edits to SpaceEngineers-Dedicated.cfg:
```xml
	<IP>[your machine's IP address]</IP>
	<LoadWorld>C:\Users\spaceengineers\AppData\Roaming\SpaceEngineersDedicated\Saves\[your world folder]\Sandbox.sbc</LoadWorld>
```
- `[your machine's IP address]` CANNOT be left as `0.0.0.0` for reasons unknown. you must set it to the machine's IP address as retrieved from `ifconfig` or the server will refuse to start, saying it can't bind address `0.0.0.0` - eons ago this was suspected to be some sort of WINE bug with regards to .NET compatibility but who knows.
- `[the user that is running the server]` - in our case will be just `spaceengineers`
- `[your world folder]` - must match the world folder's name. i shortened mine to `world` when i uploaded it to the server

you'll also want to either remove or temporarily relocate the Backups folder inside your DS's world folder! this can make uploading the world to the server much slower, and since we're all pressed for time in the face of impending nuclear war i suggest outright deleting it.

------------------
## part seven: final steps
next up, you'll want to automate pretty much everything we just did, as well as introduce a few helper commands, so:
```bash
touch ~/start.sh
chmod +x ~/start.sh
```
and inside `start.sh`, put the contents of start.sh from this repository.

------------------
## credits
 - original information from Andy_S and NolanSyKinsley of the #space-engineers IRC channel on Esper for their information, way back when
 - Indigo, NikolasMarch, mkaito, and mmmaxwwwell for their assistance and inspiration to write all this up.
