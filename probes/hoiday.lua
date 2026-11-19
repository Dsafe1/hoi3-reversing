-- hoiday.lua, loaded after the fact base's probes/hoi.lua: at the start of each country's daily pass (RunCountryDailyPass,
-- rva 0xDA530, the country at [esp+4]) and at its last block (rva 0xDBEA8, the country in ebx), one line for each country
-- of hoiDayTags: its stockpile's supplies and fuel and four of its day's pools.
local b = hoiB
local ENTRY = b + 0xDA530
local LAST = b + 0xDBEA8
hoiDayTags = hoiDayTags or { ENG = true, SOV = true, USA = true, CSX = true, HOL = true }
hoiDaySeq = 0

local function line(kind, c)
  local tag = readString(c + 0xCA4, 3)
  if not hoiDayTags[tag] then return end
  hoiDaySeq = hoiDaySeq + 1
  local st = hoiState()
  local cap = readInteger(c + 0xE24)
  local prov = readInteger(readInteger(st + 0xB8C) + cap * 4)
  local function pool(o) return readInteger(c + o + 8), readInteger(c + o + 0xC) end
  local us, uf = pool(0x98C)     -- usage
  local hs, hf = pool(0x770)     -- home_produced
  local ts, tf = pool(0x7DC)     -- traded_away
  local ds, df = pool(0xA40)     -- unit_demand
  hoiDayFile:write(string.format('%d %s %s tick=%d cap=%d sup=%d fuel=%d usage=%d/%d home=%d/%d away=%d/%d demand=%d/%d\n',
    hoiDaySeq, kind, tag, readInteger(st + 0xBDC), cap, readInteger(prov + 0x164), readInteger(prov + 0x168),
    us, uf, hs, hf, ts, tf, ds, df))
  hoiDayFile:flush()
end

function hoiDayArm(path)
  hoiDayFile = io.open(path, 'w')
  debug_setBreakpoint(ENTRY, 1, bptExecute, bpmDebugRegister, function()
    pcall(function() line('S', readInteger(ESP + 4)) end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(LAST, 1, bptExecute, bpmDebugRegister, function()
    pcall(function() line('E', EBX) end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

-- The head of the whole day (RunDailyPass, rva 0x282C20): every listed country as it stands before anything of the day.
local DAY = b + 0x282C20
function hoiDayArmHead()
  debug_setBreakpoint(DAY, 1, bptExecute, bpmDebugRegister, function()
    pcall(function()
      local db = readInteger(b + 0x16855A4)
      local first = readInteger(db + 0x16C)
      local last = readInteger(db + 0x170)
      local n = 0
      for p = first, last - 4, 4 do
        n = n + 1
        if n > 400 then break end
        local c = readInteger(p)
        if c and c ~= 0 then line('D', c) end
      end
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'head armed'
end

function hoiDayStop()
  debug_removeBreakpoint(DAY)
  debug_removeBreakpoint(ENTRY)
  debug_removeBreakpoint(LAST)
  if hoiDayFile then hoiDayFile:flush(); hoiDayFile:close(); hoiDayFile = nil end
  return 'stopped'
end

-- The filling's start (RunSupplyAndConvoyIterations, rva 0x278AB0), and an arming of the last block alone.
local FILL = b + 0x278AB0
function hoiDayArmFill()
  debug_setBreakpoint(FILL, 1, bptExecute, bpmDebugRegister, function()
    pcall(function()
      local db = readInteger(b + 0x16855A4)
      line('F', readInteger(readInteger(db + 0x16C) + 4 * 4))
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'fill armed'
end
function hoiDayArmLast(path)
  hoiDayFile = io.open(path, 'w')
  debug_setBreakpoint(LAST, 1, bptExecute, bpmDebugRegister, function()
    pcall(function() line('E', EBX) end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'last armed'
end
function hoiDayStop2()
  debug_removeBreakpoint(DAY); debug_removeBreakpoint(LAST); debug_removeBreakpoint(FILL)
  if hoiDayFile then hoiDayFile:flush(); hoiDayFile:close(); hoiDayFile = nil end
  return 'stopped'
end
