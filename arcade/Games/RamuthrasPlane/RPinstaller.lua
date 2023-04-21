-- ElvishJerricco's JSON parser
-- http://www.computercraft.info/forums2/index.php?/topic/5854-json-api-v201-for-computercraft/
------------------------------------------------------------------ utils
local controls = {["\n"]="\\n", ["\r"]="\\r", ["\t"]="\\t", ["\b"]="\\b", ["\f"]="\\f", ["\""]="\\\"", ["\\"]="\\\\"}
 
local function isArray(t)
	local max = 0
	for k,v in pairs(t) do
		if type(k) ~= "number" then
			return false
		elseif k > max then
			max = k
		end
	end
	return max == #t
end
 
local whites = {['\n']=true; ['\r']=true; ['\t']=true; [' ']=true; [',']=true; [':']=true}
function removeWhite(str)
	while whites[str:sub(1, 1)] do
		str = str:sub(2)
	end
	return str
end
 
------------------------------------------------------------------ encoding
 
local function encodeCommon(val, pretty, tabLevel, tTracking)
	local str = ""
 
	-- Tabbing util
	local function tab(s)
		str = str .. ("\t"):rep(tabLevel) .. s
	end
 
	local function arrEncoding(val, bracket, closeBracket, iterator, loopFunc)
		str = str .. bracket
		if pretty then
			str = str .. "\n"
			tabLevel = tabLevel + 1
		end
		for k,v in iterator(val) do
			tab("")
			loopFunc(k,v)
			str = str .. ","
			if pretty then str = str .. "\n" end
		end
		if pretty then
			tabLevel = tabLevel - 1
		end
		if str:sub(-2) == ",\n" then
			str = str:sub(1, -3) .. "\n"
		elseif str:sub(-1) == "," then
			str = str:sub(1, -2)
		end
		tab(closeBracket)
	end
 
	-- Table encoding
	if type(val) == "table" then
		assert(not tTracking[val], "Cannot encode a table holding itself recursively")
		tTracking[val] = true
		if isArray(val) then
			arrEncoding(val, "[", "]", ipairs, function(k,v)
				str = str .. encodeCommon(v, pretty, tabLevel, tTracking)
			end)
		else
			arrEncoding(val, "{", "}", pairs, function(k,v)
				assert(type(k) == "string", "JSON object keys must be strings", 2)
				str = str .. encodeCommon(k, pretty, tabLevel, tTracking)
				str = str .. (pretty and ": " or ":") .. encodeCommon(v, pretty, tabLevel, tTracking)
			end)
		end
	-- String encoding
	elseif type(val) == "string" then
		str = '"' .. val:gsub("[%c\"\\]", controls) .. '"'
	-- Number encoding
	elseif type(val) == "number" or type(val) == "boolean" then
		str = tostring(val)
	else
		error("JSON only supports arrays, objects, numbers, booleans, and strings", 2)
	end
	return str
end
 
function encode(val)
	return encodeCommon(val, false, 0, {})
end
 
function encodePretty(val)
	return encodeCommon(val, true, 0, {})
end
 
------------------------------------------------------------------ decoding
 
local decodeControls = {}
for k,v in pairs(controls) do
	decodeControls[v] = k
end
 
function parseBoolean(str)
	if str:sub(1, 4) == "true" then
		return true, removeWhite(str:sub(5))
	else
		return false, removeWhite(str:sub(6))
	end
end
 
function parseNull(str)
	return nil, removeWhite(str:sub(5))
end
 
local numChars = {['e']=true; ['E']=true; ['+']=true; ['-']=true; ['.']=true}
function parseNumber(str)
	local i = 1
	while numChars[str:sub(i, i)] or tonumber(str:sub(i, i)) do
		i = i + 1
	end
	local val = tonumber(str:sub(1, i - 1))
	str = removeWhite(str:sub(i))
	return val, str
end
 
function parseString(str)
	str = str:sub(2)
	local s = ""
	while str:sub(1,1) ~= "\"" do
		local next = str:sub(1,1)
		str = str:sub(2)
		assert(next ~= "\n", "Unclosed string")
 
		if next == "\\" then
			local escape = str:sub(1,1)
			str = str:sub(2)
 
			next = assert(decodeControls[next..escape], "Invalid escape character")
		end
 
		s = s .. next
	end
	return s, removeWhite(str:sub(2))
end
 
function parseArray(str)
	str = removeWhite(str:sub(2))
 
	local val = {}
	local i = 1
	while str:sub(1, 1) ~= "]" do
		local v = nil
		v, str = parseValue(str)
		val[i] = v
		i = i + 1
		str = removeWhite(str)
	end
	str = removeWhite(str:sub(2))
	return val, str
end
 
function parseObject(str)
	str = removeWhite(str:sub(2))
 
	local val = {}
	while str:sub(1, 1) ~= "}" do
		local k, v = nil, nil
		k, v, str = parseMember(str)
		val[k] = v
		str = removeWhite(str)
	end
	str = removeWhite(str:sub(2))
	return val, str
end
 
function parseMember(str)
	local k = nil
	k, str = parseValue(str)
	local val = nil
	val, str = parseValue(str)
	return k, val, str
end
 
function parseValue(str)
	local fchar = str:sub(1, 1)
	if fchar == "{" then
		return parseObject(str)
	elseif fchar == "[" then
		return parseArray(str)
	elseif tonumber(fchar) ~= nil or numChars[fchar] then
		return parseNumber(str)
	elseif str:sub(1, 4) == "true" or str:sub(1, 5) == "false" then
		return parseBoolean(str)
	elseif fchar == "\"" then
		return parseString(str)
	elseif str:sub(1, 4) == "null" then
		return parseNull(str)
	end
	return nil
end
 
function decode(str)
	str = removeWhite(str)
	t = parseValue(str)
	return t
end
 
function decodeFromFile(path)
	local file = assert(fs.open(path, "r"))
	local decoded = decode(file.readAll())
	file.close()
	return decoded
end
-- End of JSON parser

-- Ramuthra's plane installer
local github = "https://api.github.com/repos/Saldor010/Ramuthras-Plane/contents"
local cobaltGit = "https://api.github.com/repos/ebernerd/Cobalt/contents"
local args = {...}
if args[1] then 
	if not type(args[1]) == "string" then
		args[1] = nil
	elseif string.find(args[1],string.len(args[1]),string.len(args[1])) ~= "/" and string.find(args[1],string.len(args[1]),string.len(args[1])) ~= "\\" then
		args[1] = args[1].."/"
	end
end
local pathToInstall = args[1] or "RamuthrasPlane/"
local token = args[2]

local function downloadFile(url,filePath)	
	local fileContent = http.get(url)
	if fileContent then fileContent = fileContent.readAll() else return false end
	
	if not fs.exists(filePath) then
		local file = fs.open(filePath,"w")
		file.write(fileContent)
		file.close()
		return true
	else return false end
end

local function readRepository(url,path2,verify)
	if not path2 then path2 = "" end
	--[[term.setTextColor(colors.red)
	term.clear()]]--
	term.setTextColor(colors.blue)
	
	--print(url)
	local a = nil
	if token then 
		a = {
			["Authorization"] = "token "..tostring(token)
		}
	end
	local repository = http.get(url,a)
	if repository == nil then
		term.setTextColor(colors.red)
		print("Failed to reach repository.")
		term.setTextColor(colors.orange)
		print("You may have exceeded GitHub's rate limit. Please try again later or pass an OAuth token as the 2nd argument.")
		error()
	end
	if repository then repository = repository.readAll() else return false end
	repository = decode(repository)
	--print(repository)
	
	for k,v in pairs(repository) do
		--print("a")
		if v["download_url"] then
			--[[term.setCursorPos(1,7)
			term.setTextColor(colors.red)
			term.write(string.rep(" ",51))
			term.setTextColor(colors.orange)
			term.setCursorPos(math.floor(51/2)-math.floor(string.len("Downloading file:")/2),7)
			term.write("Downloading file:")
			
			term.setCursorPos(1,8)
			term.setTextColor(colors.red)
			term.write(string.rep(" ",51))
			term.setTextColor(colors.orange)]]--
			
			sleep(0.2) -- Give time for the user to actually read the message
			
			local success = nil
			--[[if string.sub(v["url"],1,70) == "https://api.github.com/repos/Saldor010/Ramuthras-Plane/contents/cobalt" or string.sub(v["url"],1,74) == "https://api.github.com/repos/Saldor010/Ramuthras-Plane/contents/cobalt-lib" or string.sub(v["url"],1,73) == "https://api.github.com/repos/Saldor010/Ramuthras-Plane/contents/cobalt-ui" then
				term.setCursorPos(math.floor(51/2)-math.floor(string.len(v["path"])/2),8)
				term.write(pathToInstall..v["path"])
				print(v["path"])
				success = downloadFile(v["download_url"],v["path"])
			else]]--
				--term.setCursorPos(math.floor(51/2)-math.floor(string.len(pathToInstall..v["path"])/2),8)
				--term.write(pathToInstall..v["path"])
				if verify(v["download_url"]) then
					print(path2..v["path"])
					success = downloadFile(v["download_url"],path2..v["path"])
				end
			--end
		else
			readRepository(v["url"],path2,verify)
		end
	end
end

if token then
	term.setTextColor(colors.orange)
	print("Token "..token.." will be used during the installation.")
	term.setTextColor(colors.blue)
end

--readRepository("https://www.google.com","A")
readRepository(github,pathToInstall,function(download_url) return true end)
readRepository(cobaltGit,"",function(download_url)
	--print(download_url)
	if string.sub(download_url,58,66) == "cobalt-ui" or string.sub(download_url,58,67) == "cobalt-lib" or string.sub(download_url,58,63) == "cobalt" then
		return true
	else
		return false
	end
end)

--[[term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.orange)]]--
term.setTextColor(colors.green)
print("Download complete! Run "..pathToInstall.."rmplane.lua to start the game!")
term.setTextColor(colors.white)