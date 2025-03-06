--%%name=QA_A
--%%type=com.fibaro.binarySwitch
--%%file=test/include_A.lua:inc
--%%save=QA_A.fqa


function QuickApp:onInit()
  self:debug(self.name,self.id)
end