local bootFiles, bootCandidates, key, Unicode, Computer, Component, invoke, paletteNotOverwrited, centerY, users, requestUserPressOnBoot, userChecked, width, height, lines, screen, internet, gpu, gpuAddress, eeprom, eepromData, needUpdate = {"/init.lua", "/boot.lua", "/OS.lua"}, {}, {}, unicode, computer, component, component.invoke

local function pullSignal(timeout)
    local signal = {Computer.pullSignal(timeout)}
    signal[1] = signal[1] or ""

    if #signal > 0 and users.n > 0 and ((signal[1]:match"ey" and not users[signal[5]]) or signal[1]:match"cl" and not users[signal[4]]) then
        return table.unpack(signal)
    end

    key[signal[4] or ""] = signal[1]:match"do" and 1

    if key[29] and (key[56] and key[46] or key[32]) and signal[1]:match"do" then
        return "F"
    end

    return table.unpack(signal)
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

local function proxy(componentType)
    return Component.list(componentType)() and Component.proxy(Component.list(componentType)())
end

local function split(text, tabulate)
    lines = {}

    for line in text:gmatch"[^\r\n]+" do
        lines[#lines + 1] = line:gsub("\t", tabulate and "    " or "")
    end
end

local function action(func, ...)
    if func and type(func):match("f") then
        return func(...)
    end
end

local function sleep(timeout, breakCode, onBreak)
    local deadline, signalType, code, _ = Computer.uptime() + (timeout or math.huge)

    ::LOOP::
    signalType, _, _, code = pullSignal(deadline - Computer.uptime())

    if signalType == "F" or signalType:match"do" and (code == breakCode or breakCode == 0) then
        action(onBreak)
        return 1
    elseif Computer.uptime() <= deadline then
        goto LOOP
    end
end

local function configureSystem()
    gpu, internet, eeprom, screen = proxy"gp", proxy"internet", Component.list"pro"(), Component.list"sc"()
    eepromData = eeprom and invoke(eeprom, "getData") or eepromData

    if gpu and screen then
        gpu.bind((screen))
        gpu.setPaletteColor(9, 0x002b36)
        gpu.setPaletteColor(11, 0x8cb9c5)
        width, height = gpu.maxResolution()
        gpuAddress = gpu.address
        centerY = height / 2
        return 1
    end
end

configureSystem()
users = select(2, execute(eepromData:match"#(.+)#" or "{}"))
requestUserPressOnBoot = eepromData:match"*"
users.n = #users
for i = 1, #users do
    users[users[i]], users[i] = 1, F
    users.n = users.n + 1
end

function Component.invoke(address, method, ...)
    if address == eeprom then
        if method == "setData" then
            eepromData = not ({...})[2] and eepromData:match"(.+)#{" and eepromData:gsub("(.+)#{", (...) .. "#{") or (...)
            return eeprom and invoke(eeprom, method, eepromData)
        elseif method == "getData" then
            return not (...) and eepromData:match"(.+)#{" or eepromData
        end
    elseif method == "set" and paletteNotOverwrited and address == gpuAddress then
        paletteNotOverwrited = F
        gpu.setPaletteColor(9, 0x969696)
        gpu.setPaletteColor(11, 0xb4b4b4)
    end

    return invoke(address, method, ...)
end

Computer.setBootAddress = function(...) return Component.invoke(eeprom, "setData", ...) end
Computer.getBootAddress = function(...) return Component.invoke(eeprom, "getData", ...) end

local function set(x, y, string, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.set(x, y, string)
end

local function fill(x, y, w, h, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.fill(x, y, w, h, " ")
end

local function clear()
    fill(1, 1, width, height)
end

local function centrize(len)
    return math.ceil(width / 2 - len / 2)
end

local function centrizedSet(y, text, background, foreground)
    set(centrize(Unicode.len(text)), y, text, background, foreground)
end

local function status(text, title, wait, breakCode, onBreak)
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
    end
end

local function cutText(text, maxLength)
    return Unicode.len(text) > maxLength and Unicode.sub(text, 1, maxLength) .. "…" or text
end

local function input(prefix, X, y, centrized, lastInput)
    local input, prefixLen, cursorPos, cursorState, x, cursorX, signalType, char, code, _ = "", Unicode.len(prefix), 1, 1

    ::LOOP::
    signalType, _, char, code = pullSignal(.5)

    if signalType:match"do" then
        if char >= 32 and Unicode.len(prefixLen .. input) < width - prefixLen - 1 then
            input = Unicode.sub(input, 1, cursorPos - 1) .. Unicode.char(char) .. Unicode.sub(input, cursorPos, -1)
            cursorPos = cursorPos + 1
        elseif char == 8 and #input > 0 then
            input = Unicode.sub(Unicode.sub(input, 1, cursorPos - 1), 1, -2) .. Unicode.sub(input, cursorPos, -1)
            cursorPos = cursorPos - 1
        elseif char == 13 then
            fill(1, y, width, 1)
            return input
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
    elseif signalType:match"mp" or signalType == "F" then
        needUpdate = signalType:match"mp" and 1
        return
    elseif not signalType:match"up" then
        cursorState = not cursorState
    end

    x = centrized and centrize(Unicode.len(input) + prefixLen) or X
    cursorX = x + prefixLen + cursorPos - 1
    fill(1, y, width, 1)
    set(x, y, prefix .. input, 0x002b36, 0xFFFFFF)
    if cursorX <= width then
        set(cursorX, y, gpu.get(cursorX, y), cursorState and 0xFFFFFF or 0x002b36, cursorState and 0x002b36 or 0xFFFFFF)
    end
    goto LOOP
end

local function print(...)
    local text = table.pack(...)
    for i = 1, text.n do
        text[i] = tostring(text[i])
    end
    split(table.concat(text, "    "), 1)

    for i = 1, #lines do
        gpu.copy(1, 1, width, height - 1, 0, -1)
        fill(1, height - 1, width, 1)
        set(1, height - 1, lines[i])
    end
end

local function bootPreview(image, booting, y, foreground)
    centrizedSet(y, image[6] and ("Boot%s %s from %s (%s)"):format(
        booting and "ing" or "",
        image[6],
        image[2],
        cutText(image[3], booting and width > 80 and 36 or 6)
    ) or ("Boot from %s (%s) is not available"):format(
        image[2],
        cutText(image[3], booting and width > 80 and 36 or 6)
    ), F, foreground)
end

local function addCandidate(address)
    local proxy = Component.proxy(address)

    if proxy and proxy.spaceTotal and address ~= Computer.tmpAddress() then
        bootCandidates[#bootCandidates + 1] = {
            proxy, proxy.getLabel() or "N/A", address, cutText(proxy.getLabel() or "N/A", 6), ("Disk usage %s%% / %s / %s"):format(
                math.floor(proxy.spaceUsed() / (proxy.spaceTotal() / 100)),
                proxy.isReadOnly() and "Read only" or "Read & Write",
                proxy.spaceTotal() < 2 ^ 20 and "FDD" or proxy.spaceTotal() < 2 ^ 20 * 12 and "HDD" or "RAID"
            )
        }

        for i = 1, #bootFiles do
            if proxy.exists(bootFiles[i]) then
                bootCandidates[#bootCandidates][6] = bootFiles[i]
                break
            end
        end
    end
end

local function updateCandidates()
    bootCandidates = {}
    addCandidate(Computer.getBootAddress())
    for address in next, Component.list"f" do
        addCandidate(address ~= Computer.getBootAddress() and address or "")
    end
end

local function boot(image)
    if image[6] then
        local handle, data, chunk, success, err = image[1].open(image[6], "r"), ""

        ::LOOP::
        chunk = image[1].read(handle, math.huge)

        if chunk then
            data = data .. chunk
            goto LOOP
        end

        image[1].close(handle)
        local function run()
            clear()
            bootPreview(image, 1, centerY)
            if Computer.getBootAddress() ~= image[3] then
                Computer.setBootAddress(image[3])
            end
            paletteNotOverwrited = 1
            success, err = execute(data, "=" .. image[6])
            paletteNotOverwrited = configureSystem() and status(err, [[¯\_(ツ)_/¯]], math.huge, 0, Computer.shutdown) or error(err)
        end

        data = requestUserPressOnBoot and not userChecked and status("Hold any button to boot", F, math.huge, 0, run) or run()
    end
end

local function bootloader()
    userChecked = 1
    ::UPDATE::
    needUpdate = F
    configureSystem()
    updateCandidates()
    local env, main, signalType, code, correction, newLabel, data, url, _

    local function createElements(workspace, elements, onDraw, y, spaces, borderHeight)
        table.insert(workspace.e, {
            s = 1,
            y = y,
            e = elements,
            o = onDraw,
            d = function(SELF, drawSelected)
                local elementsLineLength, x = 0

                for i = 1, #SELF.e do
                    SELF.e[i][3] = action(SELF.e[i][1]) or SELF.e[i][1]
                    elementsLineLength = elementsLineLength + Unicode.len(SELF.e[i][3]) + spaces
                end

                elementsLineLength = elementsLineLength - spaces
                x = centrize(elementsLineLength)

                for i = 1, #SELF.e do
                    if SELF.s == i and drawSelected then
                        fill(x - spaces / 2, SELF.y - math.floor(borderHeight / 2), Unicode.len(SELF.e[i][3]) + spaces, borderHeight, 0x8cb9c5)
                        set(x, SELF.y, SELF.e[i][3], 0x8cb9c5, 0x002b36)
                    else
                        set(x, SELF.y, SELF.e[i][3], 0x002b36, 0x8cb9c5)
                    end

                    x = x + Unicode.len(SELF.e[i][3]) + spaces
                end
            end
        })

        return #elements
    end

    local function createWorkspace(onDraw)
        return {
            s = 1,
            e = {},
            o = onDraw,
            d = function(SELF)
                if gpu and screen and not needUpdate then
                    action(SELF.o, SELF)
                    for i = 1, #SELF.e do
                        SELF.e[i]:d(SELF.s == i)
                    end
                end
            end,
            l = function(SELF)
                ::LOOP::
                signalType, _, _, code = pullSignal(0)

                if signalType:match"mp" or needUpdate or signalType == "F" then
                    return signalType
                elseif signalType:match"do" then
                    if code == 200 then -- Up
                        SELF.s = SELF.s > 1 and SELF.s - 1 or #SELF.e
                    elseif code == 208 then -- Down
                        SELF.s = SELF.s < #SELF.e and SELF.s + 1 or 1
                    elseif code == 203 then -- Left
                        SELF.e[SELF.s].s = SELF.e[SELF.s].s > 1 and SELF.e[SELF.s].s - 1 or #SELF.e[SELF.s].e
                    elseif code == 205 then -- Right
                        SELF.e[SELF.s].s = SELF.e[SELF.s].s < #SELF.e[SELF.s].e and SELF.e[SELF.s].s + 1 or 1
                    elseif code == 28 then -- Enter
                        SELF.e[SELF.s].e[SELF.e[SELF.s].s][2]()
                    end

                    SELF:d()
                end

                goto LOOP
            end
        }
    end

    main = createWorkspace()

    if #bootCandidates > 0 then
        createElements(main, {}, F, centerY - 3, 8, 3)
        for i = 1, #bootCandidates do
            main.e[1].e[i] = {
                function()
                    return bootCandidates[i][4]
                end,

                function()
                    boot(bootCandidates[i])
                end
            }
        end
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
                read = function(lastInput) print(" ") data = input("", 1, height - 1, F, lastInput) set(1, height - 1, data or "") return data end
            }, {__index = _G})

            ::LOOP::
            data = input("> ", 1, height, F, data)

            if data then
                print("> " .. data)
                set(1, height, ">")
                print(select(2, execute(data, "=stdin", env)))
                goto LOOP
            end
        end},
        internet and {"Internet boot", function()
            url = input("URL: ", F, centerY + 6, 1)

            if url and #url > 0 then
                local handle, data, chunk = internet.request(url, F, F, {["user-agent"]="Cyan"}), ""

                if handle then
                    status"Downloading..."
                    ::LOOP::
                    chunk = handle.read()

                    if chunk then
                        data = data .. chunk
                        goto LOOP
                    end

                    paletteNotOverwrited = 1
                    status(select(2, execute(data, "=Internet boot")) or "is empty", "Internet boot", math.huge, 0)
                else
                    status("Invalid URL", "Internet boot", math.huge, 0)
                end
            end
        end} or F
    }, F, centerY + (#bootCandidates > 0 and 1 or 0), #bootCandidates > 0 and 6 or 8, #bootCandidates > 0 and 1 or 3) + 1

    main.o = function(SELF)
        clear()

        if #bootCandidates > 0 then
            bootPreview(bootCandidates[SELF.e[1].s], F, centerY + 4, 0xFFFFFF)
            centrizedSet(centerY + 6, bootCandidates[SELF.e[1].s][5])

            for j = correction, #SELF.e[2].e do
                SELF.e[2].e[j] = F
            end

            if not bootCandidates[SELF.e[1].s][7] then
                if bootCandidates[SELF.e[1].s][1].isReadOnly() then
                    SELF.e[2].s = SELF.e[2].s > #SELF.e[2].e and #SELF.e[2].e or SELF.e[2].s
                else
                    SELF.e[2].e[correction] = {
                        "Rename", function()
                            newLabel = input("New label: ", F, centerY + 6, 1)

                            if newLabel and #newLabel > 0 then
                                bootCandidates[SELF.e[1].s][1].setLabel(newLabel)
                                updateCandidates()
                            end
                        end,
                    }
                    SELF.e[2].e[correction + 1] = {
                        "Format", function()
                            bootCandidates[SELF.e[1].s][1].remove("/")
                            bootCandidates[SELF.e[1].s][1].setLabel(F)
                            updateCandidates()
                        end
                    }
                end
            end
        else
            centrizedSet(centerY + 3, "No drives available", F, 0xFFFFFF)
        end
    end

    main:d()
    if main:l() ~= "F" then
        goto UPDATE
    end
    Computer.shutdown()
end

updateCandidates()
status("Hold CTRL to stay in bootloader", F, .9, 29, bootloader)
for i = 1, #bootCandidates do
    boot(bootCandidates[i])
end
gpu = configureSystem() and bootloader() or error"No drives available"