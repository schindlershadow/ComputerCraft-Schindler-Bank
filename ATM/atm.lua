local githubFilename = "atm.lua"
local githubFolder = "ATM"
local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local controllerURL =
"https://raw.githubusercontent.com/schindlershadow/ComputerCraft-Schindler-Bank/main/controller.lua"
local dropperRedstoneSide = "right"
local doorRedstoneSide = "left"
local speaker = peripheral.wrap("top")
local timeoutConnect = nil
local timeoutConnectController = nil
local controllerTimer = nil
local bankServerSocket = nil
local controllerSocket = nil
local hopper, dropper, monitor, diskdrive, wiredModem, wirelessModem
local credits = 0
local width, height
local allowHopper = false

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
    if type(commitresponse) == "nil" then
        print("Failed to check for update")
        sleep(3)
        return
    end
    local responseCode = commitresponse.getResponseCode()
    if responseCode ~= 200 then
        print("Failed to check for update")
        sleep(3)
        return
    end
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
        local startupURL = "https://raw.githubusercontent.com/" ..
            owner .. "/" .. repo .. "/main/" .. githubFolder .. "/" .. githubFilename
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

local function resetControllerTimer()
    if controllerTimer == nil then
        controllerTimer = os.startTimer(300)
    else
        os.cancelTimer(controllerTimer)
        controllerTimer = os.startTimer(300)
    end
end

local function stopControllerTimer()
    os.cancelTimer(controllerTimer)
    controllerTimer = nil
end

local function pullDisk(slot)
    if hopper ~= nil and diskdrive ~= nil then
        if hopper.getItemDetail(slot).name == "computercraft:disk" or hopper.getItemDetail(slot).name == "computercraft:pocket_computer_advanced" then
            hopper.pushItems(peripheral.getName(diskdrive), slot, 1, 1)
        else
            print("Tried to pull nondisk item to disk drive")
            debugLog("Tried to pull nondisk item to disk drive")
        end
    else
        if hopper ~= nil then
            print("pullDisk: Hopper is nil")
        elseif diskdrive ~= nil then
            print("pullDisk: diskdrive is nil")
        end
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

local function centerText(text)
    if text == nil then
        text = ""
    end
    local x, y = monitor.getSize()
    local x1, y1 = monitor.getCursorPos()
    monitor.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    monitor.write(text)
end

local function drawTransition(color)
    local x,y = monitor.getSize()
    monitor.setBackgroundColor(color)
    for i = 1, y do
        --paintutils.drawLine(1, i, termX, i, color)
        monitor.setCursorPos(1,i)
        monitor.clearLine()
        sleep(0)
    end
end

local function loadingScreen(text)
    if type(text) == nil then
        text = ""
    end
    --monitor.setBackgroundColor(colors.red)
    --monitor.clear()
    drawTransition(colors.red)
    monitor.setCursorPos(1, 2)
    centerText(text)
    monitor.setCursorPos(1, 4)
    centerText("Loading...")
    monitor.setCursorPos(1, 6)
end

local function drawScreen(text)
    if type(text) == nil then
        text = ""
    end
    --monitor.setBackgroundColor(colors.red)
    --monitor.clear()
    drawTransition(colors.gray)
    monitor.setCursorPos(1, 2)
    centerText(text)
    monitor.setCursorPos(1, 4)
end

local function getCredits(user)
    credits = 0
    local event
    cryptoNet.send(bankServerSocket, { "getCredits", user })
    repeat
        event, credits = os.pullEvent("gotCredits")
    until event == "gotCredits"
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

local function transferCredits(toUser, amount)
    local tmp = {}
    tmp.fromUser = controllerSocket.username
    tmp.toUser = toUser
    tmp.credits = amount
    local event, status
    cryptoNet.send(bankServerSocket, { "transfer", tmp })
    repeat
        event, status = os.pullEvent("gotTransfer")
    until event == "gotTransfer"
    getCredits(controllerSocket.username)
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
    local tmp = {}
    tmp.chestname = settings.get("ClientChest")
    tmp.username = controllerSocket.username
    local event, value
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
        loadingScreen("Value of 0")
        dumpClientChest()
        done = true
    end
    while done == false do
        --monitor.setBackgroundColor(colors.blue)
        --monitor.clear()
        drawTransition(colors.blue)
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("Your Items are worth")
        monitor.setCursorPos(1, 4)
        centerText("\167" .. tostring(value) .. " Credits")
        monitor.setCursorPos(1, 5)
        centerText("Select an option")
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        centerText("1) Accept")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()
        centerText("2) Cancel")

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
            getCredits(controllerSocket.username)
            done = true
        elseif (key == keys.two or key == keys.numPad2 or key == keys.backspace) then
            --Cancel touched
            loadingScreen("Returning your items...")
            dumpClientChest()
            done = true
        end
    end
end

local function depositMenu(username)
    local done = false
    allowHopper = true
    while done == false do
        --monitor.setBackgroundColor(colors.blue)
        --monitor.clear()
        drawTransition(colors.blue)
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
        centerText("1) Done")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()
        centerText("2) Cancel")

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
    allowHopper = false
end

local function amountMenu(user)
    local done = false
    local amount = "0"
    drawTransition(colors.blue)
    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 2)
        monitor.setBackgroundColor(colors.blue)
        centerText("From: " .. tostring(controllerSocket.username))
        monitor.setCursorPos(1, 3)
        centerText("Total Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 4)
        centerText("To: " .. tostring(user))
        monitor.setCursorPos(1, 6)
        centerText("Amount: " .. tostring(amount))
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        centerText("Enter) Accept")
        monitor.setCursorPos(1, 9)
        monitor.clearLine()
        centerText("Backspace) Exit")

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key" or event == "char"

        if event == "char" and (tonumber(key, 10) ~= nil) then
            amount = amount .. tostring(key)
        elseif (key == keys.enter or key == keys.numPadEnter) then
            --Accept touched
            local creditsToTransfer = tonumber(amount)
            if type(creditsToTransfer) == "number" then
                local status = transferCredits(user, creditsToTransfer)
                if status then
                    loadingScreen("Transfer Successful!")
                    sleep(2)
                else
                    loadingScreen("Transfer Failed!")
                    sleep(2)
                end
            end
            done = true
        elseif (key == keys.backspace) then
            --exit touched
            done = true
        end
    end
end

local function transferMenu()
    local done = false
    local user = ""
    --sleep to prevent double input
    --sleep(0.2)
    drawTransition(colors.blue)
    while done == false do
        monitor.setBackgroundColor(colors.blue)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("From: " .. tostring(controllerSocket.username))
        monitor.setCursorPos(1, 4)
        centerText("Total Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 6)
        centerText("To: " .. tostring(user))
        monitor.setBackgroundColor(colors.green)

        monitor.setCursorPos(1, 8)
        monitor.clearLine()
        centerText("Enter) Accept")
        monitor.setCursorPos(1, 10)
        monitor.clearLine()
        centerText("Backspace) Exit")

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key" or event == "char"

        if event == "char" then
            user = user .. tostring(key)
        elseif (key == keys.enter or key == keys.numPadEnter) then
            --Accept
            amountMenu(user)
            done = true
        elseif (key == keys.backspace) then
            --exit
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
    while done == false do
        getCredits(controllerSocket.username)
        --monitor.setBackgroundColor(colors.blue)
        --monitor.clear()
        drawTransition(colors.blue)
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 2)
        monitor.setBackgroundColor(colors.blue)
        centerText("User: " .. tostring(controllerSocket.username))
        monitor.setCursorPos(1, 3)
        centerText("Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 5)
        centerText("Select a transaction")
        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        centerText("1) Deposit")

        monitor.setCursorPos(1, 9)
        monitor.clearLine()
        centerText("2) Transfer")

        monitor.setCursorPos(1, 11)
        monitor.clearLine()
        centerText("3) Exit")

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
            --drawDiskReminder()
            playAudioExit()
            done = true
            dumpHopper()
            --Close connection to controller
            if controllerSocket ~= nil then
                cryptoNet.close(controllerSocket)
            end
            --sleep(2)
        end
    end
    --monitor.clear()
    --monitor.setCursorPos(1,1)
    --sleep(1)
    os.queueEvent("exit")
    stopControllerTimer()
    --dumpDisk()
end

local function writeControllerFile(slot)
    print("Starting writeControllerFile")
    print("Pulling pocket computer to diskdrive")
    pullDisk(slot)

    print("Getting newest controller software")
    local response = http.get(controllerURL)
    local contents = response.readAll()
    response.close()

    --[[
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
    --]]
    print("Checking for free space")
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
            print("No space on disk")
            dumpDisk()
            dumpHopper()
            return
        end
    end


    print("Writting startup file")
    local startupFile = fs.open(diskdrive.getMountPath() .. "/startup.lua", "w")
    startupFile.write(contents)
    startupFile.close()
    --[[
    monitor.setCursorPos(1, 7)
    centerText("Complete!")
    monitor.setCursorPos(1, 9)
    centerText("Make sure to restart")
    --]]
    print("Returning Pocket Computer")
    dumpDisk()
    dumpHopper()

    --[[
    monitor.setCursorPos(1, 19)
    centerText("Dont forget your Pocket computer!")
    monitor.setCursorPos(1, 20)
    centerText("\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27")
    monitor.setCursorPos(1, 21)
    centerText("\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27\27")
    sleep(5)
    ]]
end

--Background thread that will always write controller software on pocket computers
local function controllerWriteHandler()
    print("Starting controllerWriteHandler")
    while true do
        if hopper ~= nil then
            local itemList = hopper.list()
            if itemList ~= nil and allowHopper == false then
                for slot, item in pairs(itemList) do
                    debugLog(item.name)
                    if item.name == "computercraft:pocket_computer_normal" or item.name == "computercraft:pocket_computer_advanced" then
                        writeControllerFile(slot)
                        --dumpHopper()
                        --drawMonitor()
                    else
                        dumpHopper()
                    end
                end
            end
        else
            print("Hopper is nil, check settings")
        end
        sleep(1)
    end
end

local function loginScreen()
    --monitor.setBackgroundColor(colors.blue)
    --monitor.clear()
    drawTransition(colors.blue)
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.clearLine()
    centerText("Schindler Bank ATM")
    monitor.setCursorPos(1, 3)
    monitor.setBackgroundColor(colors.blue)
    centerText("Waiting for login")
    monitor.setCursorPos(1, 5)
    centerText("Please check your")
    monitor.setCursorPos(1, 6)
    centerText("pocket computer")

    local event
    repeat
        event = os.pullEvent()
    until event == "exit" or event == "timeoutConnectController" or event == "cancelLogin"
    print("loginScreen exit reason: " .. tostring(event))
end

local function drawMonitor()
    monitor.setTextScale(1)
    monitor.setCursorPos(1, 1)

    while true do
        code = math.random(1000, 9999)
        print("code: " .. tostring(code))
        --monitor.setBackgroundColor(colors.blue)
        --monitor.clear()
        drawTransition(colors.blue)
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Bank ATM")
        monitor.setCursorPos(1, 3)
        monitor.setBackgroundColor(colors.blue)
        centerText("Welcome to Schindler Bank")
        monitor.setCursorPos(1, 6)
        centerText("Please enter code")
        monitor.setCursorPos(1, 7)
        centerText("or insert Pocket Computer")
        monitor.setCursorPos(1, 8)
        centerText("into the hopper \25\25\25")

        monitor.setCursorPos(1, 12)
        monitor.setTextColor(colors.white)
        monitor.setBackgroundColor(colors.blue)
        centerText("Connect Code: " .. tostring(code))

        codeServer()

        --timeout for controller to connect
        timeoutConnectController = os.startTimer(10)

        loginScreen()
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
    if event[1] == "login" or event[1] == "hash_login" then
        local username = event[2]
        -- The socket of the client that just logged in
        local socket = event[3]
        -- The logged-in username is also stored in the socket
        print(socket.username .. " just logged in.")
        --cryptoNet.send(bankServerSocket, { "getServerType" })

        if event[1] == "hash_login" then
            redstone.setOutput(doorRedstoneSide, true)
            playAudioReturningCustomer()
            userMenu()
            redstone.setOutput(doorRedstoneSide, false)
        end
        if username == "ATM" then
            --timeout no longer needed
            os.cancelTimer(timeoutConnect)
            timeoutConnect = nil
            getCraftingServerCert()
        else
            --login from pocket computer
            redstone.setOutput(doorRedstoneSide, true)
            --accountChecker()
            sleep(1)
            redstone.setOutput(doorRedstoneSide, false)
        end
    elseif event[1] == "encrypted_message" then
        local socket = event[3]
        if socket.username == nil then
            socket.username = "LAN Host"
        end

        if socket.username ~= "LAN Host" then
            local message = event[2][1]
            local data = event[2][2]
            log("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message))

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
            elseif message == "checkPasswordHashed" then
                os.queueEvent("gotCheckPasswordHashed", data, event[2][3])
            elseif message == "getCertificate" then
                --log("gotCertificate from: " .. socket.sender .. " target:"  )
                os.queueEvent("gotCertificate", data)
            elseif message == "newID" then
                os.queueEvent("gotNewID")
            elseif message == "checkID" then
                os.queueEvent("gotCheckID", data)
            elseif message == "getCredits" then
                os.queueEvent("gotCredits", data)
                if controllerSocket ~= nil then
                    cryptoNet.send(controllerSocket, { message, data })
                end
            elseif message == "getValue" then
                os.queueEvent("gotValue", data)
            elseif message == "depositItems" then
                os.queueEvent("gotDepositItems")
            elseif message == "transfer" then
                os.queueEvent("gotTransfer", data)
            elseif message == "addUser" then
                os.queueEvent("gotAddUser", event[2][2], event[2][3])
            end

            if controllerSocket ~= nil then
                if socket.username == controllerSocket.username then
                    resetControllerTimer()
                end
            end
        else
            --User is not logged in
            local message = event[2][1]
            local data = event[2][2]
            if message == "controllerConnect" then
                controllerSocket = socket
                os.cancelTimer(timeoutConnectController)
                timeoutConnectController = nil
                resetControllerTimer()
                print("Controller connected")
            elseif message == "hashLogin" then
                --Need to auth with server
                --debugLog("hashLogin")
                print("User login request for: " .. data.username)
                log("User login request for: " .. data.username)
                local tmp = {}
                tmp.username = data.username
                tmp.passwordHash = cryptoNet.hashPassword(data.username, data.password, settings.get("BankServer"))
                tmp.servername = data.servername
                data.password = nil
                cryptoNet.send(bankServerSocket, { "checkPasswordHashed", tmp })

                local event2
                local loginStatus = false
                local permissionLevel = 0
                repeat
                    event2, loginStatus, permissionLevel = os.pullEvent("gotCheckPasswordHashed")
                until event2 == "gotCheckPasswordHashed"
                --debugLog("loginStatus:"..tostring(loginStatus))
                if loginStatus == true then
                    cryptoNet.send(socket, { "hashLogin", true, permissionLevel })
                    socket.username = data.username
                    socket.permissionLevel = permissionLevel

                    --Update internal sockets
                    for k, v in pairs(server.sockets) do
                        if v.target == socket.target then
                            server.sockets[k] = socket
                            server.sockets[k].username = data.username
                            break
                        end
                    end
                    controllerSocket.username = data.username

                    os.queueEvent("hash_login", socket.username, socket)
                else
                    print("User: " .. data.username .. " failed to login")
                    log("User: " .. data.username .. " failed to login")
                    os.queueEvent("cancelLogin")
                    cryptoNet.send(socket, { "hashLogin", false })
                end
            elseif message == "addUser" then
                --ask server to setup new user
                local event2
                local status = false
                cryptoNet.send(bankServerSocket, { "addUser", data })
                repeat
                    event2, status, reason = os.pullEvent("gotAddUser")
                until event2 == "gotAddUser"
                cryptoNet.send(controllerSocket, { "addUser", status, reason })
                if status == true then
                    drawScreen("New User Created!")
                    playAudioNewCustomer()
                else
                    drawScreen("Failed to create user")
                    monitor.write(reason)
                end
            elseif message == "cancelLogin" then
                print("cancelLogin")
                os.queueEvent("cancelLogin")
                cryptoNet.close(controllerSocket)
                controllerSocket = nil
            elseif message == "getServerType" then
                cryptoNet.send(controllerSocket, { message, "ATM" })
            end
        end
    elseif event[1] == "timer" then
        if event[2] == timeoutConnect or event[2] == timeoutConnectController or event[2] == controllerTimer then
            --Reboot after failing to connect
            loadingScreen("Timeout, Rebooting")
            print("Timeout, Rebooting")
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
        print("Connection lost, rebooting...")
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
    drawMonitor()
end

checkUpdates()

print("Client is loading, please wait....")

cryptoNet.setLoggingEnabled(true)

if not settings.get("debug") then
    --Staggered launch
    sleep(1 + math.random(30))
end

os.startThread(controllerWriteHandler)

--Main loop
cryptoNet.startEventLoop(onStart, onEvent)

cryptoNet.closeAll()
redstone.setOutput(doorRedstoneSide, false)
redstone.setOutput(dropperRedstoneSide, false)
