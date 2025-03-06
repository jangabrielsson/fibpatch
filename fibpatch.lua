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
    local text = fmt("%s %s",name,info and info.description or "")
    table.insert(options,{text=text,type='option',value=name})
  end
  self:updateView("qaSelect","options",options)

end