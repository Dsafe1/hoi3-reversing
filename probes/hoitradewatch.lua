-- hoitradewatch.lua, after probes/hoi.lua (FINDINGS-liveread.md, section 152): CTradeAction::GetAIAcceptance (rva 0x638B00) for one actor's offers - the
-- recipient, the route's two goods blocks (route at action +0x28; +0x34 what `to` hands over, +0x44 what `from` does;
-- goods 2 money, 6 rare materials, thousandths) and the score it returns, read by a one-shot breakpoint at the return.
local b = hoiB
local ACCEPT = b + 0x638B00

local function tagOf(id)
  local db = readInteger(b + 0x16855A4)
  local c = readInteger(readInteger(db + 0x16C) + id * 4)
  return c and readString(c + 0xCA4, 3) or '?'
end
local function goods(vec)
  local p = readInteger(vec)
  local t = {}
  for i = 0, 6 do t[#t + 1] = tostring(readInteger(p + i * 4)) end
  return table.concat(t, ' ')
end
local function add(s) hoiTwLines[#hoiTwLines + 1] = s end

function hoiTwArm(actorTag)
  hoiTwLines, hoiTwErrs, hoiTwRet = {}, {}, nil
  debug_setBreakpoint(ACCEPT, 1, bptExecute, bpmDebugRegister, function()
    debug_getContext()
    local ok, err = pcall(function()
      local t = ECX
      if tagOf(readInteger(t + 0xC)) ~= actorTag then return end
      local r = t + 0x28
      add(string.format('tick %d %s->%s type %d from[%s] to[%s] ret %X', hoiTick(), tagOf(readInteger(t + 0xC)),
        tagOf(readInteger(t + 0x14)), readInteger(t + 0x18), goods(r + 0x44), goods(r + 0x34), readInteger(ESP) - b))
      if hoiTwRet == nil then
        local ret = readInteger(ESP)
        hoiTwRet = ret
        debug_setBreakpoint(ret, 1, bptExecute, bpmDebugRegister, function()
          debug_getContext()
          pcall(function() add(string.format('  answered %d', EAX)) end)
          debug_removeBreakpoint(ret)
          hoiTwRet = nil
          debug_continueFromBreakpoint(co_run)
          return 1
        end)
      end
    end)
    if not ok then hoiTwErrs[#hoiTwErrs + 1] = tostring(err) end
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

function hoiTwStop()
  debug_removeBreakpoint(ACCEPT)
  if hoiTwRet then debug_removeBreakpoint(hoiTwRet); hoiTwRet = nil end
  return 'stopped'
end

function hoiTwDump()
  return 'ERR ' .. table.concat(hoiTwErrs, '\n') .. '\nLINES\n' .. table.concat(hoiTwLines, '\n')
end
