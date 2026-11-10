-- A run of saves an hour apart, with no one watching: save, run an hour, save, ...
-- hoiSeries(n, prefix, doneFile): writes <prefix>_<tick>.hoi3 for n+1 hours, then doneFile.
local AUTOSAVE = 'C:/Users/David/Documents/Paradox Interactive/Hearts of Iron III/save games/autosave.hoi3'

local function firstLine()
  local f = io.open(AUTOSAVE, 'rb')
  if not f then return nil, 0 end
  local line = f:read('l')
  local size = f:seek('end')
  f:close()
  return line, size
end

local function copy(to)
  local f = io.open(AUTOSAVE, 'rb')
  local data = f:read('a')
  f:close()
  local g = io.open(to, 'wb')
  g:write(data)
  g:close()
  return #data
end

function hoiSeries(n, prefix, doneFile)
  local k = 0
  local state = 'save'
  local previous, lastSize, stableSince, startedAt
  local log = {}
  hoiSeriesLog = log
  local timer = createTimer(nil, false)
  hoiSeriesTimer = timer
  timer.Interval = 200
  local function finish(text)
    timer.Enabled = false
    hoiClearStop()
    local f = io.open(doneFile, 'w')
    f:write(text .. '\n' .. table.concat(log, '\n') .. '\n')
    f:close()
  end
  timer.OnTimer = function()
    local ok, err = pcall(function()
      if state == 'save' then
        previous = firstLine()
        startedAt = getTickCount()
        lastSize, stableSince = -1, getTickCount()
        hoiSave()
        state = 'waitsave'
      elseif state == 'waitsave' then
        local line, size = firstLine()
        if size ~= lastSize then lastSize = size; stableSince = getTickCount() end
        local expected = hoiTick()
        if line and line ~= previous and size > 1000000 and getTickCount() - stableSince > 2500 then
          local path = prefix .. '_' .. expected .. '.hoi3'
          local bytes = copy(path)
          log[#log + 1] = string.format('%d %s %d bytes', expected, line, bytes)
          if k >= n then finish('done') else
            k = k + 1
            hoiRun(1)
            startedAt = getTickCount()
            state = 'waitrun'
          end
        elseif getTickCount() - startedAt > 60000 then
          finish('save timed out at ' .. expected)
        end
      elseif state == 'waitrun' then
        if hoiStopped and getTickCount() - startedAt > 1200 then state = 'save'
        elseif getTickCount() - startedAt > 30000 then finish('run timed out') end
      end
    end)
    if not ok then finish('error ' .. tostring(err)) end
  end
  timer.Enabled = true
end
