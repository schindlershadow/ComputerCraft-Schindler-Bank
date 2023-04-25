local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local dropperRedstoneSide = "right"
local doorRedstoneSide = "left"
local speaker = peripheral.wrap("top")
local timeoutConnect = nil
local timeoutConnectController = nil
local bankServerSocket = nil
local controllerSocket = nil
local hopper, dropper, monitor, diskdrive, wiredModem, wirelessModem
local credits = 0
local width, height

settings.define("clientName",
    { description = "The hostname of this client", "client" .. tostring(os.getComputerID()), type = "string" })
settings.define("debug", { description = "Enables debug options", default = "false", type = "boolean" })
settings.define("BankServer", { description = "bank server hostname", default = "minecraft:barrel_0", type = "string" })
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
    redstone.setOutput(dropperRedstoneSide, false)
    while numOfItems > 0 do
        redstone.setOutput(dropperRedstoneSide, true)
        sleep(0.1)
        redstone.setOutput(dropperRedstoneSide, false)
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
        local itemName = hopper.getItemDetail(slot).name
        if itemName == "computercraft:disk" or itemName == "computercraft:pocket_computer_normal" or itemName == "computercraft:pocket_computer_advanced" then
            hopper.pushItems(peripheral.getName(diskdrive), slot, 1, 1)
            --Prevent malicious execution from diskdrive
            if fs.exists("/" .. diskdrive.getMountPath() .. "/startup") then
                fs.delete("/" .. diskdrive.getMountPath() .. "/startup")
            end
            if fs.exists("/" .. diskdrive.getMountPath() .. "/startup.lua") then
                fs.delete("/" .. diskdrive.getMountPath() .. "/startup.lua")
            end
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
    diskdrive.setDiskLabel("ID: " .. tostring(id) .. " Credits: " .. tostring(credits))
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
    cryptoNet.send(bankServerSocket, { "getValue", settings.get("ClientChest") })
    repeat
        event, value = os.pullEvent("gotValue")
    until event == "gotValue"
    return value
end

local function depositItems()
    local event, value
    local tmp = {}
    tmp.chestName = settings.get("ClientChest")
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
        centerText("1) Accept")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerText("2) Cancel")
        monitor.setCursorPos(1, 13)
        monitor.clearLine()

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key"

        if (key == keys.one or key == keys.numPad1 or key == keys.enter or key == keys.numPadEnter) then
            --Accept touched
            loadingScreen("Depositing items...")
            depositItems()
            playAudioDepositAccepted()
            dumpClientChest()
            getCredits(diskdrive.getDiskID())
            done = true
        elseif (key == keys.two or key == keys.numPad2 or key == keys.backspace) then
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
        centerText("1) Done")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerText("2) Cancel")
        monitor.setCursorPos(1, 13)
        monitor.clearLine()

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key"

        if (key == keys.one or key == keys.numPad1 or key == keys.enter or key == keys.numPadEnter) then
            --Done touched
            valueMenu()
            done = true
        elseif (key == keys.two or key == keys.numPad2 or key == keys.backspace) then
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
        centerText("A) Accept")
        monitor.setCursorPos(1, 18)
        monitor.clearLine()

        monitor.setCursorPos(1, 20)
        monitor.clearLine()
        monitor.setCursorPos(1, 21)
        monitor.clearLine()
        centerText("E) Exit")
        monitor.setCursorPos(1, 22)
        monitor.clearLine()

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key" or event == "char"

        if event == "char" and (tonumber(key, 10) ~= nil) then
            amount = amount .. tostring(key)
        elseif (key == keys.a or key == keys.enter or key == keys.numPadEnter) then
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
        elseif (key == keys.e or key == keys.backspace) then
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
        centerText("A) Accept")
        monitor.setCursorPos(1, 18)
        monitor.clearLine()

        monitor.setCursorPos(1, 20)
        monitor.clearLine()
        monitor.setCursorPos(1, 21)
        monitor.clearLine()
        centerText("E) Exit")
        monitor.setCursorPos(1, 22)
        monitor.clearLine()

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key" or event == "char"

        if event == "char" and (tonumber(key, 10) ~= nil) then
            id = id .. tostring(key)
        elseif (key == keys.a or key == keys.enter or key == keys.numPadEnter) then
            --Accept touched
            amountMenu(tonumber(id))
            done = true
        elseif (key == keys.e or key == keys.backspace) then
            --exit touched
            done = true
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

local function drawDiskReminder()
    --monitor.setTextScale(1)
    monitor.setBackgroundColor(colors.blue)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.clearLine()
    centerText("Schindler ATM")
    monitor.setCursorPos(1, 3)
    monitor.setBackgroundColor(colors.blue)
    centerText("Thank you for using")
    monitor.setCursorPos(1, 4)
    centerText("Schindler Bank")
    monitor.setCursorPos(1, 19)
    centerText("Dont forget your Disk!")
    monitor.setCursorPos(1, 20)
    centerText("\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27")
    monitor.setCursorPos(1, 21)
    centerText("\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27")
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
    centerText("Code Connect")
    monitor.setCursorPos(1, 3)
    monitor.setBackgroundColor(colors.blue)
    centerText("ID: " .. tostring(diskdrive.getDiskID()) .. " Credits: \167" .. tostring(credits))
    monitor.setCursorPos(1, 12)
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.blue)
    centerText("Connect Code: " .. tostring(code))
    --timeout for controller to connect
    timeoutConnectController = os.startTimer(20)

    codeServer()
    os.cancelTimer(timeoutConnectController)

    --timeout for controller to connect
    timeoutConnectController = os.startTimer(10)

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
        centerText("1) Deposit")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerText("2) Transfer")
        monitor.setCursorPos(1, 13)
        monitor.clearLine()

        monitor.setCursorPos(1, 15)
        monitor.clearLine()
        monitor.setCursorPos(1, 16)
        monitor.clearLine()
        centerText("3) Exit")
        monitor.setCursorPos(1, 17)
        monitor.clearLine()

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key"

        if (key == keys.one or key == keys.numPad1) then
            --Deposit touched
            depositMenu()
        elseif (key == keys.two or key == keys.numPad2) then
            --Transfer touched
            transferMenu()
        elseif (key == keys.three or key == keys.numPad3 or key == keys.backspace) then
            --exit touched
            drawDiskReminder()
            playAudioExit()
            done = true
            dumpHopper()
            --Close connection to controller
            if controllerSocket ~= nil then
                cryptoNet.close(controllerSocket)
            end
            sleep(2)
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
        diskdrive.setDiskLabel("ID: " .. tostring(id) .. " Credits: 0")
        loadingScreen("New User Created!")
        playAudioNewCustomer()
        sleep(1)
        userMenu()
    end
end

local function writeControllerFile(slot)
    pullDisk(slot)
    local file = fs.open("controller.lua", "r")
    local contents = file.readAll()
    file.close()

    monitor.setBackgroundColor(colors.blue)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.clearLine()
    centerText("Schindler ATM Controller Writer")
    monitor.setCursorPos(1, 3)
    monitor.setBackgroundColor(colors.blue)
    centerText("Pocket Computer Dectected!")
    monitor.setCursorPos(1, 5)
    centerText("Writing Controller software...")

    local freespace = fs.getFreeSpace(diskdrive.getMountPath())

    if type(freespace) == "number" then
        if freespace < 10000 then
            local files = fs.list("/" .. diskdrive.getMountPath())
            for i = 1, #files do
                print("deleting " .. files[i])
                fs.delete("/" .. diskdrive.getMountPath() .. "/" .. files[i])
            end
        end
    end

    freespace = fs.getFreeSpace(diskdrive.getMountPath())
    if type(freespace) == "number" then
        if freespace < 10000 then
            loadingScreen("No space on disk")
            dumpDisk()
            dumpHopper()
            return
        end
    end



    local startupFile = fs.open(diskdrive.getMountPath() .. "/startup.lua", "w")
    startupFile.write(contents)
    startupFile.close()
    monitor.setCursorPos(1, 7)
    centerText("Complete!")
    monitor.setCursorPos(1, 9)
    centerText("Make sure to restart")
    dumpDisk()
    dumpHopper()

    monitor.setCursorPos(1, 19)
    centerText("Dont forget your Pocket computer!")
    monitor.setCursorPos(1, 20)
    centerText("\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27")
    monitor.setCursorPos(1, 21)
    centerText("\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27")
    sleep(5)
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
        monitor.setCursorPos(1, 18)
        centerText("Please insert Floppy Disk")
        monitor.setCursorPos(1, 19)
        centerText("Or Wireless Pocket Computer")
        monitor.setCursorPos(1, 20)
        centerText("\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26")
        monitor.setCursorPos(1, 21)
        centerText("\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26\26")
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
                        elseif item.name == "computercraft:pocket_computer_normal" or item.name == "computercraft:pocket_computer_advanced" then
                            writeControllerFile(slot)
                            dumpHopper()
                            drawMonitor()
                            return
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
            redstone.setOutput(doorRedstoneSide, true)
            diskChecker()
            sleep(1)
            redstone.setOutput(doorRedstoneSide, false)
        end
        --sleep(10)
    end
end

local function getCraftingServerCert()
    --Download the cert from the crafting server if it doesnt exist already
    local filePath = settings.get("BankServer") .. ".crt"
    if not fs.exists(filePath) then
        log("Download the cert from the BankServer")
        cryptoNet.send(bankServerSocket, { "getCertificate" })
        --wait for reply from server
        log("wait for reply from BankServer")
        local event, data
        repeat
            event, data = os.pullEvent("gotCertificate")
        until event == "gotCertificate"

        log("write the cert file")
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
        --timeout no longer needed
        timeoutConnect = nil

        --cryptoNet.send(bankServerSocket, { "getServerType" })
        getCraftingServerCert()
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
        elseif message == "controllerConnect" then
            controllerSocket = socket
            timeoutConnectController = nil
            print("Controller connected")
        elseif message == "keyPressed" then
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
            --log("gotCertificate from: " .. socket.sender .. " target:"  )
            os.queueEvent("gotCertificate", data)
        end
    elseif event[1] == "timer" then
        if event[2] == timeoutConnect or event[2] == timeoutConnectController then
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
    os.setComputerLabel(settings.get("clientName") .. "ID: " .. os.getComputerID())
    --clear out old log
    if fs.exists("logs/server.log") then
        fs.delete("logs/server.log")
    end
    if fs.exists("logs/serverDebug.log") then
        fs.delete("logs/serverDebug.log")
    end
    --Close any old connections and servers
    cryptoNet.closeAll()
    redstone.setOutput(doorRedstoneSide, false)
    redstone.setOutput(dropperRedstoneSide, false)

    diskdrive = peripheral.wrap(settings.get("diskdrive"))
    hopper = peripheral.wrap(settings.get("inputHopper"))
    dropper = peripheral.wrap(settings.get("outputDropper"))
    clientChest = peripheral.wrap(settings.get("ClientChest"))
    monitor = peripheral.wrap(settings.get("atmMonitor"))
    width, height = monitor.getSize()
    monitor.setTextScale(0.5)
    loadingScreen("ATM is loading, please wait....")

    dumpDisk()
    dumpHopper()
    dumpDropper()

    print("Looking for connected modems...")

    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "modem" then
            local modem = peripheral.wrap(side)
            if modem.isWireless() then
                wirelessModem = modem
                wirelessModem.side = side
                print("Wireless modem found on " .. side .. " side")
                debugLog("Wireless modem found on " .. side .. " side")
            else
                wiredModem = modem
                wiredModem.side = side
                print("Wired modem found on " .. side .. " side")
                debugLog("Wired modem found on " .. side .. " side")
            end
        end
    end

    print("Connecting to server: " .. settings.get("BankServer"))
    log("Connecting to server: " .. settings.get("BankServer"))

    timeoutConnect = os.startTimer(35)
    bankServerSocket = cryptoNet.connect(settings.get("BankServer"), 30, 5, settings.get("BankServer") .. ".crt",
        wiredModem.side)
    cryptoNet.login(bankServerSocket, "ATM", settings.get("password"))
    print("Opening rednet on side: " .. wirelessModem.side)
    rednet.open(wirelessModem.side)
    print("Opening cryptoNet server")
    server = cryptoNet.host(settings.get("clientName"), true, false, wirelessModem.side)
end

print("Client is loading, please wait....")

cryptoNet.setLoggingEnabled(true)

--Staggered launch
sleep(1 + math.random(30))

--Main loop
cryptoNet.startEventLoop(onStart, onEvent)

cryptoNet.closeAll()
redstone.setOutput(doorRedstoneSide, false)
redstone.setOutput(dropperRedstoneSide, false)
