local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local arcadeServer
local modemSide = "back"
local modem = peripheral.wrap(modemSide)

if modem == nil then
    print("No Wireless Modem found")
    return
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

local function centerText(text)
    if text == nil then
        text = ""
    end
    local x, y = term.getSize()
    local x1, y1 = term.getCursorPos()
    term.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    term.write(text)
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

local function connectToArcadeServer()
    term.setCursorPos(1, 1)
    term.clear()
    print("Enter the code displayed on the monitor: ")
    local input = read()
    local code = tonumber(input)
    if code == nil then
        connectToArcadeServer()
        return
    end
    rednet.broadcast(code)
    print("waiting for reply...")
    local id, message = rednet.receive(nil, 5)
    if not id then
        printError("No reply received")
        pcall(sleep, 2)
        connectToArcadeServer()
        return
    else
        timeoutConnect = os.startTimer(5 + math.random(10))
        arcadeServer = cryptoNet.connect(message)
        cryptoNet.send(arcadeServer, { "controllerConnect" })
        cryptoNet.send(arcadeServer, { "getControls" })
        local event
        local controls = {}
        repeat
            event, controls = os.pullEventRaw()
        until event == "gotControls"
        print("Connected!")
        --timeout no longer needed
        timeoutConnect = nil
        term.clear()
        term.setCursorPos(1, 1)
        print("Controls")
        print("")
        for k, v in pairs(controls) do
            if v ~= nil and v.key ~= nil and v.discription ~= nil then
                print(tostring(v.discription) .. ": " .. tostring(v.key))
            end
        end
        while true do
            if arcadeServer ~= nil then
                local event, key, is_held
                repeat
                    event, key, is_held = os.pullEventRaw()
                until event == "key" or event == "key_up" or event == "char"
                if type(key) == "number" and keys.getName(key) ~= "nil" or event == "char" then
                    if event == "key" then
                        debugLog(("%s held=%s"):format(keys.getName(key), is_held))
                        cryptoNet.send(arcadeServer, { "keyPressed", { key, is_held } })
                    elseif event == "key_up" then
                        debugLog(keys.getName(key) .. " was released.")
                        cryptoNet.send(arcadeServer, { "keyReleased", { key } })
                    elseif event == "char" then
                        debugLog(key .. " char was pressed")
                        cryptoNet.send(arcadeServer, { "charPressed", { key } })
                    end
                end
            end
        end
    end
end

local function onEvent(event)
    if event[1] == "connection_closed" then
        --print(dump(event))
        --log(dump(event))
        print("Connection lost, rebooting...")
        cryptoNet.closeAll()
        os.reboot()
    elseif event[1] == "encrypted_message" then
        local socket = event[3]
        local message = event[2][1]
        local data = event[2][2]
        if socket.username == nil then
            socket.username = "LAN Host"
        end
        --debugLog("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message))
        if message == "getControls" then
            os.queueEvent("gotControls", data)
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
    end
end

local function drawHelp()
    term.setBackgroundColor(colors.gray)
    term.clear()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.black)
    term.clearLine()
    term.setBackgroundColor(colors.black)
    centerText("Schindler Controller")
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(1, 3)
    print(
        "Schindler controller is your interface to Schindler Bank, Schindler Arcade and Schindler casino. Throwing a Wireless Pocket computer into a Schindler Bank ATM will create this controller software.")
    term.setCursorPos(1, 20)
    centerText("Press any key to continue...")
    local event, key
    repeat
        event, key = os.pullEvent()
    until event == "key" or event == "mouse_click"
end

local function onStart()
    rednet.open(modemSide)
    while true do
        term.setBackgroundColor(colors.gray)
        term.clear()
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.clearLine()
        centerText("Schindler Controller")
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(1, 3)
        centerText("Welcome to Schindler")
        term.setCursorPos(1, 4)
        centerText("Controller!")
        term.setCursorPos(1, 6)
        centerText("Please enter an option:")
        term.setCursorPos(2, 7)
        term.write("1) Code Connect")
        term.setCursorPos(2, 8)
        term.write("2) Help")

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key"

        if (key == keys.one or key == keys.numPad1 or key == keys.enter or key == keys.numPadEnter) then
            sleep(0.2)
            connectToArcadeServer()
        elseif key == keys.two or key == keys.numPad2 then
            drawHelp()
        end
    end
end

pcall(cryptoNet.startEventLoop, onStart, onEvent)
cryptoNet.closeAll()
os.reboot()
