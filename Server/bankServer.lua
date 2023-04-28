local githubFilename = "bankServer.lua"
local githubFolder = "Server"
local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local serverLAN, storageChest
local monitors = {}
local creditsDB = {}
local valueList = {}

settings.define("serverName",
    { description = "The hostname of this server", "BankServer" .. tostring(os.getComputerID()), type = "string" })
settings.define("StorageChest",
    {
        description = "The Chest used for storage",
        "ironchests:diamond_chest_1" .. tostring(os.getComputerID()),
        type = "string"
    })
settings.define("debug", { description = "Enables debug options", default = "false", type = "boolean" })
settings.define("bankMonitors",
    { description = "main monitor used for this bank server", default = { "monitor_0" }, type = "table" })

--Settings fails to load
if settings.load() == false then
    print("No settings have been found! Default values will be used!")
    settings.set("serverName", "BankServer" .. tostring(os.getComputerID()))
    settings.set("StorageChest", "ironchests:diamond_chest_1")
    settings.set("debug", false)
    settings.set("bankMonitors", { "monitor_0" })
    print("Stop the server and edit .settings file with correct settings")
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

--write database file
local function writeDatabase()
    if fs.exists("database.db") then
        fs.delete("database.db")
    end
    local storageFile = fs.open("database.db", "w")
    storageFile.write(textutils.serialise(creditsDB))
    storageFile.close()
end

--returns number of credits user holds
local function getCredits(username)
    if type(username) ~= "string" then
        return 0
    end
    if creditsDB[username] ~= nil then
        if creditsDB[username].username == username then
            return creditsDB[username].credits
        end
    end
    return 0
end

local function getItemValue(itemName)
    for k, v in pairs(valueList) do
        if v ~= nil and k ~= nil and v.name == itemName then
            return v.value
        end
    end
    return 0
end

local function getValue(chestName)
    if type(chestName) ~= "string" or chestName == "nil" then
        return 0
    end
    local chest = peripheral.wrap(chestName)
    local itemList = chest.list()
    local total = 0
    for k, item in pairs(itemList) do
        if item ~= nil and k ~= nil then
            local value = getItemValue(item.name)
            total = total + (value * item.count)
        end
    end
    return total
end

local function centerText(monitor, text)
    if text == nil then
        text = ""
    end
    local x, y = monitor.getSize()
    local x1, y1 = monitor.getCursorPos()
    monitor.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    monitor.write(text)
end

local function printMonitorValue()
    if monitors ~= nil then
        for k, monitorName in pairs(monitors) do
            local monitor = peripheral.wrap(monitorName)
            if monitor ~= nil then
                monitor.setTextScale(1)
                monitor.clear()
                monitor.setCursorPos(1, 1)
                centerText(monitor, "Item deposit value list")
                local line = 3
                for k, v in pairs(valueList) do
                    if v ~= nil and k ~= nil then
                        monitor.setCursorPos(1, line)
                        centerText(monitor, v.name .. ": \167" .. tostring(v.value))
                        line = line + 1
                    end
                end
            end
        end
    end
end

local function depositItems(chestName)
    local chest = peripheral.wrap(chestName)
    local itemList = chest.list()
    for k, item in pairs(itemList) do
        if item ~= nil and k ~= nil and getItemValue(item.name) > 0 then
            storageChest.pullItems(peripheral.getName(chest), k)
        end
    end
end

local function addCredits(username, value)
    if type(username) ~= "string" then
        return false
    end
    if type(value) ~= "number" then
        return false
    end
    if creditsDB[username] ~= nil then
        if creditsDB[username].username == username then
            creditsDB[username].credits = creditsDB[username].credits + value
            writeDatabase()
            return true
        end
    else
        print("user: " .. username .. " not found in database" )
    end
    --writeDatabase()
    return false
end

local function transferCredits(fromUser, toUser, credits)
    if type(fromUser) ~= "string" then
        return false
    end
    if type(toUser) ~= "string" then
        return false
    end
    if type(credits) ~= "number" then
        return false
    end
    if credits < 1 then
        return false
    end
    if creditsDB[fromUser] ~= nil and creditsDB[toUser] ~= nil then
        local currentCredits = getCredits(fromUser)
        if currentCredits - credits >= 0 then
            print("Credit trasfer from " .. fromUser .." to " .. toUser .. " amount:" .. tostring(credits))
            addCredits(fromUser, (-1 * credits))
            addCredits(toUser, credits)
            writeDatabase()
            return true
        else
            return false
        end
    else
        return false
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
    elseif event[1] == "encrypted_message" then
        local socket = event[3]
        local message = event[2][1]
        local data = event[2][2]
        if socket.username == nil then
            socket.username = "LAN Host"
        end
        print(("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message)))
        log("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message))
        debugLog("data:" .. textutils.serialise(data))
        --These can only be used by logged in users
        if socket.username ~= "LAN Host" then
            if message == "getServerType" then
                cryptoNet.send(socket, { message, "BankServer" })
            elseif message == "addUser" then
                print(socket.username .. " requested: " .. tostring(message))
                print("Request to add user: " .. data.username)
                log("Request to add user: " .. data.username)
                local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN)
                print("Permission Level:" .. tostring(permissionLevel))
                local userExists = cryptoNet.userExists(data.username, serverLAN)
                if permissionLevel >= 2 and not userExists and type(data.password) == "string" then
                    cryptoNet.addUser(data.username, data.password, 1, serverLAN)
                    creditsDB[data.username] = {}
                    creditsDB[data.username].username = data.username
                    creditsDB[data.username].credits = 0
                    cryptoNet.send(socket, { message, true, "Success" })
                    writeDatabase()
                else
                    print("Failed to create user")
                    if not userExists then
                        print("User already exists")
                        cryptoNet.send(socket, { message, false, "User already exists" })
                    elseif type(data.password) ~= "string" then
                        print("Password has invalid characters")
                        cryptoNet.send(socket, { message, false, "Password has invalid characters" })
                    elseif not (permissionLevel >= 2) then
                        print("Permission issues")
                        cryptoNet.send(socket, { message, false, "Permission issues" })
                    else
                        print("Unknown error")
                        cryptoNet.send(socket, { message, false, "Unknown error" })
                    end
                end
            elseif message == "setPassword" then
                print(socket.username .. " requested: " .. tostring(message))
                local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN)
                local userExists = cryptoNet.userExists(data.username, serverLAN)
                debugLog("setPassword:" ..
                    socket.username ..
                    ":" .. data.username .. ":" .. tostring(permissionLevel) .. ":" .. tostring(userExists))
                if tonumber(permissionLevel) >= 2 and userExists and type(data.password) == "string" then
                    cryptoNet.setPassword(data.username, data.password, serverLAN)
                    cryptoNet.send(socket, { message, true })
                elseif userExists and data.username == socket.username then
                    cryptoNet.setPassword(data.username, data.password, serverLAN)
                    cryptoNet.send(socket, { message, true })
                else
                    cryptoNet.send(socket, { message, false })
                end
            elseif message == "deleteUser" then
                print(socket.username .. " requested: " .. tostring(message))
                print("Request to delete user: " .. data.username)
                log("Request to delete user: " .. data.username)
                local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN)
                local userExists = cryptoNet.userExists(data.username, serverLAN)
                if permissionLevel >= 2 and userExists then
                    local userPermissionLevel = cryptoNet.getPermissionLevel(data.username, serverLAN)
                    if userPermissionLevel < 3 then
                        cryptoNet.deleteUser(data.username, serverLAN)
                        cryptoNet.send(socket, { message, true })
                        creditsDB[username] = nil
                        writeDatabase()
                    else
                        --super admins cannot be deleted
                        cryptoNet.send(socket, { message, false })
                    end
                else
                    cryptoNet.send(socket, { message, false })
                end
            elseif message == "checkPasswordHashed" then
                local permissionLevel = cryptoNet.getPermissionLevel(socket.username, serverLAN)
                -- check if user has perms or if on lan when logins are not required
                if tonumber(permissionLevel) >= 2 then
                    local check = cryptoNet.checkPasswordHashed(data.username, data.passwordHash, serverLAN)
                    if check then
                        permissionLevel = cryptoNet.getPermissionLevel(data.username, serverLAN)
                        cryptoNet.send(socket, { message, true, permissionLevel })
                    else
                        cryptoNet.send(socket, { message, false, 0 })
                    end
                end
            elseif message == "getCredits" then
                cryptoNet.send(socket, { message, getCredits(data) })
            elseif message == "getValue" then
                cryptoNet.send(socket, { message, getValue(data) })
            elseif message == "transfer" then
                local fromUser = data.fromUser
                local toUser = data.toUser
                local credits = data.credits
                
                local status = transferCredits(fromUser, toUser, credits)
                cryptoNet.send(socket, { message, status })
            elseif message == "pay" then
                if type(data) == "table" then
                    local username = data.username
                    local amount = data.amount
                    if type(username) == "string" and type(amount) == "number" then
                        if creditsDB[username] ~= nil then
                            local credits = getCredits(username)
                            if credits - amount >= 0 then
                                log("Credits change: user:" .. username .. " amount:" .. tostring(-1 * amount))
                                addCredits(username, (-1 * amount))
                                cryptoNet.send(socket, { message, true })
                            else
                                debugLog("Failed: credits + amount > 0")
                                cryptoNet.send(socket, { message, false })
                            end
                        else
                            debugLog("Failed creditsDB[username] ~= nil")
                            cryptoNet.send(socket, { message, false })
                        end
                    end
                else
                    cryptoNet.send(socket, { message, false })
                end
            elseif message == "depositItems" then
                local chestName = data.chestname
                local username = data.username
                print("depositItems user:" .. username .." chestname:" .. chestName)
                --local id = data.id
                local value = getValue(chestName)
                print("adding " .. tostring(value) .. " credits")
                depositItems(chestName)
                addCredits(username, value)
                cryptoNet.send(socket, { message })
            elseif message == "getCertificate" then
                local fileContents = nil
                print("Sending Cert " .. socket.sender .. ".crt")
                local filePath = socket.sender .. ".crt"
                if fs.exists(filePath) then
                    local file = fs.open(filePath, "r")
                    fileContents = file.readAll()
                    file.close()
                end
                cryptoNet.send(socket, { message, fileContents })
            end
        elseif event[2] ~= nil then
            --User is not logged in
            if message == "hashLogin" then
                --Need to auth with bank server
                --debugLog("hashLogin")
                print("User login request for: " .. data.username)
                log("User login request for: " .. data.username)
                local loginStatus = cryptoNet.checkPassword(data.username, data.password, serverLAN)
                data.password = nil
                local permissionLevel = cryptoNet.getPermissionLevel(data.username, serverLAN)
                --debugLog("loginStatus:"..tostring(loginStatus))
                if loginStatus == true then
                    cryptoNet.send(socket, { "hashLogin", true, permissionLevel })
                    socket.username = data.username
                    socket.permissionLevel = permissionLevel

                    --Update internal sockets
                    for k, v in pairs(serverLAN.sockets) do
                        if v.target == socket.target then
                            serverLAN.sockets[k] = socket
                            break
                        end
                    end
                    os.queueEvent("hash_login", socket.username, socket)
                else
                    print("User: " .. data.username .. " failed to login")
                    log("User: " .. data.username .. " failed to login")
                    cryptoNet.send(socket, { "hashLogin", false })
                end
            else
                debugLog("User is not logged in. Sender: " .. socket.sender .. " Target: " .. socket.target)
                cryptoNet.send(socket, "Sorry, I only talk to logged in users")
            end
        end
    end
end

local function onStart()
    os.setComputerLabel(settings.get("serverName"))
    --clear out old log
    if fs.exists("logs/server.log") then
        fs.delete("logs/server.log")
    end
    if fs.exists("logs/serverDebug.log") then
        fs.delete("logs/serverDebug.log")
    end
    --Close any old connections and servers
    cryptoNet.closeAll()

    storageChest = peripheral.wrap(settings.get("StorageChest"))
    monitors = settings.get("bankMonitors")

    --Read user database from disk
    if fs.exists("database.db") then
        print("Reading credits database")
        local storageFile = fs.open("database.db", "r")
        local contents = storageFile.readAll()
        storageFile.close()

        local decoded = textutils.unserialize(contents)
        if type(decoded) ~= "nil" then
            creditsDB = decoded
        else
            error("ERROR CANNOT READ DATABASE database.db")
            log("ERROR CANNOT READ DATABASE database.db")
            debugLog("ERROR CANNOT READ DATABASE database.db")
            sleep(10)
        end
    else
        print("Creating new credits database")
        local storageFile = fs.open("database.db", "w")
        storageFile.write(textutils.serialise(creditsDB))
        storageFile.close()
    end

    --Read item database from disk
    if fs.exists("items.db") then
        print("Reading Item database")
        local storageFile = fs.open("items.db", "r")
        local contents = storageFile.readAll()
        storageFile.close()

        local decoded = textutils.unserialize(contents)
        if type(decoded) ~= "nil" then
            valueList = decoded
        else
            error("ERROR CANNOT READ DATABASE items.db")
            log("ERROR CANNOT READ DATABASE items.db")
            debugLog("ERROR CANNOT READ DATABASE items.db")
            sleep(10)
        end
    else
        print("Creating new item database")
        local storageFile = fs.open("items.db", "w")
        storageFile.write(textutils.serialise(valueList))
        storageFile.close()
    end

    printMonitorValue()

    serverLAN = cryptoNet.host(settings.get("serverName"), true, false)
    if cryptoNet.userExists("ATM", serverLAN) == false then
        print("User ATM not found")
        print("Enter new ATM User Password:")
        local inputPass = read()
        print("Creating ATM user")
        cryptoNet.addUser("ATM", inputPass, 3, serverLAN)
    end
end

--checkUpdates()
print("Server is loading, please wait....")

cryptoNet.setLoggingEnabled(true)

--Main loop
cryptoNet.startEventLoop(onStart, onEvent)

cryptoNet.closeAll()
