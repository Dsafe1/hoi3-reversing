-- Every attack estimate the AI makes, with its answer: dofile() after hoi.lua, then hoiOdds(file). Armed with hoidraws.lua
-- (from hoiBeforePlay, after hoiDraws) it rides along with a recording, so a playback whose attack odds part can be set
-- beside the original's look for look (FINDINGS-liveread.md, section 146).
--
-- Two int3s in CAIUnit::EstimateAttackOdds (0x4D93B0), the four debug registers being hoidraws.lua's:
--   0x4D9DF4  `divsd xmm0, xmm1` - our damage in XMM0 and theirs in XMM1, both doubles; the odds are their quotient
--   0x4D9E0F  the arm their damage at or under nought takes, answering 50 - their damage in XMM1 as a float
-- A line each: `<tick> odds <esp> <target province> <followCombats> <our damage> <their damage>` or
-- `<tick> odds50 <esp> <target province> <followCombats> <their damage>`. The target is the function's third argument
-- ([ebp+0x10], a province whose number is at +0xD0), followCombats its fifth ([ebp+0x18]); <esp> files the look under a
-- country's pass by draws.txt's `E` lines, as a draw is. An int3 is lifted while a hit is handled, so a look made on another
-- thread meanwhile can go unlogged; entering's first pass runs on the main thread alone. Every rva is valid only for this
-- build.
local b = hoiB
local DIVIDE = b + 0x4D9DF4
local NO_DAMAGE = b + 0x4D9E0F

local function target()
  local p = readInteger(EBP + 0x10)
  return (p and p ~= 0) and (readInteger(p + 0xD0) or -1) or 0
end

function hoiOdds(path)
  hoOut = io.open(path, 'a')
  debug_setBreakpoint(DIVIDE, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      hoOut:write(string.format('%d odds %X %d %d %.9g %.9g\n', hoiTick(), ESP, target(), readInteger(EBP + 0x18) or -1,
        readDoubleLocal(debug_getXMMPointer(0)), readDoubleLocal(debug_getXMMPointer(1))))
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(NO_DAMAGE, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      hoOut:write(string.format('%d odds50 %X %d %d %.9g\n', hoiTick(), ESP, target(), readInteger(EBP + 0x18) or -1,
        readFloatLocal(debug_getXMMPointer(1))))
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

function hoiOddsStop()
  for _, at in ipairs({DIVIDE, NO_DAMAGE}) do pcall(debug_removeBreakpoint, at) end
  pcall(function() hoOut:close() end)
  return 'stopped'
end
