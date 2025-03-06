if require and not QuickApp then require('hc3emu') end

--%%name=fibrocks
--%%type=com.fibaro.genericDevice

local test = true

local fmt = string.format

function QuickApp:getQA(user,repo,name,tag,cb)
  local url = fmt("https://raw.githubusercontent.com/%s/%s/%s/%s",user,repo,tag,name)
  net.HTTPClient():get(url,{
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
  local url = fmt("https://raw.githubusercontent.com/%s/%s/master/%s",user,repo,name..".rel")
  net.HTTPClient():get(url,{
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
  if test then 
    fibaro.hc3emu.loadQA("test/QA_A.lua")
  end

  self:post({type='start'})
end