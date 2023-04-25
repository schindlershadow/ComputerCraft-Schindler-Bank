--------------------------------------------------
--please install this using the installer on my pastebin -wv1106
--------------------------------------------------

local limit = settings.get("maxBet") --minimum creds to play
local quit = false
local jackpot = 0


---------------------	percentage to win the following
local diamondW = 2 -- % chance to land diamond
local dollarW = 10 -- % chance to land dollar
local sevenW = 13  -- % chance to land seven
local bellW = 14   -- % chance to land bell
local orangeW = 19 -- % chance to land orange

--don't change enything after this
----------------------
local orangech = 30 --this is for asteticts no change needed
local diamondch = 5
local bellch = 20
local sevench = 15
local dollarch = 10
-------calc ast----------------
local a = 0
local b = diamondch
local c = b + bellch
local d = c + sevench
local e = d + dollarch
local f = e + orangech
local g = 100
------calc W------------
local aW = 0
local bW = diamondW
local cW = bW + dollarW
local dW = cW + sevenW
local eW = dW + bellW
local fW = eW + orangeW
local gW = 100
-----------------------
local creds = 0
local nr1 = 0
multeplier = 0
local amount = limit
-----------------------
local offset = 2
local termX, termY = term.getSize()

local function drawBox(startX, startY, endX, endY, color)
    paintutils.drawFilledBox(startX + offset, startY + offset, endX + offset, endY + offset, color)
end

local function drawLine(startX, startY, endX, endY, color)
    paintutils.drawLine(startX + offset, startY + offset, endX + offset, endY + offset, color)
end

local function drawImage(image, x, y)
    paintutils.drawImage(image, x + offset, y + offset)
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

local function debugLog(text)
    if settings.get("debug") then
        local logFile = fs.open("logs/slotsDebug.log", "a")
        if type(text) == "string" then
            logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. text)
        else
            logFile.writeLine(os.date("%A/%d/%B/%Y %I:%M%p") .. ", " .. textutils.serialise(text))
        end
        logFile.close()
    end
end
--clear out old log
if fs.exists("logs/slotsDebug.log") then
    fs.delete("logs/slotsDebug.log")
end

debugLog("bW: " .. tostring(bW))
debugLog("cW: " .. tostring(cW))
debugLog("dW: " .. tostring(dW))
debugLog("eW: " .. tostring(eW))
debugLog("fW: " .. tostring(fW))

local function getJackpot()
    if fs.exists("jackpot") then
        local file = fs.open("jackpot", "r")
        local contents = file.readAll()
        if tonumber(contents) == nil then
            jackpot = 0
        else
            jackpot = tonumber(contents)
        end

        file.close()
    else
        jackpot = 0
    end
end

local function setJackpot(number)
    if fs.exists("jackpot") then
        fs.delete("jackpot")
    end
    local file = fs.open("jackpot", "w")
    file.write(number)
    file.close()
    jackpot = number
end

local function drawJackpot()
    term.setTextColor(colors.white)
    for i = 1, 10 do
        if (i % 2 == 0) then
            term.setBackgroundColor(colors.blue)
        else
            term.setBackgroundColor(colors.red)
        end
        term.clear()
        term.setCursorPos(1, 11)
        centerText("JACKPOT WINNER")
        term.setCursorPos(1, 13)
        centerText("\167" .. tostring(jackpot) .. " CREDITS")
        sleep(0.5)
    end
    sleep(1)
end

local function drawNoCredits()
    term.setBackgroundColor(colors.black)
    term.clear()
    paintutils.drawImage(paintutils.loadImage("/dollar"), 1, 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 11)
    centerText("You're ruined!")
    term.setCursorPos(1, 13)
    term.setTextColor(colors.red)
    centerText("\1670 Credits")
    term.setTextColor(colors.white)
    sleep(5)
end

local function getCredits()
    local event
    os.queueEvent("requestCredits")
    repeat
        event, credits = os.pullEvent()
    until event == "gotCredits"
end

local function pay(number)
    local event, status
    os.queueEvent("requestPay", number)
    repeat
        event, status = os.pullEvent()
    until event == "gotPay"
    return status
end

--drawBox(1, 1, termX, termY, colors.green)
term.setBackgroundColor(colors.green)
term.clear()

function insert_amount()
    amount = 1
    --drawBox(1, 1, termX, termY, colors.green)
    term.setBackgroundColor(colors.green)
    term.clear()
    while true do
        if credits == 0 then
            debugLog("drawNoCredits")
            drawNoCredits()
            quit = true
            return
        end

        term.clear()
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clearLine()
        centerText("Schindler Slots")
        term.setBackgroundColor(colors.blue)
        term.setCursorPos(1, 2)
        term.clearLine()
        term.setCursorPos(1, 3)
        term.clearLine()
        term.setTextColor(colors.red)
        centerText("JACKPOT \167" .. tostring(jackpot))
        term.setCursorPos(1, 4)
        term.clearLine()
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)

        term.setCursorPos(18, 7)
        centerText("Credits: \167" .. tostring(credits))

        term.setCursorPos(18, 8)
        centerText("Max Bet: \167" .. tostring(limit))
        term.setCursorPos(18, 9)
        centerText("Enter -1 to quit")
        term.setCursorPos(18, 12)
        centerText("Bet Amount: \167")
        --term.setCursorPos(24, 13)
        amount = tonumber(io.read())

        if amount == -1 then
            quit = true
            return
        end
        if amount >= 0 and amount <= credits and amount <= limit then
            break
        end
    end
    --creds = creds - amount
    local status = false
    status = pay(amount)
    --writeCard()
    if not status then
        quit = true
    end
end

--------symbols-----------
local diamond = paintutils.loadImage("images/diamond.nfp") -- a,b
local bell = paintutils.loadImage("images/bell.nfp")       -- b,c
local seven = paintutils.loadImage("images/7.nfp")         -- c,d
local dollar = paintutils.loadImage("images/dollar.nfp")   -- d,e
local orange = paintutils.loadImage("images/orange.nfp")   -- e,f
local none = paintutils.loadImage("images/none.nfp")       -- the rest

function slotmachiene()
    --drawBox(1, 1, termX, termY, colors.green)
    term.setBackgroundColor(colors.green)
    term.clear()
    drawBox(5, 1, 46, 19, colors.lightGray)
    drawLine(5, 1, 5, 19, colors.white)
    drawLine(19, 1, 19, 19, colors.white)
    drawLine(33, 1, 33, 19, colors.white)
    drawLine(47, 1, 47, 19, colors.white)
    drawLine(2, 10, 5, 10, colors.gray)
    drawLine(47, 10, 50, 10, colors.gray)
end

function result()
    nr4 = math.random(100)
    --debugLog("nr4: " .. tostring(nr4))
    if nr4 < bW then
        multeplier = 2
        price = 1
    elseif nr4 < cW then
        multeplier = 1.75
        price = 2
    elseif nr4 < dW then
        multeplier = 1.5
        price = 3
    elseif nr4 < eW then
        multeplier = 1.25
        price = 4
    elseif nr4 < fW then
        multeplier = 1
        price = 5
    else
        price = 6
        multeplier = 0
    end
end

function random_1()
    drawBox(6, 1, 18, 19, colors.lightGray)
    for i = 1, 3 do
        h = (i * 6) - 4
        nr1 = math.random(100)
        if nr1 < b then
            drawImage(diamond, 8, h)
        elseif nr1 < c then
            drawImage(bell, 8, h)
        elseif nr1 < d then
            drawImage(seven, 8, h)
        elseif nr1 < e then
            drawImage(dollar, 8, h)
        elseif nr1 < f then
            drawImage(orange, 8, h)
        elseif nr1 <= 100 then
            drawImage(none, 8, h)
        end
    end
end

function random_2()
    drawBox(20, 1, 32, 19, colors.lightGray)
    for i = 4, 6 do
        h = ((i - 3) * 6) - 4
        nr2 = math.random(100)
        if nr2 < b then
            drawImage(diamond, 22, h)
        elseif nr2 < c then
            drawImage(bell, 22, h)
        elseif nr2 < d then
            drawImage(seven, 22, h)
        elseif nr2 < e then
            drawImage(dollar, 22, h)
        elseif nr2 < f then
            drawImage(orange, 22, h)
        elseif nr2 <= 100 then
            drawImage(none, 22, h)
        end
    end
end

function random_3()
    drawBox(34, 1, 46, 19, colors.lightGray)
    for i = 7, 9 do
        h = ((i - 6) * 6) - 4
        nr3 = math.random(100)
        if nr3 < b then
            drawImage(diamond, 36, h)
        elseif nr3 < c then
            drawImage(bell, 36, h)
        elseif nr3 < d then
            drawImage(seven, 36, h)
        elseif nr3 < e then
            drawImage(dollar, 36, h)
        elseif nr3 < f then
            drawImage(orange, 36, h)
        elseif nr3 <= 100 then
            drawImage(none, 36, h)
        end
    end
end

function roll()
    for x = 1, 25 do
        random_1()
        random_2()
        random_3()
        sleep(0, 5)
    end

    if price == 1 then
        drawBox(6, 7, 18, 13, colors.lightGray)
        drawImage(diamond, 8, 8)
    elseif price == 2 then
        drawBox(6, 7, 18, 13, colors.lightGray)
        drawImage(dollar, 8, 8)
    elseif price == 3 then
        drawBox(6, 7, 18, 13, colors.lightGray)
        drawImage(seven, 8, 8)
    elseif price == 4 then
        drawBox(6, 7, 18, 13, colors.lightGray)
        drawImage(bell, 8, 8)
    elseif price == 5 then
        drawBox(6, 7, 18, 13, colors.lightGray)
        drawImage(orange, 8, 8)
    end
    for x = 1, 25 do
        random_2()
        random_3()
        sleep(0, 5)
    end

    if price == 1 then
        drawBox(20, 7, 32, 13, colors.lightGray)
        drawImage(diamond, 22, 8)
    elseif price == 2 then
        drawBox(20, 7, 32, 13, colors.lightGray)
        drawImage(dollar, 22, 8)
    elseif price == 3 then
        drawBox(20, 7, 32, 13, colors.lightGray)
        drawImage(seven, 22, 8)
    elseif price == 4 then
        drawBox(20, 7, 32, 13, colors.lightGray)
        drawImage(bell, 22, 8)
    elseif price == 5 then
        drawBox(20, 7, 32, 13, colors.lightGray)
        drawImage(orange, 22, 8)
    end
    for x = 1, 25 do
        random_3()
        sleep(0, 5)
    end

    if price == 1 then
        drawBox(34, 7, 46, 13, colors.lightGray)
        drawImage(diamond, 36, 8)
    elseif price == 2 then
        drawBox(34, 7, 46, 13, colors.lightGray)
        drawImage(dollar, 36, 8)
    elseif price == 3 then
        drawBox(34, 7, 46, 13, colors.lightGray)
        drawImage(seven, 36, 8)
    elseif price == 4 then
        drawBox(34, 7, 46, 13, colors.lightGray)
        drawImage(bell, 36, 8)
    elseif price == 5 then
        drawBox(34, 7, 46, 13, colors.lightGray)
        drawImage(orange, 36, 8)
    end
end

function pricewon()
    --creds = creds + priceamount


    if multeplier == 2 then
        drawJackpot()
        priceamount = amount + jackpot
        setJackpot(0)
    else
        priceamount = amount * multeplier
    end
    won = priceamount - amount
    pay(-1 * priceamount)
    term.setBackgroundColor(colors.green)
    term.clear()
    --drawBox(1, 1, 51, 19, colors.green)
    if multeplier >= 1 then
        term.setBackgroundColor(colors.blue)
        term.clear()
        term.setCursorPos(1, 11)
        centerText("Winner!")
        term.setCursorPos(1, 13)
        centerText("\167" .. priceamount .. " Credits")
    elseif multeplier < 1 then
        setJackpot(jackpot + (amount / 2))
        term.setBackgroundColor(colors.red)
        term.clear()
        term.setCursorPos(1, 11)
        centerText("You lost")
        term.setCursorPos(1, 15)
        centerText("Better luck next time")
    end
    term.setCursorPos(16, 17)
    centerText("Press any key to continue")
    os.pullEvent("key")
    sleep(0.2)
end

function lever()
    --drawBox(1, 1, 51, 19, colors.green)
    term.setBackgroundColor(colors.green)
    term.clear()
    term.setCursorPos(1, 11)
    centerText("Press any key to roll")

    os.pullEvent("key")
end

if settings.get("debug") then
    local jp = 0
    local onep75 = 0
    local onep5 = 0
    local onep25 = 0
    local one = 0
    local zero = 0
    local runs = 1000
    local cost = 1
    local total = 0

    local results = {}
    for i = 1, runs do
        total = total - cost
        result()
        total = total + (cost * multeplier)
        table.insert(results, multeplier)
        if multeplier == 0 then
            zero = zero + 1
            jackpot = jackpot + ((cost * multeplier) / 2)
        elseif multeplier == 1 then
            one = one + 1
        elseif multeplier == 2 then
            total = total - (cost * multeplier)
            total = total + jackpot
            jackpot = 0
            jp = jp + 1
        elseif multeplier == 1.25 then
            onep25 = onep25 + 1
        elseif multeplier == 1.5 then
            onep5 = onep5 + 1
        elseif multeplier == 1.75 then
            onep75 = onep75 + 1
        end
    end
    local net = total + (runs * cost)

    debugLog("Totals")
    debugLog("0: " .. tostring(zero) .. " | " .. tostring((zero / runs) * 100) .. "%")
    debugLog("1: " .. tostring(one) .. " | " .. tostring((one / runs) * 100) .. "%")
    debugLog("1.25: " .. tostring(onep25) .. " | " .. tostring((onep25 / runs) * 100) .. "%")
    debugLog("1.5: " .. tostring(onep5) .. " | " .. tostring((onep5 / runs) * 100) .. "%")
    debugLog("1.75: " .. tostring(onep75) .. " | " .. tostring((onep75 / runs) * 100) .. "%")
    debugLog("jackpot: " .. tostring(jp) .. " | " .. tostring((jp / runs) * 100) .. "%")
    debugLog("Total: " .. tostring(total) .. " Cost: " .. tostring(runs * cost) .. " Net: " .. tostring(net))
    debugLog("Winning %: " .. tostring(100 + (total / (runs * cost) * 100)))

    --drawJackpot()
    jackpot = 0
end

---------------------
debugLog("Main Loop")
while not quit do
    --insert_card()
    --readCard()
    debugLog("getJackpot")
    getJackpot()
    debugLog("getCredits")
    getCredits()

    debugLog("insert_amount")
    insert_amount()
    if not quit then
        debugLog("lever")
        lever()
        if quit then break end
        debugLog("slotmachiene")
        slotmachiene()
        debugLog("result")
        result()
        debugLog("roll")
        roll()
        sleep(1)
        debugLog("pricewon")
        pricewon()
        --removeCard()
    end
end
