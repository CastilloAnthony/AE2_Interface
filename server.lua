--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--

local gui = require('gui')

local server = {} -- Stores all of the functions for the server

function server.moveCursor()
  term.scroll(1)
  local _, y = term.getCursorPos()
  term.setCursorPos(1, y)
end --end moveCursor

function server.checkForBridge()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'meBridge' then
      if peripheral.call(i, 'isConnected') then
        term.write('Bridge found!')
        server.moveCursor()
        return peripheral.wrap(i)
      end
    end
  end
  return false
end --end checkForBridge
    
function server.checkForMonitor()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'monitor' then
      term.write('Monitor found!')
      server.moveCursor()
      return peripheral.wrap(i)
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
        return peripheral.wrap(i)
      end
    end
  end
  return false
end --end checkForWirelessModem

function server.initializeNetwork(modem)
  --['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}
  if not modem.isOpen(14) then
    modem.open(14)
  end
  if not modem.isOpen(21) then
    modem.open(21)
  end
end --end initializeNetwork

function server.broadcast(modem)
  local info = {['message'] = 'This is an automated broadcast sharing the ports and additional information for the AE Server.', ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}, ['verify'] = {['id'] = os.computerID(), ['label'] = os.computerLabel()}}
  modem.transmit(7, 0, info)
end --end broadcast

function server.sendData(modem, data) -- Depreciated
  modem.transmit(28, 0, data)
end --end sendData

function server.checkMessages(modem)
  -- packet = {['message'] = 'This is a message', ['verify'] = {['id'] = os.computerID(), ['label'] = os.computerLabel()}} --A standard packet transmission
  local timerID = os.startTimer(0.1)
  --local handshake = {['id'] = 0, ['label'] = 'Anthony\'s Pocket Computer'} -- Handshake format
  local event, side, channel, replyChannel, message, distance
  while true do
    event, side, channel, replyChannel, message, distance = os.pullEvent()
    if event == 'modem_message' then
      break
    elseif (event == 'timer') and (side == timerID) then
      return false
    end
  end
  if event == 'modem_message' then
    if (channel == 14) then
      if (message['handshake'] == true) then
        local file = fs.open('clients', 'r')
        local clients = textutils.unserialize(file.readAll())
        file.close()
        for _, i in pairs(clients) do
          if (message['verify']['id'] == i['id']) and (message['verify']['label'] == i['label']) then
            modem.transmit(14,14,{['success'] = true, ['message'] = 'You are already a client.', ['verify'] = server.getComputerInfo()})
            term.write('Successful handshake with '..message['verify']['id']..' '..message['verify']['label'])
            server.moveCursor()
            return true
          end
        end
        table.insert(clients, message['verify'])
        local file = fs.open('clients', 'w')
        file.write(textutils.serialize(clients))
        file.close()
        modem.transmit(14,14,{['success'] = true, ['message'] = 'You have been added to the list of clients.', ['verify'] = server.getComputerInfo()})
        term.write('Successful handshake with '..message['verify']['id']..' '..message['verify']['label'])
        server.moveCursor()
        return true
      end
    elseif channel == 21 then
      local file = fs.open('clients', 'r')
      local clients = textutils.unserialize(file.readAll())
      file.close()
      for _, i in pairs(clients) do
        if (message['verify']['id'] == i['id']) and (message['verify']['label'] == i['label']) then
          if message['message'] == 'latestSnapshot' then
            modem.transmit(28, 0, {['message'] = 'Enjoy!',['verify'] = server.getComputerInfo(), ['data'] = server.loadLatestSnapshot()})
            term.write('Sent data packet to '..message['verify']['id']..' '..message['verify']['label'])
            server.moveCursor()
          else
           -- term.write('Unknown request.')
          end
        else
          --term.write('Unauthorized client request.')
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

function server.checkIfInTable(element, table)
  for i, j in pairs(table) do
    if element == j then
      return true
    end
  end
  return false
end --end

function server.getItemStorageInfo(bridge)
  local items = bridge.listItems()
  local topFive = {items[1], items[2], items[3], items[4], items[5]} --Knowledge Essence, Chromatic Steel, Currency, tetc. (important items)
  table.sort(topFive, server.comparison)
  local count = 0
  repeat
    count = count + 1
    for _, i in pairs(items) do
      for index, j in pairs(topFive) do
        if i['name'] ~= j['name'] and not server.checkIfInTable(i, topFive) then
          if tonumber(i['amount']) > tonumber(j['amount']) then
            topFive[index] = i
            break
          end
        end
      end
    end
  until count == 4
  --[[
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
  ]]
  return {['maxStorage'] = bridge.getTotalItemStorage(), ['currentStorage'] = bridge.getUsedItemStorage(), ['availableStorage'] = bridge.getAvailableItemStorage(), ['topFive'] = topFive}
end --end getItemStorage1
function server.getTimeInfo()
  return {os.date()}
end --end getTimeInfo

function server.loadLatestSnapshot()
  local latest = nil
  for _, i in pairs(fs.list('data')) do
    if latest == nil then
      latest = tonumber(i)
    elseif tonumber(i) > latest then
      latest = tonumber(i)
    end
  end
  --local list = fs.list('data')
  --latest = list[1]
  local file = fs.open('data/'..latest, 'r')
  local data = file.readAll()
  file.close()
  return data
end --end loadLAtestSnapshot

function server.saveSnapshot(time, items, energy, lastSnapshotTime)
  --term.write(lastSnapshotTime)
  while #fs.list('data') > 60 do
    local oldest = nil
    for _, i in pairs(fs.list('data')) do
      if oldest == nil then
        oldest = tonumber(i)
      elseif tonumber(i) < oldest then
        oldest = tonumber(i)
      end
    end
    term.write('Deleting: '..oldest)
    server.moveCursor()
    fs.delete('data/'..oldest)
  end
  if (os.clock() - lastSnapshotTime) >= 60 then
    local computer = server.getComputerInfo()
    local data = {['computer'] = computer, ['time'] = time, ['items'] = items, ['energy'] = energy}
    local filename = 'data/'..os.epoch()
    local file = fs.open(filename, 'w')
    file.write(textutils.serialize(data, {['allow_repetitions'] = true }))
    file.close()
    term.write('Saved snapshot to file: '..filename)
    server.moveCursor()
    return os.clock()
  end
end --end saveSnapshot

function server.getComputerInfo()
  return {['id'] = os.computerID(), ['label'] = os.computerLabel()}
end --end getComputerInfo

function server.main()
  term.write('Initializing...')
  server.moveCursor()
  if os.getComputerLabel() == nil then
    os.setComputerLabel('AE2_Server')
  end
  local initial = {['computerInfo'] = server.getComputerInfo() , ['bridge'] = server.checkForBridge(), ['monitor'] = server.checkForMonitor(), ['modem'] = server.checkForWirelessModem()}
  for _, i in pairs(initial) do
    if i == false then
      term.write('Cannot find either a meBridge, a monitor, or a wireless modem.')
      server.moveCursor()
      return false
    end
  end
  term.write('Computer ID: '..os.computerID())
  server.moveCursor()
  term.write('Computer Label: '..os.getComputerLabel())
  server.moveCursor()
  fs.makeDir('data')
  term.write('Saving data to /data/')
  server.moveCursor()
  local file = fs.open('clients', 'w')
  local temp = {server.getComputerInfo()}
  file.write(textutils.serialize(temp))
  file.close()
  local file = fs.open('server.keys', 'w')
  file.write(textutils.serialize(server.getComputerInfo()))
  file.close()
  local bridge = initial['bridge']
  local monitor = initial['monitor']
  local modem = initial['modem']
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
    server.checkMessages(modem)
    if (os.clock() - lastSnapshotTime) > 60 then
      server.broadcast(modem)
    end
    --server.drawData(monitor, timeInfo, itemsInfo, energyInfo)
    --os.sleep(0)
  end
end --end main

return server
