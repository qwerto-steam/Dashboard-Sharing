## Ah the old sketchy internet script trick. I'm not falling for that one again...

I wouldn't trust me either. Each script is about 300 lines. Ask a friendly online assistant to read it.

# Watch your dashboard on another device

A small script to serve **[PZ Pulse](https://steamcommunity.com/sharedfiles/filedetails/?id=3753700423)** or **[PZ Map](https://steamcommunity.com/sharedfiles/filedetails/?id=3770149036)** over your own home network.<br />
Useful if you want to use your phone, tablet, OBS or a second machine.

The script: **[serve_dashboard.ps1](serve_dashboard.ps1)** (Windows) or **[serve_dashboard.sh](serve_dashboard.sh)** (Linux, macOS)

Both do the same thing. Pick one - the steps below are the same either way.

## INSTRUCTIONS

- **Windows Security Note:**<br />
Windows warns **"Open File - Security Warning"** about editing/running downloaded scripts.<br />
Choose **Open**.<br />
If you don't want to be asked every time untick **"Always ask before opening this file"**.

0. Open your script in a text editor.
1. In game: **Options > Mods > PZ Pulse > "Copy dashboard URL"** (or **PZ Map > "Copy map URL"**)
2. Paste it on one of the 2 blank lines in the box at the top and save it.
3. Run it:<br />
   **Windows** - right-click the script > **Run with PowerShell**<br />
   **Linux / macOS** - in a terminal, in the folder you saved it: `bash serve_dashboard.sh`
4. About your firewall:<br />
   **Windows** asks about your network once - choose **Private**<br />
   **Linux** never asks, so the script checks instead, and prints the one command to run if it
   finds a firewall in the way
5. On your phone - **on the same wifi as your PC** - open the address it prints, and tap the mod
   name

Both mods at once is fine - paste each URL on its own line.

Close the window (Ctrl+C on Linux) to stop it.

## What are we doing?

It makes a `PZ_Dashboards` folder next to the script, and serves that one folder on your local
network. For each URL you pasted it puts two **shortcuts** in there - one to that mod's page, one
to the folder the game writes your live status into - plus a small menu page listing them, which is
what your phone lands on.

**Nothing of yours is copied or modified.** That menu page is the only file it writes. Because the
rest are shortcuts rather than copies, a mod update can't leave a stale version behind, and
deleting the folder afterwards removes only the shortcuts; your mods, your saves and your game data
aren't touched.

## If something doesn't work

**Windows: the script refuses to start** - "**is not digitally signed**", or "**running scripts is
disabled on this system**". Windows blocks scripts downloaded from the internet. Right-click the
file > **Properties** > tick **Unblock** > OK. Or run it as `powershell -ExecutionPolicy Bypass
-File serve_dashboard.ps1`. **Unblock** also stops the "Open File - Security Warning" box, as does
unticking "Always ask before opening this file" in the box itself.

You'll only see this if you started the script by typing its name in a terminal. Right-click >
**Run with PowerShell** (step 3 above) isn't affected, so if you're stuck here, that's the
easier way out.

**Linux: "Permission denied" running `./serve_dashboard.sh`.** The executable bit doesn't always
survive the download. Use `bash serve_dashboard.sh` instead, or `chmod +x serve_dashboard.sh` once.

**Linux: "This needs python3 to serve the files."** Nearly every distro already ships it. If yours
doesn't, the script prints the install command for your package manager.

**The phone just spins forever and never loads.** That's almost always a firewall. A blocked
connection is dropped rather than refused, so nothing reports an error at either end - which is
why the script checks for this before it starts serving and prints the exact one-line fix if it
finds it. Read what it printed.

**"Can't find the data folder."** Load a save once with the mod enabled, then run it again. The
folder doesn't exist until the game has written to it.

**Linux, playing through Proton?** Then the URL the game hands you is full of Windows drive
letters (`C:`, `S:`) and no browser of yours can open it - from inside Wine the game has no way
to know what those stand for. The `.sh` script works it out for you. Paste the URL exactly as the
game gave it to you, and ignore the warning in the mod options telling you to convert it by hand.

## Security / Streaming

**Don't put it on the public internet.** No port forwarding. For streaming, don't share a URL
at all - point an **OBS Browser Source** at the dashboard's normal `file:///` address and it's
in your video for free.

## Licence

[0BSD](LICENSE) - do whatever you like with it, no attribution required.

**Not any names or the logos though. Those I'm keeping.**
