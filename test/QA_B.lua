--%%name=QA_B
--%%type=com.fibaro.binarySwitch
--%%file=test/include_B.lua:inc
--%%save=QA_B.fqa


function QuickApp:onInit()
  self:debug(self.name,self.id)
end