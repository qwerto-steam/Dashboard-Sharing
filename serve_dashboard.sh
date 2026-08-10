#!/usr/bin/env bash
# ===========================================================================
#  PZ Pulse / PZ Map - view your dashboard on another device   (Linux, macOS)
#
#  1. In game, for EITHER mod (or both - you don't need both):
#       Options -> Mods -> PZ Pulse -> "Copy dashboard URL"
#       Options -> Mods -> PZ Map   -> "Copy map URL"
#  2. Paste it on a blank line in the box below. One mod per line.
#  3. Save this file and close it.
#  4. Run it from a terminal, in the folder you saved it in:
#       bash serve_dashboard.sh
#  5. On the other device, open the http:// address it prints. Tap the mod name.
#
#  It makes a PZ_Dashboards folder holding links to the mod and to your live
#  data, then serves that folder on your local network. Nothing is copied,
#  nothing is modified, nothing leaves your network. Ctrl+C to stop.
#
#  Playing through Proton/Wine? The URL the game gives you is full of Windows
#  drive letters and no browser of yours can open it - this script translates
#  it back to a real path for you. Nothing extra to do.
# ===========================================================================

urls=$(cat <<'PASTE_BOX'
##############  PASTE YOUR URL(S) ON A BLANK LINE BELOW  ###############
##############  PZ Pulse and/or PZ Map - one per line    ###############


##############  STOP - DON'T PASTE BELOW THIS LINE       ###############
##############  SAVE IT. CLOSE IT. RUN IT.               ###############
PASTE_BOX
)

port=8000

# --------------------------------------------------------------- no edits below

# Run by `sh script.sh` this would fail somewhere in the middle on a bashism,
# with a message about a line the reader never typed. Say so at the top instead.
if [ -z "${BASH_VERSION:-}" ]; then
  echo "Run this with bash:   bash serve_dashboard.sh" >&2
  exit 1
fi

# Not `set -e`: several steps below deliberately continue after a failure (one
# bad URL must not take the other one down with it), and the checks are all
# explicit. `set -u` still catches a typo'd variable name.
#
# Array expansions are written `${a[@]+"${a[@]}"}` throughout, which looks like
# noise and isn't: before bash 4.4 an EMPTY array counts as unset, so the plain
# form aborts under `set -u` in exactly the case an empty one is expected. That
# includes the bash 3.2 macOS still ships, which is also why nothing here uses
# `mapfile` or `${x,,}`.
set -u

if [ -t 1 ]; then
  RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; CYN=$'\033[36m'; OFF=$'\033[0m'
else
  RED=''; GRN=''; YEL=''; CYN=''; OFF=''
fi
say()  { printf '%s\n' "$*"; }
warn() { printf '%s%s%s\n' "$YEL" "$*" "$OFF"; }
bad()  { printf '%s%s%s\n' "$RED" "$*" "$OFF"; }
good() { printf '%s%s%s\n' "$GRN" "$*" "$OFF"; }
note() { printf '%s%s%s\n' "$CYN" "$*" "$OFF"; }

# The quoted here-doc delimiter takes every line verbatim, so the URL can be
# pasted bare with nothing to escape ($ and backticks included) and the banners
# can live inside the box. Drop blank and banner lines; anything else falls
# through to the loop below, so a mis-paste gets an error rather than vanishing.
url_list=()
pasted=0
while IFS= read -r line; do
  url_list+=("$line")
  pasted=$((pasted + 1))
done < <(printf '%s\n' "$urls" |
         sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' |
         grep -v '^#' | grep -v '^$')

# The Lua that builds the URL escapes spaces (%20) and nothing else, but decode
# generally anyway. Backslashes are doubled first because printf %b would eat a
# literal one - legal in a Linux path, however unwise.
url_decode() {
  local s=${1//\\/\\\\}
  printf '%b' "${s//%/\\x}"
}

# ---------------------------------------------------------------- Wine / Proton
#
# Under Proton the game is a Windows binary, so every path it can see is a Wine
# drive mapping ("C:/users/steamuser/Zomboid", "S:/workshop/...") and means
# nothing to a native browser. The game cannot fix this itself - from inside the
# prefix there is no way to ask where the prefix lives - but out here there is:
# <prefix>/dosdevices/<letter>: is a symlink to the real directory, so the
# translation is exact rather than a guess.
#
# 108600 is Project Zomboid's Steam app id, and compatdata is keyed by it.
wine_prefix=''
find_wine_prefix() {
  local root vdf lib
  for root in "$HOME/.steam/steam" "$HOME/.steam/root" "$HOME/.local/share/Steam" \
              "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"; do
    [ -d "$root" ] || continue
    if [ -d "$root/steamapps/compatdata/108600/pfx/dosdevices" ]; then
      printf '%s' "$root/steamapps/compatdata/108600/pfx"; return 0
    fi
    # The game may sit in a second Steam library on another disk; the libraries
    # are listed in libraryfolders.vdf as `"path"  "/mnt/games/SteamLibrary"`.
    vdf="$root/steamapps/libraryfolders.vdf"
    [ -f "$vdf" ] || continue
    while IFS= read -r lib; do
      [ -n "$lib" ] || continue
      if [ -d "$lib/steamapps/compatdata/108600/pfx/dosdevices" ]; then
        printf '%s' "$lib/steamapps/compatdata/108600/pfx"; return 0
      fi
    done < <(sed -n 's/.*"path"[^"]*"\(.*\)".*/\1/p' "$vdf")
  done
  return 1
}

# "C:/users/steamuser/Zomboid/Lua/PZ_Pulse" -> the real directory it stands for.
wine_to_host() {
  local win=$1 letter rest dosdev target
  letter=$(printf '%s' "${win:0:1}" | tr '[:upper:]' '[:lower:]')
  rest=${win:3}                                   # past the "C:/"
  [ -n "$wine_prefix" ] || wine_prefix=$(find_wine_prefix) || return 1
  dosdev="$wine_prefix/dosdevices/$letter:"
  [ -e "$dosdev" ] || return 1
  target=$(cd -- "$dosdev" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s' "$target" "$rest"
}

# A file:// URL -> a path this machine can actually open. A native path arrives
# as file:///home/you/Zomboid and needs only the scheme removed; a Wine path
# arrives as file:///C:/users/steamuser/Zomboid and needs translating first.
# Prints nothing on failure.
file_path() {
  local p=${1#file://}
  p=$(url_decode "$p")
  if [[ $p =~ ^/[A-Za-z]:/ ]]; then
    p=$(wine_to_host "${p#/}") || return 1
  fi
  printf '%s' "${p%/}"                            # trailing slash off
}

# ------------------------------------------------------------------ the folder
#
# Beside the saved script - a location the player chose. If that folder is
# read-only (a downloads folder on a locked-down system, a mounted image), fall
# back to the home directory rather than failing on the first mkdir.
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P) || here="$HOME"
[ -w "$here" ] || { warn "Can't write to $here - using $HOME instead."; here="$HOME"; }
root="$here/PZ_Dashboards"
mkdir -p "$root" || { bad "Couldn't create $root"; exit 1; }

cat >"$root/README.txt" <<'README'
PZ Dashboards - shared folder
=============================

Created by serve_dashboard.sh, for the Project Zomboid mods PZ Pulse / PZ Map.

The folders in here are LINKS, not copies:

  <Mod>-web    ->  the mod's dashboard page, inside your Steam workshop folder
  <Mod>-data   ->  the live status files the game writes while you are playing

Because they are links and not copies, they always point at the current
version. A mod update can never leave a stale copy behind in here.

index.html is a small menu page listing the mods, rewritten on every run.

Is it safe to delete this folder?  Yes. `rm -r` on it removes only the links.
Your mods, your saves and your game data are not touched - deleting a symlink
never touches what it points at.

Want it somewhere else?  Move it, or move the script and run it again; the
links hold absolute paths, so they keep working either way. Do not `cp -r` it
without -d / -a, though: a plain recursive copy follows the links and would
give you a real duplicate of your mod and data folders.
README

# Replaces the link and only the link. `rm` on a symlink removes the link
# itself - it is `rm -r` with a TRAILING SLASH on the name that follows it into
# the target, and the targets here are the player's mod folder and their live
# data. Never write that.
link_dir() {
  local link=$1 target=$2
  if [ ! -d "$target" ]; then bad "Can't find: $target"; return 1; fi
  if [ -L "$link" ]; then
    rm -- "$link" || return 1
  elif [ -e "$link" ]; then
    bad "$link already exists as a real folder - move it aside and re-run"; return 1
  fi
  ln -s -- "$target" "$link"
}

# The dashboard URL carries both paths: the page before ?d=, the data after it.
linked=0
menu_html=''
for u in ${url_list[@]+"${url_list[@]}"}; do
  if [[ ! $u =~ ^(file:[^?]+)\?d=(file:.+)$ ]]; then
    warn "Skipped - that doesn't look like a dashboard URL:"
    warn "  $u"
    warn "  Use the 'Copy dashboard URL' button in the mod's options."
    continue
  fi
  page=$(file_path "${BASH_REMATCH[1]}")
  data=$(file_path "${BASH_REMATCH[2]}")
  if [ -z "$page" ] || [ -z "$data" ]; then
    bad "That URL uses Windows drive letters, so the game is running under Proton,"
    bad "and the Wine prefix isn't where this script looked for it."
    bad "  $u"
    bad "Find the folder named PZ_Pulse (or PZ_Map) that contains heartbeat.txt,"
    bad "and the index.html beside it under 42/media/web, then link them by hand:"
    bad "  ln -s <that page folder> $root/PZ_Pulse-web"
    bad "  ln -s <that data folder> $root/PZ_Pulse-data"
    continue
  fi

  web=$(dirname "$page")                          # .../<ModName>/42/media/web
  # web -> media -> 42 -> <ModName>. Three levels up; two silently gives "42".
  name=$(basename "$(dirname "$(dirname "$(dirname "$web")")")")

  if [ ! -d "$data" ]; then
    bad "Can't find the data folder: $data"
    bad "  Load a save once with the mod enabled, then run this again."
    continue
  fi

  link_dir "$root/$name-web"  "$web"  || continue
  link_dir "$root/$name-data" "$data" || continue
  linked=$((linked + 1))
  menu_html="$menu_html<a href='/$name-web/index.html?d=/$name-data/'>$name</a>"
  good "Linked $name"
done

# Two different failures, and they must not share a message. "The box is empty"
# printed after a URL that WAS in the box but could not be resolved sends the
# reader back to re-do the one step they already did right.
if [ "$linked" -eq 0 ]; then
  say ""
  if [ "$pasted" -gt 0 ]; then
    bad "Nothing could be linked - the reason is printed above."
    exit 1
  fi
  bad "Nothing to share - the box at the top is still empty."
  bad "Get a URL in game, from either mod:"
  bad "  Options > Mods > PZ Pulse > 'Copy dashboard URL'"
  bad "             (or) > PZ Map  > 'Copy map URL'"
  bad "Paste it on a blank line in the box, then run this again."
  exit 1
fi

# Served at "/" so the phone never has to type a URL containing ?d=.
{
  printf '%s' "<!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>"
  printf '%s' "<title>PZ dashboards</title><style>body{background:#222;color:#e2e2e2;"
  printf '%s' "font:20px system-ui,sans-serif;padding:2em}a{color:#f3e7cb;display:block;padding:.6em 0}"
  printf '%s' "</style><h1>PZ dashboards</h1>"
  printf '%s' "$menu_html"
} >"$root/index.html"

# ------------------------------------------------------------------- the address
#
# `ip route get` reads the routing table to answer "which of my addresses would
# a packet to the internet leave from" - it sends nothing and needs no network.
#
# Every candidate is shape-checked before it is accepted. Without that, a
# command that does not exist the way this expects prints its own usage text ON
# STDOUT and the whole page of it becomes the "address."
keep_ipv4() { local v; v=$(head -n1); [[ $v =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && printf '%s' "$v"; }

lan_ip=$(ip -4 route get 1.1.1.1 2>/dev/null |
         sed -n 's/.* src \([0-9.]*\).*/\1/p' | keep_ipv4)
[ -n "$lan_ip" ] || lan_ip=$(hostname -I 2>/dev/null | awk '{print $1}' | keep_ipv4)
[ -n "$lan_ip" ] || lan_ip=$(ipconfig getifaddr en0 2>/dev/null | keep_ipv4)   # macOS
if [ -z "$lan_ip" ]; then
  lan_ip=localhost
  warn "Couldn't work out this machine's address on the network, so the link"
  warn "below only works on this machine. Find your address with 'ip addr' (look"
  warn "for a 192.168.x.x or 10.x.x.x) and use that in place of localhost."
fi

if ! command -v python3 >/dev/null 2>&1; then
  bad ""
  bad "This needs python3 to serve the files. Everything above was plain bash,"
  bad "but nothing in bash can hold open a network port and speak HTTP."
  bad "  Debian / Ubuntu / Mint:  sudo apt install python3"
  bad "  Fedora / Nobara:         sudo dnf install python3"
  bad "  Arch / Manjaro:          sudo pacman -S python"
  bad "The links in $root are already made, so any static web server pointed at"
  bad "that folder will do instead - just make sure it serves .txt as JavaScript."
  exit 1
fi

say ""
note "  Open this on your device:  http://$lan_ip:$port/"
say  "  Serving files from:        $root"
say  "  Press Ctrl+C to stop."
say  ""

# --- Will a firewall actually let the other device in? ----------------------
# The failure is invisible: a blocked inbound connection is dropped, not
# refused, so the other device spins forever and neither end prints anything.
# Loopback skips the filter, so fetching our own URL can't detect it. Most
# desktop Linux ships with nothing enabled and this says nothing at all; the
# distros that DO turn a firewall on by default are exactly the ones where a
# player would otherwise debug a hang.
firewall_hint() {
  local blocked='' fix='' after=''
  if command -v firewall-cmd >/dev/null 2>&1 &&
     firewall-cmd --state >/dev/null 2>&1; then
    if firewall-cmd --list-ports 2>/dev/null | grep -qw "$port/tcp"; then
      return                                       # already open, say nothing
    fi
    blocked="firewalld is running and port $port is not open."
    fix="sudo firewall-cmd --add-port=$port/tcp"
    after="  That lasts until you reboot, which is the right amount for this.
  Add --permanent if you would rather it stayed."
  elif command -v ufw >/dev/null 2>&1 &&
       command -v systemctl >/dev/null 2>&1 &&
       systemctl is-active --quiet ufw 2>/dev/null; then
    if LC_ALL=C ufw status 2>/dev/null | grep -q "^$port"; then
      return
    fi
    blocked="ufw is running, and it does not look like port $port is open."
    fix="sudo ufw allow $port/tcp"
    # Unlike the firewalld one, a ufw rule survives a reboot - so the thing
    # worth saying here is how to take it back off again.
    after="  A ufw rule stays until you remove it. When you are done sharing:
    sudo ufw delete allow $port/tcp"
  else
    return
  fi

  warn "  ---------------------------------------------------------------"
  warn "  Your firewall is probably going to block that address."
  warn "  $blocked"
  warn "  A blocked connection is dropped rather than refused, so the other"
  warn "  device will just spin forever with no error."
  warn ""
  warn "  To fix it, in another terminal:"
  note "    $fix"
  warn ""
  warn "$after"
  warn "  It takes effect straight away - leave this running and just reload"
  warn "  the page on the other device."
  warn "  ---------------------------------------------------------------"
  warn ""
}
firewall_hint

# --- serve --------------------------------------------------------------------
# Python only holds the socket. It reads its program from stdin, so nothing
# extra is written to disk and the whole thing stays one file.
python3 - "$root" "$port" <<'PY'
import functools, http.server, socketserver, sys

root, port = sys.argv[1], int(sys.argv[2])


class Handler(http.server.SimpleHTTPRequestHandler):
    # .txt is served as JavaScript deliberately: the dashboard pulls its data
    # with a <script> tag, and over HTTP a text/plain script runs only while no
    # nosniff header is present - a bet on browser behaviour rather than a rule.
    # If the page ever loads but shows no data over HTTP, look here first.
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.txt': 'application/javascript',
        '.js': 'application/javascript',
        '.html': 'text/html',
        '.css': 'text/css',
        '.png': 'image/png',
    }

    def end_headers(self):
        # The data files are rewritten every second; a cached one is a frozen
        # dashboard, which reads as "the mod stopped working".
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("  %s\n" % (fmt % args))


# translate_path() drops every ".." component before joining, so a request can't
# escape the folder - and it does NOT resolve symlinks, which is what lets our
# two links out to the mod and data folders keep working.
class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


try:
    with Server(('0.0.0.0', port), functools.partial(Handler, directory=root)) as httpd:
        httpd.serve_forever()
except OSError as e:
    sys.stderr.write(
        "\n  Couldn't open port %d - %s\n"
        "  Something else is using it, or this is already running in another\n"
        "  window. Change `port` at the top of the script to 8001 and re-run.\n"
        % (port, e))
    sys.exit(1)
except KeyboardInterrupt:
    sys.stderr.write("\n  Stopped.\n")
PY
