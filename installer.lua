local component = require("component")
local computer = require("computer")
local term = require("term")
local unicode = require("unicode")
local serialization = require("serialization")

local eeprom = component.eeprom
local freespace = eeprom.getDataSize() - 38
local users, checkUserOnBoot, readOnly = false, false, false

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

if QA("Create whitelist for bootloader access?") then
	::LOOP::
	io.write('Whitelist example: {"Jako", "Berserk29", "Elds01", "svchost2"}')
	io.write("Whitelist: ")
	users = read("*")
	local serialized, err = serialization.serialize(users)

	if serialized then
		if #serialized > freespace then
			io.stderr:write(("\nMaximum whitelist size is %s and you used %s\n"):format(freespace, #serialized))
			goto LOOP
		else
			users = serialized
		end
	else
		goto LOOP
		io.stderr:write(err)
	end
	checkUserOnBoot = QA("\nRequest user touch on boot?")
end

readOnly = QA("Make EEPROM read only?")
os.execute("wget -f https://raw.githubusercontent.com/BrightYC/Cyan/master/cyan.comp /tmp/")
local file = io.open("/tmp/cyan.comp")
local data = file:read("*a")
file:close()
print("Flashing...")
eeprom.set(data)
eeprom.setData(("%s#%s%s"):format(computer.getBootAddress() or component.filesystem.address, users or "", checkUserOnBoot or ""))
eeprom.setLabel("Cyan BIOS")
if readOnly then
	print("Making EEPROM read only...")
	eeprom.makeReadonly(eeprom.getChecksum())
end
computer.shutdown(true)