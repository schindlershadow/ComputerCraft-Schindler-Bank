local githubFilename = "arcade.lua"
local githubFolder = "arcade"
local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local timeoutConnect = nil
local timeoutConnectController = nil
local bankServerSocket = nil
local credits = 0
local code = 0
local wirelessModemSide = "left"
local modemSide = "bottom"
local monitorSide = "back"
local redstoneSide = "right"
local diskdrive, controllerSocket
local monitor = peripheral.wrap(monitorSide)
local modem = peripheral.wrap(wirelessModemSide)

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

-- Define a function to check for updates
function checkUpdates()
    print("Checking for updates")
    -- Set the GitHub repository information
    local owner = "schindlershadow"
    local repo = "ComputerCraft-Schindler-Bank"

    -- Set the script file information
    local filepath = "startup.lua"
    -- Get the latest commit hash from the repository
    local commiturl = "https://api.github.com/repos/" ..
    owner .. "/" .. repo .. "/contents/" .. githubFolder .. "/" .. githubFilename
    local commitresponse = http.get(commiturl)
    local commitdata = commitresponse.readAll()
    commitresponse.close()
    local latestCommit = textutils.unserializeJSON(commitdata).sha

    local currentCommit = ""
    --Get the current commit sha
    if fs.exists("sha") then
        --Read the current file
        local file = fs.open("sha", "r")
        currentCommit = file.readAll()
        file.close()
    end

    print("Current SHA256: " .. tostring(currentCommit))

    -- Check if the latest commit is different from the current one
    if currentCommit ~= latestCommit then
        print("Update found with SHA256: " .. tostring(latestCommit))
        -- Download the latest script file
        local startupURL = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/main/".. githubFolder .. "/" .. githubFilename
        local response = http.get(startupURL)
        local data = response.readAll()
        response.close()

        --remove old version
        fs.delete(filepath)
        -- Save the downloaded file to disk
        local newfile = fs.open(filepath, "w")
        newfile.write(data)
        newfile.close()

        if fs.exists("sha") then
            fs.delete("sha")
        end
        --write new sha
        local shafile = fs.open("sha", "w")
        shafile.write(latestCommit)
        shafile.close()

        -- Print a message to the console
        print("Updated " .. githubFilename .. " to the latest version.")
        sleep(3)
        os.reboot()
    else
        print("No update found")
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

local function drawDiskReminder()
    monitor.setTextScale(1)
    monitor.setBackgroundColor(colors.blue)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.clearLine()
    centerTextMonitor(monitor, "Schindler Arcade:" .. settings.get("clientName"))
    monitor.setCursorPos(1, 3)
    monitor.setBackgroundColor(colors.blue)
    centerTextMonitor(monitor, "Thanks for playing!")
    monitor.setCursorPos(1, 5)
    centerTextMonitor(monitor, "Dont forget your Disk!")
    monitor.setCursorPos(1, 10)
    monitor.write("\25\25\25\25\25\25\25\25\25\25")
    monitor.setCursorPos(1, 12)
    monitor.write("\25\25\25\25\25\25\25\25\25\25")
end

local function dumpDropper()
    local itemList = dropper.list()
    local numOfItems = 0
    if itemList ~= nil then
        for slot, item in pairs(itemList) do
            if item.name == "computercraft:disk" then
                drawDiskReminder()
            end
            numOfItems = numOfItems + item.count
        end
    end
    debugLog("numOfItems:" .. tostring(numOfItems))
    redstone.setOutput(redstoneSide, false)
    while numOfItems > 0 do
        redstone.setOutput(redstoneSide, true)
        pcall(sleep, 0.1)
        redstone.setOutput(redstoneSide, false)
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

local function loadingScreen(text)
    if type(text) == nil then
        text = ""
    end
    monitor.setBackgroundColor(colors.red)
    monitor.clear()
    monitor.setCursorPos(1, 2)
    centerTextMonitor(monitor, text)
    monitor.setCursorPos(1, 4)
    centerTextMonitor(monitor, "Loading...")
    monitor.setCursorPos(1, 6)
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

local function pay(amount)
    local event
    local status = false
    local tmp = {}
    tmp.diskdrive = settings.get("diskdrive")
    if amount == nil then
        tmp.amount = settings.get("cost")
    else
        tmp.amount = tonumber(amount)
    end
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
        monitor.setTextScale(0.5)
        shell.run("monitor", monitorSide, settings.get("launcher"))
        monitor.setTextColor(colors.white)
        monitor.setTextScale(1)
    else
        loadingScreen("Failed to make payment")
        pcall(sleep, 2)
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

local function userMenu()
    local done = false
    code = math.random(1000, 9999)
    print("code: " .. tostring(code))
    monitor.setBackgroundColor(colors.blue)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.clearLine()
    centerTextMonitor(monitor, "Connect:" .. settings.get("clientName"))
    monitor.setCursorPos(1, 3)
    monitor.setBackgroundColor(colors.blue)
    centerTextMonitor(monitor, "ID: " .. tostring(diskdrive.getDiskID()) .. " Credits: \167" .. tostring(credits))
    monitor.setCursorPos(1, 12)
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.blue)
    centerTextMonitor(monitor, "Connect Code: " .. tostring(code))
    --timeout for controller to connect
    timeoutConnectController = os.startTimer(20)

    codeServer()
    os.cancelTimer(timeoutConnectController)

    --timeout for controller to connect
    timeoutConnectController = os.startTimer(5)

    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerTextMonitor(monitor, "Schindler Arcade:" .. settings.get("clientName"))
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerTextMonitor(monitor, "ID: " .. tostring(diskdrive.getDiskID()) .. " Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 5)
        centerTextMonitor(monitor, "\167" .. tostring(settings.get("cost")) .. " Credit(s), 1 Play")
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        centerTextMonitor(monitor, "1) Play " .. settings.get("gameName"))
        monitor.setCursorPos(1, 9)
        monitor.clearLine()
        centerTextMonitor(monitor, "2) Exit")


        local event, key, x, y
        repeat
            event, key, is_held = os.pullEvent("key")
        until event == "key"

        if key == keys.one or key == keys.numPad1 then
            --play pressed
            playGame()
        elseif key == keys.two or key == keys.numPad2 then
            --exit pressed
            drawDiskReminder()

            done = true
            dumpDisk()
            dumpHopper()
            --Close connection to controller
            if controllerSocket ~= nil then
                cryptoNet.close(controllerSocket)
            end
            sleep(10)
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
        centerTextMonitor(monitor, "Schindler Arcade:" .. settings.get("clientName"))
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
    end
end

local function drawMainMenu()
    --term.setTextScale(0.5)
    --term.setCursorPos(1, 1)
    monitor.setTextColor(colors.white)
    --term.setTextColor(colors.white)

    while true do
        --term.setTextColor(colors.white)
        monitor.setTextColor(colors.white)
        drawMonitorIntro()
        --Look for floppydisk
        local diskSlot = 0
        while diskSlot == 0 do
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
            monitor.setBackgroundColor(colors.red)
            monitor.clear()
            monitor.setCursorPos(1, 2)
            centerText("Error Reading Disk")
            dumpDisk()
            pcall(sleep, 5)
        else
            diskChecker()
        end
        --sleep(10)
    end
end

local function getCraftingServerCert()
    --Download the cert from the crafting server if it doesnt exist already
    local filePath = settings.get("BankServer") .. ".crt"
    if not fs.exists(filePath) then
        print("Download the cert from the BankServer: " .. settings.get("BankServer") .. ".crt")
        cryptoNet.send(bankServerSocket, { "getCertificate" })
        --wait for reply from server
        print("wait for reply from BankServer")
        local event, data
        repeat
            event, data = os.pullEvent("gotCertificate")
        until event == "gotCertificate"

        print("write the cert file")
        --write the file
        local file = fs.open(filePath, "w")
        file.write(data)
        file.close()
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
        debugLog("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message))
        if message == "keyPressed" then
            if type(data[1]) == "number" then
                if keys.getName(data[1]) ~= "nil" then
                    debugLog("keyPressed key" .. keys.getName(data[1]) .. " is_held:" .. tostring(data[2]))
                    os.queueEvent("key", data[1], data[2])
                end
            else
                print("type(data[1]) ~= number")
            end
        elseif message == "keyReleased" then
            if type(data[1]) == "number" then
                if keys.getName(data[1]) ~= "nil" then
                    debugLog("keyReleased key" .. keys.getName(data[1]))
                    os.queueEvent("key_up", data[1])
                end
            else
                print("type(data[1]) ~= number")
            end
        elseif message == "charPressed" then
            if type(data[1]) == "string" then
                debugLog("charPressed char" .. data[1])
                os.queueEvent("char", data[1])
            end
        elseif message == "controllerConnect" then
            controllerSocket = socket
            timeoutConnectController = nil
            print("Controller connected")
        elseif message == "getControls" then
            print("Controls requested")
            local file = fs.open("controls.db", "r")
            local contents = file.readAll()
            file.close()

            local decoded = textutils.unserialize(contents)
            if type(decoded) == "table" and next(decoded) then
                print("Controls Found")
                cryptoNet.send(socket, { message, decoded })
            else
                print("Controls Not Found")
                cryptoNet.send(socket, { {} })
            end
        elseif message == "getCertificate" then
            os.queueEvent("gotCertificate", data)
        elseif message == "newID" then
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
        if event[2] == timeoutConnect or event[2] == timeoutConnectController then
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
    elseif event[1] == "quitGame" then
        print("quitGame")
        cryptoNet.closeAll()
        os.reboot()
    elseif event[1] == "requestCredits" then
        if type(event[2]) == "number" then
            getCredits(event[2])
        else
            getCredits(diskdrive.getDiskID())
        end
    elseif event[1] == "requestPay" then
        if type(event[2]) == "number" then
            pay(event[2])
        end
    end
end

local function onStart()
    os.setComputerLabel(settings.get("clientName") .. " ID:" .. tostring(os.getComputerID()))
    --clear out old log
    if fs.exists("logs/server.log") then
        fs.delete("logs/server.log")
    end
    if fs.exists("logs/serverDebug.log") then
        fs.delete("logs/serverDebug.log")
    end
    --Close any old connections and servers
    cryptoNet.closeAll()
    redstone.setOutput(redstoneSide, false)

    hopper = peripheral.wrap(settings.get("inputHopper"))
    dropper = peripheral.wrap(settings.get("outputDropper"))
    diskdrive = peripheral.wrap(settings.get("diskdrive"))
    width, height = monitor.getSize()
    --term.setTextScale(0.5)
    loadingScreen("Arcade is loading")

    dumpDisk()
    dumpHopper()
    dumpDropper()

    centerText("Connecting to server...")
    log("Connecting to server: " .. settings.get("BankServer"))

    cryptoNet.setLoggingEnabled(true)

    timeoutConnect = os.startTimer(35)
    bankServerSocket = cryptoNet.connect(settings.get("BankServer"), 30, 5, settings.get("BankServer") .. ".crt",
        modemSide)
    print("Connected!")
    --timeout no longer needed
    timeoutConnect = nil
    getCraftingServerCert()
    server = cryptoNet.host(settings.get("clientName"), true, false, wirelessModemSide)
    rednet.open(wirelessModemSide)
    drawMainMenu()
end

checkUpdates()

print("Client is loading, please wait....")

--Staggered launch
sleep((1 + math.random(30)))

--Main loop
--cryptoNet.startEventLoop(onStart, onEvent)
pcall(cryptoNet.startEventLoop, onStart, onEvent)

cryptoNet.closeAll()
dumpDisk()
redstone.setOutput(redstoneSide, false)
--os.reboot()
