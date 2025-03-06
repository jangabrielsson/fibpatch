
local EVENT = fibaro.EVENT or {}
fibaro.EVENT = EVENT

function QuickApp:post(event)
  if EVENT[event.type] then
    setTimeout(function() EVENT[event.type](event) end,0)
  end
end

function table.map(t,f)
  local r = {}
  for i,v in ipairs(t) do
    r[i] = f(v)
  end
  return r
end