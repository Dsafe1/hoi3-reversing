-- Which instructions read a defines.lua field while the game runs.
--
-- Queued 2026-11-18 (CANDIDATES.md, *Live probes queued*): twenty defines the static scans found no reader
-- for, `SURPRISE_BONUS` first. A static zero is weak for defines - the weather block is copied into globals
-- at set-up (FINDINGS-weather.md, section 5) and `GetDefines` is inlined as a test and a branch - so the
-- running game settles it. CDefines::Load is the only writer of these fields, so any access after it is a read.
--
-- dofile this in Cheat Engine attached to hoi3_tfh.exe, then:
--   defWatch(defGroups[1])   -- at most four fields: the debug registers
--   ... set it at the main menu, before a save is loaded, so a copy taken at game set-up is caught too;
--       then play with battles running and days passing ...
--   defReport()              -- writes defOut and returns the hits, by rva
--   defStop()                -- removes the breakpoints
--
-- Offsets are the record's: the block pointer at CDefines + blk (0x9C economy, 0xAC military, 0xBC diplomacy,
-- 0xCC country, 0xDC alignment), then the field, as `python scripts/definesMap.py --block <name>` prints them.

defOut = defOut or [[C:\Users\David\Documents\hoidefwatch_hits.txt]]
defHits = defHits or {}
defBps = defBps or {}

defGroups = {
  -- BASE_NIGHT_PENALTY is the control: six readers in the land, naval and air modifier code.
  { {"BASE_NIGHT_PENALTY", 0xAC, 0x120}, {"SURPRISE_BONUS", 0xAC, 0x228},
    {"COMBAT_EVENT_DURATION", 0xAC, 0x130}, {"MINIMUM_STRENGTH", 0xAC, 0x7C} },
  { {"NAVAL_STACKING_PENALTY", 0xAC, 0x1D4}, {"UNDERGROUND_PARTISAN_STRENGTH", 0xAC, 0x260},
    {"IC_TO_CONSUMER_GOODS", 0x9C, 0xC}, {"MAX_PROVINCE_SELL_PRICE", 0x9C, 0x0} },
  { {"CORE_LOSE", 0xCC, 0x0}, {"CORE_GAIN", 0xCC, 0x4},
    {"REBEL_ACCEPTANCE_MONTHS", 0xCC, 0x10}, {"ROUGH_COUNTRY_RUIN_EST_MODIFIER", 0xCC, 0x8C} },
  { {"SPY_MISSION_CHANGE_DAYS", 0xCC, 0x24}, {"SPY_CONNECTION_DETECTION_CHANCE", 0xCC, 0x28},
    {"SPY_BASE_CONNECTION_DETECTION_CHANCE", 0xCC, 0x2C}, {"WAR_THREAT", 0xDC, 0x28} },
  { {"NAP_INFLUENCE_COST", 0xBC, 0x20}, {"PURCHASE_INFLUENCE_COST", 0xBC, 0x24},
    {"RELATION_INFLUENCE_COST", 0xBC, 0x34}, {"JOINBLOCK_INFLUENCE_COST", 0xBC, 0x38} },
  { {"MILACC_CANCEL_RELATION_CHANGE", 0xBC, 0x6C} },
}

local function base() return getAddress("hoi3_tfh.exe") end

function defWatch(list)
  defStop()
  local defs = readInteger(base() + 0x1686040)       -- g_CDefines
  if defs == nil or defs == 0 then return "no CDefines yet" end
  local made = {}
  for i, e in ipairs(list) do
    if i > 4 then break end
    local name, blk, off = e[1], e[2], e[3]
    local block = blk == 0 and defs or readInteger(defs + blk)
    local addr = block + off
    defHits[name] = defHits[name] or {}
    local hits = defHits[name]
    debug_setBreakpoint(addr, 4, bptAccess, bpmDebugRegister, function()
      pcall(function()
        -- a data breakpoint stops after the access: the reader is the instruction before EIP
        local prev = getPreviousOpcode(EIP)
        local rva = (prev or EIP) - base()
        hits[rva] = (hits[rva] or 0) + 1
      end)
      debug_continueFromBreakpoint(co_run)
      return 1
    end)
    defBps[#defBps + 1] = addr
    made[#made + 1] = string.format("%s @%08X = %d", name, addr, readInteger(addr) or -1)
  end
  return table.concat(made, "\n")
end

function defStop()
  for _, a in ipairs(defBps) do pcall(debug_removeBreakpoint, a) end
  defBps = {}
  return "stopped"
end

function defReport()
  local lines = {}
  for name, hits in pairs(defHits) do
    local n = 0
    for rva, c in pairs(hits) do
      lines[#lines + 1] = string.format("%s rva %X x%d", name, rva, c)
      n = n + 1
    end
    if n == 0 then lines[#lines + 1] = name .. " no access" end
  end
  table.sort(lines)
  local f = io.open(defOut, "w")
  if f then f:write(table.concat(lines, "\n") .. "\n"); f:close() end
  return table.concat(lines, "\n")
end
