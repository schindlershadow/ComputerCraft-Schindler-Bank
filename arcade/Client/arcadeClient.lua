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

local function connectToArcadeServer()
    term.clear()
    term.write("Enter Code: ")
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
        print("Connected!")
        --timeout no longer needed
        timeoutConnect = nil
        while true do
            local event, key, is_held = os.pullEvent("key")
            print(("%s held=%s"):format(keys.getName(key), is_held))
            cryptoNet.send(arcadeServer, {"key", key, is_held})
        end
    end
end

local function onEvent()

end

local function onStart()
    rednet.open(modemSide)
    connectToArcadeServer()

end

pcall(cryptoNet.startEventLoop, onStart, onEvent)
