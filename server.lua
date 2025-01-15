--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--

local gui = require('gui')

local server = {} -- Stores all of the functions for the server

server.bridge = nil
server.monitor = nil
server.modem = nil
server.snapshot = nil
server.snapshotItems = nil
server.currDrive = nil
server.storages = {}
server.fullStorages = {}
server.craftRequests = {}

function server.write(text)
  if text ~= nil then
    --write(text)
    gui.log(text, server.selectDrive())
  end
  --term.scroll(1)
  local _, y = term.getCursorPos()
  term.setCursorPos(1, y)
end --end write

function server.findDrives()
  for _, i in pairs(peripheral.getNames()) do
    if string.find(peripheral.getType(i), 'drive') then
      table.insert(server.storages, i)
      -- server.storages[#server.storages] = i
      -- server.fullStorages[i] = nil
    end
  end
  local file = fs.open('storages.temp', 'w')
  file.write(textutils.serialize(server.storages))
  file.close()
end --end findDrives

function server.checkIfKeyInTable(table, key)
  for _, i in pairs(table) do
    if i == key then
      return true
    end
  end
  return false
end

function server.selectDrive()
  if server.currDrive ~= nil then
    if peripheral.wrap(server.currDrive).isDiskPresent() then
      if fs.getFreeSpace(peripheral.wrap(server.currDrive).getMountPath()) > 500 then
        return peripheral.wrap(server.currDrive).getMountPath()..'/'
      end
    end
  end
  for _, i in pairs(server.storages) do
    if peripheral.wrap(i).isDiskPresent() then
      if fs.getFreeSpace(peripheral.wrap(i).getMountPath()) > 500 then
        server.currDrive = i
        gui.log('Now saving logs to '..server.currDrive, server.selectDrive())
        return peripheral.wrap(i).getMountPath()..'/'
      else
        if server.checkIfKeyInTable(server.fullStorages, i) == false then
          table.insert(server.fullStorages, i)
        end
      end
    end
  end
  return './'
end --end selectDrive

function server.checkDriveStorage()
  for _, i in pairs(server.fullStorages) do
    if peripheral.wrap(i).isDiskPresent() then
      if fs.getFreeSpace(peripheral.wrap(i).getMountPath()) > 500 then
        server.fullStorages[i] = nil
      else
        gui.log(i..' is full.', server.selectDrive())
      end
    end
  end
end --end checkDriveStorage

function server.moveCursor()
  server.writeTerm()
end --end moveCursor

function server.checkForBridge()
  for _, i in pairs(peripheral.getNames()) do
    --if peripheral.getType(i) == 'meBridge' then
    if string.find(peripheral.getType(i), 'meBridge') then
      if peripheral.call(i, 'isConnected') then
        server.write('Bridge found!')
        return peripheral.wrap(i)
      end
    end
  end
  return false
end --end checkForBridge
    
function server.checkForMonitor()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'monitor' then
      server.write('Monitor found!')
      -- return peripheral.wrap(i)
      width, height = peripheral.wrap(i).getSize()
      return window.create(peripheral.wrap(i), 1, 1, width, height)
    end
  end
  server.write('Could not find a monitor, using terminal.')
  width, height = term.current().getSize()
  return window.create(term.current(), 1, 1, width, height)
end --end checkForMonitor

function server.checkForWirelessModem()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'modem' then
      if peripheral.call(i, 'isWireless') then
        server.write('Wireless Modem found!')
        return peripheral.wrap(i)
      end
    end
  end
  return false
end --end checkForWirelessModem

function server.initializeNetwork()
  --['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}
  if not server.modem.isOpen(14) then
    server.modem.open(14)
  end
  if not server.modem.isOpen(21) then
    server.modem.open(21)
  end
end --end initializeNetwork

function server.broadcast()
  local info = {['message'] = 'This is an automated broadcast sharing the ports and additional information for the AE Interface Server.', ['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}, ['verify'] = server.getComputerInfo()}
  --server.write('Broadcasted')
  server.modem.transmit(7, 0, info)
end --end broadcast

function server.broadcastDataAvailable()
  local info = {['message'] = 'There is a new snapshot available.', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'newDataAvailable'}}
  server.modem.transmit(7, 0, info)
  gui.log('A new snapshot is available.', server.selectDrive())
end

function server.checkMessages(event, side, channel, replyChannel, message, distance)
  if event == 'modem_message' then
    if (channel == 14) then
      if message['verify'] ~= nil then
        if (message['handshake'] == true) then
          local file = fs.open('./AE2_Interface/clients', 'r')
          local clients = textutils.unserialize(file.readAll())
          file.close()
          for _, i in pairs(clients) do
            if (message['verify']['id'] == i['id']) and (message['verify']['label'] == i['label']) then
              server.modem.transmit(14, 0, {['message'] = 'Welcome back '..'ID:'..message['verify']['id']..' '..message['verify']['label']..'.', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'handshake', ['success'] = true}})
              server.write('Successful handshake with '..'ID:'..message['verify']['id']..' '..message['verify']['label'])
              return true
            end
          end
          table.insert(clients, message['verify'])
          local file = fs.open('./AE2_Interface/clients', 'w')
          file.write(textutils.serialize(clients))
          file.close()
          server.modem.transmit(14, 0, {['message'] = 'You have been added to the list of clients.', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'handshake', ['success'] = true}})
          server.write('Successful handshake with '..message['verify']['label']..' (ID: '..message['verify']['id']..')')
          return true 
        end
      end
    elseif channel == 21 then
      if message['verify'] ~= nil then
        local file = fs.open('./AE2_Interface/clients', 'r')
        local clients = textutils.unserialize(file.readAll())
        file.close()
        for _, i in pairs(clients) do
          if (message['verify']['id'] == i['id']) and (message['verify']['label'] == i['label']) then
            if message['message'] == 'latestSnapshot' then
              server.modem.transmit(28, 0, {['message'] = 'Enjoy!', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'latestSnapshot', ['data'] = textutils.serialize(server.snapshot, {['allow_repetitions'] = true })}})
              server.write('Sent snapshot packet to '..'ID:'..message['verify']['id']..' '..message['verify']['label'])
            elseif message['message'] == 'allData' then
              server.modem.transmit(28, 0, {['message'] = 'Enjoy!', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'allData', ['data'] = textutils.serialize(server.snapshotItems, {['allow_repetitions'] = true })}})
              -- server.write('Sent items info packet to '..'ID:'..message['verify']['id']..' '..message['verify']['label'])
            elseif message['message'] == 'keys' then
              local file = fs.open('./AE2_Interface/server.keys', 'r')
              local keys = textutils.unserialize(file.readAll())
              file.close()
              server.modem.transmit(28, 0, {['message'] = 'Access Granted.', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'keys', ['data'] = keys}})
              server.write('Sent keys packet to '..'ID:'..message['verify']['id']..' '..message['verify']['label'])
            elseif message['message'] == 'craft' then
              if server.craftRequests[message['packet']['timestamp']] ~= nil then
                server.modem.transmit(28, 0, {['message'] = 'Acknowledged.', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'craft', ['data'] = False, ['timestamp'] = message['packet']['timestamp']}})
              else
                server.modem.transmit(28, 0, {['message'] = 'Acknowledged.', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'craft', ['data'] = server.bridge.craftItem(message['packet']['data']), ['timestamp'] = message['packet']['timestamp']}})
                server.craftRequests[message['packet']['timestamp']] = message['packet']['data']
                server.write('Crafting request from ID: '..message['verify']['id']..' '..message['verify']['label']..' for one '..message['packet']['data']['displayName'])
              end
            else
              -- gui.log('Unknown request from '..message['verify']['id'])
            server.write('Unknown request from '..message['verify']['id'])
            end
          else
            -- gui.log('Unauthorized client request.')
            -- server.write('Unauthorized client request.')
          end
        end
      end
    end
  end
end --end checkMessages

function server.checkCraftingQueue()
  gui.readSettings()
  if #gui.settings['craftingQueue'] > 0 then
    for k, v in pairs(gui.settings['craftingQueue']) do
      local item = table.remove(gui.settings['craftingQueue'])
      gui.writeSettings()
      if item ~= nil then
        server.bridge.craftItem(item)
        gui.log('Crafting one '..item['displayName'], server.selectDrive())
        break
      end
    end
  end
end --end checkCraftingqueue

function server.initializeMonitor()
  server.monitor.clear()
  server.monitor.setCursorPos(1,1)
  gui.initialize(server.monitor)
end --end initializeMonitor

function server.getEnergyInfo()
  return {['currentStorage'] = server.bridge.getEnergyStorage(), ['maxStorage'] = server.bridge.getMaxEnergyStorage(), ['usage'] = server.bridge.getEnergyUsage()}
end --end getEnergyInfo

function server.comparison(a, b)
  return a['amount'] > b['amount']
end --end comparison

function server.checkIfInTable(element, table)
  for i, j in pairs(table) do
    if element == j then
      return true
    end
  end
  return false
end --end checkIfInTable

function server.getItemStorageInfo()
  local items = server.getAllItemsInfo() -- got nil value for items
  if items == nil then
    gui.log('Encountered an error while reading data. (Was the AE network down?)', server.selectDrive())
    gui.updateLogPage()
    while items == nil do
      items = server.getAllItemsInfo()
      os.sleep(0)
    end
  end  
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
  return {['maxStorage'] = server.bridge.getTotalItemStorage(), ['currentStorage'] = server.bridge.getUsedItemStorage(), ['availableStorage'] = server.bridge.getAvailableItemStorage(), ['topFive'] = topFive}
end --end getItemStorage1

function server.getAllItemsInfo()
  return server.bridge.listItems()
end --end getAllItemsInfo

function server.getCPUInfo()
  return server.bridge.getCraftingCPUs()
end

function server.getCellsInfo()
  return server.bridge.listCells() -- Used to be bugged if a storage bus was connected to an inventory on the network, seems fine now.
  -- return {{bytesPerType = 8, cellType = "item", item = "ae2:item_storage_cell_1k", totalBytes = 1024}}
end

function server.getFluidsInfo()
  return {['maxStorage'] = server.bridge.getTotalFluidStorage(), ['currentStorage'] = server.bridge.getUsedFluidStorage(), ['availableStorage'] = server.bridge.getAvailableFluidStorage(), ['listFluid'] = server.bridge.listFluid()}
end

function server.getTimeInfo()
  return {['date'] = os.date(), ['clock'] = os.clock()}
end --end getTimeInfo

function server.getComputerInfo()
  return {['id'] = os.computerID(), ['label'] = os.computerLabel()}
end --end getComputerInfo

function server.gatherData()
  local data = {['time'] = server.getTimeInfo(), ['computer'] = server.getComputerInfo(), ['items'] = server.getItemStorageInfo(), ['energy'] = server.getEnergyInfo(), ['fluids'] = server.getFluidsInfo(), ['cells'] = server.getCellsInfo(), ['cpus'] = server.getCPUInfo(), ['craftables'] = server.bridge.listCraftableItems()}
  if data == nil then
    gui.log('Encountered an error while reading data. (Was the AE network down?)', server.selectDrive())
    gui.updateLogPage()
    while data == nil do
      data = {['time'] = server.getTimeInfo(), ['computer'] = server.getComputerInfo(), ['items'] = server.getItemStorageInfo(), ['energy'] = server.getEnergyInfo(), ['fluids'] = server.getFluidsInfo(), ['cells'] = server.getCellsInfo(), ['cpus'] = server.getCPUInfo(), ['craftables'] = server.bridge.listCraftableItems()}
      os.sleep(0)
    end
  end
  return data
end

function server.generateSnapshots() -- Run in Parallel
  while true do
    server.snapshot = server.gatherData()
    coroutine.yield()
    server.snapshotItems = server.getAllItemsInfo()
    coroutine.yield()
    if math.floor(os.epoch('local')/1000) % 5 == 0 then
      server.snapshot = server.gatherData()
      server.broadcastDataAvailable()
      coroutine.yield()
      server.checkDriveStorage()
      coroutine.yield()
    end
    server.checkCraftingQueue()
    coroutine.yield()
    os.sleep(0)
  end
end --end generateSnapshots

function server.eventHandler() -- Run in Parallel
  os.sleep(1)
  while true do
    local timer = os.startTimer(100)
    local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
    if event == 'timer' then
      timer = nil
    elseif event == 'modem_message' then
      server.checkMessages(event, arg1, arg2, arg3, arg4, arg5)
    elseif event == 'mouse_up' or event == 'monitor_touch' then
      gui.clickedButton(arg1, arg2, arg3, server.snapshot['craftables'])
    elseif evetn == 'mouse_wheel' then
      gui.mouseWheel(event, arg1, arg2, arg3)
    -- else
    --   os.queueEvent(event, arg1, arg2, arg3, arg4, arg5)
    end
  end
end --end eventHandler

function server.main() -- Run in Parallel
  server.snapshot = server.gatherData()
  server.snapshotItems = server.getAllItemsInfo()
  while true do
    gui.main(server.snapshot, server.snapshotItems)
    os.sleep(0)
  end
end --end main

function server.guiTime() -- Run in Parallel
  server.snapshot = server.gatherData()
  server.snapshotItems = server.getAllItemsInfo()
  while true do
    gui.main(server.snapshot, server.snapshotItems)
    gui.updateTime()
    os.sleep(1/60)
  end
end --end guiTime

function server.initialize()
  local _, y = term.getSize()
  server.findDrives()
  term.setCursorPos(1, y)
  server.write('Initializing...')
  if os.getComputerLabel() == nil then
    os.setComputerLabel('AE2_Server')
    server.write('Set computer\'s label to '..os.getComputerLabel())
  end
  local initial = {['computerInfo'] = server.getComputerInfo() , ['bridge'] = server.checkForBridge(), ['monitor'] = server.checkForMonitor(), ['modem'] = server.checkForWirelessModem()}
  for k, i in pairs(initial) do
    if i == false then
      server.write('There was an error in setting up a '..k)
      return false
    end
  end
  server.write('Computer ID: '..initial['computerInfo']['id'])
  server.write('Computer Label: '..initial['computerInfo']['label'])
  if not fs.exists('./AE2_Interface/clients') then
    local file = fs.open('./AE2_Interface/clients', 'w')
    file.write(textutils.serialize({server.getComputerInfo()}))
    file.close()
  end
  if not fs.exists('./AE2_Interface/server.keys') then -- Consider Implementing a Private/public key combination
    local info = server.getComputerInfo()
    info['key'] = os.clock()/7
    local file = fs.open('./AE2_Interface/server.keys', 'w')
    file.write(textutils.serialize(info))
    file.close()
  else
    local file = fs.open('./AE2_Interface/server.keys', 'r')
    local temp = textutils.unserialize(file.readAll())
    file.close()
    if not temp['id'] == initial['computerInfo']['id'] and not temp['label'] == initial['computerInfo']['label'] then
      local file = fs.open('./AE2_Interface/server.keys', 'w')
      file.write(textutils.serialize(server.getComputerInfo()))
      file.close()
    end
  end
  server.bridge = initial['bridge']
  server.monitor = initial['monitor']
  server.modem = initial['modem']
  server.initializeMonitor(monitor)
  server.initializeNetwork(modem)
  parallel.waitForAny(server.guiTime, server.generateSnapshots, server.eventHandler)-- , server.buttonHandler) --server.touchscreenHandler, server.main, 
end --end initialize

return server
