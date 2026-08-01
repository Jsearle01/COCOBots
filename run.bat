@echo off
REM run.bat - launch the port LIVE in MAME for the 25.3 visual gate.
REM Windows equivalent of run.sh; see that file for the full commentary.
REM
REM THIS FILE MUST STAY CRLF - cmd.exe cannot parse an LF-only batch file
REM (mame-idioms-coco3-port.md 14g).
REM
REM THIS IS THE GATE PATH. CLAUDE.md section 4: a captured still is static-png
REM and is explicitly NOT a live gate. Visual authority is Jay's live MAME run,
REM never a captured frame (idioms 11).
REM
REM Usage:
REM   run.bat           boot to DECB and hand you the keyboard
REM   run.bat --auto    additionally type LOADM"ROBOTSA" + EXEC for you

setlocal
cd /d "%~dp0"

if "%MAME%"==""    set MAME=mame
if "%ROMPATH%"=="" set ROMPATH=C:/mame/roms

REM --auto selects the autoload script; anything else is forwarded to MAME
REM verbatim, so the launcher itself can be exercised headlessly.
set AUTO=
set EXTRA=
:parseargs
if "%~1"=="" goto parsedone
if "%~1"=="--auto" (set AUTO=-autoboot_script tools/run_autoload.lua) else (set EXTRA=%EXTRA% %~1)
shift
goto parseargs
:parsedone

if not exist build\robots.dsk (
    echo build\robots.dsk not found - building first.
    call build.bat
    if errorlevel 1 exit /b 1
    echo.
)

REM idioms 24: mount a scratch copy, never build\robots.dsk itself.
copy /y build\robots.dsk build\run.dsk >nul

REM MAME rewrites cfg on exit; keep the tracked template pristine.
if not exist build\mame-cfg mkdir build\mame-cfg
copy /y tools\mame-cfg\coco3.cfg build\mame-cfg\coco3.cfg >nul

if "%AUTO%"=="" (
    echo =====================================================================
    echo   At the OK prompt, type these two lines:
    echo.
    echo       LOADM"ROBOTSA"
    echo       EXEC
    echo.
    echo   The load takes ~17 seconds of emulated time - wait for OK to
    echo   return before typing EXEC. Then at the menu:
    echo.
    echo       W / S      move the selection up / down
    echo       SPACE      select
    echo                  entry 0 = START GAME
    echo                  entry 1 = cycle map   ^(returns to menu by design^)
    echo                  entry 2 = difficulty  ^(returns to menu by design^)
    echo.
    echo   Note: level select and restart are known not to work -
    echo   MAP_LOAD_ROUTINE is commented out. Each disk hardcodes one level.
    echo =====================================================================
)

"%MAME%" coco3 -rompath "%ROMPATH%" -ext fdc -flop1 build/run.dsk -cfg_directory build/mame-cfg -window -nomaximize -prescale 3 -skip_gameinfo %AUTO%%EXTRA%

endlocal
