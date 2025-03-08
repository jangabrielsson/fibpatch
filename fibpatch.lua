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
--%%u={{button='b1', text='Update', onReleased='update'},{button='b2', text='Install', onReleased='install'},{button='b3', text='Refresh', onReleased='refresh'}}

local test = true
local VERSION = "0.1.0"

local fmt = string.format
local EVENT = fibaro.EVENT or {}
fibaro.EVENT = EVENT
QAs,Versions,Dists = QAs,Versions,Dists

local function ERRORF(fmt,...) fibaro.error(__TAG,fmt:format(...)) end

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
  
  -- self:testQA("install","QA_A.fqa","1.0",nil,2000)
  -- self:testQA("install","QA_A.fqa","1.1",nil,4000)
  
  self:testQA("update","QA_A.fqa","1.0",5002,2000)
end

function QuickApp:testQA(cmd,name,version,id,time) -- for testing in emulator
  time = time or 4000
  setTimeout(function() 
    self.dists:select(name)
    self.versions:select(version)
    if cmd == "update" then 
      self.qas:select(id)
      self:update()
    elseif cmd == "install" then self:install() end
  end,time)
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
  self:debug("Update")
  if not self.qas.item then
    return self:error("Please select QA to update")
  end
  self:getQA(function(ok,res)
    if not ok then return self:error(res) end
    local eid = self.qas.item.id
    local version = self.versions.item
    local function exclude(name)
      for _,p in ipairs(version.exclude or {}) do
        if name == p then return true end
      end 
    end
    local fqa = res
    
    local nprops = fqa.initialProperties
    local nifs = fqa.initialInterfaces -- do this in QA...
    
    -- update files
    local efile = api.get(fmt("/quickApp/%s/files",eid))
    local nfile = fqa.files
    local emap,nmap = {},{}
    local newFiles = {}
    local existingFiles = {}
    local deletedFiles = {}
    
    for _,f in ipairs(nfile) do nmap[f.name] = f end
    for _,f in ipairs(efile) do emap[f.name] = f end
    for _,f in ipairs(nfile) do
      if not emap[f.name] then newFiles[#newFiles+1] = f 
      else 
        if not exclude(f.name) then existingFiles[#existingFiles+1] = f end
      end
    end
    for _,f in ipairs(efile) do 
      if not nmap[f.name] and not exclude(f.name) then 
        deletedFiles[#deletedFiles+1] = f 
      end
    end
    
    for _,f in ipairs(newFiles) do
      local res,code = api.post("/quickApp/"..eid.."/files",f)
      if code > 201 then ERRORF("Failed to create file %s",f.name) end
    end
    
    local res,code = api.put("/quickApp/"..eid.."/files",existingFiles)
    if code > 202 then 
      ERRORF("Failed to update files for QuickApp %d",eid)
    end
    
    for _,f in ipairs(deletedFiles) do
      local _,code = api.delete("/quickApp/"..eid.."/files/"..f.name)
      if code > 202 then ERRORF("Failed to delete file %s",f.name) end
    end
    
    -- Update UI
    if UI then
      local viewLayout,uiView,uiCallbacks = nprops.viewLayout,nprops.uiView,nprops.uiCallbacks
      local _,code = api.put("/devices/"..eid,{
        properties = {
          viewLayout = viewLayout,
          uiView = uiView,
          uiCallbacks = uiCallbacks
        }
      })
      if code > 202 then 
        ERRORF("Failed to update UI for QuickApp %d",eid)
      end
    end
  end)
end

function QuickApp:install()
  self:getQA(function(ok,res)
    if not ok then return self:error(res) end
    local fqa = res
    local res,code = api.post("/quickApp/",fqa)
    if code < 203 then
      return self:log("Install success")
    end
    self:error("Install failed",code)
  end)
end

function QuickApp:refresh()
  self:updateQADir()
  self:updateQAlist()
end

function QuickApp:log(fmt,...)
  self:debug(fmt,...)
end