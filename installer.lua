local component = require("component")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")

if not component.isAvailable("internet") then
	io.stderr:write("This program requires an internet card to run.")
	os.exit()
end

local eeprom, internet = component.eeprom, component.internet
local password, requestPasswordAtBoot, readOnly, lzss = false, false, false

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

if QA("Set password for EEPROM?") then
	::PASSWORD::
	io.write("Password: ")
	password = read("*")
	if unicode.len(password) > 12 then
		io.stderr:write("\nMaximum password length is 12 characters\n")
		goto PASSWORD
	end
	if unicode.len(password) ~= #password then
		io.stderr:write("\nPassword doesn't not to contain non-ascii characters\n")
		goto PASSWORD
	end
	requestPasswordAtBoot = QA("\nRequest password at boot?")
end

readOnly = QA("Make EEPROM read only?")
lzss = load(request("https://raw.githubusercontent.com/BrightYC/Other/master/lzss.lua"), "=lzss.lua")()
print("Compressing...")

local compressed = lzss.getSXF(lzss.compress(request("https://raw.githubusercontent.com/BrightYC/Cyan/master/for-compress.lua")
	:gsub(
		"%%(%w+)%%",
		{
			pass = password or "",
			passOnBoot = requestPasswordAtBoot and "1" or "F"}
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