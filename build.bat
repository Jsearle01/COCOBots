@echo off
REM build.bat - reproduce the CoCo3 PETSCII Robots binary and its boot disk.
REM Windows equivalent of build.sh; see that file for the full commentary.
REM
REM THIS FILE MUST STAY CRLF. cmd.exe cannot parse an LF-only batch file and
REM fails in a way that looks like a missing toolchain
REM (mame-idioms-coco3-port.md 14g).
REM
REM Expect EXACTLY ONE lwasm warning:
REM   Warning (src/PETROBOTS_6809.asm:3146): Operand size larger than required
REM Any other warning or error is a regression (CLAUDE.md section 1).
REM
REM NEVER mount build\robots.dsk in MAME directly - MAME rewrites floppies
REM (idioms 24). Mount a copy; run.bat does this for you.

setlocal
cd /d "%~dp0"

if "%LWASM%"==""   set LWASM=lwasm
if "%IMGTOOL%"=="" set IMGTOOL=imgtool
if "%PYTHON%"==""  set PYTHON=python

if not exist build mkdir build

echo === 1/4  assemble ===
"%LWASM%" --format=decb --output=build/petrobots.bin --list=build/build.lst src/PETROBOTS_6809.asm
if errorlevel 1 goto :failed

echo.
echo === 2/4  merge game + tileset + level_a ===
"%PYTHON%" tools/decbmerge.py merge --out build/ROBOTSA.BIN --exec 0x0E01 build/petrobots.bin assets/tileset.bin assets/levels/level_a.bin
if errorlevel 1 goto :failed

echo.
echo === 3/4  verify against the pre-verified reference ===
"%PYTHON%" tools/decbmerge.py compare build/ROBOTSA.BIN dist/ROBOTSA.BIN
if errorlevel 1 goto :failed

echo.
echo === 4/4  disk image ===
if exist build\robots.dsk del /q build\robots.dsk
"%IMGTOOL%" create coco_jvc_rsdos build/robots.dsk --heads=1 --tracks=35 --sectors=18 --sectorlength=256
if errorlevel 1 goto :failed
"%IMGTOOL%" put coco_jvc_rsdos build/robots.dsk build/ROBOTSA.BIN ROBOTSA.BIN --ftype=binary --ascii=binary
if errorlevel 1 goto :failed
"%IMGTOOL%" dir coco_jvc_rsdos build/robots.dsk

echo.
echo build OK - build\ROBOTSA.BIN and build\robots.dsk
endlocal
exit /b 0

:failed
echo.
echo BUILD FAILED
endlocal
exit /b 1
