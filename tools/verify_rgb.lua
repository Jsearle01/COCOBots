-- verify_rgb.lua — confirm the cfg template actually applied Monitor Type = RGB.
--
-- Exists because idioms §18 records this failing invisibly on the sibling port:
-- a run left on MAME's Composite default renders the wrong colours while every
-- byte-level check stays green, because the framebuffer holds palette INDICES
-- and Monitor Type only changes how $FFB0-$FFBF are DECODED. Jay caught that one
-- by eye. A config that silently does not apply is the same failure.
--
-- Reads the value back rather than trusting the file (§18: "Confirm the mode
-- took by re-reading value= after").

local out = assert(io.open(os.getenv("RGB_OUT") or "build/rgb-check.txt", "w"))
local found = false

for tag, port in pairs(manager.machine.ioport.ports) do
  for name, field in pairs(port.fields) do
    if name == "Monitor Type" then
      found = true
      out:write(string.format("port=%s field=%s user_value=%d default=%d -> %s\n",
        tag, name, field.user_value, field.defvalue,
        (field.user_value == 1) and "RGB" or "COMPOSITE"))
    end
  end
end

if not found then out:write("Monitor Type field NOT FOUND\n") end
out:close()
