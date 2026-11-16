-- What each unit's AI combat-model caches hold after a load, before entering: the record's FINDINGS-liveread.md section 46
-- has the original never initialise them, so a loaded unit's first estimate takes its cached half as memory left it where
-- the dirty byte is nought, and works it out where the byte is anything else. dofile() after hoi.lua.
--
-- hoiDumpModelCaches(path) writes one line a unit of every country's list (CCountry +0xBAC, a CList: the unit at a node's
-- +0, the next node at +8), capped at 20000 units:
--   <tag> <unit +0x14> <province +0xD0 or 0> <defence dirty +0x2D8> <defence +0x2D4 as a float> <attack dirty +0x2E0>
--   <attack +0x2DC as a float> <name, CUnit +0x16C>
-- Read while the game stands between the load and Play (hoiBeforePlay in hoiLoadSave), when nothing has looked yet.
local b = hoiB

local function cstring(a)
  local cap, len = readInteger(a + 0x14), readInteger(a + 0x10)
  if not len or len <= 0 or len > 260 then return '?' end
  if cap and cap >= 16 then return readString(readInteger(a), len) end
  return readString(a, len)
end

function hoiDumpModelCaches(path)
  local f = io.open(path, 'w')
  local countries = readInteger(readInteger(b + 0x16855A4) + 0x16C)
  local units = 0
  for id = 0, 200 do
    local c = readInteger(countries + id * 4)
    if not c or c == 0 then break end
    local tag = readString(c + 0x1E4, 3)
    local node = readInteger(c + 0xBAC)
    while node and node ~= 0 and units < 20000 do
      local u = readInteger(node)
      if u and u ~= 0 then
        local p = readInteger(u + 0x130)
        f:write(string.format('%s %d %d %d %.6f %d %.6f %s\n', tag, readInteger(u + 0x14), (p and p ~= 0) and readInteger(p + 0xD0) or 0,
          readBytes(u + 0x2D8, 1), readFloat(u + 0x2D4) or 0, readBytes(u + 0x2E0, 1), readFloat(u + 0x2DC) or 0, cstring(u + 0x16C)))
        units = units + 1
      end
      node = readInteger(node + 8)
    end
  end
  f:close()
  return units
end
