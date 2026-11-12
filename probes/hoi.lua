-- Hands-off control of hoi3_tfh.exe from Cheat Engine. dofile() this after attaching.
-- Every rva is valid only for this build. A breakpoint callback that returns 1 must
-- continue the thread itself, or the game stays frozen at the breakpoint.
hoiB = getAddress('hoi3_tfh.exe')
local b = hoiB
local PASS = b + 0x282630
local FRONT_UPDATE = b + 0x2EDD60

function hoiState() return readInteger(b + 0x1689790) end
function hoiIdler() return readInteger(hoiState() + 0xBE8) end
function hoiTick() return readInteger(hoiState() + 0xBDC) end
function hoiInGame() return readBytes(hoiState() + 0xDA4, 1) end
function hoiPaused() return readBytes(hoiIdler() + 0x12D8, 1) end
function hoiPause() writeBytes(hoiIdler() + 0x12D8, 1); return hoiPaused() end
function hoiUnpause() local i = hoiIdler(); writeBytes(i + 0x12D9, 1); writeBytes(i + 0x12D8, 0); return hoiPaused() end
function hoiSave() writeBytes(hoiIdler() + 0xAB0, 1); return readBytes(hoiIdler() + 0xAB0, 1) end
function hoiSpeed(n) if n then writeInteger(hoiState() + 0xBEC, n) end return readInteger(hoiState() + 0xBEC) end

local function pump(ms)
  local t = getTickCount()
  while getTickCount() - t < ms do checkSynchronize(); sleep(20) end
end
hoiPump = pump

-- The generator, as the C# loader's generator= reads it: "<draws> <index>", then 624 words.
function hoiDumpGenerator(path)
  local f = io.open(path, 'w')
  f:write(string.format('%d %d\n', readInteger(b + 0x134DA8C), readInteger(b + 0x1311940)))
  for i = 0, 623 do f:write(string.format('%08X\n', readInteger(b + 0x1310F80 + i * 4) & 0xFFFFFFFF)) end
  f:close()
end

-- hoiRun(n): run n hours and pause as the pass of the last one begins, so that pass still runs.
-- hoiRunDump: a folder to write the generator into as that pass begins.
function hoiRun(n)
  hoiTarget = hoiTick() + n
  hoiStopped = false
  if not hoiRunArmed then
    hoiRunArmed = true
    debug_setBreakpoint(PASS, 1, bptExecute, bpmDebugRegister, function()
      if hoiTick() >= hoiTarget and not hoiStopped then
        if hoiRunDump then hoiDumpGenerator(hoiRunDump .. '/gen_' .. hoiTick() .. '.txt') end
        hoiPause()
        hoiStopped = true
      end
      debug_continueFromBreakpoint(co_run)
      return 1
    end)
  end
  hoiUnpause()
  return hoiTarget
end
function hoiClearStop() if hoiRunArmed then debug_removeBreakpoint(PASS); hoiRunArmed = false end end

-- A call on the game's main thread, at the top of the front end's frame.
-- Always a new block and clean flags: Cheat Engine's Lua state outlives the game process.
hoiStub = allocateMemory(4096)
hoiFrames = 0
hoiArmed = false
hoiRunArmed = false
hoiPending = nil
local function arm()
  if hoiArmed then return end
  hoiArmed = true
  debug_setBreakpoint(FRONT_UPDATE, 1, bptExecute, bpmDebugRegister, function()
    hoiFrames = hoiFrames + 1
    debug_getContext()
    hoiFE = ECX
    if hoiPending then
      EIP = hoiPending
      hoiPending = nil
      debug_setContext()
      hoiCallDone = true
    end
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
end
local function disarm() if hoiArmed then debug_removeBreakpoint(FRONT_UPDATE); hoiArmed = false end end

function hoiCall(fn, this, args)
  local p = hoiStub
  local bytes = { 0x60, 0x9C }
  args = args or {}
  local function imm(v) for i = 0, 3 do bytes[#bytes + 1] = (v >> (8 * i)) & 0xFF end end
  for i = #args, 1, -1 do bytes[#bytes + 1] = 0x68; imm(args[i]) end
  bytes[#bytes + 1] = 0xB9; imm(this)
  bytes[#bytes + 1] = 0xE8; imm((fn - (p + #bytes + 4)) & 0xFFFFFFFF)
  bytes[#bytes + 1] = 0x9D; bytes[#bytes + 1] = 0x61
  bytes[#bytes + 1] = 0xE9; imm((FRONT_UPDATE - (p + #bytes + 4)) & 0xFFFFFFFF)
  writeBytes(p, bytes)
  hoiCallDone = false
  arm()
  hoiPending = p
  local t = getTickCount()
  while not hoiCallDone and getTickCount() - t < 3000 do checkSynchronize(); sleep(20) end
  local f = hoiFrames
  t = getTickCount()
  while hoiFrames < f + 2 and getTickCount() - t < 3000 do checkSynchronize(); sleep(20) end
  disarm()
  return hoiCallDone
end

function hoiFindFrontEnd()
  hoiFE = nil
  arm()
  local t = getTickCount()
  while hoiFE == nil and getTickCount() - t < 3000 do checkSynchronize(); sleep(20) end
  disarm()
  return hoiFE
end
function hoiView(i) return readInteger(readInteger(hoiFE + 0x750) + i * 4) end
function hoiCurrentView() return readInteger(hoiFE + 0x760) end

local function scanBytes(s)
  local ms = createMemScan()
  ms.firstScan(soExactValue, vtByteArray, nil, s, nil, '0', '7FFFFFFF', '', fsmNotAligned, '1', true, false, false, false)
  ms.waitTillDone()
  local fl = createFoundList(ms); fl.initialize()
  local out = {}
  for i = 0, fl.Count - 1 do out[#out + 1] = tonumber(fl.Address[i], 16) end
  fl.destroy(); ms.destroy()
  return out
end

local function cstring(a)
  local cap, len = readInteger(a + 0x14), readInteger(a + 0x10)
  if not len or len <= 0 or len > 260 then return '?' end
  if cap and cap >= 16 then return readString(readInteger(a), len) end
  return readString(a, len)
end

-- The lobby's rows, by file name. Rows are found by the table their OnClicked sits in.
function hoiListSaves()
  local onClicked = b + 0x304560
  local pat = function(v) return string.format('%02X %02X %02X %02X', v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255) end
  local table_
  for _, a in ipairs(scanBytes(pat(onClicked))) do if a < 0x2000000 then table_ = a - 0x10 end end
  hoiRows = {}
  for _, r in ipairs(scanBytes(pat(table_))) do
    if r > 0x2000000 and getRTTIClassName(r) == 'CSavegameItem' then hoiRows[cstring(r + 0x28)] = r end
  end
  return hoiRows
end

-- From the main menu to a new game of the lobby's default bookmark (The Road to War, 1 January 1936), played as the owner of
-- the province given (1861, Berlin, for Germany): Single Player, CGameSetup::OnProvinceClicked with the province, Play.
-- Returns when Play has been pressed; the game loads paused at the bookmark's hour, its two days run.
function hoiNewGame(provinceId)
  hoiFindFrontEnd()
  if hoiCurrentView() ~= 3 then hoiCall(b + 0x2FCA40, hoiView(0)); pump(1500) end
  local prov = readInteger(readInteger(hoiState() + 0xB8C) + provinceId * 4)
  hoiCall(b + 0x30C0B0, hoiView(3), { prov }); pump(1000)
  local player = readInteger(hoiState() + 0xC34)
  hoiCall(b + 0x30E5B0, hoiView(3))
  return 'play pressed, player id ' .. player
end

-- From the main menu to a game of the named save. Returns when Play has been pressed.
function hoiLoadSave(name)
  hoiFindFrontEnd()
  if hoiCurrentView() ~= 3 then hoiCall(b + 0x2FCA40, hoiView(0)); pump(600) end
  hoiCall(b + 0x3154B0, hoiView(3)); pump(600)
  hoiListSaves()
  local row = hoiRows[name]
  if not row then return 'no row ' .. name end
  hoiCall(b + 0x304560, row)
  local v = hoiView(3)
  local t = getTickCount()
  -- a load pending at +0x6C4; +0x6C7 once a save is loaded
  repeat pump(200) until (readBytes(v + 0x6C4, 1) == 0 and readBytes(v + 0x6C7, 1) == 1) or getTickCount() - t > 60000
  if readBytes(v + 0x6C7, 1) ~= 1 then return 'not loaded' end
  pump(500)
  hoiCall(b + 0x30E5B0, v)
  return 'play pressed'
end
