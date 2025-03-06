if require and not QuickApp then require('hc3emu') end

--%%name=fibpatch
--%%type=com.fibaro.genericDevice
--%%proxy=FibPatchProxy
--%%file=utils.lua:utils
--%%file=dir.lua:dir

--%%u={label='tile',text=''}
--%%u={select='qaSelect', text='QA dist', onToggle='qaSelect', options={}}
--%%u={select='qaVersion', text='Version', onToggle='qaVersion', options={}}
--%%u={select='qaUpdate', text='Update', onToggle='qaUpdate', options={}}
--%%u={{button='b1', text='Update', onReleased='qaUpdate'},{button='b2', text='Install', onReleased='qaInstall'}}

local test = true
local VERSION = "0.1.0"

local fmt = string.format
local EVENT = fibaro.EVENT or {}
fibaro.EVENT = EVENT

local dir = {}
local selectedDist = nil
local selectedVersion = nil
local selectedUpdateQA = nil

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

function QuickApp:getQA(user,repo,name,tag,cb)
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

local function trim(s)
  return s:match("(.+)%.fqa$") or s
end

function QuickApp:getQAReleases(user,repo,name,cb)
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

function QuickApp:getQATags(user,repo,cb)
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

function QuickApp:onInit()
  self:debug(self.name,self.id)
  self:updateView("tile","text",fmt("FibPatch v%s",VERSION))
  if test then 
    fibaro.hc3emu.loadQA("test/QA_A.lua")
    fibaro.hc3emu.loadQA("test/QA_B.lua")
  end
  self:updateQADir()
  self:updateQAlist()
end

function QuickApp:updateQADir()
  for i,qa in ipairs(QA_DIR) do
    dir[qa.name] = qa
    self:fetchQAData(qa.user,qa.repo,qa.name)
  end
end

function QuickApp:updateQAlist()
  local options = {}
  local qas = api.get("/devices?interface=quickApp")
  for _,qa in ipairs(qas) do
    if qa.parentId==nil or qa.parentId == 0 then
      local name = fmt("%s:%s",qa.id,qa.name)
      table.insert(options,{idx=qa.name,text=name,type='option',value=tostring(qa.id)})
    end
  end
  table.sort(options,function(a,b) return a.idx < b.idx end)
  table.map(options,function(o) o.idx = nil end)
  self:updateView("qaUpdate","options",options)
end

function QuickApp:fetchQAData(user,repo,name)
  self:getQAReleases(user,repo,name,function(ok,data)
    if ok then
      dir[name].info = json.decode(data)
      self:updateDistsMenu()
    else
      self:error(fmt("fetching repo %s:%s:%s", user, repo, name))
    end
  end)
end

function QuickApp:updateDistsMenu()
  local options = {}
  for name,info in pairs(dir) do
    info = info.info
    local text = fmt("%s, %s",trim(name),info and info.description or "")
    table.insert(options,{text=text,type='option',value=name})
  end
  self:updateView("qaSelect","options",options)
end

function QuickApp:updateVersionMenu()
  local options = {}
  local dist = dir[selectedDist]
  if not dist then return end
  local info = dist.info
  local versions = info.versions
  for i,v in ipairs(versions) do
    local text = fmt("%s, %s",v.version,v.description)
    table.insert(options,{text=text,type='option',value=v.version})
  end
  self:updateView("qaVersion","options",options)
end

function QuickApp:qaSelect(event)
  local name = event.value
  selectedDist = name
  self:updateVersionMenu()
end

function QuickApp:qaVersion(event)
  selectedVersion = event.value
end

function QuickApp:qaUpdate(event)
  selectedUpdateQA = event.value
end

function QuickApp:update()
end

function QuickApp:install()
end