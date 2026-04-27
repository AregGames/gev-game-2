$ErrorActionPreference = 'Stop'

$projectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectFile = Join-Path $projectPath 'project.godot'
$godotExe = 'C:\godot\Godot_v4.6.2-stable_win64.exe'
$fallbackGodot = 'C:\godot\godot.cmd'

if (-not (Test-Path $projectFile)) {
    Write-Error "No project.godot found at $projectPath"
}

Set-Location $projectPath

if (Test-Path $godotExe) {
    & $godotExe --path $projectPath --editor
    exit $LASTEXITCODE
}

$godotCommand = Get-Command godot -ErrorAction SilentlyContinue
if ($godotCommand) {
    & $godotCommand.Source --path $projectPath --editor
    exit $LASTEXITCODE
}

if (Test-Path $fallbackGodot) {
    & $fallbackGodot --path $projectPath --editor
    exit $LASTEXITCODE
}

Write-Error 'Godot was not found. Install it at C:\godot or add it to PATH.'
