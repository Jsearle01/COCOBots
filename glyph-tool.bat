@echo off
rem glyph-tool.bat - launch the hand-authoring glyph editor from the repo root.
rem   Double-click it, or run:  glyph-tool.bat [--config a192^|shipped] [--tile N]
rem
rem   With no argument it opens the 192-glyph configuration (C5's budget
rem   decision) at the worst-RMS tile from C4's ladder, which is where the
rem   biggest visible win per hour is.
rem
rem   `--config shipped` opens the font and mapping as the game ships today.
rem   The two disagree about bit 7 of a cell code and the tool reads each on its
rem   own terms - see tools\glyph_tool\config.py.
rem
rem   Needs Python + Tkinter + Pillow + numpy.
rem   If the 192-glyph font is missing, regenerate C4's artifacts:
rem       python tools\ladder.py
cd /d "%~dp0"
python tools\glyph_tool\glyph_tool_app.py %*
if errorlevel 1 (
    echo.
    echo [glyph-tool exited with an error above]
    pause
)
