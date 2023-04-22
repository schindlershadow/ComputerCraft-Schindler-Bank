local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local mirrorURL = "https://pastebin.com/raw/DW3LCC3L"
local timeoutConnect = nil
local bankServerSocket = nil
local credits = 0
local code = 0
local diskdrive
local monitor = peripheral.wrap("back")
local modem = peripheral.wrap("left")

settings.define("clientName",
    { description = "The hostname of this client", "client" .. tostring(os.getComputerID()), type = "string" })
settings.define("gameName",
    { description = "The name of the Game on this client", "game", type = "string" })
settings.define("launcher",
    { description = "The game launcher file", "game", type = "string" })
settings.define("debug", { description = "Enables debug options", default = "false", type = "boolean" })
settings.define("BankServer", { description = "bank server hostname", default = "minecraft:barrel_0", type = "string" })
settings.define("inputHopper",
    { description = "hopper used for this host", default = "minecraft:hopper_0", type = "string" })
settings.define("outputDropper",
    { description = "dropper used for this host", default = "minecraft:dropper_0", type = "string" })
settings.define("diskdrive",
    { description = "drive used for this host", default = "minecraft:dropper_0", type = "string" })
settings.define("cost",
    { description = "amount of credits it costs to play game", default = 1, type = "number" })
settings.define("description",
    { description = "Game description", default = "A cool game", type = "string" })

--Settings fails to load
if settings.load() == false then
    print("No settings have been found! Default values will be used!")
    settings.set("clientName", "client" .. tostring(os.getComputerID()))
    settings.set("BankServer", "BankServer0")
    settings.set("gameName", "game")
    settings.set("launcher", "game")
    settings.set("description", "A cool game")
    settings.set("cost", 1)
    settings.set("diskdrive", "drive_0")
    settings.set("inputHopper", "minecraft:hopper_0")
    settings.set("outputDropper", "minecraft:dropper_0")
    settings.set("debug", false)
    print("Stop the host and edit .settings file with correct settings")
    settings.save()
    pcall(sleep, 2)
end

if not fs.exists("cryptoNet") then
    print("")
    print("cryptoNet API not found on disk, downloading...")
    local response = http.get(cryptoNetURL)
    if response then
        local file = fs.open("cryptoNet", "w")
        file.write(response.readAll())
        file.close()
        response.close()
        print("File downloaded as '" .. "cryptoNet" .. "'.")
    else
        print("Failed to download file from " .. cryptoNetURL)
        pcall(sleep, 10)
    end
end
os.loadAPI("cryptoNet")

if not fs.exists("mirror") then
    print("")
    print("mirror not found on disk, downloading...")
    local response = http.get(mirrorURL)
    if response then
        local file = fs.open("mirror", "w")
        file.write(response.readAll())
        file.close()
        response.close()
        print("File downloaded as '" .. "mirror" .. "'.")
    else
        print("Failed to download file from " .. mirrorURL)
        pcall(sleep, 10)
    end
end

--Dumps a table to string
local function dump(o)
    if type(o) == "table" then
        local s = ""
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s
    else
        return tostring(o)
    end
end

local function log(text)
    local logFile = fs.open("logs/server.log", "a")
    if type(text) == "string" then
        logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. text)
    else
        logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. textutils.serialise(text))
    end
    logFile.close()
end

local function debugLog(text)
    if settings.get("debug") then
        local logFile = fs.open("logs/serverDebug.log", "a")
        if type(text) == "string" then
            logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. text)
        else
            logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. textutils.serialise(text))
        end
        logFile.close()
    end
end

local function dumpDropper()
    local itemList = dropper.list()
    local numOfItems = 0
    if itemList ~= nil then
        for slot, item in pairs(itemList) do
            numOfItems = numOfItems + item.count
        end
    end
    debugLog("numOfItems:" .. tostring(numOfItems))
    redstone.setOutput("bottom", false)
    while numOfItems > 0 do
        redstone.setOutput("bottom", true)
        pcall(sleep, 0.1)
        redstone.setOutput("bottom", false)
        numOfItems = numOfItems - 1
        pcall(sleep, 0.1)
    end
end

local function dumpHopper()
    if dropper ~= nil and hopper ~= nil then
        local itemList = hopper.list()
        for k, v in pairs(itemList) do
            if v ~= nil and k ~= nil then
                dropper.pullItems(peripheral.getName(hopper), k)
                dumpDropper()
            end
        end
    end
    dumpDropper()
end

local function dumpDisk()
    if dropper ~= nil and diskdrive ~= nil then
        dropper.pullItems(peripheral.getName(diskdrive), 1)
    end
    dumpDropper()
end

local function pullDisk(slot)
    if hopper ~= nil and diskdrive ~= nil then
        if hopper.getItemDetail(slot).name == "computercraft:disk" then
            hopper.pushItems(peripheral.getName(diskdrive), slot, 1, 1)
        else
            error("Tried to pull nondisk item to disk drive")
            debugLog("Tried to pull nondisk item to disk drive")
        end
    end
end

local function centerText(text)
    if text == nil then
        text = ""
    end
    local x, y = term.getSize()
    local x1, y1 = term.getCursorPos()
    term.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    term.write(text)
end

local function centerTextMonitor(monitor, text)
    if monitor ~= nil then
        if text == nil then
            text = ""
        end
        local x, y = monitor.getSize()
        local x1, y1 = monitor.getCursorPos()
        monitor.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
        monitor.write(text)
    end
end

local function loadingScreen(text)
    if type(text) == nil then
        text = ""
    end
    term.setBackgroundColor(colors.red)
    term.clear()
    term.setCursorPos(1, 2)
    centerText(text)
    term.setCursorPos(1, 4)
    centerText("Loading...")
    term.setCursorPos(1, 6)
end

local function getCredits(id)
    if id == nil then
        id = diskdrive.getDiskID()
    end
    credits = 0
    local event
    cryptoNet.send(bankServerSocket, { "getCredits", settings.get("diskdrive") })
    repeat
        event, credits = os.pullEventRaw()
    until event == "gotCredits"
    diskdrive.setDiskLabel("ID: " .. tostring(id) .. " Credits: " .. tostring(credits))
    return credits
end

local function pay()
    local event
    local status = false
    local tmp = {}
    tmp.diskdrive = settings.get("diskdrive")
    tmp.amount = settings.get("cost")
    cryptoNet.send(bankServerSocket, { "pay", tmp })
    repeat
        event, status = os.pullEventRaw()
    until event == "gotPay"
    getCredits()
    return status
end

local function playGame()
    local status = pay()
    if status then
        shell.run("monitor", "top", settings.get("launcher"))
        term.setTextColor(colors.white)
    else
        loadingScreen("Failed to make payment")
        pcall(sleep, 2)
    end
end

local function userMenu()
    local done = false
    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerTextMonitor(monitor, "Schindler Bank Client:" .. settings.get("clientName"))
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerTextMonitor(monitor, "ID: " .. tostring(diskdrive.getDiskID()) .. " Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 5)
        centerTextMonitor(monitor, "\167" .. tostring(settings.get("cost")) .. " Credit(s), 1 Play")
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        monitor.setCursorPos(1, 8)
        monitor.clearLine()
        centerTextMonitor(monitor, "1) Play " .. settings.get("gameName"))
        monitor.setCursorPos(1, 9)
        monitor.clearLine()

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerTextMonitor(monitor, "2) Exit")
        monitor.setCursorPos(1, 13)
        monitor.clearLine()

        local event, key, x, y
        repeat
            event, key, x, y = os.pullEventRaw()
        until event == "mouse_click"

        if y >= 7 and y <= 9 then
            --play touched
            playGame()
        elseif y >= 11 and y <= 13 then
            --exit touched
            done = true
            dumpHopper()
        end
    end
    dumpDisk()
end

--check if disk id is registered
local function checkID()
    local event
    local isRegistered = false
    local tab = {}
    loadingScreen("Loading information from server...")
    cryptoNet.send(bankServerSocket, { "checkID", settings.get("diskdrive") })
    repeat
        event, isRegistered = os.pullEventRaw()
    until event == "gotCheckID"

    return isRegistered
end

local function diskChecker()
    local id = diskdrive.getDiskID()
    local isRegistered = checkID()

    --Prevent malicious execution from diskdrive
    if fs.exists(diskdrive.getMountPath() .. "/startup") then
        fs.delete(diskdrive.getMountPath() .. "/startup")
    end
    if fs.exists(diskdrive.getMountPath() .. "/startup.lua") then
        fs.delete(diskdrive.getMountPath() .. "/startup.lua")
    end

    if isRegistered then
        loadingScreen("User Found, Loading credits...")
        --get credits from server
        credits = getCredits(id)
        --diskdrive.setDiskLabel("ID: " .. tostring(id) .. " Credits: " .. tostring(credits))
        userMenu()
    else
        error("Disk ID not registered!")
        dumpDisk()
        dumpHopper()
        dumpDropper()
    end
end

local function drawMonitorIntro()
    if monitor ~= nil then
        monitor.setTextScale(1)
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerTextMonitor(monitor, "Client:" .. settings.get("clientName"))
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerTextMonitor(monitor, "Welcome to " .. settings.get("gameName") .. "!")
        monitor.setCursorPos(1, 5)
        centerTextMonitor(monitor, settings.get("description"))
        if string.len(settings.get("author")) > 1 then
            monitor.setCursorPos(1, 6)
            centerTextMonitor(monitor, "by " .. settings.get("author"))
            monitor.setCursorPos(1, 7)
            centerTextMonitor(monitor, "Forked by Schindler")
        end

        monitor.setCursorPos(1, 9)
        centerTextMonitor(monitor, "Please insert Floppy Disk")
        monitor.setCursorPos(1, 10)
        centerTextMonitor(monitor, "\167" .. tostring(settings.get("cost")) .. " Credit(s), 1 Play")
        monitor.setCursorPos(1, 12)
        centerTextMonitor(monitor, "Connect Code: " .. tostring(code))
    end
end

local function codeServer()
    while true do
        local id, message = rednet.receive()
        if type(message) == "number" then
            if message == code then
                rednet.send(id, settings.get("clientName"))
                return
            end
        end
    end
end

local function drawMainMenu()
    --term.setTextScale(0.5)
    term.setCursorPos(1, 1)
    monitor.setTextColor(colors.white)
    term.setTextColor(colors.white)

    while true do
        term.setTextColor(colors.white)
        monitor.setTextColor(colors.white)
        
        term.setBackgroundColor(colors.blue)
        term.clear()
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.clearLine()
        centerText("Schindler Bank Client:" .. settings.get("clientName"))
        term.setCursorPos(1, 3)
        term.setBackgroundColor(colors.blue)
        centerText("Welcome to " .. settings.get("gameName") .. "!")
        term.setCursorPos(1, 5)
        centerText(settings.get("description"))

        if string.len(settings.get("author")) > 1 then
            term.setCursorPos(1, 6)
            centerText("by " .. settings.get("author"))
            term.setCursorPos(1, 7)
            centerText("Forked by Schindler")
        end
        term.setCursorPos(1, 9)
        centerText("Please insert Floppy Disk")
        term.setCursorPos(1, 10)
        centerText("\167" .. tostring(settings.get("cost")) .. " Credit(s), 1 Play")
        
        --Look for floppydisk
        local diskSlot = 0
        while diskSlot == 0 do
            code = math.random(1000, 9999)
            drawMonitorIntro()
            codeServer()
            if hopper ~= nil then
                local itemList = hopper.list()
                if itemList ~= nil then
                    for slot, item in pairs(itemList) do
                        debugLog(item.name)
                        if item.name == "computercraft:disk" then
                            diskSlot = slot
                        else
                            dumpHopper()
                        end
                    end
                else
                    pcall(sleep, 1)
                end
            end
        end
        pullDisk(diskSlot)
        loadingScreen("Reading Disk...")
        if not diskdrive.hasData() then
            term.setBackgroundColor(colors.red)
            term.clear()
            term.setCursorPos(1, 2)
            centerText("Error Reading Disk")
            dumpDisk()
            pcall(sleep, 5)
        else
            diskChecker()
        end
        --sleep(10)
    end
end

--Cryptonet event handler
local function onEvent(event)
    if event[1] == "login" then
        local username = event[2]
        -- The socket of the client that just logged in
        local socket = event[3]
        -- The logged-in username is also stored in the socket
        print(socket.username .. " just logged in.")
    elseif event[1] == "encrypted_message" then
        local socket = event[3]
        local message = event[2][1]
        local data = event[2][2]
        if socket.username == nil then
            socket.username = "LAN Host"
        end
        log("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message))
        if message == "newID" then
            os.queueEvent("gotNewID")
        elseif message == "checkID" then
            os.queueEvent("gotCheckID", data)
        elseif message == "getCredits" then
            os.queueEvent("gotCredits", data)
        elseif message == "pay" then
            os.queueEvent("gotPay", data)
        elseif message == "getValue" then
            os.queueEvent("gotValue", data)
        elseif message == "depositItems" then
            os.queueEvent("gotDepositItems")
        elseif message == "transfer" then
            os.queueEvent("gotTransfer", data)
        end
    elseif event[1] == "timer" then
        if event[2] == timeoutConnect then
            --Reboot after failing to connect
            loadingScreen("Failed to connect, rebooting...")
            cryptoNet.closeAll()
            dumpDisk()
            dumpHopper()
            dumpDropper()
            os.reboot()
        end
    elseif event[1] == "connection_closed" then
        --print(dump(event))
        --log(dump(event))
        loadingScreen("Connection lost, rebooting...")
        cryptoNet.closeAll()
        dumpDisk()
        dumpHopper()
        dumpDropper()
        os.reboot()
    end
end

local function onStart()
    os.setComputerLabel(settings.get("clientName"))
    --clear out old log
    if fs.exists("logs/server.log") then
        fs.delete("logs/server.log")
    end
    if fs.exists("logs/serverDebug.log") then
        fs.delete("logs/serverDebug.log")
    end
    --Close any old connections and servers
    cryptoNet.closeAll()
    redstone.setOutput("bottom", false)

    hopper = peripheral.wrap(settings.get("inputHopper"))
    dropper = peripheral.wrap(settings.get("outputDropper"))
    diskdrive = peripheral.wrap(settings.get("diskdrive"))
    width, height = term.getSize()
    --term.setTextScale(0.5)
    loadingScreen("Client is loading, please wait....")

    dumpDisk()
    dumpHopper()
    dumpDropper()

    centerText("Connecting to server...")
    log("Connecting to server: " .. settings.get("BankServer"))

    cryptoNet.setLoggingEnabled(true)

    timeoutConnect = os.startTimer(5 + math.random(10))
    bankServerSocket = cryptoNet.connect(settings.get("BankServer"), 5, 2, settings.get("BankServer") .. ".crt", "bottom")
    print("Connected!")
    --timeout no longer needed
    timeoutConnect = nil
    server = cryptoNet.host(settings.get("clientName"), true, false, "left")
    rednet.open("left")
    drawMainMenu()
end

print("Client is loading, please wait....")

--Main loop
--cryptoNet.startEventLoop(onStart, onEvent)
pcall(cryptoNet.startEventLoop, onStart, onEvent)

cryptoNet.closeAll()
dumpDisk()
redstone.setOutput("bottom", false)
os.reboot()
