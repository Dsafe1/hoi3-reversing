-- Where in the scripts each math.random is drawn: hoidraws.lua's `R` line with the Lua call stack after it.
-- dofile() after hoi.lua and hoidraws.lua, with hoiDraws(folder) armed; hoiLuaWhere(depth) then replaces its math.random
-- breakpoint with one that writes `R <esp> <rand> | <source>:<line> < <source>:<line> ...`, innermost Lua frame first.
--
-- The stack is read off the lua_State as Lua 5.1.4 lays it out for a 32-bit build (lstate.h, lobject.h): L->ci at +0x14
-- and L->base_ci at +0x28; a CallInfo is 24 bytes, its func (a TValue, 16 bytes) at +4 and its savedpc at +0xC; a closure's
-- isC byte at +6 and an LClosure's Proto at +0x10; a Proto's code at +0xC, lineinfo at +0x14, source (a TString, whose
-- characters begin at +0x10) at +0x20. At the hook (lua5.1.dll+0x198B2, inside math_random) L is [EBP+8], and a Lua
-- frame's savedpc is the instruction after its call, so its line is lineinfo[(savedpc - code) / 4 - 1].
local LUA_RAND = getAddress('lua5.1.dll') + 0x198B2

local function frames(L, depth)
  local out = {}
  local ci = readInteger(L + 0x14)
  local base = readInteger(L + 0x28)
  while ci and base and ci >= base and #out < depth do
    local func = readInteger(ci + 4)
    local cl = func and readInteger(func)
    if cl and cl ~= 0 then
      if readBytes(cl + 6, 1) == 0 then
        local p = readInteger(cl + 0x10)
        local code, lineinfo, source = readInteger(p + 0xC), readInteger(p + 0x14), readInteger(p + 0x20)
        local saved = readInteger(ci + 0xC)
        local line = -1
        if saved and code and lineinfo and lineinfo ~= 0 then
          line = readInteger(lineinfo + ((saved - code) // 4 - 1) * 4) or -1
        end
        local name = (source and readString(source + 0x10, 80)) or '?'
        out[#out + 1] = string.format('%s:%d', name:match('[^/\\]+$') or name, line)
      end
    end
    ci = ci - 24
  end
  return table.concat(out, ' < ')
end

function hoiLuaWhere(depth)
  depth = depth or 6
  pcall(debug_removeBreakpoint, LUA_RAND)
  debug_setBreakpoint(LUA_RAND, 1, bptExecute, bpmDebugRegister, function()
    debug_getContext()
    pcall(function()
      hdOut:write(string.format('R %X %d | %s\n', ESP, EAX, frames(readInteger(EBP + 8), depth)))
      hdCount = hdCount + 1
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'math.random logged with its Lua stack'
end
