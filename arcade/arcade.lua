local githubFilename = "arcade.lua"
local githubFolder = "arcade"
local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local timeoutConnect = nil
local timeoutConnectController = nil
local controllerTimer = nil
local bankServerSocket = nil
local credits = 0
local code = 0
local wirelessModemSide = "left"
local modemSide = "bottom"
local monitorSide = "back"
local controllerSocket
local monitor = peripheral.wrap(monitorSide)
local modem = peripheral.wrap(wirelessModemSide)

monitor.setTextScale(1)

settings.define("clientName",
    { description = "The hostname of this client", "client" .. tostring(os.getComputerID()), type = "string" })
settings.define("gameName",
    { description = "The name of the Game on this client", "game", type = "string" })
settings.define("launcher",
    { description = "The game launcher file", "game", type = "string" })
settings.define("debug", { description = "Enables debug options", default = "false", type = "boolean" })
settings.define("BankServer", { description = "bank server hostname", default = "minecraft:barrel_0", type = "string" })
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

local function centerText(text)
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

local function drawExit()
    monitor.setTextScale(1)
    --monitor.setBackgroundColor(colors.blue)
    --monitor.clear()
    drawTransition(colors.blue)
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.clearLine()
    centerText("Schindler Arcade:" .. settings.get("clientName"))
    monitor.setCursorPos(1, 3)
    monitor.setBackgroundColor(colors.blue)
    centerText("Thanks for playing!")
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

local function getCredits()
    credits = 0
    local event
    cryptoNet.send(bankServerSocket, { "getCredits", controllerSocket.username })
    repeat
        event, credits = os.pullEvent()
    until event == "gotCredits"
    return credits
end

local function pay(amount)
    local event
    local status = false
    local tmp = {}
    tmp.username = controllerSocket.username
    if amount == nil then
        tmp.amount = settings.get("cost")
    else
        tmp.amount = tonumber(amount)
    end
    cryptoNet.send(bankServerSocket, { "pay", tmp })
    repeat
        event, status = os.pullEvent()
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
        getCredits()
    else
        loadingScreen("Failed to make payment")
        pcall(sleep, 2)
    end
end

local function codeServer()
    while true do
        local id, message = rednet.receive()
        if type(message) == "string" then
            if message == "timeoutConnectController" then
                return
            end
        end
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
        getCredits()
        --monitor.setBackgroundColor(colors.blue)
        --monitor.clear()
        drawTransition(colors.blue)
        monitor.setCursorPos(1, 1)
        monitor.setBackgroundColor(colors.black)
        monitor.clearLine()
        centerText("Schindler Arcade:" .. settings.get("clientName"))
        monitor.setCursorPos(1, 2)
        monitor.setBackgroundColor(colors.blue)
        centerText("User: " .. tostring(controllerSocket.username))
        monitor.setCursorPos(1, 3)
        centerText("Credits: \167" .. tostring(credits))
        monitor.setCursorPos(1, 5)
        if settings.get("cost") <= 0 then
            centerText("Free to play")
        elseif settings.get("cost") == 1 then
            centerText("\167" .. tostring(settings.get("cost")) .. " Credit, 1 Play")
        else
            centerText("\167" .. tostring(settings.get("cost")) .. " Credits, 1 Play")
        end

        monitor.setBackgroundColor(colors.green)
        monitor.setCursorPos(1, 7)
        monitor.clearLine()
        centerText("1) Play " .. settings.get("gameName"))
        monitor.setCursorPos(1, 9)
        monitor.clearLine()
        centerText("2) Exit")


        local event, key, x, y
        repeat
            event, key, is_held = os.pullEvent("key")
        until event == "key" or event == "timeoutConnectController"

        if event == "timeoutConnectController" then
            drawExit()
            done = true
            --Close connection to controller
            if controllerSocket ~= nil then
                cryptoNet.close(controllerSocket)
                controllerSocket = nil
            end
            sleep(5)
        end
        if key == keys.one or key == keys.numPad1 then
            --play pressed
            playGame()
        elseif key == keys.two or key == keys.numPad2 then
            --exit pressed
            drawExit()

            done = true
            --Close connection to controller
            if controllerSocket ~= nil then
                cryptoNet.close(controllerSocket)
                controllerSocket = nil
            end
            sleep(5)
        end
    end
    stopControllerTimer()
    os.queueEvent("exit")
end

local function loginScreen()
    --monitor.setBackgroundColor(colors.blue)
    --monitor.clear()
    drawTransition(colors.blue)
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.clearLine()
    centerText("Schindler Arcade:" .. settings.get("clientName"))
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

local function drawMainMenu()
    while true do
        monitor.setTextColor(colors.white)
        if monitor ~= nil then
            code = math.random(1000, 9999)
            monitor.setTextScale(1)
            --monitor.setBackgroundColor(colors.blue)
            --monitor.clear()
            drawTransition(colors.blue)
            monitor.setCursorPos(1, 1)
            monitor.setBackgroundColor(colors.black)
            monitor.clearLine()
            centerText("Schindler Arcade:" .. settings.get("clientName"))
            monitor.setCursorPos(1, 3)
            monitor.setBackgroundColor(colors.blue)
            centerText("Welcome to " .. settings.get("gameName") .. "!")
            monitor.setCursorPos(1, 5)
            centerText(settings.get("description"))
            if string.len(settings.get("author")) > 1 then
                monitor.setCursorPos(1, 6)
                centerText("by " .. settings.get("author"))
                if settings.get("author") ~= "Schindler" then
                    monitor.setCursorPos(1, 7)
                    centerText("Forked by Schindler")
                end
            end

            monitor.setCursorPos(1, 9)
            centerText("Please enter code")
            monitor.setCursorPos(1, 10)
            if settings.get("cost") <= 0 then
                centerText("Free to play")
            elseif settings.get("cost") == 1 then
                centerText("\167" .. tostring(settings.get("cost")) .. " Credit, 1 Play")
            else
                centerText("\167" .. tostring(settings.get("cost")) .. " Credits, 1 Play")
            end

            if settings.get("debug") then
                monitor.setCursorPos(1, 11)
                monitor.setTextColor(colors.red)
                centerText("DEBUG MODE")
                monitor.setTextColor(colors.white)
            end
            monitor.setCursorPos(1, 12)
            centerText("Connect Code: " .. tostring(code))

            codeServer()

            --timeout for controller to connect
            timeoutConnectController = os.startTimer(10)

            loginScreen()
        end
    end
end

local function getServerCert()
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
    elseif event[1] == "hash_login" then
        getServerCert()
        userMenu()
    elseif event[1] == "encrypted_message" then
        local socket = event[3]

        if socket.username == nil then
            socket.username = "LAN Host"
        end
        if socket.username ~= "LAN Host" then
            local message = event[2][1]
            local data = event[2][2]
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
                if controllerSocket == nil then
                    controllerSocket = socket
                    os.cancelTimer(timeoutConnectController)
                    timeoutConnectController = nil
                    resetControllerTimer()
                    print("Controller connected")
                else
                    print("Duplicate controller conection attempt!")
                    log("Duplicate controller conection attempt!")
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
            elseif message == "pay" then
                os.queueEvent("gotPay", data)
            elseif message == "getValue" then
                os.queueEvent("gotValue", data)
            elseif message == "depositItems" then
                os.queueEvent("gotDepositItems")
            elseif message == "transfer" then
                os.queueEvent("gotTransfer", data)
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
            debugLog("Client: " .. socket.target .. " request: " .. tostring(message))
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
            elseif message == "cancelLogin" then
                print("cancelLogin")
                os.queueEvent("cancelLogin")
                cryptoNet.close(controllerSocket)
                controllerSocket = nil
            elseif message == "getServerType" then
                cryptoNet.send(controllerSocket, { message, "ARCADE" })
            end
        end
    elseif event[1] == "timer" then
        if event[2] == timeoutConnect then
            --Reboot after failing to connect
            loadingScreen("Failed to connect, rebooting...")
            cryptoNet.closeAll()
            os.reboot()
        elseif event[2] == timeoutConnectController then
            if controllerSocket ~= nil then
                cryptoNet.close(controllerSocket)
                controllerSocket = nil
            end
            os.queueEvent("rednet_message", 0, "timeoutConnectController")
            debugLog("timeoutConnectController")
            os.queueEvent("timeoutConnectController")
        elseif event[2] == controllerTimer then
            debugLog("controllerTimer")
            cryptoNet.closeAll()
            os.reboot()
        end
    elseif event[1] == "connection_closed" then
        --print(dump(event))
        --log(dump(event))
        loadingScreen("Connection lost, rebooting...")
        cryptoNet.closeAll()
        os.reboot()
    elseif event[1] == "quitGame" then
        print("quitGame")
        cryptoNet.closeAll()
        os.reboot()
    elseif event[1] == "requestCredits" then
        getCredits()
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

    --hopper = peripheral.wrap(settings.get("inputHopper"))
    --dropper = peripheral.wrap(settings.get("outputDropper"))
    --diskdrive = peripheral.wrap(settings.get("diskdrive"))
    width, height = monitor.getSize()
    --term.setTextScale(0.5)
    loadingScreen("Arcade is loading")

    centerText("Connecting to server...")
    log("Connecting to server: " .. settings.get("BankServer"))

    cryptoNet.setLoggingEnabled(true)

    timeoutConnect = os.startTimer(35)
    bankServerSocket = cryptoNet.connect(settings.get("BankServer"), 30, 5, settings.get("BankServer") .. ".crt",
        modemSide)
    cryptoNet.login(bankServerSocket, "ARCADE", settings.get("password"))
    print("Connected!")
    --timeout no longer needed
    timeoutConnect = nil
    --getServerCert()
    server = cryptoNet.host(settings.get("clientName"), true, false, wirelessModemSide)
    rednet.open(wirelessModemSide)
    drawMainMenu()
end

local function startupProgram()
    shell.run(settings.get("startupProgram"))
end

loadingScreen("Arcade is loading")
checkUpdates()

print("Client is loading, please wait....")

--Staggered launch
if not settings.get("debug") then
    sleep((1 + math.random(30)))
end

if settings.get("startupProgram") ~= nil then
    os.startThread(startupProgram)
end
--Main loop
--cryptoNet.startEventLoop(onStart, onEvent)
pcall(cryptoNet.startEventLoop, onStart, onEvent)

cryptoNet.closeAll()
--dumpDisk()
--os.reboot()
