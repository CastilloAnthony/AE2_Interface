--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--

local server = {} -- Stores all of the functions for the server

function server.checkForBridge()
  for i in peripheral.getNames() do
    if i == 'meBridge_0' then
      return true
  return false
end --end checkForBridge
    
function server.main()
  if server.checkForBridge() then
        return true
