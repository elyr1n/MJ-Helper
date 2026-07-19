---@diagnostic disable: undefined-global, lowercase-global

script_author("elyrin")
script_name("MJ-Helper")
script_properties("work-in-pause")
script_version("2.1.2")

local effil = require("effil")
local vkeys = require("vkeys")
local sampev = require("samp.events")
local json = require("dkjson")
local ffi = require("ffi")
local imgui = require("mimgui")
local encoding = require("encoding")
encoding.default = "CP1251"
local u8 = encoding.UTF8

local fa = require("fAwesome6_solid")

local wantedWindow = imgui.new.bool(false)
local federalWindow = imgui.new.bool(false)
local administrativeWindow = imgui.new.bool(false)
local notepadWindow = imgui.new.bool(false)
local searchedWindow = imgui.new.bool(false)
local updateWindow = imgui.new.bool(false)
local timerWindow = imgui.new.bool(false)
local settingsTimerWindow = imgui.new.bool(false)
local settingsMegafonWindow = imgui.new.bool(false)

local timerActive = imgui.new.bool(false)

local section_buffer = imgui.new.char[16]()
local description_buffer = imgui.new.char[256]()
local search_level_buffer = imgui.new.char[2]()
local straf_buffer = imgui.new.char[8]()
local search_description_buffer = imgui.new.char[256]()
local notepad_input_buffer = imgui.new.char[8192]()
local notepad_title_buffer = imgui.new.char[32]()
local timer_time_buffer = imgui.new.char[8]()
local timer_name_buffer = imgui.new.char[128]()

local color_palitre_megafon = imgui.new.float[3]()

local redactMode = imgui.new.bool(false)

local targetID = -1

local wanteds = {}
local federals = {}
local administratives = {}
local notepad = {}
local searched = {}

local search_wanted = false

local afind = false
local afind_text = { "Команда доступна с 5 ранга", "Игрок находится в каком%-то здании", "Вы не полицейский !" }

local log_message = false

local moveSearchedWindow = false
local settingsSearchedWindow = {
    x = 960,
    y = 540
}

local updateUrls = {
    "https://raw.githubusercontent.com/elyr1n/MJ-Helper/refs/heads/main/update.json",
    "https://github.com/elyr1n/MJ-Helper/raw/refs/heads/main/MJ-Helper.lua"
}
local update = {
    version = "",
    text = ""
}

local timers = {}

local renderFont = renderCreateFont("Verdana", 10, 1 + 8)

local int_item_departament_from = imgui.new.int(0)
local item_list_departament_from = {u8("ЛСПД"), u8("СФПД"), u8("ЛВПД"), u8("ФБР"), u8("РКШД"), u8("СВАТ")}
local ImItemsDepartamentFrom = imgui.new['const char*'][#item_list_departament_from](item_list_departament_from)

local int_item_departament_to = imgui.new.int(0)
local item_list_departament_to = {u8("ОГП"), u8("ГКА"), u8("ЛСПД"), u8("СФПД"), u8("ЛВПД"), u8("РКШД"), u8("СВАТ"), u8("ФБР"), u8("ЛСа"), u8("СФа"), u8("ТСР"), u8("ЛСМЦ"), u8("СФМЦ"), u8("ЛВМЦ"), u8("ЦЛ"), u8("СМИ ЛС"), u8("СМИ СФ"), u8("СМИ ЛВ")}
local ImItemsDepartamentTo = imgui.new['const char*'][#item_list_departament_to](item_list_departament_to)

local int_item_founding = imgui.new.int(0)
local ImItemsFounding = imgui.new['const char*'][#item_list_departament_from](item_list_departament_from)

local config_path = getWorkingDirectory() .. "\\config\\MJ-Helper.json"

local sendMJHelperMessage = function(text)
    if log_message then
        return print(string.format("[MJ-Helper]: %s", text))
    end

    return sampAddChatMessage(string.format("[MJ-Helper]: {FFFFFF}%s", text), 0xff4f00)
end

local cefNotify = function (type, text)
    local code = string.format('window.executeEvent(\'event.notify.initialize\', `["%s","MJ-Helper","%s",3000]`);', type, text)

    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

local asyncHttpRequest = function(method, url, args, resolve, reject)
    local request_thread = effil.thread(function(method, url, args)
        local requests = require("requests")
        local ok, response = pcall(requests.request, method, url, args)
        if ok then
            response.json, response.xml = nil, nil
            return true, response
        end
        return false, response
    end)(method, url, args)

    if not resolve then resolve = function() end end
    if not reject then reject = function() end end

    lua_thread.create(function()
        while true do
            local status, err = request_thread:status()
            if err then return reject(err) end

            if status == "completed" then
                local ok, response = request_thread:get()
                if ok then
                    resolve(response)
                else
                    reject(response)
                end
                return
            end

            if status == "canceled" then
                return reject("canceled")
            end

            wait(0)
        end
    end)
end

local check_update = function()
    asyncHttpRequest(
        "GET",
        updateUrls[1],
        {},

        function(response)
            local status, data = pcall(json.decode, response.text)

            if status and type(data) == "table" and data.version and data.text then
                local version, text = data.version, data.text

                if version ~= thisScript().version then
                    update.version = version
                    update.text = text

                    updateWindow[0] = not updateWindow[0]
                else
                    sendMJHelperMessage("Скрипт обновлён до последней версии!")
                end
            else
                sendMJHelperMessage("Ошибка при проверке обновления скрипта!")
            end
        end
    )
end

local saveConfig = function()
    local data = {
        wanteds = wanteds,
        federals = federals,
        administratives = administratives,
        notepad = notepad,
        log_message = log_message,
        settingsSearchedWindow = settingsSearchedWindow,
        timers = timers,
        color_palitre_megafon = {color_palitre_megafon[0], color_palitre_megafon[1], color_palitre_megafon[2]}
    }

    local file = io.open(config_path, "w")

    if file then
        file:write(json.encode(data, { indent = true }))
        file:close()
    end
end

local loadConfig = function()
    local file = io.open(config_path, "r")

    if file then
        local content = file:read("*a")

        file:close()

        local ok, parsed = pcall(json.decode, content)

        if ok and parsed then
            wanteds = parsed.wanteds
            federals = parsed.federals
            administratives = parsed.administratives
            notepad = parsed.notepad
            log_message = parsed.log_message
            settingsSearchedWindow = parsed.settingsSearchedWindow
            timers = parsed.timers

            color_palitre_megafon[0] = parsed.color_palitre_megafon[1]
            color_palitre_megafon[1] = parsed.color_palitre_megafon[2]
            color_palitre_megafon[2] = parsed.color_palitre_megafon[3]
        end
    end
end

local lower = function(str)
    return str:gsub("А", "а"):gsub("Б", "б"):gsub("В", "в"):gsub("Г", "г"):gsub("Д", "д"):gsub("Е", "е"):gsub("Ё", "ё"):gsub("Ж", "ж"):gsub("З", "з"):gsub("И", "и"):gsub("Й", "й"):gsub("К", "к"):gsub("Л", "л"):gsub("М", "м"):gsub("Н", "н"):gsub("О", "о"):gsub("П", "п"):gsub("Р", "р"):gsub("С", "с"):gsub("Т", "т"):gsub("У", "у"):gsub("Ф", "ф"):gsub("Х", "х"):gsub("Ц", "ц"):gsub("Ч", "ч"):gsub("Ш", "ш"):gsub("Щ", "щ"):gsub("Ъ", "ъ"):gsub("Ы", "ы"):gsub("Ь", "ь"):gsub("Э", "э"):gsub("Ю", "ю"):gsub("Я", "я")
end

local toHEX = function(r, g, b)
    local clamp = function(v)
        return math.max(0, math.min(255, math.floor(v + 0.5)))
    end

    return string.format("%02X%02X%02X", clamp(r), clamp(g), clamp(b))
end

local hexToInt = function(hex)
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)

    local color = bit.bor(
        bit.lshift(r, 24),
        bit.lshift(g, 16),
        bit.lshift(b, 8),
        0xFF
    )

    if color >= 0x80000000 then
        color = color - 0x100000000
    end

    return color
end

local DarkTheme = function()
    imgui.SwitchContext()

    imgui.GetStyle().WindowPadding                           = imgui.ImVec2(5, 5)
    imgui.GetStyle().FramePadding                            = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemSpacing                             = imgui.ImVec2(5, 5)
    imgui.GetStyle().ItemInnerSpacing                        = imgui.ImVec2(2, 2)
    imgui.GetStyle().TouchExtraPadding                       = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing                           = 0
    imgui.GetStyle().ScrollbarSize                           = 10
    imgui.GetStyle().GrabMinSize                             = 10

    imgui.GetStyle().WindowBorderSize                        = 1
    imgui.GetStyle().ChildBorderSize                         = 1
    imgui.GetStyle().PopupBorderSize                         = 1
    imgui.GetStyle().FrameBorderSize                         = 1
    imgui.GetStyle().TabBorderSize                           = 1

    imgui.GetStyle().WindowRounding                          = 5
    imgui.GetStyle().ChildRounding                           = 5
    imgui.GetStyle().FrameRounding                           = 5
    imgui.GetStyle().PopupRounding                           = 5
    imgui.GetStyle().ScrollbarRounding                       = 5
    imgui.GetStyle().GrabRounding                            = 5
    imgui.GetStyle().TabRounding                             = 5

    imgui.GetStyle().WindowTitleAlign                        = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign                         = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign                     = imgui.ImVec2(0.5, 0.5)

    imgui.GetStyle().Colors[imgui.Col.Text]                  = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]          = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]              = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                = imgui.ImVec4(0.25, 0.25, 0.26, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]          = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]               = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]        = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]         = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]               = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]         = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]      = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]             = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]           = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]         = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]  = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]   = imgui.ImVec4(0.51, 0.51, 0.51, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]             = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]            = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]      = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]         = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]          = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]         = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]          = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]             = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]      = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]            = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]     = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                   = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]            = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]             = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]          = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]    = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]             = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]      = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]         = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]  = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]        = imgui.ImVec4(1.00, 0.00, 0.00, 0.35)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]        = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]          = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]     = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]      = imgui.ImVec4(0.00, 0.00, 0.00, 0.70)
end

imgui.OnInitialize(function()
    DarkTheme()

    local atlas = imgui.GetIO().Fonts
    local font_path = getWorkingDirectory() .. "\\resource\\fonts\\Eagle-Sans-Bold.ttf"
    local cyr_ranges = atlas:GetGlyphRangesCyrillic()

    font = atlas:AddFontFromFileTTF(font_path, 16.0, nil, cyr_ranges)

    fa.Init(12)

    imgui.GetIO().IniFilename = nil
end)

imgui.CenterText = function(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)

    imgui.SetCursorPosX(width / 2 - calc.x / 2)

    imgui.Text(text)
end

imgui.CenterColumnText = function(text)
    imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text).x / 2)
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 7)

    imgui.Text(text)
end

local bringVec4To = function(from, to, start_time, duration)
    local timer = os.clock() - start_time

    if timer >= 0.00 and timer <= duration then
        local count = timer / (duration / 100)

        return imgui.ImVec4(
            from.x + (count * (to.x - from.x) / 100),
            from.y + (count * (to.y - from.y) / 100),
            from.z + (count * (to.z - from.z) / 100),
            from.w + (count * (to.w - from.w) / 100)
        ), true
    end

    return (timer > duration) and to or from, false
end

local AnimButton = function(label, size, duration)
    if type(duration) ~= "table" then
        duration = { 0.5, 0.25 }
    end

    local cols = {
        default = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.Button]),
        hovered = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonHovered]),
        active  = imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonActive])
    }

    if UI_ANIMBUT == nil then
        UI_ANIMBUT = {}
    end

    if not UI_ANIMBUT[label] then
        UI_ANIMBUT[label] = {
            color = cols.default,
            clicked = { nil, nil },
            hovered = {
                cur = false,
                old = false,
                clock = nil,
            }
        }
    end

    local pool = UI_ANIMBUT[label]

    if pool["clicked"][1] and pool["clicked"][2] then
        if os.clock() - pool["clicked"][1] <= duration[2] then
            pool["color"] = bringVec4To(
                pool["color"],
                cols.active,
                pool["clicked"][1],
                duration[2]
            )
            goto no_hovered
        end

        if os.clock() - pool["clicked"][2] <= duration[2] then
            pool["color"] = bringVec4To(
                pool["color"],
                pool["hovered"]["cur"] and cols.hovered or cols.default,
                pool["clicked"][2],
                duration[2]
            )
            goto no_hovered
        end
    end

    if pool["hovered"]["clock"] ~= nil then
        if os.clock() - pool["hovered"]["clock"] <= duration[1] then
            pool["color"] = bringVec4To(
                pool["color"],
                pool["hovered"]["cur"] and cols.hovered or cols.default,
                pool["hovered"]["clock"],
                duration[1]
            )
        else
            pool["color"] = pool["hovered"]["cur"] and cols.hovered or cols.default
        end
    end

    ::no_hovered::

    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(pool["color"]))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(pool["color"]))
    imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(pool["color"]))

    local result = imgui.Button(label, size or imgui.ImVec2(0, 0))

    imgui.PopStyleColor(3)

    if result then
        pool["clicked"] = {
            os.clock(),
            os.clock() + duration[2]
        }
    end

    pool["hovered"]["cur"] = imgui.IsItemHovered()

    if pool["hovered"]["old"] ~= pool["hovered"]["cur"] then
        pool["hovered"]["old"] = pool["hovered"]["cur"]
        pool["hovered"]["clock"] = os.clock()
    end

    return result
end

local drawList = function (widthOne, widthTwo, widthThree, indexOne, indexTwo, ...)
    local min, max = imgui.GetItemRectMin(), imgui.GetItemRectMax()
    local dl = imgui.GetWindowDrawList()

    local x = { 0, widthOne * widthTwo, widthOne * widthThree }
    local t = {...}

    for i = indexOne, indexTwo do
        dl:AddLine(
            imgui.ImVec2(min.x + x[i], min.y),
            imgui.ImVec2(min.x + x[i], max.y),
            0x30FFFFFF
        )
    end

    for i = 1, #t do
        dl:AddText(
            imgui.ImVec2(min.x + x[i] + 8, min.y + 7),
            0xFFFFFFFF,
            t[i]
        )
    end
end

imgui.OnFrame(
    function() return wantedWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 750, 750
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        imgui.PushFont(font)
        if imgui.Begin(u8("Умный розыск"), wantedWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then
            if imgui.Checkbox(u8("Режим редактирования"), redactMode) then
                loadConfig()
            end

            imgui.Separator()

            if #wanteds ~= 0 then
                local searchText = u8:decode(ffi.string(search_description_buffer))

                imgui.PushItemWidth(740)
                imgui.InputTextWithHint("##search_description_wanted", u8("Описание статьи"), search_description_buffer, 256)
                imgui.PopItemWidth()

                imgui.Separator()

                for indexWanted, wanted in pairs(wanteds) do
                    if #searchText == 0 or string.find(lower(wanted.description), lower(searchText)) then
                        if imgui.CollapsingHeader(u8(string.format("Статья %s. %s ##" .. indexWanted, wanted.section, wanted.description))) then
                            for indexChildren, children in pairs(wanted.children) do
                                local descriptionMenu, descriptionPopup = children.description, children.description

                                if #descriptionMenu > 85 then
                                    descriptionMenu = descriptionMenu:sub(1, 85) .. "..."
                                end

                                if #descriptionPopup > 75 then
                                    descriptionPopup = descriptionPopup:sub(1, 75) .. "..."
                                end

                                local width = imgui.GetContentRegionAvail().x

                                if AnimButton("##" .. indexChildren, imgui.ImVec2(width, 30)) then
                                    wantedWindow[0] = false
                                    sampSendChat(string.format("/su %s %s %s", targetID, children.search_level, children.section))
                                end

                                drawList(width, 0.090, 0.945, 2, 3, u8(children.section), u8(descriptionMenu), children.search_level .. " " .. fa.STAR)

                                local name = u8(string.format("Редактирование [%s. %s] ##%s", children.section, descriptionPopup, indexChildren))

                                if imgui.IsItemClicked(1) then
                                    ffi.copy(section_buffer, u8(children.section))
                                    ffi.copy(description_buffer, u8(children.description))
                                    ffi.copy(search_level_buffer, u8(children.search_level))

                                    imgui.OpenPopup(name)
                                end

                                if imgui.BeginPopupModal(name, _, imgui.WindowFlags.NoResize) then
                                    if redactMode[0] then
                                        imgui.SetWindowSizeVec2(imgui.ImVec2(750, 420))
                                    else
                                        imgui.SetWindowSizeVec2(imgui.ImVec2(750, 350))
                                    end

                                    imgui.PushItemWidth(740)

                                    imgui.Text(u8("Статья:"))
                                    imgui.InputText("##section_children_wanted", section_buffer, 16)

                                    imgui.Separator()

                                    imgui.Text(u8("Описание:"))
                                    imgui.InputTextMultiline("##description_children_wanted", description_buffer, 256)

                                    imgui.Separator()

                                    imgui.Text(u8("Уровень розыска:"))
                                    imgui.InputText("##search_level_children_wanted", search_level_buffer, 2)

                                    imgui.PopItemWidth()

                                    imgui.Separator()

                                    if redactMode[0] then
                                        if AnimButton(u8("Сохранить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                            children.section = u8:decode(ffi.string(section_buffer))
                                            children.description = u8:decode(ffi.string(description_buffer))
                                            children.search_level = u8:decode(ffi.string(search_level_buffer))

                                            saveConfig()

                                            imgui.CloseCurrentPopup()
                                        end

                                        if AnimButton(u8("Удалить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                            table.remove(wanted.children, indexChildren)

                                            if #wanted.children == 0 then
                                                table.remove(wanteds, indexWanted)
                                            end

                                            saveConfig()

                                            imgui.CloseCurrentPopup()
                                        end
                                    end

                                    if AnimButton(u8("Закрыть"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                        imgui.CloseCurrentPopup()
                                    end

                                    imgui.End()
                                end
                            end

                            if redactMode[0] then
                                imgui.Separator()

                                local name = u8(string.format("Редактирование [%s. %s] ##%s", wanted.section, wanted.description, indexWanted))

                                if AnimButton(u8("Добавить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                    table.insert(wanted.children, {
                                        section = "1.2",
                                        description = "Описание",
                                        search_level = 1
                                    })

                                    saveConfig()
                                end

                                if AnimButton(u8("Изменить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                    ffi.copy(section_buffer, u8(wanted.section))
                                    ffi.copy(description_buffer, u8(wanted.description))

                                    imgui.OpenPopup(name)
                                end

                                if imgui.BeginPopupModal(name, _, imgui.WindowFlags.NoResize) then
                                    imgui.SetWindowSizeVec2(imgui.ImVec2(500, 365))

                                    imgui.PushItemWidth(490)

                                    imgui.Text(u8("Статья:"))
                                    imgui.InputText("##section_wanted", section_buffer, 16)

                                    imgui.Separator()

                                    imgui.Text(u8("Описание:"))
                                    imgui.InputTextMultiline("##description_wanted", description_buffer, 256)

                                    imgui.PopItemWidth()

                                    imgui.Separator()

                                    if AnimButton(u8("Сохранить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                        wanted.section = u8:decode(ffi.string(section_buffer))
                                        wanted.description = u8:decode(ffi.string(description_buffer))

                                        saveConfig()

                                        imgui.CloseCurrentPopup()
                                    end

                                    if AnimButton(u8("Удалить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                        table.remove(wanteds, indexWanted)

                                        saveConfig()

                                        imgui.CloseCurrentPopup()
                                    end

                                    if AnimButton(u8("Закрыть"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                        imgui.CloseCurrentPopup()
                                    end

                                    imgui.End()
                                end

                                if AnimButton(u8("Удалить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                    table.remove(wanteds, indexWanted)

                                    saveConfig()
                                end
                            end
                        end
                    end
                end
            else
                imgui.Text(u8("Розыск не настроен!"))
            end

            if redactMode[0] then
                imgui.Separator()

                if AnimButton(u8("Добавить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                    table.insert(wanteds, {
                        section = "1.1 УК",
                        description = "Описание",

                        children = {
                            {
                                section = "1.2 УК",
                                description = "Описание",
                                search_level = 1
                            }
                        }
                    })

                    saveConfig()
                end
            end

            imgui.End()
        end
        imgui.PopFont()
    end
)

imgui.OnFrame(
    function() return federalWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 750, 750
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        imgui.PushFont(font)
        if imgui.Begin(u8("Умное ФП"), federalWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then
            if imgui.Checkbox(u8("Режим редактирования"), redactMode) then
                loadConfig()
            end

            imgui.Separator()

            if #federals ~= 0 then
                local searchText = u8:decode(ffi.string(search_description_buffer))

                imgui.PushItemWidth(740)
                imgui.InputTextWithHint("##search_description_gwarn", u8("Описание статьи"), search_description_buffer, 256)
                imgui.PopItemWidth()

                imgui.Separator()

                for indexFederal, federal in pairs(federals) do
                    if #searchText == 0 or string.find(lower(federal.description), lower(searchText)) then
                        local descriptionMenu, descriptionPopup = federal.description, federal.description

                        if #descriptionMenu > 90 then
                            descriptionMenu = descriptionMenu:sub(1, 90) .. "..."
                        end

                        if #descriptionPopup > 75 then
                            descriptionPopup = descriptionPopup:sub(1, 75) .. "..."
                        end

                        local width = imgui.GetContentRegionAvail().x

                        if AnimButton("##" .. indexFederal, imgui.ImVec2(width, 30)) then
                            federalWindow[0] = false
                            sampSendChat(string.format("/gwarn %s %s", targetID, federal.section))
                        end

                        drawList(width, 0.080, 0, 2, 2, u8(federal.section), u8(descriptionMenu))

                        local name = u8(string.format("Редактирование [%s. %s] ##%s", federal.section, descriptionPopup, indexFederal))

                        if imgui.IsItemClicked(1) then
                            ffi.copy(section_buffer, u8(federal.section))
                            ffi.copy(description_buffer, u8(federal.description))

                            imgui.OpenPopup(name)
                        end

                        if imgui.BeginPopupModal(name, _, imgui.WindowFlags.NoResize) then
                            if redactMode[0] then
                                imgui.SetWindowSizeVec2(imgui.ImVec2(750, 365))
                            else
                                imgui.SetWindowSizeVec2(imgui.ImVec2(750, 295))
                            end

                            imgui.PushItemWidth(740)

                            imgui.Text(u8("Статья:"))
                            imgui.InputText("##section_children_gwarn", section_buffer, 16)

                            imgui.Separator()

                            imgui.Text(u8("Описание:"))
                            imgui.InputTextMultiline("##description_children_gwarn", description_buffer, 256)

                            imgui.PopItemWidth()

                            imgui.Separator()

                            if redactMode[0] then
                                if AnimButton(u8("Сохранить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                    federal.section = u8:decode(ffi.string(section_buffer))
                                    federal.description = u8:decode(ffi.string(description_buffer))

                                    saveConfig()

                                    imgui.CloseCurrentPopup()
                                end

                                if AnimButton(u8("Удалить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                    table.remove(federals, indexFederal)

                                    saveConfig()

                                    imgui.CloseCurrentPopup()
                                end
                            end

                            if AnimButton(u8("Закрыть"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                imgui.CloseCurrentPopup()
                            end

                            imgui.End()
                        end
                    end
                end
            else
                imgui.Text(u8("ФП не настроено!"))
            end

            if redactMode[0] then
                imgui.Separator()

                if AnimButton(u8("Добавить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                    table.insert(federals, {
                        section = "1.1 ФП",
                        description = "Описание",
                    })

                    saveConfig()
                end
            end

            imgui.End()
        end
        imgui.PopFont()
    end
)

imgui.OnFrame(
    function() return administrativeWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 750, 750
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        imgui.PushFont(font)
        if imgui.Begin(u8("Умная выдача штрафов"), administrativeWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then
            if imgui.Checkbox(u8("Режим редактирования"), redactMode) then
                loadConfig()
            end

            imgui.Separator()

            if #administratives ~= 0 then
                local searchText = u8:decode(ffi.string(search_description_buffer))

                imgui.PushItemWidth(740)
                imgui.InputTextWithHint("##search_description_administrative", u8("Описание статьи"), search_description_buffer, 256)
                imgui.PopItemWidth()

                imgui.Separator()

                for indexAdministrative, administrative in pairs(administratives) do
                    if #searchText == 0 or string.find(lower(administrative.description), lower(searchText)) then
                        local descriptionMenu, descriptionPopup = administrative.description, administrative.description

                        if #descriptionMenu > 80 then
                            descriptionMenu = descriptionMenu:sub(1, 80) .. "..."
                        end

                        if #descriptionPopup > 90 then
                            descriptionPopup = descriptionPopup:sub(1, 90) .. "..."
                        end

                        local width = imgui.GetContentRegionAvail().x

                        if AnimButton("##" .. indexAdministrative, imgui.ImVec2(width, 30)) then
                            administrativeWindow[0] = false
                            sampSendChat(string.format("/writeticket %s %s %s", targetID, administrative.straf, administrative.section))
                        end

                        drawList(width, 0.075, 0.875, 2, 3, u8(administrative.section), u8(descriptionMenu), "$" .. tostring(administrative.straf):gsub("%D", ""):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))

                        local name = u8(string.format("Редактирование [%s. %s] ##%s", administrative.section, descriptionPopup, indexAdministrative))

                        if imgui.IsItemClicked(1) then
                            ffi.copy(section_buffer, u8(administrative.section))
                            ffi.copy(description_buffer, u8(administrative.description))
                            ffi.copy(straf_buffer, u8(administrative.straf))

                            imgui.OpenPopup(name)
                        end

                        if imgui.BeginPopupModal(name, _, imgui.WindowFlags.NoResize) then
                            if redactMode[0] then
                                imgui.SetWindowSizeVec2(imgui.ImVec2(800, 420))
                            else
                                imgui.SetWindowSizeVec2(imgui.ImVec2(800, 350))
                            end

                            imgui.PushItemWidth(790)

                            imgui.Text(u8("Статья:"))
                            imgui.InputText("##section_administrative", section_buffer, 16)

                            imgui.Separator()

                            imgui.Text(u8("Описание:"))
                            imgui.InputTextMultiline("##description_administrative", description_buffer, 256)

                            imgui.Separator()

                            imgui.Text(u8("Штраф:"))
                            imgui.InputText("##straf_administrative", straf_buffer, 8)

                            imgui.PopItemWidth()

                            imgui.Separator()

                            if redactMode[0] then
                                if AnimButton(u8("Сохранить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                    administrative.section = u8:decode(ffi.string(section_buffer))
                                    administrative.description = u8:decode(ffi.string(description_buffer))
                                    administrative.straf = u8:decode(ffi.string(straf_buffer))

                                    saveConfig()

                                    imgui.CloseCurrentPopup()
                                end

                                if AnimButton(u8("Удалить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                    table.remove(administratives, indexAdministrative)

                                    saveConfig()

                                    imgui.CloseCurrentPopup()
                                end
                            end

                            if AnimButton(u8("Закрыть"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                imgui.CloseCurrentPopup()
                            end

                            imgui.End()
                        end
                    end
                end
            else
                imgui.Text(u8("АК не настроено!"))
            end

            if redactMode[0] then
                imgui.Separator()

                if AnimButton(u8("Добавить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                    table.insert(administratives, {
                        section = "1.1 АК",
                        description = "Описание",
                        straf = 100000
                    })

                    saveConfig()
                end
            end

            imgui.End()
        end
        imgui.PopFont()
    end
)

imgui.OnFrame(
    function() return notepadWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 750, 750
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        imgui.PushFont(font)
        if imgui.Begin(u8("Блокнот"), notepadWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
            if imgui.BeginTabBar("##1") then
                for index, value in pairs(notepad) do
                    if imgui.BeginTabItem(u8(value.title .. "##" .. index)) then
                        local name = u8(string.format("Редактирование [%s] ##%s", value.title, index))

                        if imgui.IsItemClicked(1) then
                            ffi.copy(notepad_title_buffer, u8(value.title))

                            imgui.OpenPopup(name)
                        end

                        if imgui.BeginPopupModal(name, _, imgui.WindowFlags.NoResize) then
                            imgui.SetWindowSizeVec2(imgui.ImVec2(500, 175))

                            imgui.PushItemWidth(490)
                            imgui.InputText("##title_notepad", notepad_title_buffer, 32)
                            imgui.PopItemWidth()

                            imgui.Separator()

                            if AnimButton(u8("Сохранить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                value.title = u8:decode(ffi.string(notepad_title_buffer))

                                saveConfig()

                                imgui.CloseCurrentPopup()
                            end

                            if AnimButton(u8("Удалить"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                table.remove(notepad, index)

                                saveConfig()

                                imgui.CloseCurrentPopup()
                            end

                            if AnimButton(u8("Закрыть"), imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                                imgui.CloseCurrentPopup()
                            end

                            imgui.End()
                        end

                        ffi.copy(notepad_input_buffer, u8(value.input_field))

                        if imgui.InputTextMultiline("##input_field_notepad", notepad_input_buffer, 8192, imgui.ImVec2(imgui.GetWindowSize().x - 10, 640)) then
                            value.input_field = u8:decode(ffi.string(notepad_input_buffer))

                            saveConfig()
                        end

                        imgui.EndTabItem()
                    end
                end

                imgui.EndTabBar()
            end

            if #notepad ~= 0 then
                imgui.Separator()
            end

            if AnimButton("+", imgui.ImVec2(imgui.GetWindowSize().x - 10, 30)) then
                table.insert(notepad, {
                    title = "Заголовок",
                    input_field = "Поле ввода"
                })

                saveConfig()
            end
            imgui.End()
        end
        imgui.PopFont()
    end
)

imgui.OnFrame(
    function() return searchedWindow[0] end,
    function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(settingsSearchedWindow.x, settingsSearchedWindow.y), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))

        imgui.PushFont(font)
        if imgui.Begin(u8("Список преступников"), searchedWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoScrollbar) then
            if imgui.GetIO().MouseClicked[2] then
                player.HideCursor = not player.HideCursor
            end

            if isKeyJustPressed(vkeys.VK_DELETE) then
                moveSearchedWindow = not moveSearchedWindow
            end

            if moveSearchedWindow then
                player.HideCursor = false

                local cX, cY = getCursorPos()
                settingsSearchedWindow.x, settingsSearchedWindow.y = cX, cY

                if imgui.IsMouseClicked(0) then
                    saveConfig()

                    moveSearchedWindow, player.HideCursor = false, true
                end
            end

            if AnimButton("/awanted", imgui.ImVec2(425, 25)) then
                sampProcessChatInput("/awanted")
            end

            imgui.Separator()

            if #searched ~= 0 then
                for indexSearch, search in pairs(searched) do
                    imgui.Columns(4)
                    imgui.CenterColumnText(search.wanted_lvl .. " " .. fa.STAR)
                    imgui.SetColumnWidth(-1, 80)

                    imgui.NextColumn()

                    imgui.CenterColumnText(string.format("%s[%s]", search.nickname, search.id))
                    imgui.SetColumnWidth(-1, 180)

                    imgui.NextColumn()

                    imgui.CenterColumnText(u8(search.distance))
                    imgui.SetColumnWidth(-1, 100)

                    imgui.NextColumn()

                    imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)
                    imgui.PushStyleVarVec2(imgui.StyleVar.ButtonTextAlign, imgui.ImVec2(0.5, 0.85))

                    if AnimButton(fa.MAGNIFYING_GLASS .. "##" .. indexSearch, imgui.ImVec2(65, 25)) then
                        sampSendChat("/pursuit " .. search.id)
                    end

                    imgui.PopStyleVar()

                    imgui.Columns(1)
                    imgui.Separator()
                end
            else
                imgui.Text(u8("Не найдено преступников!"))
            end

            imgui.End()
        end
        imgui.PopFont()
    end
)

imgui.OnFrame(
    function() return updateWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))

        imgui.PushFont(font)
        if imgui.Begin(u8(string.format("Обновление [%s ver.]", update.version)), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize) then
            imgui.Text(u8("Изменения:"))

            imgui.Separator()

            for line in update.text:gmatch("[^\n]+") do
                imgui.BulletText(u8(line))
            end

            imgui.Separator()

            if AnimButton(u8("Обновить"), imgui.ImVec2(imgui.GetContentRegionAvail().x / 2, 25)) then
                downloadUrlToFile(updateUrls[2], thisScript().path, function(id, status)
                    if status == 6 then
                        sendMJHelperMessage("Обновление успешно завершено!")
                        sendMJHelperMessage("Скрипт перезагрузится для применения изменений!")
                    end
                end)

                updateWindow[0] = not updateWindow[0]
            end

            imgui.SameLine()

            if AnimButton(u8("Отмена"), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                updateWindow[0] = not updateWindow[0]
            end

            imgui.End()
        end
        imgui.PopFont()
    end
)

imgui.OnFrame(
    function() return timerWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 500
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        imgui.PushFont(font)
        if imgui.Begin(u8("Таймеры"), timerWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollbar) then
            if #timers ~= 0 then
                for index, timer in pairs(timers) do
                    local width, name = imgui.GetContentRegionAvail().x, u8(string.format("%s ##%s", timer.name, index))

                    if AnimButton("##" .. index, imgui.ImVec2(width, 30)) then
                        timer.isActive = not timer.isActive

                        saveConfig()

                        cefNotify("info", string.format("Таймер %s %s!", timer.name, timer.isActive and "включен" or "отключён"))
                        sendMJHelperMessage(string.format("Таймер \"%s\" %s!", timer.name, timer.isActive and "включен" or "отключён"))
                    end

                    drawList(width, 0.750, 0, 2, 2, u8(timer.name), os.date("!%H:%M:%S", timer.time))

                    if imgui.IsItemClicked(1) then
                        ffi.copy(timer_name_buffer, u8(timer.name))
                        ffi.copy(timer_time_buffer, tostring(timer.time))
                        timerActive[0] = timer.isActive

                        imgui.OpenPopup(name)
                    end

                    if imgui.BeginPopupModal(name, _, imgui.WindowFlags.NoResize) then
                        imgui.SetWindowSizeVec2(imgui.ImVec2(500, 240))

                        imgui.Separator()

                        imgui.Text(u8("Время (секунды):"))

                        imgui.PushItemWidth(490)
                        imgui.InputText(u8("##timer_time"), timer_time_buffer, 8)

                        imgui.Separator()

                        imgui.Text(u8("Название:"))

                        imgui.InputText(u8("##timer_name"), timer_name_buffer, 128)
                        imgui.PopItemWidth()

                        imgui.Separator()

                        if AnimButton(u8("Сохранить"), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                            timer.name = u8:decode(ffi.string(timer_name_buffer))
                            timer.time = tonumber(u8:decode(ffi.string(timer_time_buffer)))
                            timer.isActive = timerActive[0]

                            saveConfig()

                            imgui.CloseCurrentPopup()
                        end

                        if AnimButton(u8("Удалить"), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                            table.remove(timers, index)

                            saveConfig()

                            imgui.CloseCurrentPopup()
                        end

                        if AnimButton(u8("Закрыть"), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                            imgui.CloseCurrentPopup()
                        end

                        imgui.End()
                    end

                    imgui.Separator()
                end
            else
                imgui.Text(u8("Таймеров нет!"))

                imgui.Separator()
            end

            if AnimButton(u8("Добавить"), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                table.insert(timers, {
                    name = "Новый таймер",
                    time = 60,
                    isActive = false
                })

                saveConfig()
            end

            imgui.End()
        end
        imgui.PopFont()
    end
)

imgui.OnFrame(
    function() return settingsTimerWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 200, 120
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        if imgui.Begin(u8("Вызов"), settingsTimerWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
            local time = os.date("%H:%M", os.time())
            local categories = {
                {
                    name = "Адвокат",
                    text_departament = string.format("Адвоката в допросную %s.", u8:decode(item_list_departament_from[int_item_founding[0] + 1])),
                    text_for_player = string.format("Адвокат вызван. Время вызова: %s. Время на приезд, после принятия вызова: 5 минут.", time),
                    timer = {
                        name = "Адвокат",
                        time = 180,
                        isActive = true
                    },
                },
                {
                    name = "Прокурор",
                    text_departament = string.format("Прокурора в допросную %s.", u8:decode(item_list_departament_from[int_item_founding[0] + 1])),
                    text_for_player = string.format("Прокурор вызван. Время вызова: %s. Время на приезд, после принятия вызова: 10 минут.", time),
                    timer = {
                        name = "Прокурор",
                        time = 300,
                        isActive = true
                    },
                },
                {
                    name = "Начальство",
                    text_departament = string.format("Начальство в допросную %s.", u8:decode(item_list_departament_from[int_item_founding[0] + 1])),
                    text_for_player = string.format("Начальство вызвано. Время вызова: %s. Время на приезд, после принятия вызова: 10 минут.", time),
                    timer = {
                        name = "Начальство",
                        time = 300,
                        isActive = true
                    },
                },
            }

            for index, category in pairs(categories) do
                local message_departament = string.format("/d [%s] - [%s]: %s", u8:decode(item_list_departament_from[int_item_departament_from[0] + 1]), u8:decode(item_list_departament_to[int_item_departament_to[0] + 1]), categories[index]["text_departament"])

                if AnimButton(u8(category.name), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                    imgui.OpenPopup(u8(category.name))
                end

                if imgui.BeginPopupModal(u8(category.name), _, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar) then
                    imgui.SetWindowSizeVec2(imgui.ImVec2(500, 262))

                    imgui.PushItemWidth(490)
                    imgui.Text(u8("Нахождение:"))
                    imgui.Combo("##selectFounding", int_item_founding, ImItemsFounding, #item_list_departament_from)

                    imgui.Text(u8("От:"))
                    imgui.Combo("##selectDepartamentFrom", int_item_departament_from, ImItemsDepartamentFrom, #item_list_departament_from)

                    imgui.Text(u8("Кому:"))
                    imgui.Combo("##selectDepartamentTo", int_item_departament_to, ImItemsDepartamentTo, #item_list_departament_to)
                    imgui.PopItemWidth()

                    imgui.Separator()

                    imgui.CenterText(u8(message_departament))

                    imgui.Separator()

                    if AnimButton(u8("Отправить"), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                        sampSendChat(message_departament)
                        sampSendChat(category.text_for_player)

                        table.insert(timers, category.timer)

                        saveConfig()

                        cefNotify("success", "Сообщение в департамент отправлено!")
                        sendMJHelperMessage("Сообщение в департамент отправлено!")

                        settingsTimerWindow[0] = not settingsTimerWindow[0]
                        imgui.CloseCurrentPopup()
                    end

                    if AnimButton(u8("Закрыть"), imgui.ImVec2(imgui.GetContentRegionAvail().x, 25)) then
                        imgui.CloseCurrentPopup()
                    end

                    imgui.End()
                end
            end

            imgui.End()
        end
    end
)

imgui.OnFrame(
    function() return settingsMegafonWindow[0] end,
    function()
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 300, 60
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)

        if imgui.Begin(u8("Мегафон"), settingsMegafonWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
            imgui.PushItemWidth(218)
            if imgui.ColorEdit3(u8("Цвет текста"), color_palitre_megafon) then saveConfig() end
            imgui.PopItemWidth()

            imgui.End()
        end
    end
)

local registerCommandWithArgument = function(command, window)
    sampRegisterChatCommand(command, function(id)
        if #id == 0 then
            cefNotify("error", "ID не указан!")
            return sendMJHelperMessage("ID не указан!")
        end

        targetID = tonumber(id)
        window[0] = not window[0]
    end)
end

sampev.onServerMessage = function(color, text)
    local text_without_hex = text:gsub("{......}", "")

    if afind then
        for _, error in pairs(afind_text) do
            if text_without_hex:find(error) then
                afind = false

                cefNotify("error", "/afind прекратил свою работу из-за ошибки!")
                sendMJHelperMessage("/afind прекратил свою работу из-за ошибки!")
            end
        end
    end

    if search_wanted and (text_without_hex:find("Используй%: %/wanted %[уровень розыска 1%-6%]") or text_without_hex:find("Игроков с таким уровнем розыска нету!")) then
        return false
    end

    if text_without_hex:find("%[M%] (.+)") then
        local new_color = string.format("%s", toHEX(color_palitre_megafon[0] * 255, color_palitre_megafon[1] * 255, color_palitre_megafon[2] * 255))
        local text = text:gsub("%[M%] (.+)", string.format("{%s}%s", new_color, text))

        return {hexToInt(new_color), text}
    end
end

sampev.onShowDialog = function(dialogId, style, title, button1, button2, text)
    if dialogId == 1780 and search_wanted then
        for line in text:gsub("{......}", ""):gmatch("[^\n]+") do
            local nickname, id, wanted_lvl, distance = line:match("(%w+_%w+)%((%d+)%)%s+(%d) уровень%s+%[(.+)%]")

            if nickname and id and wanted_lvl and distance then
                if distance:find("в интерьере") then distance = "В интерьере" end

                table.insert(searched, {
                    nickname = nickname,
                    id = id,
                    wanted_lvl = wanted_lvl,
                    distance = distance
                })
            end
        end

        return false
    end
end

local hi = function()
    cefNotify("success", "Хелпер для МЮ инициализирован!")

    sendMJHelperMessage("Хелпер для МЮ инициализирован!")
    sendMJHelperMessage("В консоль SampFuncs написаны все команды для хелпера и их описание!")

    print("/asu - умный розыск")
    print("/agwarn - умное ФП")
    print("/aticket - умная выдача штрафов")
    print("/bl - блокнот")
    print("/afind - поиск игрока по ID")
    print("/awanted - поиск всех игроков в розыске")
    print("/log - включить/выключить вывод сообщений в консоль")
    print("/siren - вкл/выкл сирену")
    print("/timers - настройки таймеров")
    print("/procc - вызов адвоката, прокуроров и начальства")
    print("/megafon - настройка цвета текста мегафона")
end

function main()
    while not isSampAvailable() do wait(0) end
    repeat wait(0) until sampIsLocalPlayerSpawned()

    loadConfig()
    saveConfig()

    check_update()

    hi()

    registerCommandWithArgument("asu", wantedWindow)
    registerCommandWithArgument("agwarn", federalWindow)
    registerCommandWithArgument("aticket", administrativeWindow)

    lua_thread.create(function()
        while true do
            if afind then
                sampSendChat("/find " .. targetID)
                wait(2000)
            else
                wait(0)
            end
        end
    end)

    lua_thread.create(function()
        while true do
            if #timers ~= 0 then
                for index, timer in pairs(timers) do
                    if timer.isActive then
                        timer.time = timer.time - 1

                        saveConfig()

                        if timer.time == 0 then
                            table.remove(timers, index)

                            saveConfig()

                            cefNotify("info", string.format("Таймер %s закончился!", timer.name))
                            sendMJHelperMessage(string.format("Таймер \"%s\" закончился!", timer.name))
                        end
                    end
                end
            end

            wait(1000)
        end
    end)

    sampRegisterChatCommand("afind", function(id)
        if #id == 0 then
            if afind then
                afind = false

                cefNotify("error", "/afind отключён!")
                return sendMJHelperMessage("/afind отключён!")
            end

            cefNotify("error", "ID не указан!")
            return sendMJHelperMessage("ID не указан!")
        end

        targetID = tonumber(id)

        if targetID < 0 or targetID > 999 then
            cefNotify("error", "ID должен быть от 0 до 999!")
            return sendMJHelperMessage("ID должен быть от 0 до 999!")
        end

        afind = true

        cefNotify("success", string.format("Ищу по /find игрока с ID %d!", targetID))
        sendMJHelperMessage(string.format("Ищу по /find игрока с ID %d!", targetID))
    end)

    sampRegisterChatCommand("log", function()
        log_message = not log_message

        saveConfig()

        sendMJHelperMessage(string.format("Теперь сообщения от хелпера выводятся в %s!", log_message and "лог SampFuncs" or "чат"))
    end)

    sampRegisterChatCommand("bl", function()
        notepadWindow[0] = not notepadWindow[0]
    end)

    sampRegisterChatCommand("timers", function()
        timerWindow[0] = not timerWindow[0]
    end)

    sampRegisterChatCommand("procc", function()
        settingsTimerWindow[0] = not settingsTimerWindow[0]
    end)

    sampRegisterChatCommand("megafon", function()
        settingsMegafonWindow[0] = not settingsMegafonWindow[0]
    end)

    sampRegisterChatCommand("awanted", function()
        lua_thread.create(function()
            search_wanted, searched, searchedWindow[0] = true, {}, true

            cefNotify("info", "Составляю список преступников...")
            sendMJHelperMessage("Составляю список преступников...")

            for i = 1, 7 do
                sampSendChat("/wanted " .. i)
                wait(1000)
            end

            search_wanted = false

            if #searched ~= 0 then
                cefNotify("success", string.format("Найдено преступников: %s", #searched))
                sendMJHelperMessage("Список преступников составлен!")
                sendMJHelperMessage(string.format("Найдено преступников: %s", #searched))
            else
                cefNotify("error", "Список преступников пуст!")
                sendMJHelperMessage("Список преступников пуст!")
            end
        end)
    end)

    sampRegisterChatCommand("siren", function()
        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)

            if getDriverOfCar(car) ~= PLAYER_PED then
                cefNotify("error", "Вы должны быть водителем этого автомобиля!")
                return sendMJHelperMessage("Вы должны быть водителем этого автомобиля!")
            end

            switchCarSiren(car, not isCarSirenOn(car))
            sendMJHelperMessage(string.format("Мигалки %s!", isCarSirenOn(car) and "включены" or "выключены"))
        else
            cefNotify("error", "Вы должны находиться в автомобиле!")
            sendMJHelperMessage("Вы должны находиться в автомобиле!")
        end
    end)

    while true do wait(0)
        for i, timer in pairs(timers) do
            if timer.isActive then
                renderFontDrawText(renderFont, string.format("%s: %s", timer.name, os.date("!%H:%M:%S", timer.time)), 55, 775 - (i + 1) * 20, 0xFFFFFFFF, false)
            end
        end
    end
end

addEventHandler("onWindowMessage", function(msg, wp, lp)
    if wp == 0x1B and (wantedWindow[0] or federalWindow[0] or administrativeWindow[0] or notepadWindow[0] or updateWindow[0] or timerWindow[0] or settingsTimerWindow[0] or settingsMegafonWindow[0]) then
        if msg == 0x100 then
            consumeWindowMessage(true, false)
        end

        if msg == 0x101 then
            wantedWindow[0] = false
            federalWindow[0] = false
            administrativeWindow[0] = false
            notepadWindow[0] = false
            updateWindow[0] = false
            timerWindow[0] = false
            settingsTimerWindow[0] = false
            settingsMegafonWindow[0] = false
        end
    end
end)