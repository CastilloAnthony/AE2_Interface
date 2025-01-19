--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--

local gui = require('gui')
local crypt = require('cryptography')

local server = {} -- Stores all of the functions for the server

server.bridge = nil
server.monitor = nil
server.modem = nil
server.snapshot = nil
server.snapshotItems = nil
server.currDrive = nil
server.clients = {}
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
    end
  end
end --end findDrives

function server.checkIfKeyInTable(table, key)
  for _, i in pairs(table) do
    if i == key then
      return true
    end
  end
  return false
end --end checkIfKeyInTable

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
        gui.log(peripheral.wrap(i).getMountPath()..' is full.', server.selectDrive())
      end
    end
  end
end --end checkDriveStorage

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
  server.modem.transmit(7, 0, info)
end --end broadcast

function server.broadcastDataAvailable()
  local info = {['message'] = 'There is a new snapshot available.', ['verify'] = server.getComputerInfo(), ['packet'] = {['type'] = 'newDataAvailable'}}
  server.modem.transmit(7, 0, info)
  gui.log('A new snapshot is available.', server.selectDrive())
end --end broadcastDataAvailable

function server.readClients()
  local file = fs.open('/AE2_Interface/keys/clients', 'r')
  server.clients = textutils.unserialize(file.readAll())
  file.close()
end --end readClients

function server.writeClients()
  local file = fs.open('/AE2_Interface/keys/clients', 'w')
  file.write(textutils.serialize(server.clients))
  file.close()
end --end writeClients

function server.checkMessages(event, side, channel, replyChannel, message, distance)
  if event == 'modem_message' then
    if channel == 14 then
      if message['verify'] ~= nil then
        if message['handshake'] == true then
          if message['packet'] == nil then
            if not fs.exists('/AE2_Interface/keys/parameters.tmp') then
              server.modem.transmit(14, 0, {['message'] = 'Parameters are still being computed.', ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['handshake'] = true, ['packet'] = {['result'] = false, ['parameters'] = false}})
            else
              server.readClients()
              for id, i in pairs(server.clients) do -- First search for already known client-key combos
                if id == message['verify']['id'] and (message['verify']['label'] == i['label']) then
                  if message['requestNew'] ~= nil then
                    if message['requestNew'] == true then
                      server.clients[id][privateKey] = nil
                      server.clients[id][publicKey] = nil
                      server.clients[id][sharedKey] = nil
                      break
                    end
                  else
                    if i['sharedKey'] ~= nil then
                      server.modem.transmit(14, 0, {['message'] = nil, ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['handshake'] = true, ['packet'] = {['result'] = true, ['parameters'] = false, ['encryptionTest'] = crypt.encrypt(i['sharedKey'], 'Valid')}})
                      return
                    end
                  end
                end
              end
              local file = fs.open('/AE2_Interface/keys/parameters.tmp', 'r')
              local params = textutils.unserialize(file.readAll())
              file.close()
              local privateKey, publicKey = crypt.generatePrivatePublicKeys(params['p'], params['g'], 100, 1000)
              server.clients[message['verify']['id']] = {['id'] = message['verify']['id'], ['label'] = message['verify']['label'], ['privateKey'] = privateKey, ['publicKey'] = publicKey, ['p'] = params['p']}
              server.writeClients()
              server.modem.transmit(14, 0, {['message'] = 'Parameters are available', ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['handshake'] = true, ['packet'] = {['result'] = true, ['parameters'] = true, ['p'] = params['p'], ['g'] = params['g'], ['publicKey'] = publicKey}})
              return
            end
          else
            server.readClients()
            for id, i in pairs(server.clients) do -- First search for already known client-key combos
              if id == message['verify']['id'] and message['verify']['label'] == i['label'] then
                if i['sharedKey'] == nil then
                  if message['packet']['publicKey'] ~= nil then
                    server.clients[id]['sharedKey'] = crypt.generateSharedKey(i['privateKey'], message['packet']['publicKey'], i['p'])
                    server.clients[id]['privateKey'] = nil
                    server.clients[id]['publicKey'] = nil
                    server.clients[id]['p'] = nil
                    server.writeClients()
                    server.modem.transmit(14, 0, {['message'] = nil, ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['handshake'] = true, ['packet'] = {['result'] = true, ['parameters'] = false, ['encryptionTest'] = crypt.encrypt(server.clients[id]['sharedKey'], 'Valid')}})
                  end
                end
              end
            end
          end
        end
      end
    elseif channel == 21 then
      if message['verify'] ~= nil and message['target'] ~= nil and message['packet'] ~= nil then
        if message['target']['id'] == os.getComputerID() and message['target']['label'] == os.getComputerLabel() then
          server.readClients()
          for _, i in pairs(server.clients) do
            if message['verify']['id'] == i['id'] then
              if message['verify']['label'] == i['label'] then
                local packet = textutils.unserialize(crypt.decrypt(i['sharedKey'], message['packet']))
                local file = fs.open('temp', 'w')
                file.write(textutils.serialize(packet))
                file.close()
                if packet['type'] == 'latestSnapshot' then
                  server.modem.transmit(28, 0, {['message'] = 'Enjoy!', ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['encryptionTest'] = crypt.encrypt(i['sharedKey'], 'Valid'), ['packet'] = crypt.encrypt(i['sharedKey'], textutils.serialize({['type'] = 'latestSnapshot', ['data'] = server.snapshot}, {allow_repetitions = true}))})
                  server.write('Sent snapshot packet to '..'ID:'..message['verify']['id']..' '..message['verify']['label'])
                elseif packet['type'] == 'allData' then
                  server.modem.transmit(28, 0, {['message'] = 'Enjoy!', ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['encryptionTest'] = crypt.encrypt(i['sharedKey'], 'Valid'), ['packet'] = crypt.encrypt(i['sharedKey'], textutils.serialize({['type'] = 'allData', ['data'] = server.snapshotItems}, {allow_repetitions = true}))})
                elseif packet['type'] == 'craft' then
                  if server.craftRequests[packet['timestamp']] ~= nil then
                    server.modem.transmit(28, 0, {['message'] = 'Acknowledged.', ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['encryptionTest'] = crypt.encrypt(i['sharedKey'], 'Valid'), ['packet'] = crypt.encrypt(i['sharedKey'], textutils.serialize({['type'] = 'craft', ['data'] = False, ['timestamp'] = packet['timestamp']}, {allow_repetitions = true}))})
                  else
                    server.modem.transmit(28, 0, {['message'] = 'Acknowledged.', ['verify'] = server.getComputerInfo(), ['target'] = message['verify'], ['encryptionTest'] = crypt.encrypt(i['sharedKey'], 'Valid'), ['packet'] = crypt.encrypt(i['sharedKey'], textutils.serialize({['type'] = 'craft', ['data'] = server.bridge.craftItem(packet['data']), ['timestamp'] = packet['timestamp']}, {allow_repetitions = true}))})
                    server.craftRequests[packet['timestamp']] = packet['data']
                    server.write('Crafting request from ID: '..message['verify']['id']..' '..message['verify']['label']..' for one '..packet['data']['displayName'])
                  end
                else
                  server.write('Unknown request from '..message['verify']['id']..' '..messagep['verify']['label'])
                end
              end
            end
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
end --end getCPUInfo

function server.getCellsInfo()
  return server.bridge.listCells() -- Used to be bugged if a storage bus was connected to an inventory on the network, seems fine now.
  -- return {{bytesPerType = 8, cellType = "item", item = "ae2:item_storage_cell_1k", totalBytes = 1024}}
end --end getCellsInfo

function server.getFluidsInfo()
  return {['maxStorage'] = server.bridge.getTotalFluidStorage(), ['currentStorage'] = server.bridge.getUsedFluidStorage(), ['availableStorage'] = server.bridge.getAvailableFluidStorage(), ['listFluid'] = server.bridge.listFluid()}
end -- end getFluidsInfo

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
      gui.log('Failed to generate snapshot, dumping to file.', server.selectDrive())
      local file = fs.open('snapshot.dump', 'w')
      file.write(textutils.serialize(data))
      file.close()
      data = {['time'] = server.getTimeInfo(), ['computer'] = server.getComputerInfo(), ['items'] = server.getItemStorageInfo(), ['energy'] = server.getEnergyInfo(), ['fluids'] = server.getFluidsInfo(), ['cells'] = server.getCellsInfo(), ['cpus'] = server.getCPUInfo(), ['craftables'] = server.bridge.listCraftableItems()}
      os.sleep(1)
    end
  end
  return data
end --end gatherData

function server.generateSnapshots() -- Run in Parallel
  while true do
    server.snapshot = server.gatherData()
    coroutine.yield()
    server.snapshotItems = {['time'] = server.getTimeInfo(), ['data'] = server.getAllItemsInfo()}
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
    os.sleep(1/60)
  end
end --end generateSnapshots

function server.eventHandler() -- Run in Parallel
  while server.snapshot == nil or server.snapshotItems == nil do
    os.sleep(1/60)
  end
  local timer = os.startTimer(0)
  while true do
    local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
    if event == 'timer' then
      server.broadcast()
      timer = os.startTimer(60*5)
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

function server.generateKeyParameters()
  while true do
    if fs.exists('/AE2_Interface/keys/parameters.tmp') then
      os.sleep(60*5) -- Generate new ones every Five Minutes
      local p, g = crypt.generateParameters(10000, 100000)
      local file = fs.open('/AE2_Interface/keys/parameters.tmp', 'w')
      file.write(textutils.serialize({['p'] = p, ['g'] = g}))
      file.close()
    else
      local p, g = crypt.generateParameters(1000, 10000)
      local file = fs.open('/AE2_Interface/keys/parameters.tmp', 'w')
      file.write(textutils.serialize({['p'] = p, ['g'] = g}))
      file.close()
    end
  end
end --end generateKeyParameters

function server.guiTime() -- Run in Parallel
  while server.snapshot == nil or server.snapshotItems == nil do
    os.sleep(1/60)
  end
  while true do
    gui.main(server.snapshot, server.snapshotItems['data'])
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
  if not fs.exists('/AE2_Interface/keys/clients') then
    local file = fs.open('/AE2_Interface/keys/clients', 'w')
    file.write(textutils.serialize({[os.getComputerID()] = server.getComputerInfo()}))
    file.close()
  end
  server.bridge = initial['bridge']
  server.monitor = initial['monitor']
  server.modem = initial['modem']
  server.initializeMonitor(monitor)
  server.initializeNetwork(modem)
  parallel.waitForAny(server.generateKeyParameters, server.guiTime, server.generateSnapshots, server.eventHandler)-- , server.buttonHandler) --server.touchscreenHandler, server.main, 
end --end initialize

return server