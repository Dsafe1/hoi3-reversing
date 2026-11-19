-- hoinavybase.lua, after probes/hoi.lua: who gives the fleet of `base = 9867` (French Somaliland, no naval base under
-- BlackICE) the base the save has. CNavy::LoadKey (rva 0x1CF6A0; `this` the CPersistent subobject, CNavy + 8; [esp+4] the
-- parse context, its token text at +0x22C; [esp+8] the token) catches the object as its base key is read; a write
-- breakpoint on its +0x98 then logs each writer's address, the value written and the return addresses on the stack.
local b = hoiB
local LOADKEY = b + 0x1CF6A0
local DAY = b + 0x282C20

local function log(s) hoiNbFile:write(s .. '\n'); hoiNbFile:flush() end

local function baseProvince(base)
  if not base or base == 0 then return 0 end
  local provinces = readInteger(hoiState() + 0xB8C)
  for _, id in ipairs({ 485, 9867, 9889 }) do
    local p = readInteger(provinces + id * 4)
    if p and p + 0x54 == base then return id end
  end
  return -1
end

local function stack(n)
  local out = {}
  for i = 0, n - 1 do
    local v = readInteger(ESP + i * 4)
    if v and v >= b + 0x1000 and v < b + 0x1000000 then out[#out + 1] = string.format('%X', v - b) end
  end
  return table.concat(out, ' ')
end

function hoiNbArm(path)
  hoiNbFile = io.open(path, 'w')
  hoiNbFleet = nil
  debug_setBreakpoint(LOADKEY, 1, bptExecute, bpmDebugRegister, function()
    pcall(function()
      if hoiNbFleet == nil and readInteger(ESP + 8) == 0x509 then
        local text = readString(readInteger(ESP + 4) + 0x22C, 8)
        if text and text:sub(1, 4) == '9867' then
          hoiNbFleet = ECX - 8
          log(string.format('loadkey base %s fleet %X base now %X', text, hoiNbFleet, readInteger(hoiNbFleet + 0x98) or -1))
          debug_setBreakpoint(hoiNbFleet + 0x98, 4, bptWrite, bpmDebugRegister, function()
            pcall(function()
              local v = readInteger(hoiNbFleet + 0x98)
              log(string.format('write at rva %X value %X province %d tick %d stack %s', EIP - b, v or -1, baseProvince(v),
                hoiTick(), stack(48)))
            end)
            debug_continueFromBreakpoint(co_run)
            return 1
          end)
        end
      end
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(DAY, 1, bptExecute, bpmDebugRegister, function()
    pcall(function()
      if hoiNbFleet then
        local v = readInteger(hoiNbFleet + 0x98)
        log(string.format('day head tick %d base %X province %d', hoiTick(), v or -1, baseProvince(v)))
      end
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  return 'armed'
end

function hoiNbStop()
  debug_removeBreakpoint(LOADKEY); debug_removeBreakpoint(DAY)
  if hoiNbFleet then debug_removeBreakpoint(hoiNbFleet + 0x98) end
  if hoiNbFile then hoiNbFile:close(); hoiNbFile = nil end
  return 'stopped'
end
