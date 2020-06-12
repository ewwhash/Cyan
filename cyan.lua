local bootFiles, bootCandidates, key, Unicode, Computer, invoke, centerY, users, requestUserPressOnBoot, userChecked, width, height, lines, eeprom, gpu, screen, internet, gpuAddress, eepromAddress, eepromData = {"/init.lua", "/OS.lua", "/boot.lua"}, {}, {}, unicode, computer, component.invoke

local function pullSignal(timeout)
    local signal = {Computer.pullSignal(timeout or math.huge)}
    signal[1] = signal[1] or ""

    if #signal > 0 and users.n > 0 and ((signal[1]:match"key" and not users[signal[5]]) or signal[1]:match"cl" and not users[signal[4]]) then
        return table.unpack(signal)
    end

    key[signal[4] or ""] = signal[1] == "key_down" and 1

    if key[29] and (key[56] and key[46] or key[32]) then
        return "F"
    end

    return table.unpack(signal)
end

local function arr2a_arr(tbl)
    tbl.n = 0

    for i = 1, #tbl do
        tbl[tbl[i]], tbl[i] = 1, F
        tbl.n = tbl.n + 1
    end
end

local function execute(code, stdin, env)
    local chunk, err = load("return " .. code, stdin, F, env)

    if not chunk then
        chunk, err = load(code, stdin, F, env)
    end

    if chunk then
        return xpcall(chunk, debug.traceback)
    else
        return F, err
    end
end

local function split(text, tabulate)
    lines = {}

    for line in text:gmatch"[^\r\n]+" do
        lines[#lines + 1] = line:gsub("\t", tabulate and "    " or "")
    end
end

local function sleep(timeout, breakCode, onBreak)
    local deadline, signalType, code, _ = Computer.uptime() + (timeout or math.huge)

    repeat
        signalType, _, _, code = pullSignal(deadline - Computer.uptime())

        if signalType == "F" or signalType == "key_down" and (code == breakCode or breakCode == 0) then
            if onBreak then
                onBreak()
            end
            return 1
        end
    until Computer.uptime() >= deadline
end

local function proxy(componentType)
    local address = component.list(componentType)()
    return address and component.proxy(address)
end

local function configureSystem()
    gpu, eeprom, internet, screen = proxy"gp", proxy"pr", proxy"in", component.list"sc"()
    eepromAddress = eeprom.address
    eepromData = eeprom.getData()

    if gpu and screen then
        gpu.bind((screen))
        gpu.setPaletteColor(9, 0x002b36)
        gpu.setPaletteColor(11, 0x8cb9c5)
        gpuAddress = gpu.address
        width, height = gpu.maxResolution()
        centerY = height / 2
        return 1
    end
end

configureSystem()
users = select(2, pcall(load("return " .. (eepromData:match"#(.+)#" or "{}"))))
requestUserPressOnBoot = eepromData:match"*"
arr2a_arr(users)
arr2a_arr(bootFiles)

function component.invoke(address, method, ...)
    if address == eepromAddress then
        if method == "getData" then
            return eepromData:match"[a-f-0-9]+" or eepromData
        elseif method == "setData" then
            eepromData = ({...})[2] and ({...})[1] or (eepromData:match"[a-f-0-9]+" and eepromData:gsub("[a-f-0-9]+", ({...})[2]) or ({...})[2])
        end
    elseif address == gpuAddress and method == "bind" then
        gpu.setPaletteColor(9, 0x969696)
        gpu.setPaletteColor(11, 0xb4b4b4)
    end

    return invoke(address, method, ...)
end

Computer.setBootAddress = eeprom.getData
Computer.getBootAddress = eeprom.setData

local function set(x, y, string, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.set(x, y, string)
end

local function fill(x, y, w, h, symbol, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.fill(x, y, w, h, symbol)
end

local function clear()
    fill(1, 1, width, height, " ")
end

local function centrize(len)
    return math.ceil(width / 2 - len / 2)
end

local function centrizedSet(y, text, background, foreground)
    set(centrize(Unicode.len(text)), y, text, background, foreground)
end

local function status(text, title, wait, breakCode, onBreak, restorePalette)
    if configureSystem() then
        split(text)
        clear()
        local y = math.ceil(centerY - #lines / 2)

        if title then
            centrizedSet(y - 1, title, 0x002b36, 0xFFFFFF)
            y = y + 1
        end
        for i = 1, #lines do
            centrizedSet(y, lines[i])
            y = y + 1
        end

        return sleep(wait or 0, breakCode, onBreak)
    else
        error(text)
    end
end

local function internetBoot(url, shutdown)
    if #url > 0 then
        local handle, data, chunk = internet.request(url), ""

        if handle then
            status("Downloading " .. url .. "...")
            ::LOOP::
            chunk = handle.read()

            if chunk then
                data = data .. chunk
                goto LOOP
            end

            status(select(2, execute(data, "=stdin")) or "is empty", "Internet boot:", math.huge, 0)
        else
            status("Invalid URL", "Internet boot:", math.huge, 0, shutdown and Computer.shutdown)
        end
    end
end

local function cutText(text, maxLength)
    return Unicode.len(text) > maxLength and Unicode.sub(text, 1, maxLength) .. "…" or text
end

local function input(prefix, X, y, centrized, lastInput)
    local input, prefixLen, cursorPos, cursorState, x, cursorX, signalType, char, code, _ = "", Unicode.len(prefix), 1, 1

    while 1 do
        signalType, _, char, code = pullSignal(.5)

        if signalType == "F" then
            input = F
            break
        elseif signalType == "key_down" then
            if char >= 32 and Unicode.len(prefixLen .. input) < width - prefixLen - 1 then
                input = Unicode.sub(input, 1, cursorPos - 1) .. Unicode.char(char) .. Unicode.sub(input, cursorPos, -1)
                cursorPos = cursorPos + 1
            elseif char == 8 and #input > 0 then
                input = Unicode.sub(Unicode.sub(input, 1, cursorPos - 1), 1, -2) .. Unicode.sub(input, cursorPos, -1)
                cursorPos = cursorPos - 1
            elseif char == 13 then
                break
            elseif code == 203 and cursorPos > 1 then
                cursorPos = cursorPos - 1
            elseif code == 205 and cursorPos <= Unicode.len(input) then
                cursorPos = cursorPos + 1
            elseif code == 200 and lastInput then
                input = lastInput
                cursorPos = Unicode.len(lastInput) + 1
            elseif code == 208 and lastInput then
                input = ""
                cursorPos = 1
            end

            cursorState = 1
        elseif signalType:match"cl" then
            input = Unicode.sub(input, 1, cursorPos - 1) .. char .. Unicode.sub(input, cursorPos, -1)
            cursorPos = cursorPos + Unicode.len(char)
        elseif signalType ~= "key_up" then
            cursorState = not cursorState
        end

        x = centrized and centrize(Unicode.len(input) + prefixLen) or X
        cursorX = x + prefixLen + cursorPos - 1
        fill(1, y, width, 1, " ")
        set(x, y, prefix .. input, 0x002b36, 0xFFFFFF)
        if cursorX <= width then
            set(cursorX, y, gpu.get(cursorX, y), cursorState and 0xFFFFFF or 0x002b36, cursorState and 0x002b36 or 0xFFFFFF)
        end
    end

    fill(1, y, width, 1, " ")
    return input
end

local function print(...)
    local text = table.pack(...)

    for i = 1, text.n do
        text[i] = tostring(text[i])
    end

    split(table.concat(text, "    "), 1)

    for i = 1, #lines do
        gpu.copy(1, 1, width, height - 1, 0, -1)
        fill(1, height - 1, width, 1, " ")
        set(1, height - 1, lines[i])
    end
end

local function bootPreview(image, booting)
    if image[6] then
        return ("Boot%s %s from %s")
            :format(
                booting and "ing" or "",
                image[3],
                image[2]
            )
    else
        local address = cutText(image[3], booting and 36 or 6)
        return image[4] and ("Boot%s %s from %s (%s)")
            :format(
                booting and "ing" or "",
                image[4],
                image[2],
                address
            )
        or  ("Boot from %s (%s) is not available")
            :format(
                image[2],
                address
            )
    end
end

local function addCandidate(address)
    if address:match("http") and internet then
        bootCandidates[#bootCandidates + 1] = {
            F, "Net", address, F,
        }
    else
        local proxy = component.proxy(address)

        if proxy and proxy.spaceTotal and address ~= Computer.tmpAddress() then
            bootCandidates[#bootCandidates + 1] = {
                                                        -- 1  2  3
                proxy, proxy.getLabel() or "N/A", address, F, F, F, ("Disk usage %s%% / %s / %s")
                    :format(
                        math.floor(proxy.spaceUsed() / (proxy.spaceTotal() / 100)),
                        proxy.readOnly() and "Read only" or "Read & Write",
                        proxy.spaceTotal() < 2 ^ 20 and "FDD" or proxy.spaceTotal() < 2 ^ 20 * 12 and "HDD" or "RAID"
                    )
            }

            -- 1 - boot file(4)
            -- 2 - cutted text(5)
            -- 3 - HTTP(6)

            bootCandidates[#bootCandidates][5] = cutText(bootCandidates[#bootCandidates][2], 6)

            for i = 1, #bootFiles do
                if proxy.exists(bootFiles[i]) then
                    bootCandidates[#bootCandidates][4] = bootFiles[i]
                    break
                end
            end
        end
    end
end

local function updateCandidates()
    bootCandidates = {}
    addCandidate(eeprom.getData())

    for filesystem in pairs(component.list"f") do
        addCandidate(eeprom.getData() ~= filesystem and filesystem or "")
    end
end

local function boot(image)
    if image[4] then
        local handle, data, chunk, success, err, boot = image[1].open(image[4], "r"), ""

        ::LOOP::
        chunk = image[1].read(handle, math.huge)

        if chunk then
            data = data .. chunk
            goto LOOP
        end

        image[1].close(handle)

        boot = function()
            status(bootPreview(image, 1), F, .5, F, F, 1)
            if eeprom.getData() ~= image[3] then
                eeprom.setData(image[3])
            end
            success, err = execute(data, "=" .. image[4])
            status(err, [[¯\_(ツ)_/¯]], math.huge, 0, Computer.shutdown, 1)
            Computer.shutdown()
        end

        data = requestUserPressOnBoot and not userChecked and status("Hold any button to boot", F, math.huge, 0, boot) or boot()
    end
end

local function bootloader()
    userChecked = 1
    ::UPDATE::
    local env, main, signalType, code, correction, newLabel
    updateCandidates()
    configureSystem()

    local function createWorkspace()
        return {
            w = 1,
            s = 1,
            e = {},
            d = function(SELF)
                for i = 1, #SELF.e do
                    SELF.e[i]:d(SELF.s == i)
                end
            end,
            l = function(SELF)
                while SELF.w do
                    signalType, _, _, code = pullSignal()
                    local selectedElementsLine = SELF.e[SELF.s]

                    if signalType == "key_down" and gpu and screen then
                        if code == 200 then -- Up
                            SELF.s = SELF.s > 1 and SELF.s - 1 or #SELF.e
                        elseif code == 208 then -- Down
                            SELF.s = SELF.s < #SELF.e and SELF.s + 1 or 1
                        elseif code == 203 then -- Left
                            selectedElementsLine.s = selectedElementsLine.s > 1 and selectedElementsLine.s - 1 or #selectedElementsLine.e
                            selectedElementsLine:d()
                        elseif code == 205 then -- Right
                            selectedElementsLine.s = selectedElementsLine.s < #selectedElementsLine.e and selectedElementsLine.s + 1 or 1
                            selectedElementsLine:d()
                        elseif code == 28 then -- Enter
                            selectedElementsLine.e[selectedElementsLine.s].a()
                        end
                    elseif signalType:match"mp" then
                        break
                    elseif signalType == "F" then
                        SELF.w = F
                    end
                end
            end
        }
    end

    local function createElements(workspace, elements, y, spaces, borderHeight)
        table.insert(workspace.e, {
            s = 1,
            y = y,
            e = elements,
            d = function(SELF, drawSelected)
                local elementsLineLength, x = 0

                for i = 1, #SELF.e do
                    SELF.e[i][3] = type(SELF.e[i][1]):match("fu") and SELF.e[i][1]() or SELF.e[i][1]
                    elementsLineLength = elementsLineLength + Unicode.len(SELF.e[i][3]) + spaces
                end

                elementsLineLength = elementsLineLength - spaces
                x = centrize(elementsLineLength)

                for i = 1, #SELF.e do
                    if SELF.s == i and drawSelected then
                        fill(x - spaces / 2, SELF.y - math.floor(borderHeight / 2), Unicode.len(SELF.e[i][3]) + spaces, borderHeight, " ", 0x8cb9c5)
                        set(x, SELF.y, SELF.e[i][3], 0x8cb9c5, 0x002b36)
                    else
                        set(x, SELF.y, SELF.e[i][3], 0x002b36, 0x8cb9c5)
                    end

                    x = x + Unicode.len(SELF.e[i][3])
                end
            end
        })

        return #elements
    end

    main = createWorkspace()
    if #bootCandidates > 0 then
        createElements(main, {}, centerY)
    end
    correction = createElements(main, {
        {"Power off", Computer.shutdown},
        {"Lua", function()
            clear()
            env = setmetatable({
                print = print,
                proxy = proxy,
                os = {
                    sleep = function(timeout) sleep(timeout) end
                },
                read = function(lastInput) print(" ") local data = input("", 1, height - 1, F, lastInput) set(1, height - 1, data) return data end
            }, {__index = _G})

            ::LOOP::
                data = input("> ", 1, height, F, data)

                if data then
                    print("> " .. data)
                    set(1, height, ">")
                    print(select(2, execute(data, "=stdin", env)))
                    goto LOOP
                end
            main:d()
        end},
        internet and {"Internet boot", function() internetBoot(input("URL: ", F, centerY + 7, 1)) end} or F
    }, centerY + (#bootCandidates > 0 and 2 or 0), #bootCandidates > 0 and 6 or 8, #bootCandidates > 0 and 1 or 3)
    for i = 1, #bootCandidates do
        main.e[1].e[i] = {
            function()
                return bootCandidates[i][6]
            end,

            function()
                for j = correction, #main.e[2].e do
                    main.e[2].e[j] = F
                end

                if bootCandidates[i].isReadOnly() then
                    main.e[2].s = main.e[2].s> #main.e[2].e and #main.e[2].e or main.e[2].s
                else
                    main.e[2].e[correction] = {
                        "Rename", function()
                            newLabel = input("New label: ", F, centerY + 7, 1)

                            if #newLabel > 0 then
                                pcall(bootCandidates[i][1].setLabel, newLabel)
                                updateCandidates()
                                main:d()
                            end
                        end,
                    }
                    main.e[2].e[correction + 1] = {
                        "Format", function()
                            bootCandidates[i][1].remove("/")
                            main:d()
                        end
                    }
                end
            end
        }
    end
    main:l()

    if main.w then
        goto UPDATE
    end
end

updateCandidates()
status("Hold CTRL to stay in bootloader", F, .9, 29, function() bootloader() Computer.shutdown() end)
for i = 1, #bootCandidates do
    boot(bootCandidates[i])
end
gpuAddress = configureSystem() and bootloader() or error"No drives available"