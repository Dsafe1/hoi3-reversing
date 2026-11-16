-- Who draws on the game's generator, every draw, inlined ones included: dofile() after hoi.lua. hoiGenCallers(path) sets a
-- write watchpoint on g_random_index (0x1311940, the MT19937's index, which every draw stores - the record has 19 functions
-- drawing inline rather than through Random at 0x6A2F80), a breakpoint at the hour's pass (0x282630) and a software one
-- (int3) at CCombat::Tick (0x16EBE0), and writes
--   `H <tick>`                      as the hour's pass begins
--   `D <rva of the instruction after the store> <the caller's return address as an rva>`   for each draw
--   `B <tick> <province>`            as a battle's hour begins
-- From the watchpoint EIP is the instruction after the store. Where that is MT19937Next's (0x6A2BE2), two registers are
-- pushed and the caller's return address is [ESP+8] - Random (0x6A2F80) tail-jumps into it, so that is Random's caller;
-- an inlined draw's own EIP names its function. The rvas are this build's.
local b = hoiB
local INDEX = b + 0x1311940
local PASS = b + 0x282630
local TICK = b + 0x16EBE0

function hoiGenCallers(path)
  hgcOut = io.open(path, 'w')
  debug_setBreakpoint(INDEX, 4, bptWrite, bpmDebugRegister, function()
    debug_getContext()
    pcall(function() hgcOut:write(string.format('D %X %X\n', EIP - b, (readInteger(ESP + 8) or 0) - b)) end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(PASS, 1, bptExecute, bpmDebugRegister, function()
    pcall(function() hgcOut:write(string.format('H %d\n', hoiTick())); hgcOut:flush() end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(TICK, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      local p = readInteger(ECX + 0x18)
      hgcOut:write(string.format('B %d %d\n', hoiTick(), (p and p ~= 0) and readInteger(p + 0xD0) or 0))
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'watching'
end

function hoiGenCallersStop()
  for _, a in ipairs({ INDEX, PASS, TICK }) do pcall(debug_removeBreakpoint, a) end
  pcall(function() hgcOut:close() end)
  return 'stopped'
end
