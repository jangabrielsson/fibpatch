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

function QuickApp:getQA(user,repo,name,tag,cb)
  local url = fmt("https://raw.githubusercontent.com/%s/%s/%s/%s",user,repo,tag,name)
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

function QuickApp:getQAReleases(user,repo,name,cb)
  local name = name:match("(.+)%.fqa") or name
  name = name..".releases"
  local url = fmt("https://raw.githubusercontent.com/%s/%s/master/%s",user,repo,name)
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
end

function QuickApp:updateQADir()
  for i,qa in ipairs(QA_DIR) do
    dir[qa.name] = qa
    self:fetchQAData(qa.user,qa.repo,qa.name)
  end
end

function QuickApp:fetchQAData(user,repo,name)
  self:getQAReleases(user,repo,name,function(ok,data)
    if ok then
      dir[name].releases = json.decode(data)
    else
      self:error(fmt("fetching repo %s:%s:%s", user, repo, name))
    end
  end)
  self:updateDistsMenu()
end

function QuickApp:updateDistsMenu()
  local options = {}
  for name,qa in pairs(dir) do
    table.insert(options,{text=name,type='option',value=name})
  end
  self:updateView("qaSelect","options",options)

end