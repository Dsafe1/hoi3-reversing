-- hoitradegates.lua, after probes/hoi.lua (FINDINGS-liveread.md, section 152): two of CTradeAction::GetAIAcceptance's gates for one actor's offers -
-- CTradeAction::IsConvoyPossible (VA 0xA390D0, the action in ECX) and CEU3AI::AlreadyTradingDisabledResource (VA
-- 0x89B3E0, the route on the stack; the route's from id at +0x28, to id at +0x30) - each with the answer read at its
-- return. All four debug registers.
local b = hoiB
local CONVOY = b + 0x6390D0
local DISABLED = b + 0x49B3E0

local function tagOf(id)
  local db = readInteger(b + 0x16855A4)
  local c = readInteger(readInteger(db + 0x16C) + id * 4)
  return c and readString(c + 0xCA4, 3) or '?'
end
local function add(s) hoiGwLines[#hoiGwLines + 1] = s end

local function watch(addr, name, describe)
  local slot = name .. 'Ret'
  debug_setBreakpoint(addr, 1, bptExecute, bpmDebugRegister, function()
    debug_getContext()
    local ok, err = pcall(function()
      local what = describe()
      if not what then return end
      if hoiGw[slot] then add(name .. ' busy ' .. what); return end
      local ret = readInteger(ESP)
      local tick = hoiTick()
      hoiGw[slot] = ret
      debug_setBreakpoint(ret, 1, bptExecute, bpmDebugRegister, function()
        debug_getContext()
        pcall(function() add(string.format('tick %d %s %s answered %d', tick, name, what, EAX & 0xFF)) end)
        debug_removeBreakpoint(ret)
        hoiGw[slot] = nil
        debug_continueFromBreakpoint(co_run)
        return 1
      end)
    end)
    if not ok then hoiGwErrs[#hoiGwErrs + 1] = tostring(err) end
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
end

function hoiGwArm(actorTag)
  hoiGwLines, hoiGwErrs, hoiGw = {}, {}, {}
  watch(CONVOY, 'convoy', function()
    local t = ECX
    if tagOf(readInteger(t + 0xC)) ~= actorTag then return nil end
    return tagOf(readInteger(t + 0xC)) .. '->' .. tagOf(readInteger(t + 0x14))
  end)
  watch(DISABLED, 'disabled', function()
    local r = readInteger(ESP + 4)
    local f, to = tagOf(readInteger(r + 0x28)), tagOf(readInteger(r + 0x30))
    if f ~= actorTag and to ~= actorTag then return nil end
    return f .. '->' .. to
  end)
  return 'armed'
end

function hoiGwStop()
  debug_removeBreakpoint(CONVOY); debug_removeBreakpoint(DISABLED)
  for _, r in pairs(hoiGw or {}) do debug_removeBreakpoint(r) end
  return 'stopped'
end

function hoiGwDump()
  return 'ERR ' .. table.concat(hoiGwErrs, '\n') .. '\nLINES\n' .. table.concat(hoiGwLines, '\n')
end
