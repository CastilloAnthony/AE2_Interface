--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--

local gui = require('gui')

local server = {} -- Stores all of the functions for the server

function server.checkForBridge()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'meBridge' then
      term.write('Bridge found!')
      server.moveCursor()
      return true
    end
  end
  return false
end --end checkForBridge
    
function server.checkForMonitor()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'monitor' then
      term.write('Monitor found!')
      server.moveCursor()
      return true
    end
  end
  return false
end --end checkForMonitor

function server.checkForWirelessModem()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'modem' then
      if peripheral.call(i, 'isWireless') then
        term.write('Wireless Modem found!')
        server.moveCursor()
        return true
      end
    end
  end
  return false
end --end checkForWirelessModem

function server.initializeNetwork(modem)
  --7 for broadcast
  --14 for handshake
  --21 for request
  --28 for data
  if not modem.isOpen(14) then
    modem.open(14)
  end
  if not modem.isOpen(21) then
    modem.open(21)
  end
end --end initializeNetwork

function server.broadcast(modem)
  info = {['message'] = 'This is an automated broadcast sharing the ports and additional information for the AE Server.', ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['data'] = 28}, ['additional'] = {['id'] = os.computerID(), ['label'] = os.computerLabel()}}
  modem.transmit(7, 7, info)
end --end broadcast

function server.handshake(modem)

end --end handshake

function server.request(modem)

end --end request

function server.sendData(modem, data)
  modem.transmit(28, 28, data)
end --end sendData

function server.checkMessages(modem)
  timerID = os.timer(0.5)
  --local handshake = {['id'] = 0, ['label'] = 'Anthony\'s Pocket Computer'} -- Handshake format
  local event, side, channel, replyChannel, message, distance = os.pullEvent('modem_message', 'timer')
  if event == 'timer' then
    return false
  end
  if event == 'modem_message' then
    if channel == 14 then
      file = fs.open('clients', 'r')
      local clients = textutils.unserialize(file.readAll())
      file.close()
      for i in clients do
        if (message['handshake']['id'] == i['id']) and (message['handshake']['label'] == i['label']) then
          modem.transmit(14,14,{['success'] = true, ['message'] = 'You are already a client.'})
          return
        end
      end
      table.insert(clients, message['handshake'])
      file = fs.open('clients', 'w')
      file.write(textutils.serialize(clients))
      file.close()
      return
    elseif channel == 21 then
      file = fs.open('clients', 'r')
      local clients = textutils.unserialize(file.readAll())
      file.close()
      for i in clients do
        if (message['id'] == i['id']) and (message['label'] == i['label']) then
          if message['message'] == 'latestSnapshot' then
            server.sendData(modem, server.loadLatestSnapshot())
          end
        end
      end
    end
  end
end --end checkMessages

function server.initializeMonitor(monitor)
  monitor.clear()
  monitor.setCursorPos(1,1)
  monitor.setTextScale(0.5)
end --end initializeMonitor

function server.drawData(monitor, time, items, energy) --Depreciated
  for i=1,5 do
    monitor.setCursorPos(1,i)
    monitor.clearLine()
  end
  monitor.setCursorPos(1,1)
  monitor.write('Snapshot: '..time[1])
  monitor.setCursorPos(1,2)
  monitor.write('Available Storage: '..items['availableStorage']..' '..(math.floor(items['currentStorage']/items['maxStorage']*1000)/10)..'%')
  monitor.setCursorPos(1, 3)
  monitor.write('Total Stored Items: '..items['currentStorage']..' out of '..items['maxStorage'])
  monitor.setCursorPos(1,4)
  monitor.write('Available Energy: '..(math.floor(energy['currentStorage']*2.5*10)/10)..' RF '..(math.floor(energy['currentStorage']/energy['maxStorage']*1000)/10)..'%')
  monitor.setCursorPos(1,5)
  monitor.write('Current Energy Usage: '..(math.floor(energy['usage']*2.5*10)/10)..' RF/t')
  for i=1, 5 do
    monitor.setCursorPos(1,6+i)
    monitor.write(items['topFive'][i]['displayName']..' '..items['topFive'][i]['amount'])
  end
end --end drawData

function server.getEnergyInfo(bridge)
  return {['currentStorage'] = bridge.getEnergyStorage(), ['maxStorage'] = bridge.getMaxEnergyStorage(), ['usage'] = bridge.getEnergyUsage()}
end --end getEnergyInfo

function server.comparison(a, b)
  return a['amount'] > b['amount']
end --end sort

function server.getItemStorageInfo(bridge)
  local items = bridge.listItems()
  local topFive = {items[1], items[2], items[3], items[4], items[5]} --Knowledge 
  table.sort(topFive, server.comparison)
  for _, i in pairs(items) do
    if (i['name'] ~= topFive[5]['name']) and (i['amount'] > topFive[5]['amount']) then
      if (i['name'] ~= topFive[4]['name']) and (i['amount'] > topFive[4]['amount']) then
        if (i['name'] ~= topFive[3]['name']) and (i['amount'] > topFive[3]['amount']) then
          if (i['name'] ~= topFive[2]['name']) and (i['amount'] > topFive[2]['amount']) then
            if (i['name'] ~= topFive[1]['name']) and (i['amount'] > topFive[1]['amount']) then
              topFive[1] = i
            else
              topFive[2] = i
            end
          else
            topFive[3] = i
          end
        else
          topFive[4] = i
        end
      else
        topFive[5] = i
      end
    end
  end
  --[[
    for index, j in pairs(topFive) do
      if(i['name'] ~= j['name']) and (i['amount'] > j['amount']) then
        topFive[index] = i
        break
      end
    end
  end
  ]]
  return {['maxStorage'] = bridge.getTotalItemStorage(), ['currentStorage'] = bridge.getUsedItemStorage(), ['availableStorage'] = bridge.getAvailableItemStorage(), ['topFive'] = topFive}
end --end getItemStorageInfo

function server.getTimeInfo()
  return {os.date()}
end --end getTimeInfo

function server.loadLatestSnapshot()
  latest = nil
  for i in fs.list('data') do
    if latest == nil then
      latest = i
    elseif i > latest then
      latest = i
    end
  end
  file = fs.open('data/'..latest, 'r')
  data = file.readAll()
  file.close()
  return data
end --end loadLAtestSnapshot

function server.saveSnapshot(time, items, energy, lastSnapshotTime)
  --term.write(lastSnapshotTime)
  while #fs.list('data') > 60 do
    toDelete = fs.list('data')[#fs.list('data')]
    term.write('Deleting: '..toDelete)
    server.moveCursor()
    fs.delete('data/'..toDelete)
  end
  if (os.clock() - lastSnapshotTime) >= 60 then
    computer = {['id'] = os.computerID(), ['label'] = os.computerLabel()}
    data = {['computer'] = computer, ['time'] = time, ['items'] = items, ['energy'] = energy}
    filename = 'data/'..os.epoch()
    local file = fs.open(filename, 'w')
    file.write(textutils.serialize(data, {['allow_repetitions'] = true }))
    file.close()
    term.write('Saved snapshot to file: '..filename)
    server.moveCursor()
    return os.clock()
  end
end --end saveSnapshot

function server.moveCursor()
  term.scroll(1)
  _, y = term.getCursorPos()
  term.setCursorPos(1, y)
end --end moveCursor

function server.main()
  term.write('Initializing...')
  server.moveCursor()
  local initial = {server.checkForBridge(), server.checkForMonitor(), server.checkForWirelessModem()}
  for _, i in pairs(initial) do
    if i == false then
      term.write('Cannot find either a meBridge, a monitor, or a wireless modem.')
      server.moveCursor()
      return false
    end
  end
  if os.getComputerLabel() == nil then
    os.setComputerLabel('AE2_Server')
  end
  term.write('Computer ID: '..os.computerID())
  server.moveCursor()
  term.write('Computer Label: '..os.getComputerLabel())
  server.moveCursor()
  fs.makeDir('data')
  local bridge = peripheral.find('meBridge')
  local monitor = peripheral.find('monitor')
  local modem = peripheral.find('modem')
  local lastSnapshotTime = os.clock()
  server.initializeMonitor(monitor)
  server.initializeNetwork(modem)
  while true do
    local timeInfo = server.getTimeInfo()
    local itemsInfo = server.getItemStorageInfo(bridge)
    local energyInfo = server.getEnergyInfo(bridge)
    local temp = server.saveSnapshot(timeInfo, itemsInfo, energyInfo, lastSnapshotTime)
    if not (temp == nil) then
      lastSnapshotTime = temp
    end
    gui.main(monitor, timeInfo, itemsInfo, energyInfo)
    server.broadcast(modem)
    --server.drawData(monitor, timeInfo, itemsInfo, energyInfo)
    --os.sleep(0)
  end
end --end main

return server
