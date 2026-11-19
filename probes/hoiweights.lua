-- Every land attack target the AI weighs, with its weight: dofile() after hoi.lua, then hoiWeights(file). Armed with
-- hoidraws.lua (from hoiBeforePlay, after hoiDraws) it rides along with a recording (FINDINGS-liveread.md, section 147).
--
-- An int3 in CAIUnit_ManageLandUnits' phase 1 (0x4D57F0), the four debug registers being hoidraws.lua's: at 0x4D6712, just
-- after the target's CProvinceFloat is filled (its province's number at +8, its weight at +0xC, the record in EAX), before
-- it is inserted score-descending. A line each:
--   <tick> weight <esp> <province> <weight> depot <[ebp-0x38]> far <[ebp-0x3C]> spread <[ebp-0x68]>
-- the last three the ramp's inputs: what is handed to the distance function as the depot, the farthest front province's
-- distance and the farthest less the nearest, both floats. A weight of 500 or more is attacked at stance 4. <esp> files the
-- line under a country's pass by draws.txt's `E` lines. An int3 is lifted while a hit is handled, so a target weighed on
-- another thread meanwhile can go unlogged. Every rva is valid only for this build.
local b = hoiB
local FILLED = b + 0x4D6712

function hoiWeights(path)
  hwOut = io.open(path, 'a')
  debug_setBreakpoint(FILLED, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      hwOut:write(string.format('%d weight %X %d %.6g depot %X far %.6g spread %.6g\n', hoiTick(), ESP,
        readInteger(EAX + 8) or -1, readFloat(EAX + 0xC) or -1, readInteger(EBP - 0x38) or 0,
        readFloat(EBP - 0x3C) or -1, readFloat(EBP - 0x68) or -1))
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

function hoiWeightsStop()
  pcall(debug_removeBreakpoint, FILLED)
  pcall(function() hwOut:close() end)
  return 'stopped'
end
