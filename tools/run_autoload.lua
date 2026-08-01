-- run_autoload.lua — type LOADM"ROBOTSA" + EXEC, then get out of the way.
--
-- For the LIVE gate (run.sh --auto). Unlike tools/a2c_liverun.lua this does not
-- instrument, sample, snapshot or drive the menu — it only saves the operator
-- the two lines of typing and then stops touching the machine entirely, so what
-- is on screen from that point is the port running, not a harness.
--
-- Idioms obeyed:
--   §14b  natkeyboard.in_use armed at script load, frames before the first post
--   §14c  posts gated on nk.empty, never on a frame gap
--   §14d  LOADM takes ~1000 frames on this image — poll for the LAST segment,
--         and for the prompt to return, before typing EXEC. Typing into a DECB
--         still doing disk I/O drops the keystrokes silently (A2 §6).
--
-- Monitor Type is NOT set here — run.sh supplies it via -cfg_directory, so a
-- manual run without this script gets RGB too.

local mach   = manager.machine
local mem    = mach.devices[":maincpu"].spaces["program"]
local screen = mach.screens[":screen"]
local nk     = mach.natkeyboard

nk.in_use = true                                    -- §14b

local function rd(a) return mem:read_u8(a) end

-- Screen codes, not ASCII: space is $60, ASCII $20-$3F stored +$40 (§14f).
local function prompt_back_after_loadm()
  local seen = false
  for row = 0, 15 do
    local t = {}
    for col = 0, 31 do
      local b = rd(0x0400 + row * 32 + col)
      t[#t + 1] = (b == 0x60) and " "
               or (b >= 0x40 and b <= 0x5F) and string.char(b)
               or (b >= 0x60 and b <= 0x7F) and string.char(b - 0x40)
               or "."
    end
    local line = (table.concat(t):gsub("%s+$", ""))
    if line:find("LOADM", 1, true) then seen = true
    elseif seen and line == "OK" then return true end
  end
  return false
end

-- The LAST segment is the completion signal, not the first. $5D00 is level_a's
-- load address and $7EFF its final byte; $0E01 (the entry point) lands early and
-- is NOT evidence the load is done.
local function loaded()
  return rd(0x0E01) == 0x10 and rd(0x0E02) == 0xCE
     and rd(0x41F6) ~= 0xFF
     and (rd(0x5D00) ~= 0xFF or rd(0x7EFF) ~= 0xFF)
end

local state, mark = "settle", 0

-- One status line per transition. Not instrumentation of the port — it exists so
-- that if --auto does nothing on the operator's machine, WHY is answerable
-- without a debugging session.
local logf = io.open(os.getenv("AUTOLOAD_LOG") or "build/autoload.log", "w")
local function say(fmt, ...)
  if not logf then return end
  logf:write(string.format(fmt, ...) .. "\n")
  logf:flush()
end
say("autoload armed")

_G._autoload_notifier = emu.add_machine_frame_notifier(function()
  local f = screen:frame_number()

  if state == "settle" then
    if f >= 300 then
      nk:post('LOADM"ROBOTSA"\r'); say("f=%d typed LOADM", f)
      state, mark = "drain", f
    end

  elseif state == "drain" then
    if nk.empty then say("f=%d LOADM keystrokes drained", f); state, mark = "await", f end

  elseif state == "await" then
    if loaded() and prompt_back_after_loadm() then
      say("f=%d load complete (%d frames)", f, f - mark)
      state, mark = "exec", f
    elseif f - mark > 2400 then
      say("f=%d TIMEOUT waiting for the load; handing the keyboard back", f)
      say("  $0E01=%02X $41F6=%02X $5D00=%02X $7EFF=%02X",
          rd(0x0E01), rd(0x41F6), rd(0x5D00), rd(0x7EFF))
      state = "off"
    end

  elseif state == "exec" then
    if f - mark > 120 then
      nk:post('EXEC\r'); say("f=%d typed EXEC - machine is yours", f)
      state = "off"
    end

  elseif state == "off" then
    -- Deliberately inert from here. The keyboard is yours.
  end
end)
