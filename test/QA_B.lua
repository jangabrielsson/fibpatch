--%%name=QA_B
--%%type=com.fibaro.binarySwitch
--%%file=test/include_B.lua:inc
--%%uid=53454449375
--%%manufacturer=jgab Inc
--%%model=standard
--%%role=Light
--%%description=Test QA B
--%%save=QA B.fqa


function QuickApp:onInit()
  self:debug(self.name,self.id)
  print("B=",B)
end