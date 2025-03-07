--%%name=QA_A
--%%type=com.fibaro.binarySwitch
--%%file=test/include_A.lua:inc
--%%uid=5345879375
--%%manufacturer=jgab Inc
--%%model=standard
--%%role=Light
--%%description=Test QA A
--%%save=QA_A.fqa


function QuickApp:onInit()
  self:debug(self.name,self.id)
  print("A=",A)
end