local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local timeoutConnect = nil
local bankServerSocket = nil
local hopper, dropper, monitor, diskdrive
local credits = 0
local speaker = peripheral.find("speaker")
local width, height

settings.define("clientName",
    { description = "The hostname of this client", "client" .. tostring(os.getComputerID()), type = "string" })
settings.define("debug", { description = "Enables debug options", default = "false", type = "boolean" })
settings.define("BankServer", { description = "bank server hostname", default = "minecraft:barrel_0", type = "string" })
settings.define("BankChest",
    { description = "chest used for deposits on the bank network side", default = "BankServer0", type = "string" })
settings.define("ClientChest",
    { description = "chest used for deposits on the client network side", default = "BankServer0", type = "string" })
settings.define("inputHopper",
    { description = "hopper used for this ATM", default = "minecraft:hopper_0", type = "string" })
settings.define("outputDropper",
    { description = "dropper used for this ATM", default = "minecraft:dropper_0", type = "string" })
settings.define("atmMonitor",
    { description = "main monitor used for this ATM", default = "monitor_0", type = "string" })
settings.define("diskdrive",
    { description = "drive used for this host", default = "minecraft:dropper_0", type = "string" })
settings.define("password",
    { description = "password used for this host", default = "password", type = "string" })

--Settings fails to load
if settings.load() == false then
    print("No settings have been found! Default values will be used!")
    settings.set("clientName", "client" .. tostring(os.getComputerID()))
    settings.set("BankServer", "BankServer0")
    settings.set("BankChest", "minecraft:barrel_0")
    settings.set("ClientChest", "minecraft:barrel_0")
    settings.set("inputHopper", "minecraft:hopper_0")
    settings.set("outputDropper", "minecraft:dropper_0")
    settings.set("diskdrive", "drive_0")
    settings.set("atmMonitor", "monitor_0")
    settings.set("password", "password")
    settings.set("debug", false)
    print("Stop the host and edit .settings file with correct settings")
    settings.save()
    sleep(2)
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
    end
end
os.loadAPI("cryptoNet")

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
    redstone.setOutput("left", false)
    while numOfItems > 0 do
        redstone.setOutput("left", true)
        sleep(0.1)
        redstone.setOutput("left", false)
        numOfItems = numOfItems - 1
        sleep(0.1)
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

local function dumpClientChest()
    if dropper ~= nil and clientChest ~= nil then
        local itemList = clientChest.list()
        for k, v in pairs(itemList) do
            if v ~= nil and k ~= nil then
                dropper.pullItems(peripheral.getName(clientChest), k)
                dumpDropper()
            end
        end
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
    local x, y = monitor.getSize()
    local x1, y1 = monitor.getCursorPos()
    monitor.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    monitor.write(text)
end

local function loadingScreen(text)
    if type(text) == nil then
        text = ""
    end
    monitor.setBackgroundColor(colors.red)
    monitor.clear()
    monitor.setCursorPos(1, 2)
    centerText(text)
    monitor.setCursorPos(1, 4)
    centerText("Loading...")
    monitor.setCursorPos(1, 6)
end

local function getCredits(id)
    credits = 0
    local event
    cryptoNet.send(bankServerSocket, { "getCredits", id })
    repeat
        event, credits = os.pullEvent("gotCredits")
    until event == "gotCredits"
    diskdrive.setDiskLabel("ID: " .. tostring(id) .. " Credits: \167" .. tostring(credits))
    return credits
end

--Play audioFile on speaker
local function playAudio(audioFile)
    local dfpwm = require("cc.audio.dfpwm")
    local decoder = dfpwm.make_decoder()
    for chunk in io.lines(audioFile, 16 * 1024) do
        local buffer = decoder(chunk)
        while not speaker.playAudio(buffer, 3) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

--Play thank you audio
local function playAudioExit()
    playAudio("exit.dfpwm")
end

--Play new customer audio
local function playAudioNewCustomer()
    playAudio("new.dfpwm")
end

--Play returning customer audio
local function playAudioReturningCustomer()
    playAudio("returning.dfpwm")
end

--Play Deposit audio
local function playAudioDepositAccepted()
    playAudio("deposit.dfpwm")
end

local function pullItemsToClientChest()
    if clientChest ~= nil and hopper ~= nil then
        local itemList = hopper.list()
        for k, v in pairs(itemList) do
            if v ~= nil and k ~= nil then
                clientChest.pullItems(peripheral.getName(hopper), k)
            end
        end
    end
end

local function transferCredits(fromID, toID, amount)
    local tmp = {}
    tmp.fromID = fromID
    tmp.toID = toID
    tmp.credits = amount
    local event, status
    cryptoNet.send(bankServerSocket, { "transfer", tmp })
    repeat
        event, status = os.pullEvent("gotTransfer")
    until event == "gotTransfer"
    getCredits(fromID)
    return status
end

local function getValue()
    local event, value
    cryptoNet.send(bankServerSocket, { "getValue", settings.get("BankChest") })
    repeat
        event, value = os.pullEvent("gotValue")
    until event == "gotValue"
    return value
end

local function depositItems()
    local event, value
    local tmp = {}
    tmp.chestName = settings.get("BankChest")
    tmp.id = diskdrive.getDiskID()
    cryptoNet.send(bankServerSocket, { "depositItems", tmp })
    repeat
        event = os.pullEvent("gotDepositItems")
    until event == "gotDepositItems"
end

local function valueMenu()
    pullItemsToClientChest()
    local value = getValue()
    local done = false
    if value < 1 then
        loadingScreen("Value of 0, Returning your items...")
        dumpClientChest()
        done = true
    end
    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("Your Items are worth #" .. tostring(value) .. " Credits")
        monitor.setCursorPos(1, 5)
        centerText("Select an option")
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        monitor.setCursorPos(1, 8)
        monitor.clearLine()
        centerText("Accept")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerText("Cancel")
        monitor.setCursorPos(1, 13)
        monitor.clearLine()

        local event, key, x, y
        repeat
            event, key, x, y = os.pullEvent()
        until event == "monitor_touch"

        if y >= 7 and y <= 9 then
            --Accept touched
            loadingScreen("Depositing items...")
            depositItems()
            playAudioDepositAccepted()
            dumpClientChest()
            getCredits(diskdrive.getDiskID())
            done = true
        elseif y >= 11 and y <= 13 then
            --Cancel touched
            loadingScreen("Returning your items...")
            dumpClientChest()
            done = true
        end
    end
end

local function depositMenu()
    local done = false
    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("Deposit")
        monitor.setCursorPos(1, 5)
        centerText("Throw items into hopper")
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        monitor.setCursorPos(1, 8)
        monitor.clearLine()
        centerText("Done")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerText("Cancel")
        monitor.setCursorPos(1, 13)
        monitor.clearLine()

        local event, key, x, y
        repeat
            event, key, x, y = os.pullEvent()
        until event == "monitor_touch"

        if y >= 7 and y <= 9 then
            --Done touched
            valueMenu()
            done = true
        elseif y >= 11 and y <= 13 then
            --Cancel touched
            done = true
        end
    end
end

local function amountMenu(id)
    local done = false
    local amount = "0"
    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 2)
        monitor.setBackgroundColor(colors.blue)
        centerText("From: ID: " .. tostring(diskdrive.getDiskID()) .. " Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 3)
        centerText("To: ID: " .. tostring(id))
        monitor.setCursorPos(1, 5)
        centerText("Amount: " .. tostring(amount))
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(14, 7)
        monitor.write("       ")
        monitor.setCursorPos(14, 8)
        monitor.write(" 1 2 3 ")
        monitor.setCursorPos(14, 9)
        monitor.write("       ")
        monitor.setCursorPos(14, 10)
        monitor.write(" 4 5 6 ")
        monitor.setCursorPos(14, 11)
        monitor.write("       ")
        monitor.setCursorPos(14, 12)
        monitor.write(" 7 8 9 ")
        monitor.setCursorPos(14, 13)
        monitor.write("       ")
        monitor.setCursorPos(14, 14)
        monitor.write("   0   ")

        monitor.setCursorPos(1, 16)
        monitor.clearLine()
        monitor.setCursorPos(1, 17)
        monitor.clearLine()
        centerText("Accept")
        monitor.setCursorPos(1, 18)
        monitor.clearLine()

        monitor.setCursorPos(1, 20)
        monitor.clearLine()
        monitor.setCursorPos(1, 21)
        monitor.clearLine()
        centerText("Exit")
        monitor.setCursorPos(1, 22)
        monitor.clearLine()

        local event, key, x, y
        repeat
            event, key, x, y = os.pullEvent()
        until event == "monitor_touch"

        if y >= 16 and y <= 18 then
            --Accept touched
            local creditsToTransfer = tonumber(amount)
            if type(creditsToTransfer) == "number" then
                local status = transferCredits(diskdrive.getDiskID(), id, creditsToTransfer)
                if status then
                    loadingScreen("Transfer Successful!")
                    sleep(2)
                else
                    loadingScreen("Transfer Failed!")
                    sleep(2)
                end
            end
            done = true
        elseif y >= 20 and y <= 22 then
            --exit touched
            done = true
        elseif y >= 8 and y <= 14 then
            if amount == "0" then
                amount = ""
            end
            if y == 8 then
                if x == 14 + 1 then
                    amount = amount .. "1"
                elseif x == 14 + 3 then
                    amount = amount .. "2"
                elseif x == 14 + 5 then
                    amount = amount .. "3"
                end
            elseif y == 10 then
                if x == 14 + 1 then
                    amount = amount .. "4"
                elseif x == 14 + 3 then
                    amount = amount .. "5"
                elseif x == 14 + 5 then
                    amount = amount .. "6"
                end
            elseif y == 12 then
                if x == 14 + 1 then
                    amount = amount .. "7"
                elseif x == 14 + 3 then
                    amount = amount .. "8"
                elseif x == 14 + 5 then
                    amount = amount .. "9"
                end
            elseif y == 14 then
                if x == 14 + 3 then
                    amount = amount .. "0"
                end
            end
        end
    end
end

local function transferMenu()
    local done = false
    local id = "0"
    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("From: ID: " .. tostring(diskdrive.getDiskID()) .. " Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 5)
        centerText("To: ID: " .. tostring(id))
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(14, 7)
        monitor.write("       ")
        monitor.setCursorPos(14, 8)
        monitor.write(" 1 2 3 ")
        monitor.setCursorPos(14, 9)
        monitor.write("       ")
        monitor.setCursorPos(14, 10)
        monitor.write(" 4 5 6 ")
        monitor.setCursorPos(14, 11)
        monitor.write("       ")
        monitor.setCursorPos(14, 12)
        monitor.write(" 7 8 9 ")
        monitor.setCursorPos(14, 13)
        monitor.write("       ")
        monitor.setCursorPos(14, 14)
        monitor.write("   0   ")

        monitor.setCursorPos(1, 16)
        monitor.clearLine()
        monitor.setCursorPos(1, 17)
        monitor.clearLine()
        centerText("Accept")
        monitor.setCursorPos(1, 18)
        monitor.clearLine()

        monitor.setCursorPos(1, 20)
        monitor.clearLine()
        monitor.setCursorPos(1, 21)
        monitor.clearLine()
        centerText("Exit")
        monitor.setCursorPos(1, 22)
        monitor.clearLine()

        local event, key, x, y
        repeat
            event, key, x, y = os.pullEvent()
        until event == "monitor_touch"

        if y >= 16 and y <= 18 then
            --Accept touched
            amountMenu(tonumber(id))
            done = true
        elseif y >= 20 and y <= 22 then
            --exit touched
            done = true
        elseif y >= 8 and y <= 14 then
            if id == "0" then
                id = ""
            end
            if y == 8 then
                if x == 14 + 1 then
                    id = id .. "1"
                elseif x == 14 + 3 then
                    id = id .. "2"
                elseif x == 14 + 5 then
                    id = id .. "3"
                end
            elseif y == 10 then
                if x == 14 + 1 then
                    id = id .. "4"
                elseif x == 14 + 3 then
                    id = id .. "5"
                elseif x == 14 + 5 then
                    id = id .. "6"
                end
            elseif y == 12 then
                if x == 14 + 1 then
                    id = id .. "7"
                elseif x == 14 + 3 then
                    id = id .. "8"
                elseif x == 14 + 5 then
                    id = id .. "9"
                end
            elseif y == 14 then
                if x == 14 + 3 then
                    id = id .. "0"
                end
            end
        end
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
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("ID: " .. tostring(diskdrive.getDiskID()) .. " Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 5)
        centerText("Select a transaction")
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        monitor.setCursorPos(1, 8)
        monitor.clearLine()
        centerText("Deposit")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerText("Transfer")
        monitor.setCursorPos(1, 13)
        monitor.clearLine()

        monitor.setCursorPos(1, 15)
        monitor.clearLine()
        monitor.setCursorPos(1, 16)
        monitor.clearLine()
        centerText("Exit")
        monitor.setCursorPos(1, 17)
        monitor.clearLine()

        local event, key, x, y
        repeat
            event, key, x, y = os.pullEvent()
        until event == "monitor_touch"

        if y >= 7 and y <= 9 then
            --Deposit touched
            depositMenu()
        elseif y >= 11 and y <= 13 then
            --Transfer touched
            transferMenu()
        elseif y >= 15 and y <= 17 then
            --exit touched
            playAudioExit()
            done = true
            dumpHopper()
        end
    end
    dumpDisk()
end

local function diskChecker()
    local id = diskdrive.getDiskID()
    --check if disk id is registered
    local event
    local isRegistered = false
    loadingScreen("Loading information from server...")
    cryptoNet.send(bankServerSocket, { "checkID", id })
    repeat
        event, isRegistered = os.pullEvent("gotCheckID")
    until event == "gotCheckID"

    if isRegistered then
        loadingScreen("User Found, Loading credits...")
        --get credits from server
        credits = getCredits(id)
        --diskdrive.setDiskLabel("ID: " .. tostring(id) .. " Credits: " .. tostring(credits))
        playAudioReturningCustomer()
        userMenu()
    else
        --format disk and create user
        loadingScreen("Creating new User...")
        --ask server to setup new user
        event = ""
        cryptoNet.send(bankServerSocket, { "newID", id })
        repeat
            event = os.pullEvent("gotNewID")
        until event == "gotNewID"
        diskdrive.setDiskLabel("ID: " .. tostring(id) .. " Credits: \1670")
        loadingScreen("New User Created!")
        playAudioNewCustomer()
        sleep(1)
        userMenu()
    end
end

local function drawMonitor()
    monitor.setTextScale(0.5)
    monitor.setCursorPos(1, 1)

    while true do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("Welcome to Schindler Bank!")
        monitor.setCursorPos(1, 5)
        centerText("Please insert Floppy Disk")
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
                    sleep(1)
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
            sleep(5)
        else
            redstone.setOutput("right", true)
            diskChecker()
            sleep(1)
            redstone.setOutput("right", false)
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
        --timeout no longer needed
        timeoutConnect = nil

        --cryptoNet.send(bankServerSocket, { "getServerType" })

        drawMonitor()
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
            dumpClientChest()
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
        dumpClientChest()
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
    redstone.setOutput("right", false)
    redstone.setOutput("left", false)

    diskdrive = peripheral.wrap(settings.get("diskdrive"))
    hopper = peripheral.wrap(settings.get("inputHopper"))
    dropper = peripheral.wrap(settings.get("outputDropper"))
    bankChest = peripheral.wrap(settings.get("BankChest"))
    clientChest = peripheral.wrap(settings.get("ClientChest"))
    monitor = peripheral.wrap(settings.get("atmMonitor"))
    width, height = monitor.getSize()
    monitor.setTextScale(0.5)
    loadingScreen("Client is loading, please wait....")

    dumpDisk()
    dumpHopper()
    dumpDropper()

    print("Connecting to server: " .. settings.get("BankServer"))
    log("Connecting to server: " .. settings.get("BankServer"))

    timeoutConnect = os.startTimer(5+math.random(5))
    bankServerSocket = cryptoNet.connect(settings.get("BankServer"), 5, 2, settings.get("BankServer") .. ".crt", "back")
    cryptoNet.login(bankServerSocket, "ATM", settings.get("password"))
end

print("Client is loading, please wait....")

cryptoNet.setLoggingEnabled(true)

--Main loop
cryptoNet.startEventLoop(onStart, onEvent)

cryptoNet.closeAll()
redstone.setOutput("right", false)
redstone.setOutput("left", false)