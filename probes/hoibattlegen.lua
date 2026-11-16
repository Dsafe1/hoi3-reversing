-- Where the game's generator stands as each battle's hour begins: dofile() after hoi.lua; hoiBattleGen(folder) sets a
-- software breakpoint (int3 - hoidraws.lua holds all four debug registers) at CCombat::Tick (0x16EBE0, the battle in ECX)
-- and for each battle each hour writes
--   battles.txt   `B <tick> <province> <L|A|N|B> draws <g_random_draws> index <the MT19937's index>`
--   mt_<tick>_<province>_<kind>.txt   the whole generator, as hoiDumpGenerator writes it, which OpenHOI3's savegame tool
--                                     puts back before that battle with generator=FOLDER
-- The draw count runs on from the hour's dump (gen_<tick>.txt of hoidraws.lua), so the draws made in the hour before each
-- battle are the difference. The province is the battle's CMapProvince (+0x18) and its id (+0xD0), as the kit's
-- battleseries.lua read them.
local b = hoiB
local TICK = b + 0x16EBE0

local function kind(c)
  local name = getRTTIClassName(c) or '?'
  if name == 'CLandCombat' then return 'L' end
  if name == 'CAirCombat' then return 'A' end
  if name == 'CNavalCombat' then return 'N' end
  return 'B'
end

function hoiBattleGen(folder)
  hbgFolder = folder
  hbgOut = io.open(folder .. '/battles.txt', 'a')
  debug_setBreakpoint(TICK, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      local c = ECX
      local tick = hoiTick()
      local p = readInteger(c + 0x18)
      local prov = (p and p ~= 0) and readInteger(p + 0xD0) or 0
      local k = kind(c)
      hbgOut:write(string.format('B %d %d %s draws %d index %d\n', tick, prov, k, readInteger(b + 0x134DA8C), readInteger(b + 0x1311940)))
      hbgOut:flush()
      hoiDumpGenerator(string.format('%s/mt_%d_%d_%s.txt', folder, tick, prov, k))
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'battles logged'
end

function hoiBattleGenStop()
  pcall(debug_removeBreakpoint, TICK)
  pcall(function() hbgOut:close() end)
  return 'stopped'
end
