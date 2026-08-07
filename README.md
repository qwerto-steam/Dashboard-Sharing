# Watch your dashboard on another device

A small PowerShell script.

Put one or both mods on your phone, tablet or second machine - over your own home network.

**[PZ Pulse](https://steamcommunity.com/sharedfiles/filedetails/?id=3753700423)**

**[PZ Map](https://steamcommunity.com/sharedfiles/filedetails/?id=3766049939)**

**[Download `serve_dashboard.ps1`](serve_dashboard.ps1)**

0. Windows warns **"Open File - Security Warning"** about editing/running downloaded scripts.
   Choose **Open**. If you don't want to be asked every time, untick **"Always ask before
   opening this file"** before you do
1. In game: **Options > Mods > PZ Pulse > "Copy dashboard URL"** (or **PZ Map > "Copy map URL"**)
2. Open the script in Notepad and paste it on a blank line in the box at the top
3. Right-click the script > **Run with PowerShell**
4. Choose **Private** when Windows asks about your network
5. On your phone, open the address it prints, and tap the mod name

Both mods at once is fine - paste each URL on its own line. 

Close the window to stop it.

## What are we doing?

It makes a `PZ_Dashboards` folder containing four **shortcuts** - to each mod's page, and to the
folder the game writes your live status into - and serves that one folder on your local network.

**Nothing is copied and nothing is modified.** Because they are shortcuts rather than copies, a
mod update can't leave a stale version behind. Deleting the folder afterwards removes only the
shortcuts; your mods, your saves and your game data aren't touched.

## Ah the old sketchy internet script trick. I'm not falling for that again...

I wouldn't trust me either. It's about 300 lines. Ask a friendly online assistant to read it.

## If something doesn't work

**"Running scripts is disabled on this system."** Windows blocks scripts downloaded from the
internet. Right-click the file > **Properties** > tick **Unblock** > OK. Or run it as
`powershell -ExecutionPolicy Bypass -File serve_dashboard.ps1`. **Unblock** also stops the
"Open File - Security Warning" box, as does unticking "Always ask before opening this file"
in the box itself.

**The phone just spins forever and never loads.** That's almost always Windows Firewall. A blocked
connection is dropped rather than refused, so nothing reports an error at either end - which is
why the script checks for this before it starts serving and prints the exact one-line fix if it
finds it. Read what it printed.

**"Can't find the data folder."** Load a save once with the mod enabled, then run it again. The
folder doesn't exist until the game has written to it.

## Security / Streaming

**Don't put it on the public internet.** No port forwarding. For streaming, don't share a URL 
at all - point an **OBS Browser Source** at the dashboard's normal `file:///` address and it's 
in your video for free.

## Licence

[0BSD](LICENSE) - do whatever you like with it, no attribution required.

**Not any names or the logos though. Those I'm keeping.**
