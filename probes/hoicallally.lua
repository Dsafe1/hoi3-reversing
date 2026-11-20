-- hoicallally.lua, after probes/hoi.lua: a call to arms followed through (FINDINGS-liveread.md, section 151) -
-- CCallAllyAction::IsSelectable (rva 0x62A4E0) with its answer read at its return by a one-shot breakpoint (the fourth
-- debug register), Apply (rva 0x627BA0) and GetAIAcceptance (rva 0x62AC80), each with its parties and type. Lines are
-- kept in memory (hoiCw4Lines, read with hoiCw4Dump()), and every handler fetches the hit thread's context first: these
-- run on the AI's worker threads, where without debug_getContext() the registers are not the hit thread's. `value` is a
-- byte: read its low byte only. Every rva is valid only for this build.
local b = hoiB
local SELECTABLE = b + 0x62A4E0
local APPLY = b + 0x627BA0
local ACCEPTANCE = b + 0x62AC80

local function tagOf(id)
  local db = readInteger(b + 0x16855A4)
  local c = readInteger(readInteger(db + 0x16C) + id * 4)
  return c and readString(c + 0xCA4, 3) or '?'
end
local function parties(t)
  return string.format('actor %s recipient %s versus %s type %s value %s', tagOf(readInteger(t + 0xC)),
    tagOf(readInteger(t + 0x14)), tagOf(readInteger(t + 0x2C)), tostring(readInteger(t + 0x18)), tostring(readInteger(t + 0x24)))
end
local function add(s) hoiCw4Lines[#hoiCw4Lines + 1] = s end
local function guard(f)
  return function()
    debug_getContext()
    local ok, err = pcall(f)
    if not ok then hoiCw4Errs[#hoiCw4Errs + 1] = tostring(err) end
    debug_continueFromBreakpoint(co_run)
    return 1
  end
end

function hoiCw4Arm()
  hoiCw4Lines, hoiCw4Errs, hoiCw4Ret = {}, {}, nil
  debug_setBreakpoint(SELECTABLE, 1, bptExecute, bpmDebugRegister, guard(function()
    add(string.format('selectable tick %d %s ret %X', hoiTick(), parties(ECX), readInteger(ESP) - b))
    if hoiCw4Ret == nil then
      local ret = readInteger(ESP)
      hoiCw4Ret = ret
      debug_setBreakpoint(ret, 1, bptExecute, bpmDebugRegister, guard(function()
        add(string.format('  selectable answered %d', EAX & 0xFF))
        debug_removeBreakpoint(ret)
        hoiCw4Ret = nil
      end))
    end
  end))
  debug_setBreakpoint(APPLY, 1, bptExecute, bpmDebugRegister, guard(function()
    add(string.format('apply tick %d %s ret %X', hoiTick(), parties(ECX), readInteger(ESP) - b))
  end))
  debug_setBreakpoint(ACCEPTANCE, 1, bptExecute, bpmDebugRegister, guard(function()
    add(string.format('acceptance tick %d %s ret %X', hoiTick(), parties(ECX), readInteger(ESP) - b))
  end))
  return 'armed'
end

function hoiCw4Stop()
  debug_removeBreakpoint(SELECTABLE); debug_removeBreakpoint(APPLY); debug_removeBreakpoint(ACCEPTANCE)
  if hoiCw4Ret then debug_removeBreakpoint(hoiCw4Ret); hoiCw4Ret = nil end
  return 'stopped'
end

function hoiCw4Dump()
  return 'ERR ' .. table.concat(hoiCw4Errs, '\n') .. '\nLINES\n' .. table.concat(hoiCw4Lines, '\n')
end
