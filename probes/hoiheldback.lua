-- The commitment's reserve, division by division: dofile() after hoi.lua, then hoiHeldBack(file, agentName). Armed with
-- hoidraws.lua (from hoiBeforePlay, after hoiDraws) it rides along with a recording, so a playback whose reserve parts can be
-- read from the original's side (FINDINGS-liveread.md, section 117).
--
-- Three int3s in CAIUnit::ManageSubordinates (0x4B1D10), the four debug registers being hoidraws.lua's:
--   0x4B298B  `hold` - a division held back by the test (unit in EBX)
--   0x4B2CAC  `recall` - a held-back division recalled to the line (unit in EAX, the agent in EDI)
--   0x4B3243  `detach` - a committed division taken into the reserve (unit in EAX)
-- A line each: `<tick> <kind> <agent's unit> | <division> at <province>`. With agentName given, the first detach of each pass of
-- that agent also writes `<tick> list <agent> n <count>` and then every division of the committed vector (+0x12C..+0x130) in
-- order, `  <index> <division> at <province> delay <attack delay> 2C8=<held-back byte>`, which is the order a tie is settled in.
-- The agent is the function's `this`, kept at [esp+0x14] after its prologue. Every rva is valid only for this build.
local HOLD, RECALL, DETACH = hoiB + 0x4B298B, hoiB + 0x4B2CAC, hoiB + 0x4B3243

local function cstr(a)
  local cap, len = readInteger(a + 0x14), readInteger(a + 0x10)
  if not len or len <= 0 or len > 200 then return '?' end
  local s = (cap and cap >= 16) and readString(readInteger(a), len) or readString(a, len)
  return (s or '?'):gsub('[\128-\255]', '?')
end

local function unitName(u) return cstr(u + 0x16C) end
local function where(u) return readInteger(readInteger(u + 0x130) + 0xD0) or -1 end
local function agentName(a)
  local u = a and readInteger(a + 0x64)
  if not u or u == 0 then return '?' end
  return unitName(u)
end

local listedTick, listedAgent

local function line(kind, unit, agent)
  local tick = hoiTick()
  local an = agentName(agent)
  hbOut:write(string.format('%d %s %s | %s at %d\n', tick, kind, an, unitName(unit), where(unit)))
  if kind == 'detach' and hbAgent and an == hbAgent and (listedTick ~= tick or listedAgent ~= agent) then
    listedTick, listedAgent = tick, agent
    local first, last = readInteger(agent + 0x12C), readInteger(agent + 0x130)
    local n = (first and last and last >= first) and (last - first) // 4 or -1
    hbOut:write(string.format('%d list %s n %d\n', tick, an, n))
    if n > 0 and n <= 400 then
      for i = 0, n - 1 do
        local d = readInteger(first + 4 * i)
        if d and d ~= 0 then
          hbOut:write(string.format('  %d %s at %d delay %d 2C8=%d\n', i, unitName(d), where(d),
            readInteger(d + 0xD4) or -1, readBytes(d + 0x2C8, 1) or -1))
        end
      end
    end
  end
  hbOut:flush()
end

local function arm(at, kind, reg)
  debug_setBreakpoint(at, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      local unit = reg == 'ebx' and EBX or EAX
      local agent = kind == 'recall' and EDI or readInteger(ESP + 0x14)
      line(kind, unit, agent)
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
end

function hoiHeldBack(path, agent)
  hbOut = io.open(path, 'a')
  hbAgent = agent
  arm(HOLD, 'hold', 'ebx')
  arm(RECALL, 'recall', 'eax')
  arm(DETACH, 'detach', 'eax')
  return 'armed'
end

function hoiHeldBackStop()
  for _, at in ipairs({HOLD, RECALL, DETACH}) do pcall(debug_removeBreakpoint, at) end
  pcall(function() hbOut:close() end)
  return 'stopped'
end
