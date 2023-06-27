--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--

local server = {} -- Stores all of the functions for the server

function server.checkForBridge()
  for _, i in pairs(peripheral.getNames()) do
    if i == 'meBridge_0' then
      term.write('Bridge found!')
      return true
    elseif (i == 'bottom') or (i == 'top') or (i == 'left') or (i == 'right') or (i == 'front') or (i == 'back') then
      if peripheral.getType(i) == 'meBridge' then
        term.write('Bridge found!')
        return true
      end
    end
  return false
  end
end --end checkForBridge
    
function server.checkForMonitor()
  for _, i in pairs(peripheral.getNames()) do
    if i == 'monitor' then
      term.write('Monitor found!')
      return true
    elseif (i == 'bottom') or (i == 'top') or (i == 'left') or (i == 'right') or (i == 'front') or (i == 'back') then
      if peripheral.getType(i) == 'monitor' then
        term.write('Monitor found!')
        return true
      end
    end
  end
  return false
end --end checkForMonitor

function server.initializeMonitor()
  monitor.clear()
  monitor.setCursorPos(0,0)
end --end initializeMonitor

function server.drawData(monitor, items, energy)
  monitor.clear()
  monitor.setCursorPos(0,0)
  monitor.write('Available Storage: ')
  monitor.write(items[2])
  monitor.write(' ')
  monitor.write(items[1]/items[0])
  monitor.write('%')
  monitor.setCursorPos(0, 1)
  monitor.write('Total Stored Items: ')
  monitor.write(items[1])
  monitor.write(' out of ')
  monitor.write(items[0])
  monitor.setCursorPos(0,2)
  montior.write('Available Energy: ')
  monitor.write(energy[0])
  monitor.write(' ')
  monitor.write(energy[0]/energy[1])
  monitor.setCursorPos(0,3)
  monitor.write('Current Energy Usage: ')
  monitor.write(energy[2])
end --end drawData

function server.getEnergyInfo(bridge)
  return {bridge.getEnergyStorage(), bridge.getMaxEnergyStorage(), bridge.getEnergyUsage()}
end --end getEnergyInfo

function server.getItemStorageInfo(bridge)
  return {bridge.getTotalItemStorage(), bridge.getUsedItemStorage(), bridge.getAvailableItemStorage()}
end --end getItemStorageInfo

function server.main()
  if server.checkForBridge() and server.checkForMonitor() then
    local bridge = peripheral.find('meBridge')
    local monitor = peripheral.find('monitor')
  else
    term.write('Cannot find either the meBridge or the monitor.')
    return false
  end
  server.initializeMonitor()
  while true do
    itemsInfo = server.getItemStorage(bridge)
    energyInfo = server.getEnergyInfo(bridge)
    server.drawData(monitor, itemsInfo, energyInfo)
    os.sleep(1)
  end
end --end main

return server
