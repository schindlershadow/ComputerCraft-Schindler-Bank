local githubFilename = "controller.lua"
local githubFolder = ""
local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local serverSocket
local modemSide = "back"
local modem = peripheral.wrap(modemSide)
local termX, termY = term.getSize()
local username = ""
local password = ""
local credits = -1

settings.define("debug", { description = "Enables debug options", default = "false", type = "boolean" })

--Settings fails to load
if settings.load() == false then
    settings.set("debug", false)
    settings.save()
end

if modem == nil then
    print("No Wireless Modem found")
    print(
    "Place this pocket computer in a crafting table with a Wireless Modem above it to craft a Wireless Pocket Computer")
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

local function centerText(text)
    if text == nil then
        text = ""
    end
    local x, y = term.getSize()
    local x1, y1 = term.getCursorPos()
    term.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    term.write(text)
end

local function drawTransition(color)
    term.setBackgroundColor(color)
    for i = 1, termY do
        --paintutils.drawLine(1, i, termX, i, color)
        term.setCursorPos(1, i)
        term.clearLine()
        sleep(0)
    end
end

local function loadingScreen(text)
    if type(text) == nil then
        text = ""
    end
    term.setBackgroundColor(colors.red)
    --term.clear()
    drawTransition(colors.red)
    term.setCursorPos(1, 2)
    centerText(text)
    term.setCursorPos(1, 4)
    centerText("Loading...")
    term.setCursorPos(1, 6)
end

local function debugLog(text)
    if settings.get("debug") then
        local logFile = fs.open("logs/debug.log", "a")
        if type(text) == "string" then
            logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. text)
        else
            logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. textutils.serialise(text))
        end
        logFile.close()
    end
end

--Logs in using password hash
--This allows multiple servers to use a central server as an auth server
local function login(socket, user, pass, code)
    local tmp = {}
    tmp.username = user
    tmp.password = pass
    tmp.code = code
    --log("hashLogin")
    cryptoNet.send(socket, { "hashLogin", tmp })
    --mark for garbage collection
    tmp = nil
    local event
    local loginStatus = false
    local permissionLevel = 0
    timeoutConnect = os.startTimer(15)
    repeat
        event, loginStatus, permissionLevel = os.pullEvent("hashLogin")
    until event == "hashLogin"
    os.cancelTimer(timeoutConnect)
    timeoutConnect = nil
    debugLog("loginStatus:" .. tostring(loginStatus))
    if loginStatus == true then
        socket.username = user
        socket.permissionLevel = permissionLevel
        os.queueEvent("login", user, socket)
        username = user
        password = pass
        pass = nil
    else
        pass = nil
        term.setCursorPos(1, 1)
        loadingScreen("Failed to login to Server")
        --clear cached creds
        username = ""
        password = ""
        sleep(5)
        return
    end

    debugLog("Wait for the connection to finish")
    --Wait for the connection to finish
    --os.pullEvent("exit")
    local event2
    repeat
        event2 = os.pullEvent()
    until event2 == "exit"
    debugLog("exit")
end

local function userAdd(user, pass, code)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    --term.clear()
    drawTransition(colors.black)
    term.setCursorPos(1, 1)
    if string.len(pass) < 4 then
        print("Password too short!")
        sleep(3)
        return false
    end
    print("Confirm password:")
    local pass2 = read("*")
    if pass ~= pass2 then
        print("Passwords are not the same...")
        sleep(3)
        return false
    end
    loadingScreen("Creating User")

    local tmp = {}
    tmp.username = user
    tmp.password = pass
    pass = nil
    pass2 = nil

    local event, statusUserCreate, reason
    cryptoNet.send(serverSocket, { "addUser", tmp })
    repeat
        event, statusUserCreate, reason = os.pullEvent("gotAddUser")
    until event == "gotAddUser"

    local exitCode = false
    if statusUserCreate == true then
        print("User added successfully")
        exitCode = true
    else
        print("Failed to add user")
        print("Reason: " .. tostring(reason))
    end
    print("")
    print("Press any key to continue...")
    local event2
    repeat
        event2 = os.pullEvent()
    until event2 == "key" or event2 == "mouse_click"
    return exitCode
end

local function newUserMenu(serverName, code)
    local done = false
    local user = ""
    local pass = ""
    local text = ""
    local selectedField = "user"
    local width, height = term.getSize()
    drawTransition(colors.gray)
    while done == false do
        term.setBackgroundColor(colors.gray)
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.white)

        --calc the width needed to fit the server name in login box
        local border
        border = math.ceil((width - string.len(serverName) - 2) / 2)
        local widthBlanks = ""
        for i = 1, width, 1 do
            widthBlanks = widthBlanks .. " "
        end

        --print computer information
        if (settings.get("debug")) then
            term.setCursorPos(1, 1)
            term.write("DEBUG MODE")
        end
        term.setCursorPos(1, height)
        term.write("ID:" .. tostring(os.getComputerID()))


        --print(tostring(border))
        local forth = math.floor(height / 4)
        for k = forth, height - forth, 1 do
            if k == forth then
                term.setBackgroundColor(colors.black)
            else
                term.setBackgroundColor(colors.lightGray)
            end
            term.setCursorPos(1, k)
            term.write(widthBlanks)
        end

        term.setBackgroundColor(colors.black)
        term.setCursorPos(1, forth)
        centerText("New User")

        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.lightGray)
        term.setCursorPos(1, forth + 2)
        for i = border, width - border, 1 do
            term.setCursorPos(i, forth + 2)
            term.write("~")
        end
        term.setCursorPos(1, forth + 3)
        centerText(serverName)
        term.setCursorPos(1, forth + 4)
        for i = border, width - border, 1 do
            term.setCursorPos(i, forth + 4)
            term.write("~")
        end

        border = 1

        term.setCursorPos(1, forth + 5)
        centerText("Press \"TAB\" to switch")

        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
        for i = border + 6, width - border - 1, 1 do
            term.setCursorPos(i, forth + 6)
            term.write(" ")
        end
        term.setCursorPos(border + 6, forth + 6)
        term.write(user)
        term.setCursorPos(border + 1, forth + 6)
        if selectedField == "user" then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        print("User:")

        term.setBackgroundColor(colors.white)
        for i = border + 6, width - border - 1, 1 do
            term.setCursorPos(i, forth + 8)
            term.write(" ")
        end
        term.setCursorPos(border + 6, forth + 8)
        --write password sub text
        for i = 1, string.len(pass), 1 do
            term.write("*")
        end
        term.setCursorPos(border + 1, forth + 8)
        if selectedField == "pass" then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        print("Pass:")

        term.setCursorPos(border + 1, forth + 10)
        term.setBackgroundColor(colors.red)
        term.write(" Cancel ")

        term.setCursorPos(width - border - 13, forth + 10)
        term.setBackgroundColor(colors.green)
        term.write(" Create User ")

        local event, button, x, y
        repeat
            event, button, x, y = os.pullEvent()
        until event == "mouse_click" or event == "key" or event == "char"

        if event == "char" then
            local key = button
            --search = search .. key
            if selectedField == "user" then
                user = user .. key
            else
                pass = pass .. key
            end
        elseif event == "key" then
            local key = button
            if key == keys.backspace then
                --remove from text entry
                if selectedField == "user" then
                    if user == "" then
                        done = true
                    end
                    user = user:sub(1, -2)
                else
                    if pass == "" then
                        done = true
                    end
                    pass = pass:sub(1, -2)
                end
            elseif key == keys.enter or key == keys.numPadEnter then
                --login(serverSocket, user, pass, code)
                local status = userAdd(user, pass, code)
                if status == true then
                    done = true
                else
                    user = ""
                    pass = ""
                    selectedField = "user"
                end
            elseif key == keys.tab then
                --toggle user/pass text entry
                if selectedField == "user" then
                    selectedField = "pass"
                else
                    selectedField = "user"
                end
            end
        elseif event == "mouse_click" then
            --log("mouse_click x" .. tostring(x) .. " y" .. tostring(y) .. " scroll: " .. tostring(scroll))
            if y == math.floor(height / 4) + 10 then
                if (x > width - border - 13 and x < width - border - 13 + 15) then
                    --login(serverSocket, user, pass, code)
                    local status = userAdd(user, pass, code)
                    if status == true then
                        done = true
                    else
                        user = ""
                        pass = ""
                        selectedField = "user"
                    end
                elseif (x > border + 1 and x < border + 1 + 7) then
                    --cancel
                    done = true
                end
            end
        end
    end
    term.setTextColor(colors.white)
    --term.setBackgroundColor(colors.gray)
    --term.clear()
    --term.setCursorPos(1, 1)
end

local function loginMenu(serverName, code, serverType)
    if username ~= "" then
        login(serverSocket, username, password, code)
        return
    end
    local done = false
    local user = ""
    local pass = ""
    local text = ""
    local selectedField = "user"
    local width, height = term.getSize()
    drawTransition(colors.gray)
    while done == false do
        term.setBackgroundColor(colors.gray)
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.white)

        --calc the width needed to fit the server name in login box
        local border
        border = math.ceil((width - string.len(serverName) - 2) / 2)
        local widthBlanks = ""
        for i = 1, width, 1 do
            widthBlanks = widthBlanks .. " "
        end

        --print computer information
        if (settings.get("debug")) then
            term.setCursorPos(1, 1)
            term.write("DEBUG MODE")
        end
        term.setCursorPos(1, height)
        term.write("ID:" .. tostring(os.getComputerID()))


        --print(tostring(border))
        local forth = math.floor(height / 4)
        for k = forth, height - forth, 1 do
            if k == forth then
                term.setBackgroundColor(colors.black)
            else
                term.setBackgroundColor(colors.lightGray)
            end
            term.setCursorPos(1, k)
            term.write(widthBlanks)
        end

        term.setBackgroundColor(colors.black)
        term.setCursorPos(1, forth)
        centerText("User Login")

        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.lightGray)
        term.setCursorPos(1, forth + 2)
        for i = border, width - border, 1 do
            term.setCursorPos(i, forth + 2)
            term.write("~")
        end
        term.setCursorPos(1, forth + 3)
        centerText(serverName)
        term.setCursorPos(1, forth + 4)
        for i = border, width - border, 1 do
            term.setCursorPos(i, forth + 4)
            term.write("~")
        end

        border = 1

        term.setCursorPos(1, forth + 5)
        centerText("Press \"TAB\" to switch")
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
        for i = border + 6, width - border - 1, 1 do
            term.setCursorPos(i, forth + 6)
            term.write(" ")
        end
        term.setCursorPos(border + 6, forth + 6)
        term.write(user)
        term.setCursorPos(border + 1, forth + 6)
        if selectedField == "user" then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        print("User:")

        term.setBackgroundColor(colors.white)
        for i = border + 6, width - border - 1, 1 do
            term.setCursorPos(i, forth + 8)
            term.write(" ")
        end
        term.setCursorPos(border + 6, forth + 8)
        --write password sub text
        for i = 1, string.len(pass), 1 do
            term.write("*")
        end
        term.setCursorPos(border + 1, forth + 8)
        if selectedField == "pass" then
            term.setBackgroundColor(colors.green)
        else
            term.setBackgroundColor(colors.lightGray)
        end
        print("Pass:")

        term.setCursorPos(1, forth + 10)
        term.setBackgroundColor(colors.red)
        term.write(" Cancel ")
        term.setCursorPos(9, forth + 10)
        if serverName ~= "LocalHost" and serverType == "ATM" then
            term.setBackgroundColor(colors.blue)
            term.write(" New (F1)  ")
        end
        term.setCursorPos(width - 6, forth + 10)
        term.setBackgroundColor(colors.green)
        if serverName ~= "LocalHost" then
            term.write(" Login ")
        else
            term.write(" Save  ")
        end

        local event, button, is_held
        repeat
            event, button, is_held = os.pullEvent()
        until event == "mouse_click" or event == "key" or event == "char"

        if event == "char" then
            local key = button
            --search = search .. key
            if selectedField == "user" then
                user = user .. key
            else
                pass = pass .. key
            end
        elseif event == "key" then
            local key = button
            if key == keys.backspace then
                --remove from text entry
                if selectedField == "user" then
                    if user == "" and is_held == false then
                        if serverName ~= "LocalHost" then
                            cryptoNet.send(serverSocket, { "cancelLogin" })
                        end
                        done = true
                    end
                    user = user:sub(1, -2)
                else
                    if pass == "" and is_held == false then
                        if serverName ~= "LocalHost" then
                            cryptoNet.send(serverSocket, { "cancelLogin" })
                        end
                        done = true
                    end
                    pass = pass:sub(1, -2)
                end
            elseif key == keys.enter or key == keys.numPadEnter then
                if serverName ~= "LocalHost" then
                    login(serverSocket, user, pass, code)
                else
                    --update cached creds
                    username = user
                    password = pass
                end
                done = true
            elseif key == keys.tab then
                --toggle user/pass text entry
                if selectedField == "user" then
                    selectedField = "pass"
                else
                    selectedField = "user"
                end
            elseif key == keys.f1 then
                if serverName ~= "LocalHost" and serverType == "ATM" then
                    newUserMenu(serverName, code)
                    drawTransition(colors.gray)
                end
            end
        elseif event == "mouse_click" then
            --log("mouse_click x" .. tostring(x) .. " y" .. tostring(y) .. " scroll: " .. tostring(scroll))
            if y == math.floor(height / 4) + 10 then
                if (x > width - 6 and x < width - 6 + 15) then
                    if serverName ~= "LocalHost" then
                        login(serverSocket, user, pass, code)
                    else
                        --update cached creds
                        username = user
                        password = pass
                    end
                    done = true
                elseif (x > 10 and x < 9 + 7) then
                    --newuser
                    if serverName ~= "LocalHost" and serverType == "ATM" then
                        newUserMenu(serverName, code)
                        drawTransition(colors.gray)
                    end
                elseif (x > 1 and x < 7) then
                    --cancel
                    if serverName ~= "LocalHost" then
                        cryptoNet.send(serverSocket, { "cancelLogin" })
                    end
                    done = true
                end
            end
        end
    end
    term.setTextColor(colors.white)
    --term.setBackgroundColor(colors.gray)
    --term.clear()
    --term.setCursorPos(1, 1)
end

local function connectToServer()
    term.setBackgroundColor(colors.gray)
    --term.clear()
    drawTransition(colors.gray)
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.black)
    term.clearLine()
    centerText("Schindler Controller")
    sleep(0)
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(1, 6)
    term.write("Put this Pocket Computer")
    sleep(0)
    term.setCursorPos(1, 7)
    term.write("in your offhand")
    sleep(0)
    term.setCursorPos(1, 9)
    term.write("Enter the code displayed")
    sleep(0)
    term.setCursorPos(1, 10)
    term.write("on the monitor")
    sleep(0)
    term.setCursorPos(1, 12)
    term.write("Enter 0 to exit")
    sleep(0)
    paintutils.drawFilledBox(1, termY, 6, termY, colors.darkGrey)
    sleep(0)
    term.setCursorPos(1, termY)
    term.write("CODE: ")
    sleep(0)
    paintutils.drawFilledBox(7, termY, termX, termY, colors.white)
    term.setCursorPos(8, termY)
    term.setTextColor(colors.black)
    local input = read()
    local code = tonumber(input)
    term.setTextColor(colors.white)

    if code == nil then
        return
    elseif code == 0 or code < 1000 or code > 9999 then
        return
    end
    rednet.broadcast(code)
    print("waiting for reply...")
    local id, message = rednet.receive(nil, 5)
    if not id then
        printError("No reply received")
        pcall(sleep, 2)
        connectToServer()
        return
    else
        --term.clear()
        loadingScreen("Connecting")
        timeoutConnect = os.startTimer(15)
        serverSocket = cryptoNet.connect(message, 30, 5)
        --timeout no longer needed
        os.cancelTimer(timeoutConnect)
        timeoutConnect = nil
        cryptoNet.send(serverSocket, { "controllerConnect" })
        cryptoNet.send(serverSocket, { "getServerType" })
        local event, serverType
        repeat
            event, serverType = os.pullEventRaw()
        until event == "gotServerType"
        debugLog("serverType: " .. tostring(serverType))
        loginMenu(message, code, serverType)
    end
end

local function onEvent(event)
    if event[1] == "login" then
        cryptoNet.send(serverSocket, { "getControls" })
        local controlsEvent
        local controls = {}
        repeat
            controlsEvent, controls = os.pullEventRaw()
        until controlsEvent == "gotControls"
        print("Connected!")

        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        --term.clear()
        drawTransition(colors.black)
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.blue)
        term.clearLine()
        centerText("Schindler Controller")
        sleep(0)
        term.setCursorPos(1, 2)
        term.setBackgroundColor(colors.gray)
        term.clearLine()
        centerText("Controls")
        sleep(0)
        term.setBackgroundColor(colors.black)
        term.setCursorPos(1, 3)
        --debugLog("controls:" .. textutils.serialise(controls))
        for k, v in pairs(controls) do
            if v ~= nil and v.key ~= nil and v.discription ~= nil then
                print(tostring(v.discription) .. ": " .. tostring(v.key))
                sleep(0)
            end
        end
        while true do
            if serverSocket ~= nil then
                local event3, key, is_held
                repeat
                    event3, key, is_held = os.pullEventRaw()
                until event3 == "key" or event3 == "key_up" or event3 == "char" or event3 == "exit"

                if event3 == "exit" then
                    return
                elseif type(key) == "number" and keys.getName(key) ~= "nil" or event3 == "char" then
                    if event3 == "key" then
                        debugLog(("%s held=%s"):format(keys.getName(key), is_held))
                        cryptoNet.send(serverSocket, { "keyPressed", { key, is_held } })
                    elseif event3 == "key_up" then
                        debugLog(keys.getName(key) .. " was released.")
                        cryptoNet.send(serverSocket, { "keyReleased", { key } })
                    elseif event3 == "char" then
                        debugLog(key .. " char was pressed")
                        cryptoNet.send(serverSocket, { "charPressed", { key } })
                    end
                end
            end
        end
    elseif event[1] == "connection_closed" then
        --print(dump(event))
        --log(dump(event))
        print("Connection lost")
        cryptoNet.closeAll()
        os.queueEvent("exit")
        --os.reboot()
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
            credits = data
        elseif message == "pay" then
            os.queueEvent("gotPay", data)
        elseif message == "getValue" then
            os.queueEvent("gotValue", data)
        elseif message == "depositItems" then
            os.queueEvent("gotDepositItems")
        elseif message == "transfer" then
            os.queueEvent("gotTransfer", data)
        elseif message == "hashLogin" then
            os.queueEvent("hashLogin", event[2][2], event[2][3])
        elseif message == "addUser" then
            os.queueEvent("gotAddUser", event[2][2], event[2][3])
        elseif message == "getServerType" then
            os.queueEvent("gotServerType", data)
        end
    elseif event[1] == "timer" then
        if event[2] == timeoutConnect then
            cryptoNet.closeAll()
            os.reboot()
        end
    end
end

local function drawHelp()
    term.setBackgroundColor(colors.gray)
    --term.clear()
    drawTransition(colors.gray)
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.black)
    term.clearLine()
    centerText("Schindler Controller")
    sleep(0)
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(1, 3)
    textutils.slowPrint(
        "Schindler controller is your interface to Schindler Bank, Schindler Arcade and Schindler casino. Throwing a Wireless Pocket computer into a Schindler Bank ATM will create this controller software.",
        40)
    sleep(0)
    term.setCursorPos(1, 20)
    centerText("Press any key to continue...")
    local event, key
    repeat
        event, key = os.pullEvent()
    until event == "key" or event == "mouse_click"
end

local function onStart()
    rednet.open(modemSide)
    drawTransition(colors.gray)
    while true do
        term.setBackgroundColor(colors.gray)
        term.clear()
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.clearLine()
        centerText("Schindler Controller")
        sleep(0)
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(1, 3)
        centerText("Welcome to Schindler")
        sleep(0)
        term.setCursorPos(1, 4)
        centerText("Controller!")
        sleep(0)
        term.setCursorPos(1, 6)
        if username == "" then
            centerText("Not logged in!")
            sleep(0)
        else
            centerText("Hello " .. username)
            sleep(0)
            term.setCursorPos(1, 7)
            centerText("Your login is cached")
            sleep(0)
            if credits ~= -1 then
                term.setCursorPos(1, 8)
                centerText("Credits: \167" .. tostring(credits))
                sleep(0)
            end
        end
        term.setCursorPos(1, 10)
        centerText("Please enter an option:")
        sleep(0)
        term.setCursorPos(2, 11)
        term.write("1) Code Connect")
        sleep(0)
        term.setCursorPos(2, 12)
        term.write("2) Help")
        sleep(0)
        term.setCursorPos(2, 13)
        if username ~= "" then
            term.write("3) Logout")
        else
            term.write("3) Cache login")
        end
        term.setCursorPos(1, 20)
        term.write("ID:" .. os.getComputerID())
        term.setCursorPos(1, 1)

        local event, key
        repeat
            event, key = os.pullEvent()
        until event == "key"

        if (key == keys.one or key == keys.numPad1 or key == keys.enter or key == keys.numPadEnter) then
            sleep(0.2)
            connectToServer()
            drawTransition(colors.gray)
        elseif key == keys.two or key == keys.numPad2 then
            drawHelp()
            drawTransition(colors.gray)
        elseif key == keys.three or key == keys.numPad3 then
            if username ~= "" then
                username = ""
                password = ""
            else
                sleep(0.2)
                --Cache login
                loginMenu("LocalHost", 0, "LocalHost")
                drawTransition(colors.gray)
            end
        end
    end
end


if not settings.get("debug") then
    checkUpdates()
end
cryptoNet.setLoggingEnabled(false)
pcall(cryptoNet.startEventLoop, onStart, onEvent)
cryptoNet.closeAll()
if not settings.get("debug") then
    os.reboot()
end
