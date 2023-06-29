
local gui = require('gui')

local remote = {}

function remote.scrollTerminal()
    term.scroll(1)
    local _, y = term.getCursorPos()
    term.setCursorPos(1, y)
  end --end scrollTerminal

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
                term.write('Wireless modem found!')
                remote.scrollTerminal()
                return peripheral.wrap(i) 
            end
        end
    end
    term.write('Could not find a wireless modem.')
    return false
end --end checkForWirelessModem

function remote.performHandshake(modem)
    -- packet = {['message'] = 'This is a message', ['verify'] = {['id'] = os.computerID(), ['label'] = os.computerLabel()}} --A standard packet transmission
    term.write('Attempting handshake...')
    remote.scrollTerminal()
    local timerID = os.startTimer(0.2)
    modem.transmit(14, 0, {['handshake'] = true, ['verify'] = remote.getComputerInfo()})
    local event, side, channel, replyChannel, message, distance
    while true do
        event, side, channel, replyChannel, message, distance = os.pullEvent()
        if event == 'modem_message' then
            break
        elseif (event == 'timer') and (side == timerID) then
            --term.write('Handshake timed out.')
            --remote.scrollTerminal()
            return false
        end
    end
    if (event == 'modem_message') then
        if (channel == 7) then
            return remote.performHandshake(modem)
        elseif (channel == 14) then
            local file = fs.open('server.key', 'r')
            local serverKeys = textutils.unserialize(file.readAll())
            file.close()
            if (message['verify']['id'] == serverKeys['id']) and (message['verify']['label'] == serverKeys['label']) then
                if (message['success'] == true) then
                    write('Message from server: '..message['message'])
                    remote.scrollTerminal()
                    return true
                else
                    write('Unsuccessful')
                    remote.scrollTerminal()
                end
            else
                write('Nonauthorized Server')
                remote.scrollTerminal()
            end
        else
            write('Wrong channel'..channel)
            remote.scrollTerminal()
        end
    end 
    return false
end

function remote.requestData(modem) -- Retrieves the latest snapshot from the server
    local retrived = false
    while (not retrived) do
        local timerID = os.startTimer(0.2)
        local event, side, channel, replyChannel, message, distance
        while true do
            modem.transmit(21, 0, {['message'] = 'latestSnapshot', ['verify'] = remote.getComputerInfo()})
            event, side, channel, replyChannel, message, distance = os.pullEvent()
            if event == 'modem_message' then
                break
            elseif (event == 'timer') and (side == timerID) then
                return remote.requestData(modem)
            end
        end
        if (event == 'modem_message') then
            if (channel == 28) then
                local file = fs.open('server.key', 'r')
                local serverKeys = textutils.unserialize(file.readAll())
                file.close()
                if (message['verify']['id'] == serverKeys['id']) and (message['verify']['label'] == serverKeys['label']) then
                    --write('Message from server: '..message['message'])
                    --remote.scrollTerminal()
                    return textutils.unserialize(message['data'])
                end
            else
                --write('Incorrect channel: '..channel)
            end
        end
    end
end --end retrieveData

function remote.setupServerKey()
end --end setupServerKey

function remote.initializeNetwork(modem)
    --['ports'] = {['broadcast'] = 7, ['handshake'] = 14, ['requests'] = 21, ['dataTransfer'] = 28}
    if not modem.isOpen(7) then
        modem.open(7)
      end 
    if not modem.isOpen(14) then
        modem.open(14)
    end
    if not modem.isOpen(28) then
        modem.open(28)
    end
end --end initializeNetwork

function remote.getComputerInfo()
    return {['id'] = os.computerID(), ['label'] = os.computerLabel()}
end

function remote.main()
    local modem = remote.checkForWirelessModem()
    if modem == false then
        return false
    end
    remote.initializeNetwork(modem)
    if os.computerLabel() == nil then
        os.setComputerLabel('RemoteDevice')
    end
    write(textutils.serialize(remote.getComputerInfo()))
    remote.scrollTerminal()
    local noHandshake = true
    while (noHandshake) do
        if (remote.performHandshake(modem) == true) then
            noHandshake = false
        end
    end
    while true do
        --write('Polling Server...')
        --remote.scrollTerminal()
        local data = remote.requestData(modem)
        gui.main(term, data['time'], data['items'], data['energy'])
        os.sleep(60)
    end
    --[[
    data = remote.requestData(modem)
    for i=1, #data do
        term.write(data[i])
        remote.scrollTerminal()
    end
    ]]
end --end main

return remote