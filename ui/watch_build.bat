@echo off
SETLOCAL EnableDelayedExpansion

:: --- CONFIGURATION ---
SET "RES_NAME=LastMenu"
SET "BUILD_DIR=dist"
title [ADVANCED WATCHER] - %RES_NAME%

:: Console Aesthetics
mode con: cols=95 lines=28
color 0F

:init
cls
:: Extract time without milliseconds
set "CUR_TIME=%time:~0,8%"
echo ========================================================
echo     SVELTE MONITORING SYSTEM V1.0
echo     Launched: %date% at %CUR_TIME%
echo ========================================================
echo.

:: 1. Environment Check
if not exist "package.json" (
    color 0C
    echo [%date% - %time:~0,8%] [ERROR] package.json not found. 
    pause
    exit
)

if not exist "node_modules\" (
    echo [%date% - %time:~0,8%] [INFO] node_modules missing. Installing...
    call npm install
)

:: 2. Build Folder Cleanup
if exist "%BUILD_DIR%" (
    echo [%date% - %time:~0,8%] [CLEAN] Cleaning the %BUILD_DIR% folder...
    rmdir /s /q "%BUILD_DIR%"
)

echo [%date% - %time:~0,8%] [READY] Active monitoring on: %RES_NAME%
echo [HINT] Press Ctrl+C to stop the watcher.
echo --------------------------------------------------------
echo.

:: 3. Launching Vite
:: Note: In --watch mode, Vite displays its own timestamps, 
:: but the crash message below will use ours.
color 0A
call npx vite build --watch --clearScreen false

:: 4. Exit/Crash Management
if %ERRORLEVEL% neq 0 (
    set "CUR_TIME=%time:~0,8%"
    color 0C
    echo.
    echo --------------------------------------------------------
    echo [%date% - !CUR_TIME!] [CRASH] The Watcher has stopped.
    echo [TIPS] Check your Svelte code to fix the error.
    echo --------------------------------------------------------
    timeout /t 10
    goto init
)

echo [%date% - %time:~0,8%] [END] Monitoring finished.
pause