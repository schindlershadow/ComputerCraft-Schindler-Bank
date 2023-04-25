--------------------------------------------------
--please install this using the installer on my pastebin -wv1106
--------------------------------------------------

local limit = settings.get("maxBet") --minimum creds to play
local quit = false


---------------------	percentage to win the following
local diamondW = 2 -- % chance to land diamond
local dollarW = 3  -- % chance to land dollar
local sevenW = 4   -- % chance to land seven
local bellW = 5    -- % chance to land bell
local orangeW = 6  -- % chance to land orange




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

local function centerText(text)
    if text == nil then
        text = ""
    end
    local x, y = term.getSize()
    local x1, y1 = term.getCursorPos()
    term.setCursorPos((math.floor(x / 2) - (math.floor(#text / 2))), y1)
    term.write(text)
end

paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
function readCard()
    if not fs.exists("disk/creds.lua") then
        --os.reboot()
    end
    local Card = fs.open("disk/creds.lua", "r")
    data = Card.readAll()
    Card.close()
    a, b = string.find(data, "11066011")
    c, d = string.find(data, "11077011")
    creds = tonumber(string.sub(data, b + 1, c - 1))
    if creds < limit then
        paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
        term.clear()
        term.setCursorPos(5, 10)
        term.write("{you don't have enough credits to continiue}")
        while fs.exists("disk/") do
            sleep(0, 5)
        end
        os.reboot()
    end
end

function writeCard()
    if not fs.exists("disk/creds.lua") then
        --os.reboot()
    end
    --local Card = fs.open("disk/creds.lua", "w")
    --data = (tostring(math.random(1, 163456)) .. "11066011" .. tostring(creds) .. "11077011" .. tostring(math.random(1, 163456)))
    --Card.write(tostring(data))
    --Card.close()
    --disk.setLabel("bottom", tostring(creds) .. "$")
end

function insert_card()
    paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
    while not fs.exists("disk/") do
        term.clear()
        paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
        term.setCursorPos(16, 10)
        term.write("{please insert card}")
        sleep(1)
    end
    term.clear()
end

function insert_amount()
    amount = 1
    paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
    while true do
        if credits == 0 then
            quit = true
            return
        end

        term.clear()
        
        term.setCursorPos(18, 7)
        centerText("Credits: " .. tostring(credits))
        
        term.setCursorPos(18, 8)
        centerText("Max Bet: " .. tostring(limit))
        term.setCursorPos(18, 9)
        centerText("Enter -1 to quit")
        term.setCursorPos(18, 12)
        centerText("Bid Amount: ")
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
    paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
    paintutils.drawFilledBox(5, 1, 46, 19, colors.lightGray)
    paintutils.drawLine(5, 1, 5, 19, colors.white)
    paintutils.drawLine(19, 1, 19, 19, colors.white)
    paintutils.drawLine(33, 1, 33, 19, colors.white)
    paintutils.drawLine(47, 1, 47, 19, colors.white)
    paintutils.drawLine(2, 10, 5, 10, colors.gray)
    paintutils.drawLine(47, 10, 50, 10, colors.gray)
end

function result()
    nr4 = math.random(100)
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
    paintutils.drawFilledBox(6, 1, 18, 19, colors.lightGray)
    for i = 1, 3 do
        h = (i * 6) - 4
        nr1 = math.random(100)
        if nr1 < b then
            paintutils.drawImage(diamond, 8, h)
        elseif nr1 < c then
            paintutils.drawImage(bell, 8, h)
        elseif nr1 < d then
            paintutils.drawImage(seven, 8, h)
        elseif nr1 < e then
            paintutils.drawImage(dollar, 8, h)
        elseif nr1 < f then
            paintutils.drawImage(orange, 8, h)
        elseif nr1 <= 100 then
            paintutils.drawImage(none, 8, h)
        end
    end
end

function random_2()
    paintutils.drawFilledBox(20, 1, 32, 19, colors.lightGray)
    for i = 4, 6 do
        h = ((i - 3) * 6) - 4
        nr2 = math.random(100)
        if nr2 < b then
            paintutils.drawImage(diamond, 22, h)
        elseif nr2 < c then
            paintutils.drawImage(bell, 22, h)
        elseif nr2 < d then
            paintutils.drawImage(seven, 22, h)
        elseif nr2 < e then
            paintutils.drawImage(dollar, 22, h)
        elseif nr2 < f then
            paintutils.drawImage(orange, 22, h)
        elseif nr2 <= 100 then
            paintutils.drawImage(none, 22, h)
        end
    end
end

function random_3()
    paintutils.drawFilledBox(34, 1, 46, 19, colors.lightGray)
    for i = 7, 9 do
        h = ((i - 6) * 6) - 4
        nr3 = math.random(100)
        if nr3 < b then
            paintutils.drawImage(diamond, 36, h)
        elseif nr3 < c then
            paintutils.drawImage(bell, 36, h)
        elseif nr3 < d then
            paintutils.drawImage(seven, 36, h)
        elseif nr3 < e then
            paintutils.drawImage(dollar, 36, h)
        elseif nr3 < f then
            paintutils.drawImage(orange, 36, h)
        elseif nr3 <= 100 then
            paintutils.drawImage(none, 36, h)
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
        paintutils.drawFilledBox(6, 7, 18, 13, colors.lightGray)
        paintutils.drawImage(diamond, 8, 8)
    elseif price == 2 then
        paintutils.drawFilledBox(6, 7, 18, 13, colors.lightGray)
        paintutils.drawImage(dollar, 8, 8)
    elseif price == 3 then
        paintutils.drawFilledBox(6, 7, 18, 13, colors.lightGray)
        paintutils.drawImage(seven, 8, 8)
    elseif price == 4 then
        paintutils.drawFilledBox(6, 7, 18, 13, colors.lightGray)
        paintutils.drawImage(bell, 8, 8)
    elseif price == 5 then
        paintutils.drawFilledBox(6, 7, 18, 13, colors.lightGray)
        paintutils.drawImage(orange, 8, 8)
    end
    for x = 1, 25 do
        random_2()
        random_3()
        sleep(0, 5)
    end

    if price == 1 then
        paintutils.drawFilledBox(20, 7, 32, 13, colors.lightGray)
        paintutils.drawImage(diamond, 22, 8)
    elseif price == 2 then
        paintutils.drawFilledBox(20, 7, 32, 13, colors.lightGray)
        paintutils.drawImage(dollar, 22, 8)
    elseif price == 3 then
        paintutils.drawFilledBox(20, 7, 32, 13, colors.lightGray)
        paintutils.drawImage(seven, 22, 8)
    elseif price == 4 then
        paintutils.drawFilledBox(20, 7, 32, 13, colors.lightGray)
        paintutils.drawImage(bell, 22, 8)
    elseif price == 5 then
        paintutils.drawFilledBox(20, 7, 32, 13, colors.lightGray)
        paintutils.drawImage(orange, 22, 8)
    end
    for x = 1, 25 do
        random_3()
        sleep(0, 5)
    end

    if price == 1 then
        paintutils.drawFilledBox(34, 7, 46, 13, colors.lightGray)
        paintutils.drawImage(diamond, 36, 8)
    elseif price == 2 then
        paintutils.drawFilledBox(34, 7, 46, 13, colors.lightGray)
        paintutils.drawImage(dollar, 36, 8)
    elseif price == 3 then
        paintutils.drawFilledBox(34, 7, 46, 13, colors.lightGray)
        paintutils.drawImage(seven, 36, 8)
    elseif price == 4 then
        paintutils.drawFilledBox(34, 7, 46, 13, colors.lightGray)
        paintutils.drawImage(bell, 36, 8)
    elseif price == 5 then
        paintutils.drawFilledBox(34, 7, 46, 13, colors.lightGray)
        paintutils.drawImage(orange, 36, 8)
    end
end

function pricewon()
    priceamount = amount * multeplier
    --creds = creds + priceamount

    won = priceamount - amount
    pay(-1*priceamount)
    writeCard()
    paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
    if multeplier > 1 then
        term.clear()
        term.setCursorPos(20, 8)
        term.write("{You've won}")
        term.setCursorPos(20, 10)
        term.write(won .. " credits")
    elseif multeplier == 1 then
        term.clear()
        term.setCursorPos(20, 8)
        term.write("{You've won}")
        term.setCursorPos(20, 10)
        term.write("0 credits")
        term.setCursorPos(16, 12)
        term.write("better luck next time")
    elseif multeplier < 1 then
        term.clear()
        term.setCursorPos(18, 8)
        term.write("{You've lost}")
        term.setCursorPos(14, 10)
        term.write("better luck next time")
    end
    os.pullEvent("key")
    sleep(0.2)
end

function lever()
    paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
    term.setCursorPos(8, 8)
    term.write("{pull and release the lever to roll}")

    os.pullEvent("key")
end

function removeCard()
    term.clear()
    paintutils.drawFilledBox(1, 1, 51, 19, colors.green)
    term.setCursorPos(12, 8)
    term.write("{pull lever to roll again}")
    local Rstate = redstone.getInput("right")
    while not (Rstate == true or not fs.exists("disk/creds.lua")) do
        Rstate = redstone.getInput("right")
        sleep(0, 1)
    end
    while not (Rstate == false or not fs.exists("disk/creds.lua")) do
        Rstate = redstone.getInput("right")
        sleep(0, 1)
    end
end

---------------------
while not quit do
    --insert_card()
    --readCard()
    getCredits()
    insert_amount()
    if not quit then
        lever()
        if quit then break end
        slotmachiene()
        result()
        roll()
        sleep(1)
        pricewon()
        --removeCard()
    end
end
