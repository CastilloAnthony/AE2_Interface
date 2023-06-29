

local gui = {}

function gui.initialize(monitor)
    monitor.clear()
    monitor.setCursorPos(1,1)
    return monitor.getSize()
end --end initialize

function gui.touch()
    local event, side, x, y = os.pullEvent('monitor_touch')
    local event, side, x, y = os.pullEvent('mouse_up')
end --end touch

function gui.main(monitor, timeInfo, itemsInfo, energyInfo)
    local width, height = gui.initialize(monitor)
    local widthFactor = 7/10
    monitor.setBackgroundColor(colors.gray)
    for i=1, height do
        for j=1, width do
            monitor.setCursorPos(j,i)
            monitor.write(' ')
        end
    end
    monitor.setCursorPos(1,1)
    monitor.write(timeInfo[1])
    monitor.setCursorPos(2,2)
    monitor.write('Power: '..(math.floor((energyInfo['currentStorage']/energyInfo['maxStorage'])*1000)/10)..'%')
    monitor.setCursorPos(2,3)
    monitor.setBackgroundColor(colors.red)
    for i=1, (energyInfo['currentStorage']/energyInfo['maxStorage'])*width-1 do
        monitor.write(' ')
    end
    monitor.setBackgroundColor(colors.gray)
    monitor.setCursorPos(2,5)
    monitor.write('Items: '..(math.floor((itemsInfo['currentStorage']/itemsInfo['maxStorage'])*1000)/10)..'%')
    monitor.setCursorPos(2,6)
    monitor.setBackgroundColor(colors.green)
    for i=1, (itemsInfo['currentStorage']/itemsInfo['maxStorage'])*width-1 do
        monitor.write(' ')
    end
    monitor.setBackgroundColor(colors.gray)
    monitor.setCursorPos(2,8)
    monitor.write('Power Usage: ')
    monitor.setCursorPos(width*widthFactor,8)
    monitor.write((math.floor(energyInfo['usage']*2.5*10)/10)..'RF/t')
    monitor.setCursorPos(2,9)
    monitor.write('Max Storage: ')
    monitor.setCursorPos(width*widthFactor,9)
    monitor.write(''..itemsInfo['maxStorage'])
    monitor.setCursorPos(2,10)
    monitor.write('Stored Items: ')
    monitor.setCursorPos(width*widthFactor,10)
    monitor.write(''..itemsInfo['currentStorage'])
    monitor.setCursorPos(2,11)
    monitor.write('Free Storage: ')
    monitor.setCursorPos(width*widthFactor,11)
    monitor.write(''..itemsInfo['availableStorage'])
    monitor.setCursorPos(2,13)
    monitor.write('Top Five Most Items: ')
    monitor.setTextColor(colors.cyan)
    for i, j in pairs(itemsInfo['topFive']) do
        monitor.setCursorPos(2, 13+i)
        monitor.write(j['displayName'])
        monitor.setCursorPos(width*widthFactor, 13+i)
        monitor.write(''..j['amount'])
    end
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(1, height)
end --end main

return gui