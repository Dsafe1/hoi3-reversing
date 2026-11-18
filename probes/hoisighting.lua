-- Every naval sighting asked, with who looked at whom: dofile() after hoi.lua, then hoiSighting(file). Armed with
-- hoidraws.lua (from hoiBeforePlay, after hoiDraws) it rides along with a recording, so the sighting rolls of a hour whose
-- draws part can be told apart (FINDINGS-liveread.md, section 123).
--
-- An int3 on ShouldStartNavalCombat (0x431840; ours at [esp+4], theirs at [esp+8] as it begins), the four debug registers
-- being hoidraws.lua's. A line per call:
--   <tick> <draws> <ours tag> <ours id> <ours name> at <province> | <theirs tag> <theirs id> <theirs name> <ships>
-- where <draws> is the game generator's draw count (+0x134DA8C) as the call begins - set beside the hour's gen_ dump, whose
-- first figure is the count as the hour began, it is the place in the hour's draws. Every rva is valid only for this build.
local AT = hoiB + 0x31840
local DRAWS = hoiB + 0x134DA8C

local function cstr(a)
  local cap, len = readInteger(a + 0x14), readInteger(a + 0x10)
  if not len or len <= 0 or len > 200 then return '?' end
  local s = (cap and cap >= 16) and readString(readInteger(a), len) or readString(a, len)
  return (s or '?'):gsub('[\128-\255]', '?'):gsub(' ', '_')
end

local function where(u) local p = readInteger(u + 0x130); return (p and p ~= 0) and readInteger(p + 0xD0) or -1 end

function hoiSighting(path)
  sgOut = io.open(path, 'a')
  debug_setBreakpoint(AT, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      local ours, theirs = readInteger(ESP + 4), readInteger(ESP + 8)
      sgOut:write(string.format('%d %d %s %d %s at %d | %s %d %s %d\n', hoiTick(), readInteger(DRAWS),
        readString(ours + 0x124, 3), readInteger(ours + 0x14), cstr(ours + 0x16C), where(ours),
        readString(theirs + 0x124, 3), readInteger(theirs + 0x14), cstr(theirs + 0x16C), readInteger(theirs + 0x40) or -1))
      sgOut:flush()
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

function hoiSightingStop()
  pcall(debug_removeBreakpoint, AT)
  pcall(function() sgOut:close() end)
  return 'stopped'
end
