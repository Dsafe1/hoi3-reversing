-- hoix87.lua, after probes/hoi.lua (FINDINGS-liveread.md, section 152): every thread's x87 control word, read through
-- Wow64GetThreadContext called inside Cheat Engine's own process (64-bit) on a handle to each of the game's threads -
-- nothing is run in the game. hoiX87() answers a count by control word and the first few threads; 0x007F is 24-bit
-- precision (as Direct3D 9 leaves its thread), 0x027F the default 53. hoiX87Esp() gives each thread's ESP as well, to
-- match against the ESP a breakpoint saw (ProcessAI's, for instance). Best read with the game paused.
local function contexts()
  local openThread = getAddress('kernel32.OpenThread', true)
  local getCtx = getAddress('kernel32.Wow64GetThreadContext', true)
  local closeH = getAddress('kernel32.CloseHandle', true)
  local ms = createMemoryStream()
  ms.Size = 1024
  local buf = ms.Memory
  local tl = createStringlist()
  getThreadlist(tl)
  local threads = {}
  for i = 0, tl.Count - 1 do
    local tid = tonumber(tl[i], 16)
    local h = executeCodeLocalEx(openThread, 0x0008 + 0x0040, 0, tid)  -- THREAD_GET_CONTEXT | THREAD_QUERY_INFORMATION
    if h and h ~= 0 then
      for j = 0, 1023, 4 do writeIntegerLocal(buf + j, 0) end
      writeIntegerLocal(buf, 0x10009)  -- WOW64_CONTEXT_i386 | CONTROL | FLOATING_POINT
      executeCodeLocalEx(getCtx, h, buf)
      -- FloatSave begins at +28, its ControlWord first; Esp is at +0xC4.
      threads[#threads + 1] = {tid = tid, cw = readIntegerLocal(buf + 28) & 0xFFFF, esp = readIntegerLocal(buf + 0xC4)}
      executeCodeLocalEx(closeH, h)
    end
  end
  tl.destroy(); ms.destroy()
  return threads
end

function hoiX87Esp() return contexts() end

function hoiX87()
  local counts, out = {}, {}
  for i, t in ipairs(contexts()) do
    local key = string.format('%04X', t.cw)
    counts[key] = (counts[key] or 0) + 1
    if i <= 10 then out[#out + 1] = string.format('tid %X cw %04X esp %X', t.tid, t.cw, t.esp) end
  end
  local s = {}
  for k, v in pairs(counts) do s[#s + 1] = k .. ' x' .. v end
  return 'control words: ' .. table.concat(s, ', ') .. '\n' .. table.concat(out, '\n')
end
