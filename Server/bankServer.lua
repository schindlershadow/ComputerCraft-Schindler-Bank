local githubFilename = "bankServer.lua"
local githubFolder = "Server"
local cryptoNetURL = "https://raw.githubusercontent.com/SiliconSloth/CryptoNet/master/cryptoNet.lua"
local serverLAN, storageChest
local monitors = {}
local users = {}
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

local function checkIDExists(id)
    if type(id) ~= "number" then
        id = tonumber(id)
    end
    for k, v in pairs(users) do
        if v.id == id then
            return true
        end
    end
    return false
end

--write database file
local function writeDatabase()
    if fs.exists("database.db") then
        fs.delete("database.db")
    end
    local storageFile = fs.open("database.db", "w")
    storageFile.write(textutils.serialise(users))
    storageFile.close()
end

--adds new id to database
local function newID(id)
    if type(id) ~= "number" then
        id = tonumber(id)
    end
    if not checkIDExists(id) then
        local new = {}
        new.id = id
        new.credits = 0
        table.insert(users, new)
        writeDatabase()
        return true
    else
        error("Tried to add existing id as new")
        return false
    end
end

--returns number of credits id holds
local function getCredits(id)
    if type(id) ~= "number" then
        id = tonumber(id)
    end
    for k, v in pairs(users) do
        if v.id == id then
            return v.credits
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

local function addCredits(id, value)
    if type(id) ~= "number" then
        id = tonumber(id)
    end
    if type(value) ~= "number" then
        value = tonumber(value)
    end
    if id == nil or value == nil then
        return false
    end
    for k, v in pairs(users) do
        if v.id == id then
            users[k].credits = users[k].credits + value
            writeDatabase()
            return true
        end
    end
    writeDatabase()
    return false
end

local function transferCredits(fromID, toID, credits)
    if type(fromID) ~= "number" then
        fromID = tonumber(fromID)
    end
    if type(toID) ~= "number" then
        toID = tonumber(toID)
    end
    if type(credits) ~= "number" then
        credits = tonumber(credits)
    end
    if fromID == nil or toID == nil or credits == nil or credits < 1 then
        return false
    end
    if checkIDExists(fromID) and checkIDExists(toID) then
        local currentCredits = getCredits(fromID)
        if currentCredits - credits >= 0 then
            addCredits(fromID, (-1 * credits))
            addCredits(toID, credits)
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
        print(("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message)))
        log("User: " .. socket.username .. " Client: " .. socket.target .. " request: " .. tostring(message))
        debugLog("data:" .. textutils.serialise(data))
        --These can only be used by logged in users
        if socket.username ~= "LAN Host" then
            if message == "getServerType" then
                cryptoNet.send(socket, { message, "BankServer" })
            elseif message == "newID" then
                local status = newID(data)
                cryptoNet.send(socket, { message, status })
            elseif message == "checkID" then
                cryptoNet.send(socket, { message, checkIDExists(data) })
            elseif message == "getCredits" then
                cryptoNet.send(socket, { message, getCredits(data) })
            elseif message == "getValue" then
                cryptoNet.send(socket, { message, getValue(data) })
            elseif message == "transfer" then
                local fromID = data.fromID
                local toID = data.toID
                local credits = data.credits
                local status = transferCredits(fromID, toID, credits)
                cryptoNet.send(socket, { message, status })
            elseif message == "pay" then
                if type(data) == "table" then
                    local id = data.id
                    local amount = data.amount
                    if type(id) == "number" and type(data.amount) == "number" and checkIDExists(id) then
                        local credits = getCredits(id)
                        if credits - amount >= 0 then
                            log("Credits change: ID:" .. tostring(id) .. " amount:" .. tostring(-1 * amount))
                            addCredits(id, (-1 * amount))
                            cryptoNet.send(socket, { message, true })
                        else
                            cryptoNet.send(socket, { message, false })
                        end
                    else
                        cryptoNet.send(socket, { message, false })
                    end
                else
                    cryptoNet.send(socket, { message, false })
                end
            elseif message == "depositItems" then
                local chestName = data.chestName
                local id = data.id
                local value = getValue(chestName)
                depositItems(chestName)
                addCredits(id, value)
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
        else
            --These can be used by users not logged in
            if message == "getServerType" then
                cryptoNet.send(socket, { message, "BankServer" })
            elseif message == "pay" then
                if type(data) == "table" then
                    local diskdriveName = data.diskdrive
                    local amount = data.amount
                    if type(diskdriveName) == "string" and type(amount) == "number" then
                        local diskdrive = peripheral.wrap(diskdriveName)
                        if diskdrive ~= nil then
                            local id = diskdrive.getDiskID()
                            if type(id) == "number" and type(data.amount) == "number" and checkIDExists(id) then
                                local credits = getCredits(id)
                                if credits - amount >= 0 then
                                    log("Credits change: ID:" .. tostring(id) .. " amount:" .. tostring(-1 * amount))
                                    addCredits(id, (-1 * amount))
                                    cryptoNet.send(socket, { message, true })
                                else
                                    debugLog("Failed: credits + amount > 0")
                                    cryptoNet.send(socket, { message, false })
                                end
                            else
                                debugLog(
                                    "Failed: type(id) == number and type(data.amount) == number and checkIDExists(id)")
                                cryptoNet.send(socket, { message, false })
                            end
                        end
                    end
                else
                    cryptoNet.send(socket, { message, false })
                end
            elseif message == "checkID" then
                if type(data) == "string" then
                    local id = peripheral.wrap(data).getDiskID()
                    cryptoNet.send(socket, { message, checkIDExists(id) })
                end
            elseif message == "getCredits" then
                if type(data) == "string" then
                    local id = peripheral.wrap(data).getDiskID()
                    cryptoNet.send(socket, { message, getCredits(id) })
                end
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
        print("Reading User database")
        local storageFile = fs.open("database.db", "r")
        local contents = storageFile.readAll()
        storageFile.close()

        local decoded = textutils.unserialize(contents)
        if type(decoded) ~= "nil" then
            users = decoded
        else
            error("ERROR CANNOT READ DATABASE database.db")
            log("ERROR CANNOT READ DATABASE database.db")
            debugLog("ERROR CANNOT READ DATABASE database.db")
            sleep(10)
        end
    else
        print("Creating new user database")
        local storageFile = fs.open("database.db", "w")
        storageFile.write(textutils.serialise(users))
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
end

checkUpdates()
print("Server is loading, please wait....")

cryptoNet.setLoggingEnabled(true)

--Main loop
cryptoNet.startEventLoop(onStart, onEvent)

cryptoNet.closeAll()
