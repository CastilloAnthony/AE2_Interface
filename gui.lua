
local gui = {}

gui.totalPages = 4
--gui.currentPage = 
gui.settings = nil
gui.width = nil
gui.height = 100
gui.widthFactor = 7/10
gui.monitor = nil
gui.logList = {}
gui.logCount = 0
gui.userSearch = ''
gui.userSearchTable = {}

function gui.initialize(monitor)
    gui.monitor = monitor
    gui.monitor.clear()
    gui.monitor.setCursorPos(1,1)
    gui.width, gui.height =  gui.monitor.getSize()
end --end initialize

function gui.write(string)
    if string == nil then
        return
    end
    gui.monitor.setCursorPos(1, gui.height)
    gui.monitor.write(string)
end --end write

function gui.log(string)
    local logging = {['order'] = gui.logCount+1, ['time'] = os.date('%T'), ['message'] = string}
    table.insert(gui.logList, logging)
    local file = fs.open('logs/'..os.date('%F'), 'a')
    file.write(logging['time']..' '..logging['message']..'\n')
    file.close()
    gui.logCount = gui.logCount + 1
    while #gui.logList > gui.height-5 do
        local oldestIndex = nil
        local oldest = nil
        for i, j in pairs(gui.logList) do
            if oldest == nil then
                oldestIndex = i
                oldest = j['time']
            elseif j['time'] < oldest then
                oldestIndex = i
                oldest = j['time']
            end
        end
        table.remove(gui.logList, oldestIndex)
    end
    while #fs.list('logs') > 7 do
        server.write('Deleting log: logs/'..fs.list('logs')[1])
        fs.delete('logs/'..fs.list('logs')[1])
    end
end

function gui.sortLogElements(a, b)
    return tonumber(a['order']) > tonumber(b['order'])
end

function gui.sortUserSearch(a, b)
    return tonumber(a['amount']) > tonumber(b['amount'])
end

function gui.populateTable(allData)
    if gui.userSearch ~= gui.settings['userSearch'] then
        if gui.userSearch == '' then
            gui.userSearch = gui.settings['userSearch']
        else
            gui.settings['userSearch'] = gui.userSearch
            gui.writeSettings()
        end
        if gui.userSearchTable ~= nil then
            for i=1, #gui.userSearchTable do
                table.remove(gui.userSearchTable)
            end
        end
        if gui.userSearch ~= nil then
            for _, i in pairs(allData) do
                if string.find(string.lower(i['displayName']), gui.userSearch) ~= nil then
                    if not gui.checkIfInTable(gui.userSearchTable, i) then
                        table.insert(gui.userSearchTable, i)
                    end
                end
            end
            table.sort(gui.userSearchTable, gui.sortUserSearch)
        end
    end
end

function gui.checkIfInTable(table, element)
    for _, i in pairs(table) do
        if element['displayName'] == i['displayName'] then
            return true
        end
    end
    return false
end --end checkIfInTable

function gui.main(timeInfo, itemsInfo, energyInfo, allData)
    gui.readSettings()
    --gui.initialize(gui.monitor)
    if gui.settings['currentPage'] == 1 then
        gui.page1(timeInfo, itemsInfo, energyInfo)
    elseif gui.settings['currentPage'] == 2 then
        gui.page2(timeInfo, itemsInfo, allData)
    elseif gui.settings['currentPage'] == 3 then
        gui.page3(timeInfo, itemsInfo, allData)
    elseif gui.settings['currentPage'] == 4 then
        gui.page4(timeInfo)
    end
end --end main()

function gui.readSettings()
    if not fs.exists('settings') then
        gui.writeSettings('default')
    end
    local file = fs.open('settings', 'r')
    gui.settings = textutils.unserialize(file.readAll())
    file.close()
end --end readSettings

function gui.writeSettings(settings)
    if settings == 'default' then
        gui.settings = {['currentPage'] = 1, ['userSearch'] = gui.userSearch, ['preferredItems'] = {}}
    end
    local file = fs.open('settings', 'w')
    file.write(textutils.serialize(gui.settings))
    file.close()   
end

function gui.nextPage(forward) -- true/false forwards/backwards
    gui.readSettings()
    if forward ~= nil then
        if forward == true then
            if gui.settings['currentPage'] == gui.totalPages then
                gui.settings['currentPage'] = 1
            else
                gui.settings['currentPage'] = gui.settings['currentPage'] + 1
            end
        elseif forward == false then
            if gui.settings['currentPage'] == 1 then
                gui.settings['currentPage'] = gui.totalPages
            else
                gui.settings['currentPage'] = gui.settings['currentPage'] - 1
            end
        end
    end
    gui.writeSettings()
end

function gui.clickedButton(button, x, y)
    if button == 1 or peripheral.isPresent(tostring(button)) then
        if y == gui.height-1 then
            if x>=gui.width-6 and x<=gui.width-2 then --Next
                gui.nextPage(true)
                return true
            elseif x>=2 and x<=6 then --Prev
                gui.nextPage(false)
                return true
            end
        elseif y == 3 then
            if gui.settings['currentPage'] == 2 then
                if x>=2 and x<=gui.width-1 then
                    gui.monitor.setBackgroundColor(colors.lightGray)
                    gui.monitor.setCursorPos(2,3)
                    for i=2, gui.width-1 do
                        gui.monitor.write(' ')
                    end
                    gui.monitor.setCursorPos(2,3)
                    gui.userSearch = string.lower(read())
                    gui.log('Usr Inpt: '..gui.userSearch)
                    --gui.userSearchTable = {}
                end
            end
        end
    end
    return false
end

function gui.changeSettings(currentPage, preferredItems) --Not used
    if currentPage == nil and preferredItems == nil then
        return
    end
    if not fs.exists('settings') then
        gui.writeSettings('default')
    end
    local file = fs.open('settings', 'r')
    local settings = textutils.unserialize(file.readAll())
    file.close()
    if currentPage ~= nil then
        settings['currentPage'] = currentPage
    end
    if preferredItems ~= nil then
        settings['preferredItems'] = preferredItems
    end
    gui.writeSettings(settings)
end

function gui.resizeString(string)
    return string.sub(string, 1, gui.width*gui.widthFactor-3)
end

function gui.drawHeader(timeInfo)
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setTextColor(colors.white)
    for i=1, gui.height do
        for j=1, gui.width do
            gui.monitor.setCursorPos(j,i)
            gui.monitor.write(' ')
        end
    end
    gui.monitor.setCursorPos(1,1)
    gui.monitor.write(timeInfo[1])
    gui.monitor.setCursorPos(2,2)
end

function gui.drawButtons()
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setBackgroundColor(colors.lightGray)
    gui.monitor.setCursorPos(2, gui.height-1)
    gui.monitor.write('<PREV')
    gui.monitor.setCursorPos(gui.width-5-1, gui.height-1)
    gui.monitor.write('NEXT>')
    gui.monitor.setCursorPos(1, gui.height)
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setCursorPos(gui.width/2-2, gui.height)
    gui.monitor.write('Page '..gui.settings['currentPage'])
    gui.monitor.setCursorPos(1, gui.height)
end

function gui.page1(timeInfo, itemsInfo, energyInfo)
    gui.drawHeader(timeInfo)

    gui.monitor.setTextColor(colors.orange)
    gui.monitor.write('Power: ')
    gui.monitor.setTextColor(colors.pink)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,2)
    gui.monitor.write((math.floor((energyInfo['currentStorage']/energyInfo['maxStorage'])*1000)/10)..'%')
    gui.monitor.setCursorPos(2,3)
    gui.monitor.setBackgroundColor(colors.red)
    for i=1, (energyInfo['currentStorage']/energyInfo['maxStorage'])*gui.width-1 do
        gui.monitor.write(' ')
    end
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setTextColor(colors.orange)
    gui.monitor.setCursorPos(2,4)
    gui.monitor.write('Power Usage: ')
    gui.monitor.setTextColor(colors.pink)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,4)
    gui.monitor.write((math.floor(energyInfo['usage']*2.5*10)/10)..'RF/t')
    gui.monitor.setCursorPos(2,6)
    gui.monitor.setTextColor(colors.lightBlue)
    gui.monitor.write('Items: ')--..(math.floor((itemsInfo['currentStorage']/itemsInfo['maxStorage'])*1000)/10)..'%')
    gui.monitor.setTextColor(colors.cyan)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,6)
    gui.monitor.write((math.floor(itemsInfo['currentStorage']/itemsInfo['maxStorage']*1000)/10)..'%')
    gui.monitor.setCursorPos(2,7)
    gui.monitor.setBackgroundColor(colors.blue)
    for i=1, (itemsInfo['currentStorage']/itemsInfo['maxStorage'])*gui.width-1 do
        gui.monitor.write(' ')
    end
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setTextColor(colors.lightBlue)
    gui.monitor.setCursorPos(2,8)
    gui.monitor.write('Max Storage: ')
    gui.monitor.setTextColor(colors.cyan)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,8)
    gui.monitor.write(''..itemsInfo['maxStorage'])
    gui.monitor.setTextColor(colors.lightBlue)
    gui.monitor.setCursorPos(2,9)
    gui.monitor.write('Stored Items: ')
    gui.monitor.setTextColor(colors.cyan)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,9)
    gui.monitor.write(''..itemsInfo['currentStorage'])
    gui.monitor.setTextColor(colors.lightBlue)
    gui.monitor.setCursorPos(2,10)
    gui.monitor.write('Free Storage: ')
    gui.monitor.setTextColor(colors.cyan)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,10)
    gui.monitor.write(''..itemsInfo['availableStorage'])
    gui.monitor.setCursorPos(2,12)
    gui.monitor.setTextColor(colors.yellow)
    gui.monitor.write('Top Five Stored: ')
    for i, j in pairs(itemsInfo['topFive']) do
        gui.monitor.setTextColor(colors.green)
        gui.monitor.setCursorPos(2, 12+i)
        gui.monitor.write(gui.resizeString(j['displayName']))
        gui.monitor.setTextColor(colors.brown)
        gui.monitor.setCursorPos(gui.width*gui.widthFactor, 12+i)
        gui.monitor.write(''..j['amount'])
    end

    gui.drawButtons()
end --end main

function gui.page2(timeInfo, itemsInfo, allData)
    gui.drawHeader(timeInfo)
    gui.monitor.setBackgroundColor(colors.lightGray)
    gui.monitor.setCursorPos(2, 3)
    for i=2, gui.width-1 do
        gui.monitor.write(' ')
    end
    gui.monitor.setCursorPos(2, 3)
    gui.monitor.write('Search...')
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setCursorPos(2, 5)
    gui.populateTable(allData)
    if gui.userSearchTable ~= {} then
        for i = 1, gui.height-8 do
            if i > #gui.userSearchTable then
                break
            end
            gui.monitor.setTextColor(colors.green)
            gui.monitor.setCursorPos(2, i+4)
            gui.monitor.write(gui.resizeString(gui.userSearchTable[i]['displayName']))
            gui.monitor.setTextColor(colors.brown)
            gui.monitor.setCursorPos(gui.width*gui.widthFactor, i+4)
            gui.monitor.write(''..gui.userSearchTable[i]['amount'])
        end
    end
    gui.drawButtons()
end

function gui.page3(timeInfo, itemsInfo, allData)
    gui.drawHeader(timeInfo)

    --gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setTextColor(colors.yellow)
    gui.monitor.setCursorPos(2, 3)
    gui.monitor.write('At a Glance:') --Watch List
    for i=4, gui.height-3 do
        local selection = math.random(1,#allData)
        gui.monitor.setTextColor(colors.green)
        gui.monitor.setCursorPos(2,i)
        if #allData == 0 then
            gui.log('Error in large packet, size is 0.')
        end
        if type(allData[selection]) == 'table' then
            --gui.monitor.write(gui.resizeString(allData[i-3]['displayName']))
            gui.monitor.write(gui.resizeString(allData[selection]['displayName']))
            gui.monitor.setTextColor(colors.brown)
            gui.monitor.setCursorPos(gui.width*gui.widthFactor,i)
            gui.monitor.write(''..allData[selection]['amount'])
        else
            gui.monitor.write(allData)
        end
    end

    gui.drawButtons()
end

function gui.page4(timeInfo, itemsInfo)
    gui.drawHeader(timeInfo)
    table.sort(gui.logList , gui.sortLogElements)
    gui.monitor.setBackgroundColor(colors.black)
    for i=3, gui.height-3 do
        for j=1, gui.width do
            gui.monitor.setCursorPos(j, i)
            gui.monitor.write(' ')
        end
    end
    for i=1, gui.height-5 do
        if gui.logList[i] == nil then
            break
        end
        
        gui.monitor.setCursorPos(1,gui.height-i-2)
        gui.monitor.write(gui.logList[i]['time']..' '..gui.logList[i]['message'])
    end
    gui.drawButtons()
end

function gui.pageN_format(timeInfo, itemsInfo, energyInfo)
    gui.drawHeader(timeInfo)

    gui.drawButtons()
end

return gui