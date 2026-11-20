-- hoiresvalues.lua, after probes/hoi.lua (FINDINGS-liveread.md, section 152): CResourceValues::GetResourceValues (VA 0x8EA9A0, thiscall:
-- the values in ECX, the country and the good on the stack) for chosen countries and goods, its six floats read at the
-- return: expense, home, convoyed in, pool, income, balance. One return watched at a time; a call that finds it busy is
-- noted as skipped.
local b = hoiB
local GRV = b + 0x4EA9A0

local function tagOf(c) return readString(c + 0xCA4, 3) end
local function add(s) hoiRvLines[#hoiRvLines + 1] = s end

function hoiRvArm(tags, goods)
  hoiRvLines, hoiRvErrs, hoiRvRet = {}, {}, nil
  debug_setBreakpoint(GRV, 1, bptExecute, bpmDebugRegister, function()
    debug_getContext()
    local ok, err = pcall(function()
      local c = readInteger(ESP + 4)
      local g = readInteger(ESP + 8)
      local tag = tagOf(c)
      if not tags[tag] or not goods[g] or (hoiRvHour and hoiTick() % 24 ~= hoiRvHour) then return end
      if hoiRvRet ~= nil then add(string.format('tick %d %s good %d skipped (busy)', hoiTick(), tag, g)); return end
      local ret, this, esp = readInteger(ESP), ECX, ESP
      hoiRvRet = ret
      debug_setBreakpoint(ret, 1, bptExecute, bpmDebugRegister, function()
        debug_getContext()
        pcall(function()
          local f = {}
          for i = 0, 5 do f[#f + 1] = string.format('%.6f', readFloat(this + i * 4)) end
          add(string.format('tick %d %s good %d esp %X: %s', hoiTick(), tag, g, esp, table.concat(f, ' ')))
        end)
        debug_removeBreakpoint(ret)
        hoiRvRet = nil
        debug_continueFromBreakpoint(co_run)
        return 1
      end)
    end)
    if not ok then hoiRvErrs[#hoiRvErrs + 1] = tostring(err) end
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

function hoiRvStop()
  debug_removeBreakpoint(GRV)
  if hoiRvRet then debug_removeBreakpoint(hoiRvRet); hoiRvRet = nil end
  return 'stopped'
end

function hoiRvDump()
  return 'ERR ' .. table.concat(hoiRvErrs, '\n') .. '\nLINES\n' .. table.concat(hoiRvLines, '\n')
end
