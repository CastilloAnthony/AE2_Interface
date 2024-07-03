
local gui = require('gui')

local remote = {}

remote.monitor = nil
remote.modem = nil
remote.data = nil
remote.allData = nil
remote.gettingData = false

function remote.write(text)
    if text ~= nil then
        --textutils.slowWrite(text)
        gui.log(text)
    end
    --term.scroll(1)
    local _, y = term.getCursorPos()
    term.setCursorPos(1, y)
end --end write

function remote.readData()
    local file = fs.open('data/'..fs.list('data')[1], 'r')
    local contents = file.readAll()
    file.close()
    return textutils.unserialize(contents)
end --end readData

function remote.checkForWirelessModem()
    for _, i in pairs(peripheral.getNames()) do
        if (peripheral.getType(i) == 'modem') then
            if (peripheral.call(i, 'isWireless')) then
                --remote.write('Wireless modem found!')
                return peripheral.wrap(i) 
            end
        end
    end
    --term.write('Could not find a wireless modem.')
    --remote.write('Could not find a wireless modem.')
    return false
end --end checkForWirelessModem

function remote.checkForMonitor()
  for _, i in pairs(peripheral.getNames()) do
    if peripheral.getType(i) == 'monitor' then
      remote.write('Monitor found!')
      return peripheral.wrap(i)
    end
  end
  remote.write('Could not find a monitor, using terminal.')
  return term
end --end checkForMonitor

function remote.initializeMonitor()
  remote.monitor.clear()
  remote.monitor.setCursorPos(1,1)
  if remote.monitor ~= term then
    remote.monitor.setTextScale(1)
  end
  gui.initialize(remote.monitor)
end --end initializeMonitor

function remote.performHandshake()
    -- packet = {['message'] = 'This is a message', ['verify'] = {['id'] = os.computerID(), ['label'] = os.computerLabel()}} --A standard packet transmission
    local event, side, channel, replyChannel, message, distance
    local timerID = os.startTimer(0.05)
    remote.modem.transmit(14, 0, {['handshake'] = true, ['verify'] = remote.getComputerInfo()})
    while true do
        event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            break
        elseif (event == 'timer') and (side == timerID) then
            return false
        end
    end
    if (event == 'modem_message') then
        if (channel == 7) then
            return remote.performHandshake()
        elseif (channel == 14) then
            if message['verify']['label'] == 'AE2_Server' then
                if (message['packet']['type'] == 'handshake') then
                    if message['packet']['success'] == true then
                        remote.write('Handshake with '..message['verify']['label'])
                        remote.write('Msg: '..message['message'])
                        gui.log('Handshake: '..message['verify']['label'])
                        gui.log('Msg: '..message['message'])
                        return true
                    end
                end
            end
        end
    end 
    return false
end

function remote.requestServerKeys()
    local even, side, channel, replyChannel, message, distance
    local timerID = os.startTimer(0.05)
    remote.modem.transmit(21, 0, {['message'] = 'keys', ['verify'] = remote.getComputerInfo()})
    while true do
        event, side, channel, replyChannel, message, distance = os.pullEvent()
        if (event == 'timer') and (side == timerID) then
            return false
        elseif event == 'modem_message' then
            if (channel == 28) then
                if message['packet']['type'] == 'keys' then
                    if (message['verify']['id'] == message['packet']['data']['id']) and (message['verify']['label'] == message['packet']['data']['label']) then
                        print('Keys recieved')
                        local file = fs.open('server.key', 'w')
                        file.write(textutils.serialize(message['packet']['data']))
                        file.close()
                        remote.write('Keys retrieved from: '..message['verify']['label'])
                        remote.write('Msg: '..message['message'])
                        gui.log('Got keys: '..message['packet']['data']['id']..' '..message['packet']['data']['label'])
                        gui.log('Msg: '..message['message'])
                        return true
                    end
                end
            end
        end
        return false
    end
end --end requestServerKeys

function remote.latestData() -- Retrieves the latest snapshot from the server
    while true do
        local timerID = os.startTimer(0.05)
        local event, side, channel, replyChannel, message, distance
        while true do
            remote.modem.transmit(21, 0, {['message'] = 'latestSnapshot', ['verify'] = remote.getComputerInfo()})
            event, side, channel, replyChannel, message, distance = os.pullEvent()
            if event == 'modem_message' then
                break
            elseif (event == 'timer') and (side == timerID) then
                return remote.latestData()
            end
        end
        if (event == 'modem_message') then
            if (channel == 28) then
                local file = fs.open('server.key', 'r')
                local serverKeys = textutils.unserialize(file.readAll())
                file.close()
                if (message['verify']['id'] == serverKeys['id']) and (message['verify']['label'] == serverKeys['label']) then
                    if message['packet']['type'] == 'latestSnapshot' then
                        return textutils.unserialize(message['packet']['data'])
                    end
                end
            end
        end
    end
end --end retrieveData

function remote.requestAllData()
    while true do
        local timerID = os.startTimer(0.05)
        local even, side, channel, replyChannel, message, distance
        while true do
            remote.modem.transmit(21, 0, {['message'] = 'allData', ['verify'] = remote.getComputerInfo()})
            event, side, channel, replyChannel, message, distance = os.pullEvent()
            if event == 'modem_message' then
                break
            elseif (event == 'timer') and (side == timerID) then
                return remote.requestAllData()
            end
        end
        if (event == 'modem_message') then
            if (channel == 28) then
                local file = fs.open('server.key', 'r')
                local serverKeys = textutils.unserialize(file.readAll())
                file.close()
                if (message['verify']['id'] == serverKeys['id']) and (message['verify']['label'] == serverKeys['label']) then
                    if message['packet']['type'] == 'allData' then
                        return message['packet']['data']
                    end
                end
            end
        end
    end
end --end requestAllData

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

function remote.getPackets()
    remote.gettingData = true
    gui.log('Retrieving data...')
    remote.data = remote.latestData()
    remote.allData = remote.requestAllData()
    gui.log('Packets recieved!')
    remote.gettingData = false
end

function remote.eventHandler()
    --local timerID = os.startTimer(0.5)
    --remote.getPackets()
    --gui.main(remote.data, remote.allData)
    --local event, arg1, arg2, arg3, arg4, arg5
    while true do
        local event, arg1, arg2, arg3, arg4, arg5 = os.pullEvent()
        if event == 'mouse_up' or event == 'monitor_touch' then
            gui.clickedButton(arg1, arg2, arg3)
            gui.main(remote.data, remote.allData)--, remote.data['time'], remote.data['items'], remote.data['energy'], remote.allData, remote.data['fluids'], remote.data['cells'], remote.data['cpus'], remote.data['computer'])
        elseif event == 'modem_message' then
            if arg2 == 7 then
                local file = fs.open('server.key', 'r')
                local serverKeys = textutils.unserialize(file.readAll())
                file.close()
                if arg4['verify']['id'] == serverKeys['id'] and arg4['verify']['label'] == serverKeys['label'] then
                    if arg4['packet']['type'] == 'newDataAvailable' then
                        remote.getPackets()
                        gui.main(remote.data, remote.allData)--, remote.data['time'], remote.data['items'], remote.data['energy'], remote.allData, remote.data['fluids'], remote.data['cells'], remote.data['cpus'], remote.data['computer'])
                        --timerID = os.startTimer(16)
                    end
                end
            end
        --elseif event == 'timer' and arg1 == timerID then
            --timerID = os.startTimer(0.5)
            --gui.main(remote.data, remote.allData)
        end
    end
end --end main

function remote.guiTime()
    --remote.getPackets()
    while true do
        gui.updateTime()
        os.sleep(0.5)
    end
end

function remote.initialize()
    local _, y = term.getSize()
    term.setCursorPos(1, y)
    term.clear()
    remote.write('Initializing...')
    textutils.slowWrite('Initializing...')
    if os.computerLabel() == nil then
        os.setComputerLabel('RemoteDevice')
    end
    remote.write('Computer ID: '..remote.getComputerInfo()['id'])
    term.scroll(1)
    textutils.slowWrite('Computer ID: '..remote.getComputerInfo()['id'])
    remote.write('Computer Name: '..remote.getComputerInfo()['label'])
    term.scroll(1)
    textutils.slowWrite('Computer Name: '..remote.getComputerInfo()['label'])
    remote.modem = remote.checkForWirelessModem()
    if remote.modem == false then
        gui.log('Could not find a Wireless modem.')
        term.scroll(1)
        textutils.slowWrite('Could not find a Wireless modem.')
        return false
    else
        gui.log('Wireless modem found!')
        term.scroll(1)
        textutils.slowWrite('Wireless modem found!')
    end
    remote.monitor = remote.checkForMonitor()
    remote.initializeMonitor()
    remote.initializeNetwork()
    remote.write('Attempting handshake...')
    term.scroll(1)
    textutils.slowWrite('Attempting handshake...')
    local noHandshake = true
    while noHandshake do
        if remote.performHandshake() == true then
            noHandshake = false
        end
    end
    local noKeys = true
    while noKeys do 
        if remote.requestServerKeys() == true then
            noKeys = false
        end
    end
    --gui.initialize(term)
    remote.getPackets()
    gui.main(remote.data, remote.allData)
    parallel.waitForAny(remote.guiTime, remote.eventHandler)--, remote.mainLoop)
end --end initialize

return remote
