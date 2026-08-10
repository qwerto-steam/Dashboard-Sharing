# ===========================================================================
#  PZ Pulse / PZ Map - view your dashboard on another device
#
#  1. In game, for EITHER mod (or both - you don't need both):
#       Options -> Mods -> PZ Pulse -> "Copy dashboard URL"
#       Options -> Mods -> PZ Map   -> "Copy map URL"
#  2. Paste it on a blank line in the box below. One mod per line.
#  3. Save this file and close it. Then right-click it -> Run with PowerShell.
#  4. Windows warns "Open File - Security Warning" about running a downloaded
#     file. Choose OPEN. To stop it asking every time, untick "Always ask
#     before opening this file" first.
#  5. Windows will ask once to allow this on your network - choose PRIVATE.
#     (If it never asks, or you miss it, this script tells you what to do.)
#  6. On the other device, open the http:// address it prints. Tap the mod name.
#
#  It makes a PZ_Dashboards folder holding shortcuts to the mod and to your
#  live data, then serves that folder on your local network. Nothing is copied,
#  nothing is modified, nothing leaves your network. Close the window to stop.
# ===========================================================================

$urls = @'
##############  PASTE YOUR URL(S) ON A BLANK LINE BELOW  ###############
##############  PZ Pulse and/or PZ Map - one per line    ###############


##############  STOP - DON'T PASTE BELOW THIS LINE       ###############
##############  SAVE IT. CLOSE IT. RUN IT.               ###############
'@

$port = 8000

# --------------------------------------------------------------- no edits below

$ErrorActionPreference = 'Stop'

# The single-quoted here-string takes every line verbatim, so the URL can be
# pasted bare with nothing to escape and the banners can live inside the box.
# Drop blank and banner lines; anything else falls through to the loop below,
# so a mis-paste gets an error rather than vanishing.
$urls = @($urls -split "`r?`n" |
          ForEach-Object { $_.Trim() } |
          Where-Object { $_ -and -not $_.StartsWith('#') })

function Convert-FileUrl([string]$u) {
  $p = $u -replace '^file:/+', ''
  $p = [uri]::UnescapeDataString($p)          # the Lua escapes spaces only (%20)
  ($p -replace '/', '\').TrimEnd('\')
}

# Beside the saved .ps1 (a location the player chose); Documents when pasted,
# where the working directory is nobody's decision.
$base = if ($PSScriptRoot) { $PSScriptRoot } else { [Environment]::GetFolderPath('MyDocuments') }
if (-not $base) { $base = $env:USERPROFILE }
# Never put a junction in a synced folder - OneDrive would walk it into the
# Steam workshop folder.
if ($base -match 'OneDrive') {
  $base = Join-Path $env:USERPROFILE 'Zomboid'
  Write-Host "That folder is synced by OneDrive - using $base instead." -ForegroundColor Yellow
}
$root = Join-Path $base 'PZ_Dashboards'
New-Item -ItemType Directory -Path $root -Force | Out-Null

$readme = @"
PZ Dashboards - shared folder
=============================

Created by serve_dashboard.ps1, for the Project Zomboid mods PZ Pulse / PZ Map.

The folders in here are SHORTCUTS, not copies:

  <Mod>-web    ->  the mod's dashboard page, inside your Steam workshop folder
  <Mod>-data   ->  the live status files the game writes while you are playing

Because they are shortcuts and not copies, they always point at the current
version. A mod update can never leave a stale copy behind in here.

Is it safe to delete this folder?  Yes. Deleting it removes only the shortcuts.
Your mods, your saves and your game data are not touched.

Want it somewhere else?  Run the script again from the folder you want it in,
then delete this one. Do not drag this folder somewhere else - Windows copies
the CONTENTS of shortcuts like these rather than moving the links, so you would
end up with a real duplicate of your mod and data folders.
"@
Set-Content -LiteralPath (Join-Path $root 'README.txt') -Value $readme -Encoding UTF8

function New-SafeJunction([string]$link, [string]$target) {
  if (-not (Test-Path -LiteralPath $target)) { throw "not found: $target" }
  $existing = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
  if ($existing) {
    if ($existing.LinkType) {
      # Deletes the LINK only. Never Remove-Item -Recurse: the targets are the
      # player's mod folder and their live data, and that would delete through.
      [IO.Directory]::Delete($link, $false)
    } else {
      throw "$link already exists as a real folder - move it aside and re-run"
    }
  }
  New-Item -ItemType Junction -Path $link -Target $target | Out-Null
}

# The dashboard URL carries both paths: the page before ?d=, the data after it.
$mods = @()
foreach ($u in $urls) {
  if ($u -notmatch '^(?<page>file:[^?]+)\?d=(?<data>file:.+)$') {
    Write-Host "Skipped - that doesn't look like a dashboard URL:" -ForegroundColor Yellow
    Write-Host "  $u" -ForegroundColor Yellow
    Write-Host "  Use the 'Copy dashboard URL' button in the mod's options." -ForegroundColor Yellow
    continue
  }
  $page = Convert-FileUrl $Matches.page
  $data = Convert-FileUrl $Matches.data
  $web  = Split-Path $page -Parent           # ...\<ModName>\42\media\web
  # web -> media -> 42 -> <ModName>. Four levels; three silently gives "42".
  $name = Split-Path (Split-Path (Split-Path (Split-Path $web -Parent) -Parent) -Parent) -Leaf

  if (-not (Test-Path -LiteralPath $web)) {
    Write-Host "Can't find the mod folder: $web" -ForegroundColor Red; continue
  }
  if (-not (Test-Path -LiteralPath $data)) {
    Write-Host "Can't find the data folder: $data" -ForegroundColor Red
    Write-Host "  Load a save once with the mod enabled, then run this again." -ForegroundColor Red; continue
  }

  New-SafeJunction (Join-Path $root "$name-web")  $web
  New-SafeJunction (Join-Path $root "$name-data") $data
  $mods += [pscustomobject]@{ Name = $name; Link = "/$name-web/index.html?d=/$name-data/" }
  Write-Host "Linked $name" -ForegroundColor Green
}

if (-not $mods) {
  Write-Host "`nNothing to share - the box at the top is still empty." -ForegroundColor Red
  Write-Host "Get a URL in game, from either mod:" -ForegroundColor Red
  Write-Host "  Options > Mods > PZ Pulse > 'Copy dashboard URL'" -ForegroundColor Red
  Write-Host "             (or) > PZ Map  > 'Copy map URL'" -ForegroundColor Red
  Write-Host "Paste it on a blank line in the box, then run this again." -ForegroundColor Red
  return
}

$ip = (Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).IPv4Address.IPAddress
if (-not $ip) {
  $ip = ([Net.Dns]::GetHostAddresses($env:COMPUTERNAME) |
          Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1).IPAddressToString
}
if (-not $ip) { $ip = 'localhost' }

# Served at "/" so the phone never has to type a URL containing ?d=.
$index = "<!doctype html><meta name=viewport content='width=device-width,initial-scale=1'>" +
         "<title>PZ dashboards</title><style>body{background:#222;color:#e2e2e2;" +
         "font:20px system-ui,sans-serif;padding:2em}a{color:#f3e7cb;display:block;padding:.6em 0}" +
         "</style><h1>PZ dashboards</h1>" +
         (($mods | ForEach-Object { "<a href='$($_.Link)'>$($_.Name)</a>" }) -join '')

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $port)
try {
  $listener.Start()
} catch {
  Write-Host "`nCouldn't open port $port - something else is using it," -ForegroundColor Red
  Write-Host "or this is already running in another window." -ForegroundColor Red
  Write-Host "Change `$port at the top to 8001 and try again." -ForegroundColor Red
  return
}

Write-Host ""
Write-Host "  Open this on your device:  http://${ip}:$port/" -ForegroundColor Cyan
Write-Host "  Serving files from:        $root"
Write-Host "  Close this window to stop."
Write-Host ""

# --- Will Windows Firewall actually let the other device in? ----------------
# The failure is invisible: a blocked inbound connection is dropped, not
# refused, so the other device spins forever and neither end prints anything.
# Loopback skips the inbound filter, so fetching our own URL can't detect it -
# the rules have to be read directly. Reading needs no Administrator.
function Test-InboundAllowed([int]$p) {
  try {
    $cat = (Get-NetConnectionProfile -ErrorAction SilentlyContinue |
             Where-Object { $_.IPv4Connectivity -ne 'Disconnected' } |
             Select-Object -First 1).NetworkCategory
    if (-not $cat) { return $null }
    # Get-NetConnectionProfile says "DomainAuthenticated"; firewall rules say "Domain".
    $name = if ("$cat" -eq 'DomainAuthenticated') { 'Domain' } else { "$cat" }

    # Enabled inbound Allow rules covering the profile we're on. Filters join
    # back to rules on InstanceID == rule.Name.
    $rules = @{}
    foreach ($r in (Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True `
                      -ErrorAction SilentlyContinue)) {
      if ("$($r.Profile)" -eq 'Any' -or "$($r.Profile)" -match $name) { $rules[$r.Name] = $true }
    }
    if ($rules.Count -eq 0) { return $null }

    # One pass: find a rule for THIS exe, and record which rules are scoped to
    # a program at all.
    $exe = (Get-Process -Id $PID).Path
    $appScoped = @{}
    $ours = $false
    foreach ($f in (Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue)) {
      $prog = "$($f.Program)"
      if (-not $prog -or $prog -eq 'Any') { continue }
      $appScoped[$f.InstanceID] = $true
      if ($exe -and $prog -eq $exe -and $rules.ContainsKey($f.InstanceID)) { $ours = $true }
    }
    if ($ours) { return @{ Allowed = $true; Category = $name } }

    foreach ($f in (Get-NetFirewallPortFilter -ErrorAction SilentlyContinue)) {
      if ("$($f.Protocol)" -ne 'TCP' -or -not $rules.ContainsKey($f.InstanceID)) { continue }
      $lp = @($f.LocalPort)
      # An app rule leaves LocalPort as "Any", so counting "Any" on its own made
      # every allowed program (Steam, a browser) read as "port open" - it passed
      # in the blocked state. Only an unscoped rule opens a port.
      if ($lp -contains "$p" -or ($lp -contains 'Any' -and -not $appScoped.ContainsKey($f.InstanceID))) {
        return @{ Allowed = $true; Category = $name }
      }
    }
    return @{ Allowed = $false; Category = $name }
  } catch {
    return $null   # can't tell - say nothing rather than cry wolf
  }
}

$fw = Test-InboundAllowed $port
if ($fw -and -not $fw.Allowed) {
  Write-Host "  ---------------------------------------------------------------" -ForegroundColor Yellow
  Write-Host "  Windows Firewall is going to block that address." -ForegroundColor Yellow
  Write-Host "  This network is $($fw.Category), and nothing is allowed in on port $port," -ForegroundColor Yellow
  Write-Host "  so the other device will just spin forever with no error." -ForegroundColor Yellow
  Write-Host ""
  if ($fw.Category -eq 'Public') {
    # Don't talk a player into opening a port on a network Windows classes as
    # untrusted. If it is their home network, re-classifying it is the safer
    # and smaller fix.
    Write-Host "  Windows has this network marked PUBLIC, which is how it treats" -ForegroundColor Yellow
    Write-Host "  cafe and hotel wifi. If this is your own home network, fix that" -ForegroundColor Yellow
    Write-Host "  instead - it is safer than opening a port to a public network:" -ForegroundColor Yellow
    Write-Host "    Settings > Network & Internet > (your network) > Private network" -ForegroundColor Cyan
    Write-Host "  Then close this window and run this again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  If it really is a public network and you want to do it anyway:" -ForegroundColor Yellow
  } else {
    Write-Host "  To fix it:" -ForegroundColor Yellow
  }
  Write-Host "  Press Start, type 'terminal', right-click Terminal and pick" -ForegroundColor Yellow
  Write-Host "  'Run as administrator'. Paste this one line and press Enter:" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "    New-NetFirewallRule -DisplayName 'PZ Dashboards' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port -Profile $($fw.Category) -RemoteAddress LocalSubnet" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  It takes effect straight away - leave this window running and" -ForegroundColor Yellow
  Write-Host "  just reload the page on the other device." -ForegroundColor Yellow
  Write-Host ""
  # A Windows firewall rule survives a reboot, so the thing worth saying is how
  # to take it back off. The .sh says this for ufw; without it the port stays
  # open for good after one evening of sharing.
  Write-Host "  That rule stays until you remove it - a reboot does not. When you" -ForegroundColor Yellow
  Write-Host "  are done sharing, in an administrator terminal:" -ForegroundColor Yellow
  Write-Host "    Remove-NetFirewallRule -DisplayName 'PZ Dashboards'" -ForegroundColor Cyan
  Write-Host "  ---------------------------------------------------------------" -ForegroundColor Yellow
  Write-Host ""
}

$rootFull = [IO.Path]::GetFullPath($root)

function Send-Response($stream, [int]$code, [string]$status, [string]$type, [byte[]]$body) {
  $head = "HTTP/1.1 $code $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`n" +
          "Cache-Control: no-store`r`nConnection: close`r`n`r`n"
  $hb = [Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($hb, 0, $hb.Length)
  if ($body.Length) { $stream.Write($body, 0, $body.Length) }
  $stream.Flush()
}

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $stream.ReadTimeout = 3000
      $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
      $line = $reader.ReadLine()
      if (-not $line) { continue }
      $parts = $line -split ' '
      if ($parts[0] -ne 'GET') {
        Send-Response $stream 405 'Method Not Allowed' 'text/plain' ([byte[]]@()); continue
      }

      $path = [uri]::UnescapeDataString(($parts[1] -split '\?')[0])
      if ($path -eq '/') {
        Send-Response $stream 200 'OK' 'text/html; charset=utf-8' ([Text.Encoding]::UTF8.GetBytes($index))
        continue
      }

      # Traversal check on the LOGICAL path: GetFullPath collapses ".." and does
      # NOT resolve junctions, so our links stay inside the root by this test
      # while an escape attempt doesn't.
      $full = [IO.Path]::GetFullPath((Join-Path $rootFull ($path.TrimStart('/') -replace '/', '\')))
      if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        Send-Response $stream 403 'Forbidden' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('no'))
        continue
      }
      if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Send-Response $stream 404 'Not Found' 'text/plain' ([Text.Encoding]::UTF8.GetBytes('not found'))
        continue
      }

      # .txt is served as JavaScript deliberately: the page pulls its data with
      # a <script> tag, and over HTTP a text/plain script runs only while no
      # nosniff header is present - a bet on browser behaviour. If the page ever
      # loads but shows no data over HTTP, look here first.
      $type = switch ([IO.Path]::GetExtension($full).ToLower()) {
        '.html' { 'text/html; charset=utf-8' }
        '.txt'  { 'application/javascript; charset=utf-8' }
        '.js'   { 'application/javascript; charset=utf-8' }
        '.png'  { 'image/png' }
        '.css'  { 'text/css; charset=utf-8' }
        default { 'application/octet-stream' }
      }
      Send-Response $stream 200 'OK' $type ([IO.File]::ReadAllBytes($full))
    } catch {
    } finally {
      $client.Close()
    }
  }
} finally {
  $listener.Stop()
}
