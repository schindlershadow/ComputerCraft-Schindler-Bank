if settings.get("startupMonitor") == nil then
    error("startupMonitor not defined in settings!")
    return
end
local monitor = peripheral.wrap(settings.get("startupMonitor"))
if monitor == nil then
    error(settings.get("startupMonitor") .. " peripheral returned nil!")
    return
end
local jackpot = 0
monitor.setTextScale(2)
local monitorX, monitorY = monitor.getSize()

local function getJackpot()
    if fs.exists("jackpot") then
        local file = fs.open("jackpot", "r")
        local contents = file.readAll()
        if tonumber(contents) == nil then
            jackpot = 0
        else
            jackpot = tonumber(contents)
        end

        file.close()
    else
        jackpot = 0
    end
end

local function centerText(text)
    if text == nil then
        text = ""
    end
    local x1, y1 = monitor.getCursorPos()
    monitor.setCursorPos((math.floor(monitorX / 2) - (math.floor(#text / 2))), y1)
    monitor.write(text)
end



local blue = true
local textColor = colors.red
while true do
    getJackpot()
    if blue then
        monitor.setBackgroundColor(colors.blue)
        textColor = colors.red
        blue = false
    else
        monitor.setBackgroundColor(colors.red)
        textColor = colors.blue
        blue = true
    end

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextColor(colors.yellow)
    centerText("JACKPOT")
    monitor.setCursorPos(1, 2)
    monitor.setTextColor(textColor)
    centerText("\167" .. tostring(jackpot))
    monitor.setCursorPos(1, 3)
    monitor.setTextColor(colors.yellow)
    sleep(5)
end
