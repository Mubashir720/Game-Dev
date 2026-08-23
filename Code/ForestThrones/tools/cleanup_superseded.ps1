# ═══════════════════════════════════════════════════════════════════════════════
#  Forest Thrones — retire the files the v5 rebuild superseded.
#
#  Run once from the project root:
#      cd "D:\Game Dev\Code\ForestThrones"
#      powershell -ExecutionPolicy Bypass -File tools\cleanup_superseded.ps1
#
#  Or just double-click  tools\cleanup.bat
#
#  ── This MOVES, it does not DELETE ────────────────────────────────────────────
#  Everything listed below is moved into  _superseded_backup\  keeping its folder
#  structure, so nothing is destroyed and putting a file back is a drag and drop.
#  Godot ignores the folder because of the .gdignore this script drops in it.
#
#  Once the project has run clean for a while, delete _superseded_backup yourself.
#
#  (The git repo is at D:\Game Dev, one level ABOVE this project. Whether these
#  particular files were ever committed is not something the script can promise,
#  which is exactly why it moves them instead of trusting `git checkout`.)
#
#  Add -WhatIf to see what would happen without touching anything.
# ═══════════════════════════════════════════════════════════════════════════════

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $BackupDir = '_superseded_backup'
)

$ErrorActionPreference = 'Stop'

# Safety: refuse to run anywhere that isn't the Forest Thrones project root.
if (-not (Test-Path 'project.godot')) {
    Write-Error "No project.godot here. cd to the project root first (D:\Game Dev\Code\ForestThrones)."
    exit 1
}

$superseded = [ordered]@{
    'scripts/data/map_generator.gd'          = 'duplicate of scenes/world/map_generator.gd (older, unused copy)'
    'scenes/hud/hud.gd'                      = 'replaced by scenes/hud/game_hud.gd'
    'scenes/hud/hud.tscn'                    = 'replaced by scenes/hud/game_hud.tscn'
    'scenes/lighting/day_night_cycle.gd'     = 'replaced by scenes/lighting/day_night_controller.gd'
    'scenes/lighting/day_night_cycle.tscn'   = 'replaced by the DayNightController node in main.tscn'
    'scenes/resources/resource_spawner.gd'   = 'replaced by scenes/resources/resource_field.gd'
    'scenes/resources/resource_node.gd'      = 'replaced by scenes/resources/resource_field.gd (records, not nodes)'
    'scenes/resources/resource_node.tscn'    = 'replaced by scenes/resources/resource_field.gd'
    'scenes/squad/squad.gd'                  = 'replaced by scenes/ai/squad_brain.gd'
    'scenes/player/player_stats.gd'          = 'replaced by scenes/actors/actor.gd'
    'scenes/player/player.tscn'              = 'MatchDirector spawns the player from script now'
    'scenes/camera/game_camera.tscn'         = 'replaced by the IsometricCamera node in main.tscn'
    'scenes/world/world.tscn'                = 'main.tscn creates the World node directly'
    'scenes/minimap/minimap.tscn'            = 'GameHUD builds the Minimap in code'
    'scripts/test_economy.gd'                = 'replaced by the harnesses in tools/'
    'scripts/test_living_world.gd'           = 'replaced by the harnesses in tools/'
    'scripts/test_moments.gd'                = 'replaced by the harnesses in tools/'
    'scripts/test_polish.gd'                 = 'replaced by the harnesses in tools/'
}

# Stop Godot from importing anything we park in the backup folder.
if (-not (Test-Path $BackupDir)) {
    if ($PSCmdlet.ShouldProcess($BackupDir, 'Create backup folder')) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $BackupDir '.gdignore') -Force | Out-Null
    }
}

$moved   = 0
$missing = 0

foreach ($path in $superseded.Keys) {
    $reason = $superseded[$path]
    $win    = $path -replace '/', '\'

    # Each script also has a Godot .uid sibling; take it with the file.
    $targets = @($win, "$win.uid") | Where-Object { Test-Path $_ }

    if ($targets.Count -eq 0) {
        Write-Host ("  already gone   {0}" -f $path) -ForegroundColor DarkGray
        $missing++
        continue
    }

    foreach ($t in $targets) {
        $dest    = Join-Path $BackupDir $t
        $destDir = Split-Path $dest -Parent
        if ($PSCmdlet.ShouldProcess($t, "Move to $BackupDir")) {
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Move-Item -LiteralPath $t -Destination $dest -Force
        }
    }
    Write-Host ("  retired        {0}" -f $path) -ForegroundColor Green
    Write-Host ("                 -> {0}" -f $reason) -ForegroundColor DarkGray
    $moved++
}

# Prune directories this leaves empty.
foreach ($dir in @('scenes\camera', 'scripts\data')) {
    if ((Test-Path $dir) -and -not (Get-ChildItem -LiteralPath $dir -Force)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Remove empty directory')) {
            Remove-Item -LiteralPath $dir -Force
        }
        Write-Host ("  removed dir    {0}" -f $dir) -ForegroundColor Green
    }
}

Write-Host ''
Write-Host ("Done. {0} retired into {1}\, {2} already absent." -f $moved, $BackupDir, $missing) -ForegroundColor Cyan
Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  1. Reopen the project in Godot so it rebuilds its script class cache.'
Write-Host '  2. Verify:  godot --headless --script tools/compile_all.gd     (expect failures=0)'
Write-Host ("  3. Once you are happy, delete {0}\ yourself." -f $BackupDir)
