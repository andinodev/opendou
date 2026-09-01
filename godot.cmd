@echo off
setlocal

:: Priority 1: Check environment variables
if defined GODOT_PATH (
    if exist "%GODOT_PATH%" (
        "%GODOT_PATH%" %*
        exit /b %ERRORLEVEL%
    )
)

if defined GodotSteamPath (
    if exist "%GodotSteamPath%" (
        "%GodotSteamPath%" %*
        exit /b %ERRORLEVEL%
    )
)

:: Priority 2: Check standard Steam Godot installation
set "STEAM_GODOT=C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if exist "%STEAM_GODOT%" (
    "%STEAM_GODOT%" %*
    exit /b %ERRORLEVEL%
)

set "STEAM_GODOT_64=C:\Program Files\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if exist "%STEAM_GODOT_64%" (
    "%STEAM_GODOT_64%" %*
    exit /b %ERRORLEVEL%
)

:: Priority 3: Fallback to PATH godot.exe
where godot.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    godot.exe %*
    exit /b %ERRORLEVEL%
)

echo [ERROR] Could not find Godot Steam executable at:
echo   %STEAM_GODOT%
echo Please set GODOT_PATH environment variable.
exit /b 1
