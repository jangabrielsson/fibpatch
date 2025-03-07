_DEVELOP="../hc3emu"
if require and not QuickApp then require('hc3emu') end

--%%name=fibpatch
--%%type=com.fibaro.genericDevice
--%%proxy=FibPatchProxy
--%%file=utils.lua:utils
--%%file=dir.lua:dir

--%%u={label='title',text=''}
--%%u={select='qaSelect', text='QA dist', onToggled='qaSelect', options={}}
--%%u={select='qaVersion', text='Version', onToggled='qaVersion', options={}}
--%%u={select='qaUpdate', text='Update', onToggled='qaUpdate', options={}}
--%%u={label='info',text=''}
--%%u={{button='b1', text='Update', onReleased='qaUpdate'},{button='b2', text='Install', onReleased='qaInstall'},{button='b3', text='Refresh', onReleased='refresh'}}

local test = true
local VERSION = "0.1.0"

local fmt = string.format
local EVENT = fibaro.EVENT or {}
fibaro.EVENT = EVENT
QAs,Versions,Dists = QAs,Versions,Dists

local function trim(s)
  return s:match("(.+)%.fqa$") or s
end

fibaro.hc3emu.installLocal = true

local QAS = {}

class "Dists"(Selectable)
function Dists:__init(qa) Selectable.__init(self,qa,"qaSelect","qaSelect") end
function Dists:name(item) return trim(item.name) end
function Dists:key(item) return item.name end
function Dists:sort(a,b) return a.name < b.name end
function Dists:selected(item)
  DistUID = item.info.uid
  self.qa.versions:update(item.info.versions)
  self.qa.qas:update(QAS)
  self.qa:updateInfo()
end

class "Versions"(Selectable)
function Versions:__init(qa) Selectable.__init(self,qa,"qaVersion","qaVersion") end
function Versions:name(item) return fmt("%s, %s",item.version,item.description) end
function Versions:key(item) return item.version end
function Versions:sort(a,b) return a.version < b.version end
function Versions:selected(item) self.qa:updateInfo() end

class "QAs"(Selectable)
function QAs:__init(qa) Selectable.__init(self,qa,"qaUpdate","qaUpdate") end
function QAs:name(item) return fmt("%s: %s",item.id,item.name) end
function QAs:key(item) return item.id end
function QAs:sort(a,b) return a.name < b.name end
function QAs:filter(item) return item.properties.quickAppUuid == DistUID end
function QAs:selected(item) self.qa:updateInfo() end

function QuickApp:onInit()
  self:debug(self.name,self.id)
  self:updateView("title","text",fmt("FibPatch v%s",VERSION))
  if test then 
    fibaro.hc3emu.loadQA("test/QA_A.lua")
    fibaro.hc3emu.loadQA("test/QA_B.lua")
  end
  
  self.dists = Dists(self)
  self.versions = Versions(self)
  self.qas = QAs(self)
  
  self:updateQADir()
  self:updateQAlist()
  
  setTimeout(function() 
    self.dists:select("QA_A.fqa")
    self.versions:select("10")
    self:qaInstall()
  end,1000)
end

local dir = {}
function QuickApp:updateQADir()
  dir = {}
  for i,qa in ipairs(QA_DIR) do
    dir[qa.name] = qa
    self:getQAReleases(qa.user,qa.repo,qa.name)
  end
end

function QuickApp:getQAReleases(user,repo,name)
  self:git_getQAReleases(user,repo,name,function(ok,data)
    if ok then
      dir[name].info = json.decode(data)
      self.dists:update(dir)  -- updated to call dists
    else
      self:error(fmt("fetching repo %s:%s:%s", user, repo, name))
    end
  end)
end

local qas = {}
function QuickApp:updateQAlist()
  local res = api.get("/devices?interface=quickApp") or {}
  qas = {}
  for _,d in ipairs(res) do
    if 
    (d.parentId==nil or d.parentId==0) and
    (d.encrypted == nil or d.encrypted == false)
    then
      table.insert(qas,d)
    end
  end
  QAS = qas
  self.qas:update(qas)
end

function QuickApp:updateInfo()
  local str = fmt("QA:%s\nVersion:%s\nUpdate:%s"
  ,self.dists.item and self.dists.item.name or "N/A"
  ,self.versions.item and self.versions.item.version or "N/A"
  ,self.qas.item and self.qas.item.name or "N/A"
)
local updb = self.dists.item and self.versions.item and self.qas.item and true or false
self:updateView("b1","visible",updb)
self:updateView("info","text",str)
end

function QuickApp:getQA(cb)
  if not(self.dists.item and self.versions.item) then
    return self:error("Please select dist, version to install")
  end
  local dist = self.dists.item
  local version = self.versions.item
  local tag = version.tag
  if not tag then 
    return self:error(fmt("Version %s not found",version.version))
  end
  self:git_getQA(dist.user,dist.repo,dist.name,tag,function(ok,res)
    if ok then ok,res = pcall(json.decode,res) end
    cb(ok,res)
  end)
end

function QuickApp:update()
  if not self.qas.item then
    return self:error("Please select QA to update")
  end
  self:getQA(function(ok,res)
    local fqa = json.decode(res)
    local files = fqa.files
    local props = fqa.initialProperties
    local ifs = fqa.initialInterfaces
  end)
end

function QuickApp:qaInstall()
  self:getQA(function(ok,res)
    local fqa = res
    local res,code = api.post("/quickApp/",fqa)
    if code < 203 then
      self:log("Install success")
      return
    end
    self:error("Install failed")
  end)
end

function QuickApp:refresh()
  self:updateQADir()
  self:updateQAlist()
end

function QuickApp:log(fmt,...)
  self:debug(fmt,...)
end