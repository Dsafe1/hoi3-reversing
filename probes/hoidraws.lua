-- The original's draws, recorded for a replay: every draw a country's AI makes, with the country it was made for.
-- dofile() after hoi.lua (and hoiseries.lua). hoiDraws(folder) arms four hardware breakpoints - all of them - and one software one:
--
--   the hour's pass (PASS)   a line `H <tick>`, and both generators dumped as the pass begins: gen_<tick>.txt (the
--                            game's, as hoiDumpGenerator writes it) and ai_<tick>.txt (CGameState +0x124, the AI's
--                            MT19937: its index, then its 624 words); and hoiRun's stop, which this replaces
--   ProcessAI's entry        `E <esp> <tag>`: one country's whole AI pass begins on the thread whose stack this is
--   the AI generator's draw  `A <esp> <index> <caller rva> =<value>`: MT19937Next on the AI's state, the index it drew
--                            at and the value it returns; `... trade <tag> =<value>` for the hourly trading's two
--                            draws (CCountry::RunHourlyAITrade), with the country
--   Lua's math.random        `R <esp> <rand>`: the value MSVCR80's rand gave lua5.1.dll's math_random
--   the inline draw          `A <esp> <index> 496FBC =<value>`: the one draw on the AI's generator not made through
--                            MT19937Next, CEU3AI_RankInvasionAreas' staging step (0x496F5A-0x496FBA) - a software
--                            breakpoint (int3), the four hardware ones being taken; a scan of .text for the generator's
--                            index (+0xAE4) finds no other reader but its constructor and loader
--
-- A draw belongs to the country of the latest `E` of this hour whose esp is above it and within a stack's reach;
-- one with none - the hourly trade, run inside the pass - belongs to nobody. Every rva is valid only for this build.
--
-- With hoiDrawsGameCallers set before hoiDraws, the hour's pass is a software breakpoint instead and the debug register
-- it frees watches the game's generator's index (g_random_index, 0x1311940) for writes, which every one of its draws makes
-- (19 functions draw inline): a line `D <rva after the store> <caller rva>` each - the caller [ESP+8] where the store is
-- MT19937Next's (0x6A2BE2), Random (0x6A2F80) tail-jumping into it - and `B <tick> <province>` as each battle's hour begins
-- (CCombat::Tick, 0x16EBE0, int3), and `F ...` for each land unit's shots in an hour (CLandCombatant::FireUnit, int3,
-- below). The playback's reader passes over all three. **ProcessAI must stay on a debug register**: on an int3, which is
-- lifted while each hit is handled, passes entered together on the worker threads went unlogged and their draws were filed
-- under the pass before - Germany's `destiny` decision draw among them, in two recordings of 2026-11-16 made so. The
-- software breakpoints here are on what the main thread alone runs: the hour's pass, CCombat::Tick, FireUnit.
local b = hoiB
local PASS = b + 0x282630
local PROCESS_AI = b + 0x4894E0
-- MT19937Next's last store, `mov [edi+0x9C0], edx`: the value it returns in EAX, the state in EDI, the new index in EDX.
-- Its entry would give only the index, and the AI's generator is drawn on unlocked from several threads at once - two
-- that enter at one index can come out with different values (seen: Japan's, the Soviet Union's and France's trading,
-- all at 263 at 01:00 on 17 July 1941).
local MT_STORE = b + 0x6A2BDC
-- The staging step's inline copy of the draw, just after its last tempering step: the value in EAX, the state in EDI.
local STAGING = b + 0x496FBC
local LUA_RAND = getAddress('lua5.1.dll') + 0x198B2
local GAME_INDEX = b + 0x1311940
local COMBAT_TICK = b + 0x16EBE0
local FIRE_SHOTS = b + 0x16AF96
-- Just after the naval patrol's centre is drawn (CAIUnit_ManageNavalUnits, `call rand` at 0x4D33E6 into the C runtime's
-- rand at 0x797F3F, the one caller of it in the AI's code): the value in EAX, the list's size in ESI.
local PATROL_RAND = b + 0x4D33EB

local function tagOf(id)
  local arr = readInteger(readInteger(b + 0x16855A4) + 0x16C)
  local c = arr and readInteger(arr + id * 4)
  return (c and c ~= 0) and readString(c + 0x1E4, 3) or '?'
end

local function dumpAi(path)
  local gen = hoiState() + 0x124
  local f = io.open(path, 'w')
  f:write(string.format('%d\n', readInteger(gen + 0x9C0)))
  local words = readBytes(gen, 624 * 4, true)
  for i = 0, 623 do
    local v = words[i * 4 + 1] | (words[i * 4 + 2] << 8) | (words[i * 4 + 3] << 16) | (words[i * 4 + 4] << 24)
    f:write(string.format('%08X\n', v))
  end
  f:close()
end

function hoiDraws(folder)
  hdFolder = folder
  hdOut = io.open(folder .. '/draws.txt', 'a')
  hdCount = 0
  hoiRunArmed = true -- hoiClearStop removes the hour's breakpoint, which is this one
  -- With hoiDrawsGameCallers the hour's pass, which only the main thread runs, is the software breakpoint: an int3 is lifted
  -- while each hit is handled, so one on ProcessAI, which the worker threads enter together, lets passes through unlogged.
  -- With both modes the game generator's watch takes the fourth debug register and the patrol's draw is an int3: whole for
  -- the passes the main thread runs (Germany, Britain, the Soviet Union, the United States), possibly short a draw for a
  -- country whose pass enters on a worker thread while another's is being logged.
  local patrolMode = (hoiDrawsGameCallers and hoiDrawsPatrol) and bpmInt3 or bpmDebugRegister
  debug_setBreakpoint(PASS, 1, bptExecute, (hoiDrawsGameCallers or hoiDrawsPatrol) and bpmInt3 or bpmDebugRegister, function()
    pcall(function()
      local tick = hoiTick()
      hdOut:write(string.format('H %d\n', tick))
      hdOut:flush()
      hoiDumpGenerator(string.format('%s/gen_%d.txt', folder, tick))
      dumpAi(string.format('%s/ai_%d.txt', folder, tick))
      if hoiTarget and tick >= hoiTarget and not hoiStopped then
        hoiPause()
        hoiStopped = true
      end
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(PROCESS_AI, 1, bptExecute, bpmDebugRegister, function()
    debug_getContext()
    pcall(function()
      local ai = readInteger(ESP + 4)
      hdOut:write(string.format('E %X %s\n', ESP, tagOf(readInteger(ai + 0x24))))
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(MT_STORE, 1, bptExecute, bpmDebugRegister, function()
    debug_getContext()
    pcall(function()
      local gen = hoiState() + 0x124
      if EDI == gen then
        -- Two pushes in: the caller's return address at [ESP+8]. EAX is the value it returns, EDX the index it stores.
        local caller = readInteger(ESP + 8) - b
        -- The hourly trade draws outside any country's job (CCountry::RunHourlyAITrade, stdcall, run inside the pass):
        -- its country is that function's argument, [EBP+8] in its frame - MT19937Next never touches EBP.
        -- Written as the word `trade` and the tag, so that a reader of the log needs no address of this build.
        local who = ''
        if caller == 0xDC7AE or caller == 0xDC803 then
          local t = readString(readInteger(EBP + 8) + 0x1E4, 3)
          who = ' trade ' .. ((t and t:match('^[A-Z][A-Z0-9][A-Z0-9]$')) and t or '?')
        end
        hdOut:write(string.format('A %X %d %X%s =%d\n', ESP, (EDX + 623) % 624, caller, who, EAX))
        hdCount = hdCount + 1
      end
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(LUA_RAND, 1, bptExecute, bpmDebugRegister, function()
    debug_getContext()
    pcall(function()
      hdOut:write(string.format('R %X %d\n', ESP, EAX))
      hdCount = hdCount + 1
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  debug_setBreakpoint(STAGING, 1, bptExecute, bpmInt3, function()
    debug_getContext()
    pcall(function()
      if EDI == hoiState() + 0x124 then
        hdOut:write(string.format('A %X %d 496FBC =%d\n', ESP, (readInteger(EDI + 0x9C0) + 623) % 624, EAX))
        hdCount = hdCount + 1
      end
    end)
    debug_continueFromBreakpoint(co_run)
    return 1
  end)
  if hoiDrawsPatrol then
    -- `P <esp> <rand> <list size>`: the C runtime rand() each patrol centre was drawn with. It is per thread, and the main
    -- thread's has run since the process began, so a playback cannot make it again (FINDINGS-liveread.md, section 112).
    debug_setBreakpoint(PATROL_RAND, 1, bptExecute, patrolMode, function()
      debug_getContext()
      pcall(function() hdOut:write(string.format('P %X %d %d\n', ESP, EAX, ESI)) end)
      debug_continueFromBreakpoint(co_run)
      return 1
    end)
  end
  if hoiDrawsGameCallers then
    debug_setBreakpoint(GAME_INDEX, 4, bptWrite, bpmDebugRegister, function()
      debug_getContext()
      pcall(function() hdOut:write(string.format('D %X %X\n', EIP - b, (readInteger(ESP + 8) or 0) - b)) end)
      debug_continueFromBreakpoint(co_run)
      return 1
    end)
    debug_setBreakpoint(COMBAT_TICK, 1, bptExecute, bpmInt3, function()
      debug_getContext()
      pcall(function()
        local p = readInteger(ECX + 0x18)
        hdOut:write(string.format('B %d %d\n', hoiTick(), (p and p ~= 0) and readInteger(p + 0xD0) or 0))
      end)
      debug_continueFromBreakpoint(co_run)
      return 1
    end)
    -- Each land unit's shots for the hour, once CLandCombatant::FireUnit has worked them out (0x16AF96, the count in EDI
    -- after the chance at one more): the attacker (ESI), the target it drew ([ESP+8]), the shots, and the attacker's two
    -- attack products (+0xEC, +0xF4). `F <tick> <attacker +0x14> <target +0x14> <shots> <+0xEC> <+0xF4>`.
    debug_setBreakpoint(FIRE_SHOTS, 1, bptExecute, bpmInt3, function()
      debug_getContext()
      pcall(function()
        local t = readInteger(ESP + 8)
        hdOut:write(string.format('F %d %d %d %d %d %d\n', hoiTick(), readInteger(ESI + 0x14) or -1,
          (t and t ~= 0) and readInteger(t + 0x14) or -1, EDI, readInteger(ESI + 0xEC) or -1, readInteger(ESI + 0xF4) or -1))
      end)
      debug_continueFromBreakpoint(co_run)
      return 1
    end)
  end
  return 'armed'
end

-- hoiRun as hoi.lua has it, but leaving the hour's breakpoint to hoiDraws: only the target is set.
function hoiDrawsRun(n)
  hoiTarget = hoiTick() + n
  hoiStopped = false
  hoiUnpause()
  return hoiTarget
end

function hoiDrawsStop()
  for _, a in ipairs({ PASS, PROCESS_AI, MT_STORE, LUA_RAND, STAGING, GAME_INDEX, COMBAT_TICK, FIRE_SHOTS, PATROL_RAND }) do pcall(debug_removeBreakpoint, a) end
  hoiRunArmed = false
  pcall(function() hdOut:close() end)
  return 'stopped'
end
