-- a2c_liverun.lua — drive DECB to LOADM + EXEC ROBOTSA.BIN and capture the result.
--
-- Launch path: live-disk (CLAUDE.md §4). Nothing is poked; the guest loads the
-- program off the mounted floppy exactly as a user would.
--
-- Idioms this obeys (mame-idioms-coco3-port.md):
--   §14a  -ext fdc is mandatory — supplied on the command line
--   §14b  natkeyboard.in_use armed at script load, frames before the first post
--   §14c  posts gated on nk.empty, never on a frame gap
--   §14d  LOADM takes ~400 frames — poll for the image, don't settle-and-hope
--   §14f  the VDG text screen is screen codes, not ASCII
--   §11l  Monitor Type is a :screen_config ioport, not a CLI flag; set it early
--   §10   keep taps/notifiers referenced in _G or they are GC'd and stop firing
--   §10   write output with io.open; print() is not captured headless
--
-- TWO INSTRUMENT FAULTS FOUND IN v1 OF THIS FILE, corrected here:
--
--   1. GIME registers $FF90-$FF9F are WRITE-ONLY. v1 read them back and logged
--      the result as state. All five read the SAME value ($1B, then $26) every
--      time, which is the floating bus, not the registers. Reading them cannot
--      tell you the video mode. v2 installs a WRITE TAP instead, which records
--      what the guest actually wrote.
--
--   2. v1 polled for the FIRST segment ($0E01) and treated that as "loaded".
--      $0E01 is segment 7 of 11 — $14BB, $41F6, $5200 and $5D00 (25 KB, the
--      bulk of the file) are still streaming in at that point. v1 then typed
--      EXEC into a DECB that was busy doing disk I/O and not polling the
--      keyboard, so the keystrokes were dropped and the game never started.
--      v2 waits for the LAST segment AND for the prompt to come back.

local OUT   = os.getenv("A2C_OUT") or "build/a2c"
local SHOTS = OUT .. "/shot"

local logfile = assert(io.open(OUT .. "/run.log", "w"))
local function log(fmt, ...)
  local line = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  logfile:write(line .. "\n")
  logfile:flush()
end

local mach   = manager.machine
local cpu    = mach.devices[":maincpu"]
local mem    = cpu.spaces["program"]
local screen = mach.screens[":screen"]

local function rd(a) return mem:read_u8(a) end

-- §11l: Monitor Type — Composite is MAME's default; CLAUDE.md §4 gates on RGB.
local function set_rgb()
  for tag, port in pairs(mach.ioport.ports) do
    for name, field in pairs(port.fields) do
      if name == "Monitor Type" then
        field.user_value = 1
        log("monitor : '%s' on %s set to 1 (RGB), reads back %d",
            name, tag, field.user_value)
        return true
      end
    end
  end
  log("monitor : WARNING — 'Monitor Type' not found; running MAME default (Composite)")
  return false
end

mach.natkeyboard.in_use = true          -- §14b: arm at script load
set_rgb()
log("mame    : %s", emu.app_version and emu.app_version() or "?")
log("nk armed: in_use=%s", tostring(mach.natkeyboard.in_use))

-- ===================================================================== taps ==
-- GIME writes. The registers cannot be read back (fault 1 above), so the only
-- way to know whether the port set its video mode is to watch the writes.
_G._gime_writes = {}
_G._gime_tap = mem:install_write_tap(0xFF90, 0xFF9F, "gime", function(offset, data)
  local t = _G._gime_writes
  t[#t + 1] = string.format("f=%d $%04X <- $%02X", screen:frame_number(), offset, data)
  return data
end)

-- Palette registers $FFB0-$FFBF are write-only too, and fb2png.py needs them to
-- decode a framebuffer dump into real colours. Capture the guest's writes.
_G._pal = {}
for i = 0, 15 do _G._pal[i] = 0 end
_G._pal_writes = {}
_G._pal_tap = mem:install_write_tap(0xFFB0, 0xFFBF, "palette", function(offset, data)
  _G._pal[offset - 0xFFB0] = data
  local t = _G._pal_writes
  t[#t + 1] = string.format("f=%d $%04X <- $%02X", screen:frame_number(), offset, data)
  return data
end)

-- Execution detection. §10: on 6809 program-space READ taps DO fire on opcode
-- fetch, so tapping the game's code region is a direct "did control transfer"
-- test — far stronger than sampling PC once a frame.
_G._exec_seen  = false
_G._exec_frame = nil
_G._exec_first = nil
_G._code_tap = mem:install_read_tap(0x0E01, 0x3B4D, "gamecode", function(offset, data)
  if not _G._exec_seen then
    _G._exec_seen  = true
    _G._exec_frame = screen:frame_number()
    _G._exec_first = offset
  end
  return data
end)

-- CURRENT_KEY ($0034) is filled by the VSYNC IRQ keyboard scanner and consumed
-- by ISLOOP. Sampling it once a frame always reads $00 because the loop clears
-- it faster than that. Tapping the WRITES is the only way to see which key
-- codes actually arrived — which separates "the harness never delivered the
-- key" from "the game ignored it".
_G._keys = {}
_G._key_tap = mem:install_write_tap(0x0034, 0x0034, "curkey", function(offset, data)
  if data ~= 0 then
    local t = _G._keys
    t[#t + 1] = string.format("f=%d key=$%02X (%d)", screen:frame_number(), data, data)
  end
  return data
end)

-- INIT_GAME is at $0E33 (build.lst line 285). Menu 0 = START GAME does
-- JMP INIT_GAME, so a read here is the definitive "the game actually started".
_G._ingame_seen  = false
_G._ingame_frame = nil
_G._ingame_tap = mem:install_read_tap(0x0E33, 0x0E35, "initgame", function(offset, data)
  if not _G._ingame_seen then
    _G._ingame_seen  = true
    _G._ingame_frame = screen:frame_number()
  end
  return data
end)

log("taps    : GIME write $FF90-$FF9F, palette $FFB0-$FFBF, game-code read $0E01-$3B4D, CURRENT_KEY write $0034, INIT_GAME read $0E33")

-- ================================================================== helpers ==
-- §14f: VDG screen codes. Space is $60; ASCII $20-$3F is stored +$40. Decoding
-- as plain ASCII makes correctly-typed input look mangled.
local function screen_rows()
  local rows = {}
  for row = 0, 15 do
    local t = {}
    for col = 0, 31 do
      local b = rd(0x0400 + row * 32 + col)
      t[#t + 1] = (b == 0x60) and " "
               or (b >= 0x40 and b <= 0x5F) and string.char(b)
               or (b >= 0x60 and b <= 0x7F) and string.char(b - 0x40)
               or "."
    end
    rows[#rows + 1] = (table.concat(t):gsub("%s+$", ""))
  end
  return rows
end

local function dump_screen(tag)
  log("--- text screen (%s) ---", tag)
  for _, r in ipairs(screen_rows()) do log("|%s|", r) end
  log("--- end ---")
end

-- The prompt is back when a bare "OK" appears BELOW the LOADM line we typed.
local function prompt_returned()
  local rows, seen_cmd = screen_rows(), false
  for _, r in ipairs(rows) do
    if r:find('LOADM', 1, true) then seen_cmd = true
    elseif seen_cmd and r == "OK" then return true
    elseif seen_cmd and r:find("ERROR", 1, true) then return true, r end
  end
  return false
end

local function screen_error()
  for _, r in ipairs(screen_rows()) do
    if r:find("ERROR", 1, true) then return r end
  end
  return nil
end

-- Fault 2: the LAST segment is the load-complete signature, not the first.
-- $5D00 is level_a's load address; $7EFF is its final byte.
local function image_complete()
  return rd(0x0E01) == 0x10 and rd(0x0E02) == 0xCE     -- entry  LDS #$01FF
     and rd(0x41F6) ~= 0xFF                            -- font
     and (rd(0x5D00) ~= 0xFF or rd(0x7EFF) ~= 0xFF)    -- level, last segment
end

local function log_state(tag)
  log("%-22s frame=%-6d PC=$%04X S=$%04X DP=$%02X CC=$%02X  (GIME regs are write-only — see tap log)",
      tag, screen:frame_number(), cpu.state["PC"].value,
      cpu.state["S"].value, cpu.state["DP"].value, cpu.state["CC"].value)
end

-- v2 logged five successful snapshots and wrote zero files: screen:snapshot()
-- with a path silently no-ops, and nothing appeared in MAME's snap directory
-- either. v3 tries both APIs and VERIFIES a file exists, so a failure is
-- reported as a failure (CLAUDE.md §8 — instruments fail silently).
-- FOURTH instrument fault, and this one was pure operator error: v2/v3 called
-- screen:snapshot("build/a2c/shot-x.png") and then checked for the file at that
-- literal path. MAME resolves a snapshot filename RELATIVE TO -snapshot_directory,
-- so the files were really landing at snap/build/a2c/shot-x.png and the checks
-- looked in the wrong place — reporting "0 bytes" for snapshots that existed.
-- Pass a BARE filename, point -snapshot_directory at OUT, and verify there.
local snaps_taken = 0
local function snap(name)
  local file = "shot-" .. name .. ".png"
  local ok, err = pcall(function() screen:snapshot(file) end)
  local path = OUT .. "/" .. file
  local f = io.open(path, "rb")
  local bytes = 0
  if f then bytes = #f:read("a"); f:close() end
  if bytes > 0 then snaps_taken = snaps_taken + 1 end
  log("snapshot %-16s -> %d bytes at %s%s", name, bytes, path,
      ok and "" or ("   pcall FAILED: " .. tostring(err)))
end

local function dump_fb(name)
  local f = assert(io.open(OUT .. "/fb-" .. name .. ".bin", "wb"))
  local t = {}
  for a = 0x8000, 0x8000 + 32000 - 1 do
    t[#t + 1] = string.char(rd(a))
    if #t == 4096 then f:write(table.concat(t)); t = {} end
  end
  if #t > 0 then f:write(table.concat(t)) end
  f:close()
  -- Palette alongside it, or fb2png.py has nothing to decode indices with.
  local p = assert(io.open(OUT .. "/palette.bin", "wb"))
  for i = 0, 15 do p:write(string.char(_G._pal[i])) end
  p:close()
  log("framebuffer -> %s/fb-%s.bin (32000 B from $8000) + palette.bin", OUT, name)
end

-- ============================================================ state machine ==
local nk    = mach.natkeyboard
local state = "settle"
local mark  = 0

local function advance(s) state = s; mark = screen:frame_number() end

_G._a2c_notifier = emu.add_machine_frame_notifier(function()
  local f = screen:frame_number()

  if state == "settle" then
    if f >= 300 then
      log_state("boot settled")
      dump_screen("after boot")
      snap("00-decb-prompt")
      advance("post_loadm")
    end

  elseif state == "post_loadm" then
    -- Short filename deliberately: the $034D segment sits inside the $02DC line
    -- buffer and a long command eats the 112-byte margin (CLAUDE.md §2H).
    nk:post('LOADM"ROBOTSA"\r')
    log("posted LOADM at frame %d", f)
    advance("drain_loadm")

  elseif state == "drain_loadm" then
    if nk.empty then                      -- §14c
      log("LOADM keystrokes drained at frame %d (%d frames)", f, f - mark)
      advance("await_load")
    elseif f - mark > 900 then
      log("TIMEOUT draining the LOADM post"); dump_screen("drain timeout")
      advance("give_up")
    end

  elseif state == "await_load" then
    local err = screen_error()
    if err then
      log("DECB REPORTED AN ERROR during LOADM at frame %d: %s", f, err)
      log_state("load error"); dump_screen("load error"); snap("01-load-error")
      advance("give_up")
    elseif image_complete() and prompt_returned() then
      log("LOAD COMPLETE at frame %d (%d frames after typing)", f, f - mark)
      log("  $0E01..$0E08 = %02X %02X %02X %02X %02X %02X %02X %02X  (entry)",
          rd(0x0E01), rd(0x0E02), rd(0x0E03), rd(0x0E04),
          rd(0x0E05), rd(0x0E06), rd(0x0E07), rd(0x0E08))
      log("  $41F6 = %02X %02X (font)   $5200 = %02X %02X (tileset)   $5D00 = %02X %02X (level)",
          rd(0x41F6), rd(0x41F7), rd(0x5200), rd(0x5201), rd(0x5D00), rd(0x5D01))
      log("  $7EFF = %02X (last byte of the last segment)", rd(0x7EFF))
      log_state("loaded"); dump_screen("after LOADM"); snap("01-after-loadm")
      advance("post_exec")
    elseif f - mark > 2400 then
      log("TIMEOUT waiting for the load to complete")
      log("  $0E01=%02X $41F6=%02X $5D00=%02X $7EFF=%02X  prompt_returned=%s",
          rd(0x0E01), rd(0x41F6), rd(0x5D00), rd(0x7EFF), tostring(prompt_returned()))
      log_state("load timeout"); dump_screen("load timeout"); snap("01-load-timeout")
      advance("give_up")
    end

  elseif state == "post_exec" then
    if f - mark > 120 then                -- let the prompt settle
      nk:post('EXEC\r')
      log("posted EXEC at frame %d", f)
      advance("drain_exec")
    end

  elseif state == "drain_exec" then
    if nk.empty then                      -- §14c, missing in v1
      log("EXEC keystrokes drained at frame %d (%d frames)", f, f - mark)
      dump_screen("after EXEC typed")
      log("  line buffer $02DD..$02E4 = %02X %02X %02X %02X %02X %02X %02X %02X",
          rd(0x02DD), rd(0x02DE), rd(0x02DF), rd(0x02E0),
          rd(0x02E1), rd(0x02E2), rd(0x02E3), rd(0x02E4))
      log("  $034D..$0354 sprite table = %02X %02X %02X %02X %02X %02X %02X %02X",
          rd(0x034D), rd(0x034E), rd(0x034F), rd(0x0350),
          rd(0x0351), rd(0x0352), rd(0x0353), rd(0x0354))
      advance("watch")
    elseif f - mark > 900 then
      log("TIMEOUT draining the EXEC post"); advance("give_up")
    end

  elseif state == "watch" then
    local d = f - mark
    if d % 120 == 0 then
      log_state("watch +" .. d)
      log("  game code entered: %s | CURRENT_KEY($0034)=$%02X MENUY($0049)=$%02X",
          tostring(_G._exec_seen), rd(0x0034), rd(0x0049))
    end
    if d == 60 then snap("02-exec+60") end
    if d % 120 == 0 and _G._ingame_seen then
      log("  IN GAME since frame %d", _G._ingame_frame)
    end

    -- Menu reached: PC sits in ISLOOP ($1F75), which is
    --     ISLOOP  LDA CURRENT_KEY / BEQ ISLOOP
    -- i.e. the intro menu waiting on a key that the VSYNC IRQ scanner fills.
    -- Dispatch §6 lists "keyboard not responding" as reportable, so probe it
    -- MECHANICALLY: MENUY ($0049) is the menu selection; if pressing the
    -- documented move-down key changes it, the scanner and the IRQ are live.
    if d == 240 then
      _G._menuy_before = rd(0x0049)
      log("KEYBOARD PROBE: MENUY before = $%02X; posting 'S' (KEY_MOVE_DOWN default)",
          _G._menuy_before)
      dump_screen("+240 after EXEC (menu)")
      snap("03-menu"); dump_fb("menu")
      nk:post("S")
    end
    if d == 420 then
      local after = rd(0x0049)
      log("KEYBOARD PROBE: MENUY after 'S' = $%02X (before $%02X) -> scanner %s",
          after, _G._menuy_before,
          (after ~= _G._menuy_before) and "RESPONDED" or "NO CHANGE")
      _G._kbd_responded = (after ~= _G._menuy_before)
      dump_fb("after-key")
      -- 'S' moved the selection DOWN, i.e. OFF "START GAME" (menu 0) and onto
      -- menu 1 = cycle-through-maps, whose handler deliberately BRA ISLOOPs.
      -- Go back up before selecting, or SPACE just cycles the map.
      log("posting 'W' (KEY_MOVE_UP default) to return to menu 0 = START GAME")
      nk:post("W")
    end
    if d == 600 then
      log("MENUY back to $%02X (want $00 = START GAME)", rd(0x0049))
      snap("04-menu-start"); dump_fb("menu-start")
    end

    -- SPACE selects the current entry (IS002 -> EXEC_COMMAND). With MENUY = 0
    -- that is JMP INIT_GAME ($0E33), which the read tap below confirms.
    if d == 660 then
      log("posting SPACE to select menu 0 (START GAME); MENUY=$%02X", rd(0x0049))
      nk:post(" ")
    end
    if d == 840 then
      log("after SPACE: in-game=%s MENUY=$%02X", tostring(_G._ingame_seen), rd(0x0049))
      dump_screen("+840 (after START GAME)")
      snap("05-ingame"); dump_fb("ingame-1")
    end
    if d == 1200 then snap("06-ingame2"); dump_fb("ingame-2") end
    if d == 1800 then
      snap("07-final"); dump_fb("ingame-3")
      dump_screen("+1800 after EXEC")
      log_state("final")
      advance("done")
    end

  elseif state == "give_up" then
    log_state("giving up"); snap("99-failure"); advance("done")

  elseif state == "done" then
    if f % 600 == 0 then
      log("=== GIME writes seen: %d ===", #_G._gime_writes)
      for i, w in ipairs(_G._gime_writes) do
        if i <= 60 then log("  %s", w) end
      end
      if #_G._gime_writes > 60 then log("  ... %d more", #_G._gime_writes - 60) end
      log("=== palette writes seen: %d ===", #_G._pal_writes)
      for _, w in ipairs(_G._pal_writes) do log("  %s", w) end
      local pal = {}
      for i = 0, 15 do pal[#pal + 1] = string.format("$%02X", _G._pal[i]) end
      log("=== final palette $FFB0-$FFBF: %s ===", table.concat(pal, " "))
      log("=== CURRENT_KEY writes seen: %d ===", #_G._keys)
      for _, k in ipairs(_G._keys) do log("  %s", k) end
      log("=== game code entered: %s ===", tostring(_G._exec_seen))
      log("=== keyboard responded: %s ===", tostring(_G._kbd_responded))
      log("=== snapshots written: %d ===", snaps_taken)
      advance("quiet")
    end

  elseif state == "quiet" then
    -- idle until -seconds_to_run ends the session
  end
end)

log("harness armed")
