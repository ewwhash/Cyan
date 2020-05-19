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

if computer.getArchitecture() == "Lua 5.2" then
	if QA("(This program requires Lua 5.3 or better. Install?)") then
		computer.setArchitecture("Lua 5.3")
	else
		os.exit()
	end
end


if QA("Set password for EEPROM?") then
	::PASSWORD::
	io.write("Password: ")
	password = read("*")
	if unicode.len(password) > 12 then
		print("\nMaximum password length is 12 characters")
		goto PASSWORD
	end
	requestPasswordAtBoot = QA("\nRequest password at boot?")
end

readOnly = QA("Make EEPROM read only?")
lzss = load(request("https://raw.githubusercontent.com/BrightYC/Other/master/lzss.lua"), "=lzss.lua")()
print("Compressing...")

local compressed = lzss.getSXF(lzss.compress(request("https://raw.githubusercontent.com/BrightYC/Other/master/EEPROM/Installer/eeprom-minified.lua")
	:gsub(
		"%%(%w+)%%",
		{
			pass = password or "",
			passOnBoot = requestPasswordAtBoot and "1" or "F"}
		)
	),
	true
)

print("Flashing...")
eeprom.set(compressed)
eeprom.setLabel("Cyan BIOS")
if readOnly then
	print("Making EEPROM read only...")
	eeprom.makeReadonly(eeprom.getChecksum())
end

computer.shutdown(true)