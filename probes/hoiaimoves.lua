-- Every move the AI gives, with the step that gave it: dofile() after hoi.lua, then hoiAiMoves(file). Armed with hoidraws.lua
-- (from hoiBeforePlay, after hoiDraws) it rides along with a recording, so a playback that parts can be read from the
-- original's side: which of its steps moved the unit (FINDINGS-liveread.md, section 110).
--
-- A line per call of CEU3AI::MoveUnit (0x49A840): `<tick> move <tag> <unit name> at <province> -> <province asked>
-- record <recordOnly> safe <safe> vsafe <verySafe> from <caller rva> 2CC=<the unit's +0x2CC as the call begins>`.
-- The caller says the step: 0x4CA94A the line's pull, 0x4CA2B3 the line's second ring, 0x4CC42E a headquarters pulled in,
-- 0x4CB751 the garrisons - see each function's record in ghidra/project.json.
--
-- It is an int3, the four debug registers being hoidraws.lua's: an int3 is lifted while a hit is handled, so a move made on
-- another thread meanwhile can go unlogged (entering the July 1941 save logged 156 of the 171 land orders the save shows).
-- Every rva is valid only for this build.
local AT = hoiB + 0x49A840

local function cstr(a)
  local cap, len = readInteger(a + 0x14), readInteger(a + 0x10)
  if not len or len <= 0 or len > 200 then return '?' end
  local s = (cap and cap >= 16) and readString(readInteger(a), len) or readString(a, len)
  return (s or '?'):gsub('[\128-\255]', '?')
end

function hoiAiMoves(path)
  amOut = io.open(path, 'a')
  debug_setBreakpoint(AT, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      local u = readInteger(ESP + 4)
      amOut:write(string.format('%d move %s %s at %d -> %d record %d safe %d vsafe %d from %X 2CC=%d\n', hoiTick(),
        readString(u + 0x124, 3), cstr(u + 0x16C), readInteger(readInteger(u + 0x130) + 0xD0), readInteger(ESP + 8),
        readInteger(ESP + 0xC), readBytes(ESP + 0x10, 1), readBytes(ESP + 0x14, 1), readInteger(ESP) - hoiB,
        readInteger(u + 0x2CC) or -1))
      amOut:flush()
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

function hoiAiMovesStop()
  pcall(debug_removeBreakpoint, AT)
  pcall(function() amOut:close() end)
  return 'stopped'
end
