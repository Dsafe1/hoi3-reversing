-- hoibuildingwatch.lua, after probes/hoi.lua: every write to province 9867's naval base level_max (its building object, the
-- province's +0x300, +0x20), with the writer's rva, the value and the return addresses on the stack.
local b = hoiB
function hoiNwArm(path, id)
  hoiNwFile = io.open(path, 'w')
  local p = readInteger(readInteger(hoiState() + 0xB8C) + id * 4)
  local pb = p and readInteger(p + 0x300)
  if not pb or pb == 0 then hoiNwFile:write('no building object yet\n'); hoiNwFile:flush(); return 'none' end
  hoiNwAddr = pb + 0x20
  hoiNwFile:write(string.format('watching %X (province %X)\n', hoiNwAddr, p)); hoiNwFile:flush()
  debug_setBreakpoint(hoiNwAddr, 4, bptWrite, bpmDebugRegister, function()
    pcall(function()
      local out = {}
      for i = 0, 63 do
        local v = readInteger(ESP + i * 4)
        if v and v >= b + 0x1000 and v < b + 0x1000000 then out[#out + 1] = string.format('%X', v - b) end
      end
      hoiNwFile:write(string.format('write at rva %X value %d stack %s\n', EIP - b, readInteger(hoiNwAddr) or -1,
        table.concat(out, ' ')))
      hoiNwFile:flush()
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'watching'
end
function hoiNwStop()
  if hoiNwAddr then debug_removeBreakpoint(hoiNwAddr) end
  if hoiNwFile then hoiNwFile:close(); hoiNwFile = nil end
  return 'stopped'
end
