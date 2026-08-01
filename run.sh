#!/bin/sh
# run.sh — launch the port LIVE in MAME for the 25.3 visual gate.
#
# THIS IS THE GATE PATH. CLAUDE.md §4: a captured still is `static-png` and is
# explicitly NOT a live gate — it verifies endpoints only and cannot show
# motion. Visual authority is Jay's live MAME run, never a captured frame
# (mame-idioms-coco3-port.md §11). Stills are a last resort for the cases where
# a live run is impossible, not the deliverable.
#
# What this sets up for you, all of which is easy to get wrong by hand:
#   -ext fdc          MANDATORY. A bare coco3 has NO disk controller, boots to
#                     plain ECB, and LOADM silently does nothing (idioms §14a).
#   -cfg_directory    points at a copy of tools/mame-cfg/coco3.cfg, which sets
#                     Monitor Type = RGB. Not a CLI flag; MAME defaults to
#                     Composite and would decode the palette wrongly (§11l, §18).
#   a COPY of the .dsk  MAME opens floppies read-write and will rewrite the
#                     built artifact. Never mount it directly (§24).
#
# Usage:
#   ./run.sh           boot to DECB and hand you the keyboard
#   ./run.sh --auto    additionally type LOADM"ROBOTSA" + EXEC for you
#
# Env: ROMPATH (default C:/mame/roms), MAME (default mame)

set -e

MAME=${MAME:-mame}
ROMPATH=${ROMPATH:-C:/mame/roms}

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

AUTO=""
if [ "$1" = "--auto" ]; then
    AUTO="-autoboot_script tools/run_autoload.lua"
    shift
fi
# Anything else is forwarded to MAME verbatim, so the launcher itself can be
# exercised headlessly (e.g. ./run.sh --auto -seconds_to_run 60 -video none).

if [ ! -f build/robots.dsk ]; then
    echo "build/robots.dsk not found — building first."
    ./build.sh
    echo ""
fi

# §24: mount a scratch copy, never build/robots.dsk itself.
cp -f build/robots.dsk build/run.dsk

# MAME rewrites cfg on exit; keep the tracked template pristine.
mkdir -p build/mame-cfg
cp -f tools/mame-cfg/coco3.cfg build/mame-cfg/coco3.cfg

if [ -z "$AUTO" ]; then
    cat <<'EOF'
=====================================================================
  At the OK prompt, type these two lines:

      LOADM"ROBOTSA"
      EXEC

  The load takes ~17 seconds of emulated time — wait for OK to return
  before typing EXEC. Then at the menu:

      W / S      move the selection up / down
      SPACE      select
                 entry 0 = START GAME
                 entry 1 = cycle map   (returns to the menu by design)
                 entry 2 = difficulty  (returns to the menu by design)

  Note: level select and restart are known not to work — MAP_LOAD_ROUTINE
  is commented out. Each disk hardcodes one level (level_a here).
=====================================================================
EOF
fi

exec "$MAME" coco3 \
    -rompath "$ROMPATH" \
    -ext fdc \
    -flop1 build/run.dsk \
    -cfg_directory build/mame-cfg \
    -window -nomaximize -prescale 3 \
    -skip_gameinfo \
    $AUTO "$@"
