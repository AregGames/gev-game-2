@echo off
set "PROJECT_DIR=%~dp0"
set "GODOT_EXE=C:\godot\Godot_v4.6.2-stable_win64.exe"

if not exist "%PROJECT_DIR%project.godot" (
  echo No project.godot found at "%PROJECT_DIR%"
  exit /b 1
)

if exist "%GODOT_EXE%" (
  "%GODOT_EXE%" --path "%PROJECT_DIR%" --editor
  exit /b %ERRORLEVEL%
)

godot --path "%PROJECT_DIR%" --editor
