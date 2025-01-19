--[[
  Developed by Anthony Castillo 6/27/2023
  (WIP)  
]]--

local gui = require('gui')
local crypt = require('cryptography')

local remote = {}

remote.monitor = nil
remote.modem = nil
remote.data = nil
remote.allData = nil
remote.gettingData = false
remote.currDrive = nil
remote.keys = {}
remote.storages = {}
remote.fullStorages = {}
remote.craftRequests = {}

function remote.write(text)
    if text ~= nil then
        --textutils.slowWrite(text)
        gui.log(text, remote.selectDrive())
    end
    --term.scroll(1)
    local _, y = term.getCursorPos()
    term.setCursorPos(1, y)
end --end write

function remote.checkIfKeyInTable(table, key)
    for _, i in pairs(table) do
        if i == key then
            return true
        end
    end
    return false
end --end checkIfKeyInTable

function remote.findDrives()
    for _, i in pairs(peripheral.getNames()) do
        if string.find(peripheral.getType(i), 'drive') then
            remote.storages[#remote.storages] = i
            remote.fullStorages[i] = nil
        end
    end
end --end findDrives

function remote.selectDrive()
    if remote.currDrive ~= nil then
        if peripheral.wrap(remote.currDrive).isDiskPresent() then
            if fs.getFreeSpace(peripheral.wrap(remote.currDrive).getMountPath()) > 500 then
                return peripheral.wrap(remote.currDrive).getMountPath()..'/'
            end
        end
    end
    for _, i in pairs(remote.storages) do
        if peripheral.wrap(i).isDiskPresent() then
            if fs.getFreeSpace(peripheral.wrap(i).getMountPath()) > 500 then
                if remote.fullStorages[i] ~= nil then
                    remote.fullStorages[i] = nil
                end
                remote.currDrive = i
                gui.log('Logs: '..remote.currDrive)
                return peripheral.wrap(i).getMountPath()..'/'
            else
                if remote.checkIfKeyInTable(remote.fullStorages, i) == flase then
                    table.insert(remote.fullStorages, i)
                end
            end
        end
    end
    return './'
end --end selectDrive

function remote.checkDriveStorage()
    for _, i in pairs(remote.fullStorages) do
        if peripheral.wrap(i).isDiskPresent() then
            if fs.getFreeSpace(peripheral.wrap(i).getMountPath()) > 500 then
                remote.fullStorages[i] = nil
            else
                gui.log(peripheral.wrap(i).getMountPath()..' is full.', remote.selectDrive())
            end
        end
    end
end --end checkDriveStorage

function remote.checkForWirelessModem()
    for _, i in pairs(peripheral.getNames()) do
        if (peripheral.getType(i) == 'modem') then
            if (peripheral.call(i, 'isWireless')) then
                return peripheral.wrap(i) 
            end
        end
    end
    return false
end --end checkForWirelessModem

function remote.checkForMonitor()
    for _, i in pairs(peripheral.getNames()) do
        if peripheral.getType(i) == 'monitor' then
            remote.write('Monitor found!')
            width, height = peripheral.wrap(i).getSize()
            return window.create(peripheral.wrap(i), 1, 1, width, height)
        end
    end
    remote.write('No monitor, defaulting to the terminal.')
    width, height = term.current().getSize()
    return window.create(term.current(), 1, 1, width, height)
end --end checkForMonitor

function remote.initializeMonitor()
    remote.monitor.clear()
    remote.monitor.setCursorPos(1,1)
    gui.initialize(remote.monitor)
end --end initializeMonitor

function remote.performHandshake()
    -- packet = {['message'] = 'This is a message', ['verify'] = {['id'] = os.computerID(), ['label'] = os.computerLabel()}, ['target'] = {['id'] = 7, ['label'] = AE2_Server}, ['packet'] = {['data'] = 'Some data.'}} --A standard packet transmission
    remote.readKeys()
    local first, second = nil, nil
    local event, side, channel, replyChannel, message, distance
    local timer = os.startTimer(60)
    while true do
        event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            if message['verify'] ~= nil then
                if channel == 7 then
                    if first ~= true then
                        if string.find(string.lower(message['verify']['label']), 'ae') then
                            if message['ports'] ~= nil then
                                remote.keys['id'] = message['verify']['id']
                                remote.keys['label'] = message['verify']['label'] 
                                remote.modem.transmit(14, 0, {['message'] = 'Hello, can I have access?', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, ['handshake'] = true, })
                                first = true
                            elseif message['packet']['type'] ~= nil then
                                if message['packet']['type'] == 'newDataAvailable' then
                                    remote.keys['id'] = message['verify']['id']
                                    remote.keys['label'] = message['verify']['label'] 
                                    remote.modem.transmit(14, 0, {['message'] = 'Hello, can I have access?', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, ['handshake'] = true, })
                                    first = true
                                end
                            end
                        end
                    end
                elseif channel == 14 then
                    if second ~= true then
                        if message['verify']['label'] == remote.keys['label'] and message['verify']['id'] == remote.keys['id'] then
                            if message['packet']['parameters'] == true then
                                local private, public = crypt.generatePrivatePublicKeys(message['packet']['p'], message['packet']['g'], 1000, 10000)
                                local shared = crypt.generateSharedKey(private, message['packet']['publicKey'], message['packet']['p'])
                                remote.keys['sharedKey'] = shared
                                remote.modem.transmit(14, 0, {['message'] = 'Sending public key.', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, ['handshake'] = true, ['packet'] = {['publicKey'] = public}})
                                second = true
                            else
                                if message['packet']['encryptionTest'] ~= nil then
                                    if remote.keys['sharedKey'] ~= nil then
                                        if crypt.decrypt(remote.keys['sharedKey'], message['packet']['encryptionTest']) == 'Valid' then
                                            return
                                        else
                                            remote.modem.transmit(14, 0, {['message'] = 'Sending public key.', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, ['handshake'] = true, ['requestNew'] = true})
                                        end
                                    end
                                end
                            end
                        end
                    elseif second == true then
                        if message['verify']['label'] == remote.keys['label'] and message['verify']['id'] == remote.keys['id'] then
                            if message['packet']['encryptionTest'] ~= nil then
                                if crypt.decrypt(remote.keys['sharedKey'], message['packet']['encryptionTest']) == 'Valid' then
                                    remote.writeKeys()
                                    return
                                else
                                    second = false
                                    remote.keys['sharedKey'] = nil
                                    remote.modem.transmit(14, 0, {['message'] = 'Sending public key.', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, ['handshake'] = true, ['requestNew'] = true})
                                end
                            end
                        end
                    end
                end
            end
        elseif event == 'timer' then
            first, second = nil, nil
            timer = os.startTimer(60)
        end
    end
end --end performHandshake

function remote.initializeNetwork()
    --['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}
    if not remote.modem.isOpen(7) then
        remote.modem.open(7)
      end 
    if not remote.modem.isOpen(14) then
        remote.modem.open(14)
    end
    if not remote.modem.isOpen(28) then
        remote.modem.open(28)
    end
end --end initializeNetwork

function remote.getComputerInfo()
    return {['id'] = os.computerID(), ['label'] = os.computerLabel()}
end --end getComputerInfo

function remote.readKeys()
    if fs.exists('/AE2_Interface/keys/server.key') then
        local file = fs.open('/AE2_Interface/keys/server.key', 'r')
        remote.keys = textutils.unserialize(file.readAll())
        file.close()
    end
end --end readKeys

function remote.writeKeys()
    local file = fs.open('/AE2_Interface/keys/server.key', 'w')
    file.write(textutils.serialize(remote.keys))
    file.close()
end --end writeKeys

function remote.eventHandler()
    while true do
        gui.readSettings()
        if #gui.settings['craftingQueue'] > 0 then -- Crafting Queue checking one item at a time
            local item = table.remove(gui.settings['craftingQueue'])
            gui.writeSettings()
            local timestamp = os.clock()
            remote.craftRequests[timestamp] = item
            remote.modem.transmit(21, 0, {['message'] = 'Hello', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, ['packet'] = crypt.encrypt(remote.keys['sharedKey'], textutils.serialize({['type'] = 'craft', ['data'] = item, ['timestamp'] = timestamp}))})
        elseif #remote.craftRequests > 0 then
            for k, v in pairs(remote.craftRequests) do
                remote.modem.transmit(21, 0, {['message'] = 'Hello', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, ['packet'] = crypt.encrypt(remote.keys['sharedKey'], textutils.serialize({['type'] = 'craft', ['data'] = v, ['timestamp'] = k}))})
            end
        end
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        if event == 'mouse_up' or event == 'monitor_touch' then
            if remote.data ~= nil then
                gui.clickedButton(arg1, arg2, arg3, remote.data['craftables'])
            end
        elseif event == 'mouse_wheel' then
            if remote.data ~= nil then
                gui.mouseWheel(event, arg1, arg2, arg3)
            end
        elseif event == 'modem_message' then -- event, side, channel, replyChannel, message, distance
            remote.readKeys()
            if arg4['verify'] ~= nil then
                if arg4['verify']['id'] == remote.keys['id'] and arg4['verify']['label'] == remote.keys['label'] then
                    if arg2 == 7 then
                        if arg4['packet'] ~= nil then
                            if arg4['packet']['type'] == 'newDataAvailable' then
                                remote.modem.transmit(21, 0, {
                                    ['message'] = 'Hello', 
                                    ['verify'] = remote.getComputerInfo(), 
                                    ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, 
                                    ['packet'] = crypt.encrypt(remote.keys['sharedKey'], textutils.serialize({['type'] = 'latestSnapshot'}))
                                })
                                remote.modem.transmit(21, 0, {
                                    ['message'] = 'Hello', 
                                    ['verify'] = remote.getComputerInfo(), 
                                    ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}, 
                                    ['packet'] = crypt.encrypt(remote.keys['sharedKey'], textutils.serialize({['type'] = 'allData'}))
                                })
                            end
                        end
                    elseif arg2 == 28 then
                        if arg4['target'] ~= nil and arg4['encryptionTest'] ~= nil then
                            if arg4['target']['id'] == os.getComputerID() and arg4['target']['label'] == os.getComputerLabel() then
                                if crypt.decrypt(remote.keys['sharedKey'], arg4['encryptionTest']) == 'Valid' then
                                    local packet = textutils.unserialize(crypt.decrypt(remote.keys['sharedKey'], arg4['packet']))
                                    if packet['type'] == 'craft' then
                                        if arg4['message'] == 'Acknowledged.' then
                                            if remote.craftRequests[packet['timestamp']] ~= nil then
                                                gui.log('Sent crafting request for one '..remote.craftRequests[packet['timestamp']]['displayName'], remote.selectDrive())
                                                table.remove(remote.craftRequests, packet['timestamp'])
                                            end
                                        end
                                    elseif packet['type'] == 'latestSnapshot' then
                                        if remote.data == nil then
                                            remote.data = packet['data']
                                            gui.log('Snapshot Updated!', remote.selectDrive())
                                        elseif remote.data['time']['clock'] ~= packet['data']['time']['clock'] then
                                            remote.data = packet['data']
                                            gui.log('Snapshot Updated!', remote.selectDrive())
                                        end
                                    elseif packet['type'] == 'allData' then
                                        if remote.allData == nil then
                                            remote.allData = packet['data']
                                        elseif remote.allData['time']['clock'] ~= packet['data']['time']['clock'] then
                                            remote.allData = packet['data']
                                        end
                                    end
                                else
                                    remote.performHandshake()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end --end eventHandler

function remote.guiTime()
    --remote.getPackets()
    while remote.data == nil or remote.allData == nil do
        os.sleep(1/60)
    end
    while true do
        gui.updateTime()
        gui.main(remote.data, remote.allData['data'])
        os.sleep(1/60)
    end
end --end guiTime

function remote.initialize()
    remote.findDrives()
    local _, y = term.getSize()
    term.setCursorPos(1, y)
    term.clear()
    remote.write('Initializing...')
    textutils.slowWrite('Initializing...')
    if os.computerLabel() == nil then
        os.setComputerLabel('RemoteDevice')
    end
    term.scroll(1)
    remote.write('Computer ID: '..remote.getComputerInfo()['id'])
    textutils.slowWrite('Computer ID: '..remote.getComputerInfo()['id'])
    term.scroll(1)
    remote.write('Computer Name: '..remote.getComputerInfo()['label'])
    textutils.slowWrite('Computer Name: '..remote.getComputerInfo()['label'])
    remote.modem = remote.checkForWirelessModem()
    if remote.modem == false then
        term.scroll(1)
        remote.write('Could not find a Wireless modem.')
        textutils.slowWrite('Could not find a Wireless modem.')
        return false
    else
        term.scroll(1)
        remote.write('Wireless modem found!')
        textutils.slowWrite('Wireless modem found!')
    end
    remote.initializeNetwork()
    term.scroll(1)
    remote.write('Attempting handshake...')
    textutils.slowWrite('Attempting handshake...')
    remote.performHandshake()
    remote.monitor = remote.checkForMonitor()
    remote.initializeMonitor()
    remote.modem.transmit(21, 0, {['message'] = 'latestSnapshot', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}})
    remote.modem.transmit(21, 0, {['message'] = 'allData', ['verify'] = remote.getComputerInfo(), ['target'] = {['id'] = remote.keys['id'], ['label'] = remote.keys['label']}})
    parallel.waitForAny(remote.eventHandler, remote.guiTime)--, remote.checkCraftingQueue)--, remote.mainLoop)
end --end initialize

return remote