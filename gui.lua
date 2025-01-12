local completion = require('cc.completion')
local gui = {}

gui.totalPages = 9
gui.width = nil
gui.height = 100
gui.widthFactor = 7/10
gui.monitor = nil
gui.logList = {}
gui.logCount = 0
gui.userSearch = ''
gui.settings = nil
gui.userSearchTable = {}
gui.searching = false
gui.possible = {}

function gui.initialize(monitor)
    gui.monitor = monitor
    gui.monitor.clear()
    gui.monitor.setCursorPos(1,1)
    gui.width, gui.height =  gui.monitor.getSize()
    gui.readSettings()
end --end initialize

function gui.write(string)
    if string == nil then
        return
    end
    gui.monitor.setCursorPos(1, gui.height)
    gui.monitor.write(string)
end --end write

function gui.log(string, storage)
    local logging = {['order'] = gui.logCount+1, ['time'] = os.date('%T'), ['message'] = string}
    table.insert(gui.logList, logging)
    local file = nil
    if storage ~= nil then
        file = fs.open(storage..'AE2_Interface/logs/'..os.date('%F'), 'a')
    else
        file = fs.open('./'..'AE2_Interface/logs/'..os.date('%F'), 'a')
    end 
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
end --end log

function gui.main(data, allData)
    if data == nil or allData == nil then
        gui.log('No data was given.', nil)
        return
    end
    --timeInfo, itemsInfo, energyInfo, allData, fluidInfo, cellsInfo, cpuInfo, serverInfo, craftables
    gui.readSettings()
    --gui.initialize(gui.monitor)
    gui.monitor.setVisible(false)
    if gui.settings['currentPage'] == 1 then
        gui.page1(data['computer'], data['time'], data['items'], data['energy'], data['fluids'])
    elseif gui.settings['currentPage'] == 2 then
        gui.page2(data['energy'], data['time'])
    elseif gui.settings['currentPage'] == 3 then
        gui.page3(data['items'], allData)
    elseif gui.settings['currentPage'] == 4 then
        gui.page4(data['fluids'])
    elseif gui.settings['currentPage'] == 5 then
        gui.page5(allData)
    elseif gui.settings['currentPage'] == 6 then
        gui.page6(data['craftables'])
    elseif gui.settings['currentPage'] == 7 then
        gui.page7(data['cells'])
    elseif gui.settings['currentPage'] == 8 then
        gui.page8(data['cpus'])
    elseif gui.settings['currentPage'] == 9 then
        gui.page9()
    end
    gui.monitor.setVisible(true)
end --end main()

function gui.updateLogPage()
    gui.readSettings()
    if gui.settings['currentPage'] == 9 then
        gui.page9()
    end
end

function gui.sortLogElements(a, b)
    return tonumber(a['order']) > tonumber(b['order'])
end --end sorLogElements

function gui.compareByAmount(a, b)
    return tonumber(a['amount']) > tonumber(b['amount'])
end --end compareByAmount

function gui.compareByBytes(a, b)
    return tonumber(a['totalBytes']) > tonumber(b['totalBytes'])
end --end compareByBytes

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
                    if string.find(string.lower(i['displayName']), gui.userSearch) == 1 then
                        if not gui.checkIfInTable(gui.userSearchTable, i) then
                            table.insert(gui.userSearchTable, i)
                        end
                    end
                end
            end
            table.sort(gui.userSearchTable, gui.compareByAmount)
        end
    end
end --end populateTable

function gui.checkIfInTable(table, element)
    for _, i in pairs(table) do
        if element['displayName'] == i['displayName'] then
            return true
        end
    end
    return false
end --end checkIfInTable

function gui.readSettings()
    if not fs.exists('./AE2_Interface/settings.cfg') then
        gui.writeSettings('default')
    end
    local file = fs.open('./AE2_Interface/settings.cfg', 'r')
    gui.settings = textutils.unserialize(file.readAll())
    file.close()
end --end readSettings

function gui.writeSettings(settings)
    if settings == 'default' then
        gui.settings = {
            ['currentPage'] = 1, 
            ['userSearch'] = gui.userSearch, 
            ['searchHistory'] = {}, 
            ['craftingQueue'] = {}, 
            ['storedPower'] = 0, 
            ['deltaPower'] = 0, 
            ['snapshotTime'] = 0, 
            ['deltaTime'] = 0,
            ['itemsMouseWheel'] = 0,
            ['searchingMouseWheel'] = 0,
            ['craftablesMouseWheel'] = 0,
            ['logsMouseWheel'] = 0,
        }
    end
    local file = fs.open('./AE2_Interface/settings.cfg', 'w')
    file.write(textutils.serialize(gui.settings))
    file.close()   
end --end writeSettings

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
end --end nextPage

function gui.populatePossibleAnswers(allData)
    if #gui.possible > 1 then
        repeat 
            table.remove(gui.possible, #gui.possible)
        until not (#gui.possible > 1)
    end
    for i, j in pairs(allData) do
        table.insert(gui.possible, string.lower(j['displayName']))
    end
end --end populatePossibleAnswers

function gui.searchPartialComplete(text)
    gui.monitor.setBackgroundColor(colors.lightGray)
    return completion.choice(string.lower(text), gui.possible)
end --end searchPartialComplete

function gui.clickedButton(button, x, y, craftables)
    gui.readSettings()
    if button == 1 or peripheral.isPresent(tostring(button)) then
        if y == gui.height-1 then -- Previous/Next Buttons
            if x>=gui.width-6 and x<=gui.width-2 then --Next
                gui.nextPage(true)
                gui.writeSettings()
                return true
            elseif x>=2 and x<=6 then --Prev
                gui.nextPage(false)
                gui.writeSettings()
                return true
            end
        elseif gui.settings['currentPage'] == 5 then -- Searching
            if y == 3 then
                if x>=2 and x<=gui.width-1 then
                    gui.searching = true
                    gui.monitor.setBackgroundColor(colors.lightGray)
                    gui.monitor.setCursorPos(2,3)
                    for i=2, gui.width-1 do
                        gui.monitor.write(' ')
                    end
                    gui.monitor.setCursorPos(2,3)
                    local userInput = read(nil, gui.settings['searchHistory'], gui.searchPartialComplete)
                    gui.userSearch = string.lower(userInput)
                    gui.searching = false
                    gui.log('Usr Inpt: '..gui.userSearch, nil)
                end
            end
        elseif gui.settings['currentPage'] == 6 then -- Craftables
            if (x > 1 and x < gui.width*gui.widthFactor) then
                if (y > 3 and y < gui.height-3) then
                    if x>=2 and x<=gui.width*gui.widthFactor then -- Clicked the name of an item
                        i = 1
                        for k, v in pairs(craftables) do
                            if i == y-3 then
                                item = v
                                item['count'] = 1
                                gui.readSettings()
                                if gui.settings['craftingQueue'][#gui.settings['craftingQueue']] ~= item then
                                    table.insert(gui.settings['craftingQueue'], item)
                                    gui.writeSettings()
                                end
                                break
                            end
                            i = i + 1
                        end
                    end
                end
            end
        elseif y == 1 and x == gui.width then
            gui.monitor.setBackgroundColor(colors.black)
            gui.monitor.clear()
            gui.monitor.setTextColor(colors.red)
            print('AE2 Interface has been ')
            gui.monitor.setTextColor(colors.white)
            os.queueEvent('terminate')
            os.sleep(100)
        end
    end
    return false
end --end clickedButton

function gui.mouseWheel(button, dir, x, y)
    gui.readSettings()
    if button == 'mouse_wheel' then
        if gui.settings['currentPage'] == 3 then -- Items
            if (y > 10 and y < gui.height-3) then
                if dir == -1 then
                    if gui.settings['itemsMouseWheel'] > 0 then
                        gui.settings['itemsMouseWheel'] = gui.settings['itemsMouseWheel']-1
                    end
                else
                    gui.settings['itemsMouseWheel'] = gui.settings['itemsMouseWheel']+1
                end
            end
        elseif gui.settings['currentPage'] == 5 then -- Searching
            if (y > 4 and y < gui.height-3) then
                if dir == -1 then
                    if gui.settings['searchingMouseWheel'] > 0 then
                        gui.settings['searchingMouseWheel'] = gui.settings['searchingMouseWheel']-1
                    end
                else
                    gui.settings['searchingMouseWheel'] = gui.settings['searchingMouseWheel']+1
                end
            end
        elseif gui.settings['currentPage'] == 6 then -- Craftables
            if (y > 3 and y < gui.height-3) then
                if dir == -1 then
                    if gui.settings['craftableMouseWheel'] > 0 then
                        gui.settings['craftableMouseWheel'] = gui.settings['craftableMouseWheel']-1
                    end
                else
                    gui.settings['craftableMouseWheel'] = gui.settings['craftableMouseWheel']+1
                end
            end
        elseif gui.settings['currentPage'] == 9 then -- Logs
            if (y > 2 and y < gui.height-3) then
                if dir == -1 then
                    if gui.settings['logsMouseWheel'] > 0 then
                        gui.settings['logsMouseWheel'] = gui.settings['logsMouseWheel']+1
                    end
                else
                    gui.settings['logsMouseWheel'] = gui.settings['logsMouseWheel']-1
                end
            end
        end
    end
    gui.writeSettings()
end

function gui.resizeString(string, smaller)
    if smaller == nil then
        smaller = 0
    end
    return string.sub(string, 1, gui.width*gui.widthFactor-3-smaller)
end --end resizeString

function gui.updateTime()
    local tempText = gui.monitor.getTextColor()
    local tempBack = gui.monitor.getBackgroundColor()
    local x, y = gui.monitor.getCursorPos()
    gui.monitor.setVisible(false)
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setBackgroundColor(colors.red)
    gui.monitor.setCursorPos(gui.width, 1)
    gui.monitor.write('X')
    gui.monitor.setBackgroundColor(colors.gray)
    for i=1, gui.width-1 do
        gui.monitor.setCursorPos(i,1)
        gui.monitor.write(' ')
    end
    gui.monitor.setCursorPos(1,1)
    gui.monitor.write(os.date())
    gui.monitor.setCursorPos(x, y)
    gui.monitor.setTextColor(tempText)
    gui.monitor.setBackgroundColor(tempBack)
    gui.monitor.setVisible(true)
end

function gui.clearScreen()
    gui.monitor.setBackgroundColor(colors.gray)
    for i=2, gui.height do
        for j=1, gui.width do
            gui.monitor.setCursorPos(j,i)
            gui.monitor.write(' ')
        end
    end
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
end --end drawButtons

function gui.page1(serverInfo, timeInfo, itemsInfo, energyInfo, fluidInfo) -- Main Page
    gui.clearScreen()
    gui.monitor.setCursorPos(2, 3)
    gui.monitor.setTextColor(colors.yellow)
    gui.monitor.write('Snapshot Report: ')
    gui.monitor.setCursorPos(2,4)
    gui.monitor.setTextColor(colors.white)
    gui.monitor.write(timeInfo['date'])
    gui.monitor.setCursorPos(2,6)
    gui.monitor.setTextColor(colors.yellow)
    gui.monitor.write('Server Info:')
    gui.monitor.setTextColor(colors.white)
    gui.monitor.setCursorPos(2,7)
    gui.monitor.write('Name: '..serverInfo['label'])
    gui.monitor.setCursorPos(2,8)
    gui.monitor.write('ID: '..serverInfo['id'])
    gui.monitor.setCursorPos(2,10)
    gui.monitor.setTextColor(colors.purple)
    gui.monitor.write('Power: ')
    gui.monitor.setTextColor(colors.magenta)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,10)
    gui.monitor.write((math.floor((energyInfo['currentStorage']/energyInfo['maxStorage'])*1000)/10)..'%')
    gui.monitor.setCursorPos(2,11)
    gui.monitor.setBackgroundColor(colors.red)
    for i=1, (energyInfo['currentStorage']/energyInfo['maxStorage'])*gui.width-2 do
        gui.monitor.write(' ')
    end
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setCursorPos(2,13)
    gui.monitor.setTextColor(colors.lime)
    gui.monitor.write('Items: ')
    gui.monitor.setTextColor(colors.brown)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,13)
    gui.monitor.write((math.floor(itemsInfo['currentStorage']/itemsInfo['maxStorage']*1000)/10)..'%')
    gui.monitor.setCursorPos(2,14)
    gui.monitor.setBackgroundColor(colors.green)
    for i=1, (itemsInfo['currentStorage']/itemsInfo['maxStorage'])*gui.width-2 do
        gui.monitor.write(' ')
    end
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setCursorPos(2,16)
    gui.monitor.setTextColor(colors.lightBlue)
    gui.monitor.write('Fluids:')
    gui.monitor.setTextColor(colors.cyan)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,16)
    gui.monitor.write((math.floor(fluidInfo['currentStorage']/fluidInfo['maxStorage']*1000)/10)..'%')
    gui.monitor.setCursorPos(2,17)
    gui.monitor.setBackgroundColor(colors.blue)
    for i=1, (fluidInfo['currentStorage']/fluidInfo['maxStorage'])*gui.width-2 do
        gui.monitor.write(' ')
    end
    gui.monitor.setBackgroundColor(colors.gray)
    gui.drawButtons()
end --end page1

function gui.page2(energyInfo, timeInfo) -- Energy
    gui.clearScreen()
    gui.monitor.setCursorPos(2, 3)
    gui.monitor.setTextColor(colors.purple)
    gui.monitor.write('Power: ')
    gui.monitor.setTextColor(colors.magenta)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,3)
    gui.monitor.write((math.floor((energyInfo['currentStorage']/energyInfo['maxStorage'])*1000)/10)..'%')
    gui.monitor.setCursorPos(2,4)
    gui.monitor.setBackgroundColor(colors.red)
    for i=1, (energyInfo['currentStorage']/energyInfo['maxStorage'])*gui.width-2 do
        gui.monitor.write(' ')
    end
    gui.monitor.setBackgroundColor(colors.gray)

    --Header
    gui.monitor.setTextColor(colors.purple)
    gui.monitor.setCursorPos(2,6)
    gui.monitor.write('Statistic')
    gui.monitor.setTextColor(colors.magenta)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,6)
    gui.monitor.write('(AE)')
    gui.monitor.setTextColor(colors.purple)
    
    gui.monitor.setCursorPos(2,7)
    gui.monitor.write('Max Power: ')
    gui.monitor.setTextColor(colors.magenta)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,7)
    gui.monitor.write(''..math.floor(energyInfo['maxStorage']/1000)..'k')
    gui.monitor.setTextColor(colors.purple)
    gui.monitor.setCursorPos(2,8)
    gui.monitor.write('Stored Power: ')
    gui.monitor.setTextColor(colors.magenta)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,8)
    gui.monitor.write(''..math.floor(energyInfo['currentStorage']/1000)..'k')
    gui.monitor.setTextColor(colors.purple)
    gui.monitor.setCursorPos(2,9)
    gui.monitor.write('Power Usage: ')
    gui.monitor.setTextColor(colors.magenta)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,9)
    gui.monitor.write(''..(math.floor(energyInfo['usage']*10)/10)..'/t')
    gui.monitor.setTextColor(colors.purple)
    gui.monitor.setCursorPos(2,10)
    gui.readSettings()
    -- gui.log('Current Energy Storage: '..energyInfo['currentStorage'])
    -- gui.log('Previous Stored Power: '..gui.settings['storedPower'])
    -- if gui.settings['storedPower'] == nil then
    --     gui.settings['deltaPower'] = 0
    --     gui.settings['storedPower'] = 0
    --     gui.writeSettings()
    if energyInfo['currentStorage'] ~= gui.settings['storedPower'] then
        -- gui.monitor.write('Delta Power: ')
        -- gui.monitor.setTextColor(colors.magenta)
        -- gui.monitor.setCursorPos(gui.width*gui.widthFactor,10)
        gui.settings['deltaPower'] = math.floor((energyInfo['currentStorage']-gui.settings['storedPower'])/100)/10
        gui.settings['deltaTime'] = math.floor((timeInfo['clock']-gui.settings['snapshotTime'])*10)/10
        gui.settings['storedPower'] = energyInfo['currentStorage']
        -- gui.monitor.write(''..gui.settings['deltaPower']..'/'..gui.settings['deltaTime']..'s')
        gui.settings['snapshotTime'] = timeInfo['clock']
        gui.writeSettings()
    end
    gui.monitor.write('Delta Power: ')
    gui.monitor.setTextColor(colors.magenta)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,10)
    gui.monitor.write(''..gui.settings['deltaPower']..'k/'..gui.settings['deltaTime']..'s')
    --gui.monitor.write(math.floor(energyInfo['currentStorage']-gui.settings['recentPower'])..' '..'TBD')
    gui.monitor.setTextColor(colors.purple)
    gui.monitor.setCursorPos(2,11)
    gui.drawButtons()
end --end page2

function gui.page3(itemsInfo, allData) -- Items
    gui.clearScreen()
    gui.monitor.setCursorPos(2,3)
    gui.monitor.setTextColor(colors.lime)
    gui.monitor.write('Items: ')
    gui.monitor.setTextColor(colors.brown)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,3)
    gui.monitor.write((math.floor(itemsInfo['currentStorage']/itemsInfo['maxStorage']*1000)/10)..'%')
    gui.monitor.setCursorPos(2,4)
    gui.monitor.setBackgroundColor(colors.green)
    for i=1, (itemsInfo['currentStorage']/itemsInfo['maxStorage'])*gui.width-2 do
        gui.monitor.write(' ')
    end
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setTextColor(colors.lime)
    gui.monitor.setCursorPos(2,6)
    gui.monitor.write('Max Storage: ')
    gui.monitor.setTextColor(colors.brown)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,6)
    gui.monitor.write(''..itemsInfo['maxStorage'])
    gui.monitor.setTextColor(colors.lime)
    gui.monitor.setCursorPos(2,7)
    gui.monitor.write('Stored Items: ')
    gui.monitor.setTextColor(colors.brown)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,7)
    gui.monitor.write(''..itemsInfo['currentStorage'])
    gui.monitor.setTextColor(colors.lime)
    gui.monitor.setCursorPos(2,8)
    gui.monitor.write('Free Storage: ')
    gui.monitor.setTextColor(colors.brown)
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,8)
    gui.monitor.write(''..itemsInfo['availableStorage'])
    gui.monitor.setCursorPos(2,10)
    gui.monitor.setTextColor(colors.yellow)
    gui.monitor.write('Item')
    gui.monitor.setCursorPos(gui.width*gui.widthFactor,10)
    gui.monitor.write('Quantity')
    table.sort(allData, gui.compareByAmount)
    if gui.settings['itemsMouseWheel']+gui.height-13 > #allData then -- Looking at the bottom of the list
        for i=1, gui.height-13 do
            if i > #allData then
                break
            end
            gui.monitor.setTextColor(colors.lime)
            gui.monitor.setCursorPos(2,gui.height-i)--i+10)
            gui.monitor.write(gui.resizeString(allData[#allData-i]['displayName']))
            gui.monitor.setTextColor(colors.brown)
            gui.monitor.setCursorPos(gui.width*gui.widthFactor,i+10)
            gui.monitor.write(''..allData[i]['amount'])
        end
    else
        for i=1, gui.height-13 do
            if gui.settings['itemsMouseWheel']+i > #allData then
                break
            end
            gui.monitor.setTextColor(colors.lime)
            gui.monitor.setCursorPos(2,i+10)
            gui.monitor.write(gui.resizeString(allData[gui.settings['itemsMouseWheel']+i]['displayName']))
            gui.monitor.setTextColor(colors.brown)
            gui.monitor.setCursorPos(gui.width*gui.widthFactor,i+10)
            gui.monitor.write(''..allData[i]['amount'])
        end
    end
    gui.drawButtons()
end --end page3

function gui.page4(fluidInfo) -- Fluids
    gui.clearScreen()
    if fluidInfo == nil then
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('No fluid information found.')
    elseif #fluidInfo['listFluid'] >= 1 then
        table.sort(fluidInfo['listFluid'], gui.compareByAmount)
        gui.monitor.setCursorPos(2,3)
        gui.monitor.setTextColor(colors.lightBlue)
        gui.monitor.write('Fluids:')
        gui.monitor.setTextColor(colors.cyan)
        gui.monitor.setCursorPos(gui.width*gui.widthFactor,3)
        gui.monitor.write((math.floor(fluidInfo['currentStorage']/fluidInfo['maxStorage']*1000)/10)..'%')
        gui.monitor.setCursorPos(2,4)
        gui.monitor.setBackgroundColor(colors.blue)
        for i=1, (fluidInfo['currentStorage']/fluidInfo['maxStorage'])*gui.width-2 do
            gui.monitor.write(' ')
        end
        gui.monitor.setBackgroundColor(colors.gray)
        gui.monitor.setTextColor(colors.lightBlue)
        gui.monitor.setCursorPos(2,6)
        gui.monitor.write('Max Storage: ')
        gui.monitor.setTextColor(colors.cyan)
        gui.monitor.setCursorPos(gui.width*gui.widthFactor,6)
        gui.monitor.write(''..fluidInfo['maxStorage'])
        gui.monitor.setTextColor(colors.lightBlue)
        gui.monitor.setCursorPos(2,7)
        gui.monitor.write('Stored Fluid: ')
        gui.monitor.setTextColor(colors.cyan)
        gui.monitor.setCursorPos(gui.width*gui.widthFactor,7)
        gui.monitor.write(''..fluidInfo['currentStorage'])
        gui.monitor.setTextColor(colors.lightBlue)
        gui.monitor.setCursorPos(2,8)
        gui.monitor.write('Free Storage: ')
        gui.monitor.setTextColor(colors.cyan)
        gui.monitor.setCursorPos(gui.width*gui.widthFactor,8)
        gui.monitor.write(''..fluidInfo['availableStorage'])
        gui.monitor.setTextColor(colors.yellow)
        gui.monitor.setCursorPos(2,10)
        gui.monitor.write('Fluid')
        gui.monitor.setCursorPos(gui.width*gui.widthFactor,10)
        gui.monitor.write('mBuckets')
        for i, j in pairs(fluidInfo['listFluid']) do
            if i > gui.height-14 then
                break
            end
            gui.monitor.setTextColor(colors.lightBlue)
            gui.monitor.setCursorPos(2, i+10)
            gui.monitor.write(string.upper(string.sub(j['name'], string.find(j['name'], ':')+1,string.find(j['name'], ':')+1))..string.sub(j['name'], string.find(j['name'], ':')+2, string.len(j['name'])))
            gui.monitor.setCursorPos(gui.width*gui.widthFactor, i+10)
            gui.monitor.setTextColor(colors.cyan)
            gui.monitor.write(''..j['amount']..'mB')
        end
    else
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('No fluid information found.')
    end
    gui.drawButtons()
end --end page4

function gui.page5(allData) -- Search
    while gui.searching do
        os.sleep(0.5)
    end
    gui.populatePossibleAnswers(allData)
    gui.clearScreen()
    gui.monitor.setBackgroundColor(colors.lightGray)
    gui.monitor.setCursorPos(2, 3)
    for i=2, gui.width-1 do
        gui.monitor.write(' ')
    end
    gui.monitor.setCursorPos(2, 3)
    gui.monitor.write('Search for items...')
    gui.monitor.setBackgroundColor(colors.gray)
    gui.monitor.setCursorPos(2, 5)
    gui.populateTable(allData)
    if gui.userSearchTable ~= {} then
        for i = 1, gui.height-7 do
            if i > #gui.userSearchTable then
                break
            end
            gui.monitor.setTextColor(colors.lime)
            gui.monitor.setCursorPos(2, i+4)
            gui.monitor.write(gui.resizeString(gui.userSearchTable[i]['displayName']))
            gui.monitor.setTextColor(colors.brown)
            gui.monitor.setCursorPos(gui.width*gui.widthFactor, i+4)
            gui.monitor.write(''..gui.userSearchTable[i]['amount'])
        end
    end
    gui.drawButtons()
    gui.monitor.setBackgroundColor(colors.lightGray)
    gui.monitor.setCursorPos(2, 3)
end --end page5

-- function gui.page6(allData) -- Watch List
--     gui.clearScreen()
--     gui.monitor.setTextColor(colors.yellow)
--     gui.monitor.setCursorPos(2, 3)
--     gui.monitor.write('At a Glance:')
--     for i=4, gui.height-3 do
--         local selection = math.random(1,#allData)
--         gui.monitor.setTextColor(colors.lime)
--         gui.monitor.setCursorPos(2,i)
--         if #allData == 0 then
--             gui.log('Error in large packet, size is 0.')
--         end
--         if type(allData[selection]) == 'table' then
--             gui.monitor.write(gui.resizeString(allData[selection]['displayName']))
--             gui.monitor.setTextColor(colors.brown)
--             gui.monitor.setCursorPos(gui.width*gui.widthFactor,i)
--             gui.monitor.write(''..allData[selection]['amount'])
--         else
--             gui.monitor.write(allData)
--         end
--     end

--     gui.drawButtons()
-- end --end page6

function gui.page6(craftables) -- Craftable Items
    gui.clearScreen()
    gui.monitor.setTextColor(colors.yellow)
    gui.monitor.setCursorPos(2, 3)
    gui.monitor.write('Craftables:')
    for i=4, gui.height-3 do
        gui.monitor.setTextColor(colors.lime)
        gui.monitor.setCursorPos(2,i)
        if type(craftables[i-3]) == 'table' then
            gui.monitor.write(gui.resizeString(craftables[i-3]['displayName']))
            gui.monitor.setTextColor(colors.brown)
            gui.monitor.setCursorPos(gui.width*gui.widthFactor,i)
            gui.monitor.write(''..craftables[i-3]['amount'])
        end
    end
    gui.drawButtons()
end --end page6

function gui.page7(cellsInfo) -- Cells
    gui.clearScreen()
    gui.monitor.setTextColor(colors.yellow)
    if cellsInfo == nil then
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('No cells information found.')
    elseif #cellsInfo >= 1 then
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('Type'..'  '..'Name')
        gui.monitor.setCursorPos(gui.width*gui.widthFactor, 3)
        gui.monitor.write('MaxBytes')
        table.sort(cellsInfo, gui.compareByBytes)
        for i, j in pairs(cellsInfo) do
            local space = '  '
            if i > gui.height-6 then
                break
            end
            local adjustment = 0
            if j['cellType'] == 'item' then
                gui.monitor.setTextColor(colors.green)
                adjustment = 4
            elseif j['cellType'] == 'fluid' then
                gui.monitor.setTextColor(colors.blue)
                adjustment = 5
                space = ' '
            else
                gui.monitor.setTextColor(colors.red)
            end
            gui.monitor.setCursorPos(2, i+3)
            gui.monitor.write(string.upper(j['cellType']))
            gui.monitor.setTextColor(colors.lightBlue)
            if j['bytesPerType'] ~= nil then
                gui.monitor.write(gui.resizeString(space..(j['bytesPerType']/8)..'k'..' Storage Cell', adjustment))
            else
                gui.monitor.write(gui.resizeString(space..(j['totalBytes']/1000)..'k'..' Deep Storage Cell', adjustment))
            end
            gui.monitor.setCursorPos(gui.width*gui.widthFactor, i+3)
            gui.monitor.setTextColor(colors.cyan)
            gui.monitor.write(''..j['totalBytes'])
        end
    else
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('No cells information found.')
    end
    gui.drawButtons()
end --end page7

function gui.page8(cpuInfo) -- CPUs
    gui.clearScreen()
    if cpuInfo == nil then
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('No crafting CPUs found.')
    elseif #cpuInfo >= 1 then
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('Number of crafting CPUs: '..#cpuInfo)
        gui.monitor.setCursorPos(2,5)
        gui.monitor.setTextColor(colors.yellow)
        gui.monitor.write('CPU')
        gui.monitor.setCursorPos(gui.width/4, 5)
        gui.monitor.write('Busy')
        gui.monitor.setCursorPos(gui.width/4*2, 5)
        gui.monitor.write('COs')
        gui.monitor.setCursorPos(gui.width/4*3, 5)
        gui.monitor.write('Storage')
        for i, j in pairs(cpuInfo) do
            if i>gui.height-8 then
                break
            end
            gui.monitor.setTextColor(colors.green)
            gui.monitor.setCursorPos(2,i+5)
            gui.monitor.write(''..i)
            gui.monitor.setCursorPos(gui.width/4, i+5)
            if j['isBusy'] then
                gui.monitor.setTextColor(colors.red)
                gui.monitor.write(j['isBusy'])
            else
                gui.monitor.setTextColor(colors.blue)
                gui.monitor.write(j['isBusy'])
            end
            gui.monitor.setTextColor(colors.lightBlue)
            gui.monitor.setCursorPos(gui.width/4*2, i+5)
            gui.monitor.write(''..j['coProcessors'])
            gui.monitor.setTextColor(colors.cyan)
            gui.monitor.setCursorPos(gui.width/4*3, i+5)
            gui.monitor.write(''..j['storage'])
        end
    else
        gui.monitor.setCursorPos(2, 3)
        gui.monitor.write('No crafting CPUs found.')
    end
    gui.drawButtons()
end --end page8

function gui.page9() -- Logs
    gui.clearScreen()
    table.sort(gui.logList , gui.sortLogElements)
    gui.monitor.setBackgroundColor(colors.black)
    for i=3, gui.height-3 do
        for j=1, gui.width do
            gui.monitor.setCursorPos(j, i)
            gui.monitor.write(' ')
        end
    end
    for i=1, gui.height-4 do
        if gui.logList[i] == nil then
            break
        end
        gui.monitor.setCursorPos(1,gui.height-i-2)
        gui.monitor.write(gui.logList[i]['time']..' '..gui.logList[i]['message'])
    end
    gui.drawButtons()
end --end page9

function gui.pageN_format(itemsInfo, energyInfo)
    gui.drawHeader()

    gui.drawButtons()
end --end 

return gui
