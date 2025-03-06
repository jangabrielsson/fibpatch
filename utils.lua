
local EVENT = fibaro.EVENT or {}
fibaro.EVENT = EVENT

function QuickApp:post(event)
  if EVENT[event.type] then
    setTimeout(function() EVENT[event.type](event) end,0)
  end
end