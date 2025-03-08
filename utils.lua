local fmt = string.format

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

----------------- Github -----------------
local function urlencode(str) -- very useful
  if str then
    str = str:gsub("\n", "\r\n")
    str = str:gsub("([ %-%_%.%~])", function(c)
      return ("%%%02X"):format(string.byte(c))
    end)
    str = str:gsub(" ", "%%20")
  end
  return str	
end

local function trim(s)
  return s:match("(.+)%.fqa$") or s
end

function QuickApp:git_getQA(user,repo,name,tag,cb)
  local url = urlencode(fmt("/%s/%s/%s/%s",user,repo,tag,name))
  url = "https://raw.githubusercontent.com"..url
  net.HTTPClient():request(url,{
    options = {checkCertificate = false, timeout=20000},
    success = function(response)
      if response and response.status == 200 then
        cb(true,response.data)
      else cb(false,response and response.status or "nil") end
    end,
    error = function(err) cb(false,err) end
  })
end

function QuickApp:git_getQAReleases(user,repo,name,cb)
  name = trim(name)
  name = name..".releases"
  local url = urlencode(fmt("/%s/%s/master/%s",user,repo,name))
  url = "https://raw.githubusercontent.com"..url
  net.HTTPClient():request(url,{
    options = {checkCertificate = false, timeout=20000},
    success = function(response)
      if response and response.status == 200 then
        cb(true,response.data)
      else cb(false,response and response.status or "nil") end
    end,
    error = function(err) cb(false,err) end
  })
end

function QuickApp:git_getQATags(user,repo,cb)
  local url = fmt("https://api.github.com/repos/%s/%s/tags",user,repo)
  net.HTTPClient():request(url,{
    options = {checkCertificate = false, timeout=20000},
    success = function(response)
      if response and response.status == 200 then
        cb(true,response.data)
      else cb(false,response and response.status or "nil") end
    end,
    error = function(err) cb(false,err) end
  })
end

------------------ Selectable ------------------
local function mkKey(item) return tostring(item):gsub("[^%w]","") end
Selectable = Selectable
class 'Selectable'
function Selectable:__init(qa,id,fun)
  self.id = id
  self.qa = qa
  self.fun = fun
  self.qa[fun] = function(_,event)
    self.value = tostring(event.values[1])
    self.item = self.map[self.value]
    if self.selected then
      self:selected(self.item)
    end
  end
end
function Selectable:update(list)
  local r = {}
  for _,item in pairs(list) do
    if self.filter then 
      if self:filter(item) then table.insert(r,item) end
    else table.insert(r,item) end
  end
  if self.sort then
    local function sort(a,b) return self:sort(a,b) end
    table.sort(r,sort) 
  end
  self.list = r
  self.map = {}
  local options = {}
  for _,item in ipairs(self.list) do
    local key = mkKey(self:key(item)) -- corrected parenthesis
    local name = self:name(item)
    self.map[key] = item
    table.insert(options,{text=name,type='option',value=key})
  end
  --print("Updated",self.id,#options)
  self:_updateList("options",options)
end
function Selectable:select(key)
  key = mkKey(key)
  if not self.map[key] then 
    return fibaro.warning(__TAG,"Invalid key: "..key)
  end
  self:_updateList("selectedItem",key)
  self.qa[self.fun](self.qa,{values={key}})
  self:selected(self.map[key])
end

function Selectable:_updateList(prop,value)
  self.qa:updateView(self.id,prop,value)
end

--[[
function Selectable:selected(value) ...end
function Selectable:key(item) return item.key end
function Selectable:name(item) return item.name end
function Selectable:sort(a,b) return a.name < b.name end
Selectable.value
--]]