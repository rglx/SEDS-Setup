# SEDS-Setup

Script for starting and configuring a Space Engineers server on a (optionally headless) Linux machine.

Report issues on the issues page. MAKE SURE YOU LOOK THROUGH THEM FIRST. Someone's probably already posted a solution.


##Usage

###Step one: Download the script.

<pre><code>mkdir ~/spaceengineers
cd ~/spaceengineers
wget -O start.sh [https://github.com/ArghArgh200/SEDS-Setup/raw/master/start.sh](<https://github.com/ArghArgh200/SEDS-Setup/raw/master/start.sh>)</pre></code>

The script is hardcoded to put your server in ~/spaceengineers. If you want to make it less... hardcoded feel free to do so and share it back with me.

###Step two: Check your wine version.

Run <code>wine --version</code> and also check if you have winetricks installed. (Run <code>which winetricks</code>)

If your wine version is not 1.7.30 or higher the script will not run and I will close any issue tickets you make until you upgrade.

###Step three: Run the script's setup function

<pre><code>cd ~/spaceengineers
chmod +x start.sh
./start.sh setup</pre></code>

It'll ask you for your Steam user and password. Not to worry, your password is NOT saved anywhere on disk. (Your username is used at server start to check for updates, and is stored in plaintext at ~/spaceengineers/Steamcmd/.steamuser )

It'll probably ask for you to download some links and put them in a folder. You may have to run the script twice.

###Step four: Upload your configuration and start the server.

This is probably the most important part, and also the part where most of the stuff that can go wrong goes wrong.

Your configuration needs to go in <code>~/spaceengineers/config/SpaceEngineers-Dedicated.cfg</code>, your world in <code>~/spaceengineers/config/saves/SEDSWorld</code>, and your configuration's LoadWorld directive should point to C:\users\<your username>\Application Data\SpaceEngineersDedicated\Saves\SEDSWorld</code>.

Alternatively you can just put the config on the server, and have the server generate a world.

This should get you off the ground. I won't tell you how to make the configurations here, but there are numerous forum posts on the matter. [Here's one you can use.](<http://forums.keenswh.com/post/tutorial-dedicated-server-on-ubuntu-13-10-using-wine-6922069>)

Now, run <code>./start.sh</code>, <code>screen -x spaceengineers<code>, and enjoy!

Credits to Andy_S and NolanSyKinsley of the #space-engineers IRC channel on Esper for their tidbits, and Andy_S's NPC identity cleaner.
