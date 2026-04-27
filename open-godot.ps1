$ErrorActionPreference = 'Stop'

$projectPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$godotCommand = Get-Command godot -ErrorAction SilentlyContinue
$fallbackGodot = 'C:\godot\godot.cmd'

if ($godotCommand) {
    & $godotCommand.Source --path $projectPath --editor
    exit $LASTEXITCODE
}

if (Test-Path $fallbackGodot) {
    & $fallbackGodot --path $projectPath --editor
    exit $LASTEXITCODE
}

Write-Error 'Godot was not found. Add Godot to PATH or install it at C:\godot\godot.cmd.'
