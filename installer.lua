local component = require("component")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")
local serialization = require("serialization")

if not component.isAvailable("internet") then
	io.stderr:write("This program requires an internet card to run.")
	os.exit()
end

local FREESPACE = 77
local eeprom, internet = component.eeprom, component.internet
local users, checkUserOnBoot, readOnly, lzss = false, false, false

local function request(url)
	local handle, data, chunk = internet.request(url, nil, {["user-agent"]="Chrome/81.0.4044.129"}), ""

	if handle then
		while true do
			chunk = handle.read()

			if chunk then
				data = data .. chunk
			else
				break
			end
		end
	else
		error("Failed to open handle for request " .. url)
	end

	return data
end

local function read(hint)
	local input = term.read(nil, nil, nil, hint)

	if not input then
		os.exit()
	end

	return input:gsub("\n", "")
end

local function QA(text)
	io.write(("%s [Y/n] "):format(text))
	local input = unicode.lower(read())

	if input == "y" or input == "" then
		return true
	end
end

local function currentScript()
	local info
	for runLevel = 0, math.huge do
		info = debug.getinfo(runLevel)
		if info then
			if info.what == "main" then
				return info.source:sub(2, -1)
			end
		else
			error("Failed to get debug info for runlevel " .. runLevel)
		end
	end
end

do local pattern = ("\n%s"):format(currentScript())

	if computer.getArchitecture() == "Lua 5.2" then
		local file = io.open("/home/.shrc", "a")
		if file then
			file:write(pattern)
			file:close()
		end
		computer.setArchitecture("Lua 5.3")
	end

	local file = io.open("/home/.shrc", "r")
	if file then
		local data = file:read("*a")
		file:close()

		if data:match(pattern) then
			data = data:gsub(pattern, "")
		end

		file = io.open("/home/.shrc", "w")
		if file then
			file:write(data)
			file:close()
		end
	end
end

if QA("Create whitelist for bootloader access?") then
	::LOOP::
	io.write('Whitelist example: {"Jako", "Berserk29", "Elds01", "svchost2"}')
	io.write("Whitelist: ")
	users = read("*")
	local serialized, err = serialization.serialize(users)

	if serialized then
		if #serialized > FREESPACE then
			io.stderr:write(("\nMaximum whitelist size is %s and you used %s\n"):format(FREESPACE, #serialized))
			goto LOOP
		end
	else
		goto LOOP
		io.stderr:write(err)
	end
	checkUserOnBoot = QA("\nRequest user touch on boot?")
end

readOnly = QA("Make EEPROM read only?")
lzss = load(request("https://raw.githubusercontent.com/BrightYC/Other/master/lzss.lua"), "=lzss.lua")()
print("Compressing...")

local compressed = lzss.getSXF(lzss.compress(request("https://raw.githubusercontent.com/BrightYC/Cyan/master/for-compress.lua")
	:gsub(
		"%%(%w+)%%",
		{
			users = users or "{}",
			checkUserOnBoot = checkUserOnBoot and "1" or "F"}
		)
	),
	true
)
_G.suka  = compressed

if load(compressed) then
	print("Flashing...")
	eeprom.set(compressed)
	eeprom.setLabel("Cyan BIOS")
	if readOnly then
		print("Making EEPROM read only...")
		eeprom.makeReadonly(eeprom.getChecksum())
	end
	computer.shutdown(true)
else
	io.stderr:write("EEPROM src malformed, please contact with developer")
end