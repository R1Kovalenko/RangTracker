script_name("RankTracker 3.1")
script_author("ROMAN KOVALENKO")
script_version("3.1")

require('lib.moonloader')
local IS_MOBILE = MONET_VERSION ~= nil
local sampev   = require 'lib.samp.events'
local inicfg   = require 'inicfg'
local requests = require 'requests'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local imgui = require 'mimgui'
local ffi = require 'ffi'
local dkok, dkjson = pcall(require, "dkjson")

if IS_MOBILE then
    print('[RankTracker] Мобильная версия через MonetLoader')
else
    print('[RankTracker] ПК версия')
end

-- ================= SETTINGS =================
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1495625228959875264/pDdTB8lLaS4KmWyqTtMNeKOwSjjpvXFlTmXOMX5kHdGpzoIBtKO7g2sMrhckoHB1T8CR"
local PROFIT_PERCENT  = 0.5
local MANAGER_NAME    = "Nick_Name"

-- ================= CONFIG =================
local worked_dir  = getWorkingDirectory():gsub('\\','/')
local config_dir  = worked_dir .. "/RankTracker/"
local config_file = config_dir .. "RankTracker.ini"
if not doesDirectoryExist(config_dir) then createDirectory(config_dir) end

local main_ini = inicfg.load({
    Settings = { MyName = MANAGER_NAME }
}, config_file)

-- ================= CACHE =================
local Cache = { buyer = "", rank = "?", days = "?", price = 0, profit = 0, time = 0 }

-- ================= GUI STATE =================
-- Используем imgui.new только для значений, НЕ для строк на мобиле через ffi
local show_menu = imgui.new.bool(false)
-- MonetLoader не поддерживает imgui.new.char[N](val) — используем ffi напрямую
local new_name_buf = ffi.new("char[64]")
ffi.fill(new_name_buf, 64, 0)
local log_scroll_bottom = false

-- ================= CP1251 -> UTF-8 =================
local cp1251_to_utf8 = {
    [0x80]="\xE2\x82\xAC",[0x81]="?",[0x82]="\xE2\x80\x9A",[0x83]="\xC6\x92",
    [0x84]="\xE2\x80\x9E",[0x85]="\xE2\x80\xA6",[0x86]="\xE2\x80\xA0",[0x87]="\xE2\x80\xA1",
    [0x88]="\xCB\x86",[0x89]="\xE2\x80\xB0",[0x8A]="\xC5\xA0",[0x8B]="\xE2\x80\xB9",
    [0x8C]="\xC5\x92",[0x8D]="?",[0x8E]="\xC5\xBD",[0x8F]="?",
    [0x90]="?",[0x91]="\xE2\x80\x98",[0x92]="\xE2\x80\x99",[0x93]="\xE2\x80\x9C",
    [0x94]="\xE2\x80\x9D",[0x95]="\xE2\x80\xA2",[0x96]="\xE2\x80\x93",[0x97]="\xE2\x80\x94",
    [0x98]="\xCB\x9C",[0x99]="\xE2\x84\xA2",[0x9A]="\xC5\xA1",[0x9B]="\xE2\x80\xBA",
    [0x9C]="\xC5\x93",[0x9D]="?",[0x9E]="\xC5\xBE",[0x9F]="\xC5\xB8",
    [0xA0]="\xC2\xA0",[0xA1]="\xD0\x8E",[0xA2]="\xD1\x9E",[0xA3]="\xD0\x88",
    [0xA4]="\xC2\xA4",[0xA5]="\xD2\x90",[0xA6]="\xC2\xA6",[0xA7]="\xC2\xA7",
    [0xA8]="\xD0\x81",[0xA9]="\xC2\xA9",[0xAA]="\xD0\x84",[0xAB]="\xC2\xAB",
    [0xAC]="\xC2\xAC",[0xAD]="\xC2\xAD",[0xAE]="\xC2\xAE",[0xAF]="\xD0\x87",
    [0xB0]="\xC2\xB0",[0xB1]="\xC2\xB1",[0xB2]="\xD0\x86",[0xB3]="\xD1\x96",
    [0xB4]="\xD2\x91",[0xB5]="\xC2\xB5",[0xB6]="\xC2\xB6",[0xB7]="\xC2\xB7",
    [0xB8]="\xD1\x91",[0xB9]="\xE2\x84\x96",[0xBA]="\xD1\x94",[0xBB]="\xC2\xBB",
    [0xBC]="\xD1\x98",[0xBD]="\xD0\x83",[0xBE]="\xD1\x93",[0xBF]="\xD1\x97",
    [0xC0]="\xD0\x90",[0xC1]="\xD0\x91",[0xC2]="\xD0\x92",[0xC3]="\xD0\x93",
    [0xC4]="\xD0\x94",[0xC5]="\xD0\x95",[0xC6]="\xD0\x96",[0xC7]="\xD0\x97",
    [0xC8]="\xD0\x98",[0xC9]="\xD0\x99",[0xCA]="\xD0\x9A",[0xCB]="\xD0\x9B",
    [0xCC]="\xD0\x9C",[0xCD]="\xD0\x9D",[0xCE]="\xD0\x9E",[0xCF]="\xD0\x9F",
    [0xD0]="\xD0\xA0",[0xD1]="\xD0\xA1",[0xD2]="\xD0\xA2",[0xD3]="\xD0\xA3",
    [0xD4]="\xD0\xA4",[0xD5]="\xD0\xA5",[0xD6]="\xD0\xA6",[0xD7]="\xD0\xA7",
    [0xD8]="\xD0\xA8",[0xD9]="\xD0\xA9",[0xDA]="\xD0\xAA",[0xDB]="\xD0\xAB",
    [0xDC]="\xD0\xAC",[0xDD]="\xD0\xAD",[0xDE]="\xD0\xAE",[0xDF]="\xD0\xAF",
    [0xE0]="\xD0\xB0",[0xE1]="\xD0\xB1",[0xE2]="\xD0\xB2",[0xE3]="\xD0\xB3",
    [0xE4]="\xD0\xB4",[0xE5]="\xD0\xB5",[0xE6]="\xD0\xB6",[0xE7]="\xD0\xB7",
    [0xE8]="\xD0\xB8",[0xE9]="\xD0\xB9",[0xEA]="\xD0\xBA",[0xEB]="\xD0\xBB",
    [0xEC]="\xD0\xBC",[0xED]="\xD0\xBD",[0xEE]="\xD0\xBE",[0xEF]="\xD0\xBF",
    [0xF0]="\xD1\x80",[0xF1]="\xD1\x81",[0xF2]="\xD1\x82",[0xF3]="\xD1\x83",
    [0xF4]="\xD1\x84",[0xF5]="\xD1\x85",[0xF6]="\xD1\x86",[0xF7]="\xD1\x87",
    [0xF8]="\xD1\x88",[0xF9]="\xD1\x89",[0xFA]="\xD1\x8A",[0xFB]="\xD1\x8B",
    [0xFC]="\xD1\x8C",[0xFD]="\xD1\x8D",[0xFE]="\xD1\x8E",[0xFF]="\xD1\x8F",
}

function cp1251_utf8(str)
    if not str then return "" end
    local result = {}
    for i = 1, #str do
        local b = str:byte(i)
        if b >= 0x80 then
            result[#result+1] = cp1251_to_utf8[b] or "?"
        else
            result[#result+1] = string.char(b)
        end
    end
    return table.concat(result)
end

-- ================= UTILS =================
function fmt(n)
    return string.format("%.0f", n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function escape_json(str)
    str = tostring(str)
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"',  '\\"')
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")
    return str
end

function stripColors(str)
    return (str or ""):gsub("{%x%x%x%x%x%x}", "")
end

function parseAmount(str)
    if not str then return 0 end
    str = tostring(str)
    str = str:gsub("\xD0\x9A\xD0\x9A", "KK")
    str = str:gsub("\xCA\xCA", "KK")
    str = str:gsub("\xD0\x9A", "K")
    str = str:gsub("\xCA", "K")
    str = str:gsub(":KK:", "KK"):gsub(":K:", "K"):gsub(":M:", "M")
    str = str:gsub("[%.,%s]", "")
    local kk_val, k_val = str:match("KK(%d+)K(%d+)")
    if kk_val and k_val then
        return tonumber(kk_val) * 1000000 + tonumber(k_val)
    end
    local kk = str:match("KK(%d+)")
    if kk then return tonumber(kk) * 1000000 end
    local k = str:match("K(%d+)")
    if k then return tonumber(k) * 1000 end
    local m = str:match("M(%d+)")
    if m then return tonumber(m) * 1000000000 end
    return tonumber(str:match("%d+")) or 0
end

function getStoredName()
    if main_ini.Settings.MyName and main_ini.Settings.MyName ~= "Unknown" and main_ini.Settings.MyName ~= "" then
        return main_ini.Settings.MyName
    end
    local ok, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if ok then
        local name = sampGetPlayerNickname(id)
        if name and #name > 2 then
            main_ini.Settings.MyName = name
            inicfg.save(main_ini, config_file)
            return name
        end
    end
    return "Unknown"
end

function logToFile(text)
    local log_dir = worked_dir .. "/RankTracker/logs/"
    if not doesDirectoryExist(log_dir) then createDirectory(log_dir) end
    local f = io.open(log_dir .. "rank_tracker.log", "a")
    if f then
        f:write(os.date("[%d.%m.%Y %H:%M:%S] ") .. text .. "\n")
        f:close()
    end
end

function getLogs()
    local log_file = worked_dir .. "/RankTracker/logs/rank_tracker.log"
    if not doesFileExist(log_file) then return "Лог пуст." end
    local f = io.open(log_file, "r")
    if not f then return "Ошибка открытия лога." end
    local content = f:read("*a")
    f:close()
    return content ~= "" and content or "Лог пуст."
end

-- ================= UPDATE FROM GITHUB =================
function updateFromGitHub()
    if not dkok then
        sampAddChatMessage("{e74c3c}[RankTracker] dkjson not found!", -1)
        return
    end
    local update_url = "https://raw.githubusercontent.com/R1Kovalenko/ARZ/main/Update.json"
    sampAddChatMessage("{f1c40f}[RankTracker] Checking for updates...", -1)
    local ok, res = pcall(function() return requests.get(update_url) end)
    if not ok or not res or res.status_code ~= 200 then
        sampAddChatMessage("{e74c3c}[RankTracker] Update check failed!", -1)
        return
    end
    local data = dkjson.decode(res.text)
    if not data or not data.version or not data.url then
        sampAddChatMessage("{e74c3c}[RankTracker] Invalid update data!", -1)
        return
    end
    if data.version == thisScript().version then
        sampAddChatMessage("{2ecc71}[RankTracker] Latest version: " .. thisScript().version, -1)
        return
    end
    local ok2, res2 = pcall(function() return requests.get(data.url) end)
    if not ok2 or not res2 or res2.status_code ~= 200 then
        sampAddChatMessage("{e74c3c}[RankTracker] Download failed!", -1)
        return
    end
    local f = io.open(thisScript().path, "w")
    if f then
        f:write(res2.text)
        f:close()
        sampAddChatMessage("{2ecc71}[RankTracker] Updated to " .. data.version .. "! Reload script.", -1)
    else
        sampAddChatMessage("{e74c3c}[RankTracker] Save failed!", -1)
    end
end

-- ================= DISCORD =================
function sendDiscord(buyer, rank, days, price, profit, title)
    local datetime  = os.date("%d.%m.%Y %H:%M")
    local price_kk  = fmt(price  / 1000000)
    local profit_kk = fmt(profit / 1000000)
    local manager   = getStoredName()

    local buyer_u  = escape_json(cp1251_utf8(buyer))
    local rank_u   = escape_json(cp1251_utf8(rank))
    local title_u  = escape_json(cp1251_utf8(title))

    local f_buyer  = "\xD0\x9F\xD0\xBE\xD0\xBA\xD1\x83\xD0\xBF\xD0\xB0\xD1\x82\xD0\xB5\xD0\xBB\xD1\x8C"
    local f_rank   = "\xD0\xA0\xD0\xB0\xD0\xBD\xD0\xB3"
    local f_sum    = "\xD0\xA1\xD1\x83\xD0\xBC\xD0\xBC\xD0\xB0"
    local f_profit = "\xD0\x94\xD0\xBE\xD1\x85\xD0\xBE\xD0\xB4"
    local f_mgr    = "\xD0\x9C\xD0\xB5\xD0\xBD\xD0\xB5\xD0\xB4\xD0\xB6\xD0\xB5\xD1\x80"
    local dn       = "\xD0\xB4\xD0\xBD"

    local body = '{"embeds":[{"title":"' .. title_u .. '",' ..
        '"color":3447003,' ..
        '"fields":[' ..
            '{"name":"' .. f_buyer  .. '","value":"' .. buyer_u .. '","inline":true},' ..
            '{"name":"' .. f_rank   .. '","value":"' .. rank_u  .. ' (' .. escape_json(days) .. ' ' .. dn .. '.)","inline":true},' ..
            '{"name":"' .. f_sum    .. '","value":"' .. escape_json(price_kk)  .. ' KK","inline":true},' ..
            '{"name":"' .. f_profit .. '","value":"' .. escape_json(profit_kk) .. ' KK","inline":true},' ..
            '{"name":"' .. f_mgr   .. '","value":"' .. MANAGER_NAME .. '","inline":false}' ..
        '],' ..
        '"footer":{"text":"' .. f_mgr .. ': ' .. escape_json(manager) .. ' | ' .. escape_json(datetime) .. '"}' ..
    '}]}'

    local ok, res = pcall(function()
        return requests.request("POST", DISCORD_WEBHOOK, {
            data    = body,
            headers = { ["Content-Type"] = "application/json; charset=utf-8" }
        })
    end)
    local status = ok and res and tostring(res.status_code) or "ERR"
    sampAddChatMessage("{2ecc71}[RankTracker] Discord: " .. status, -1)
    if not ok then print("[RankTracker] Discord ERROR: " .. tostring(res)) end
end

function sendLog(buyer, rank, days, price, profit, title)
    lua_thread.create(function() sendDiscord(buyer, rank, days, price, profit, title) end)
    logToFile(string.format("[%s] %s | %s | %s KK", title, buyer, rank, fmt(price / 1000000)))
    sampAddChatMessage("{43b581}[RankTracker] {ffffff}Отправка в Discord...", -1)
end

-- ================= DIALOG HANDLER =================
function sampev.onShowDialog(id, style, title, button1, button2, text)
    pcall(function()
        local clean = stripColors(text)
        if not clean:find("Общая стоимость:") then return end

        local buyer = clean:match("[Вв]ыбранный игрок:%s*([%w_%-]+)%(%d+%)")
                   or clean:match("[Вв]ыбранный игрок:%s*([%w_%-]+)")
                   or clean:match("^([%w]+_[%w]+)")

        local rank = clean:match("[Рр]анг игрока:%s*([^\n]+)")
                  or clean:match("[Вв]ыбранный ранг:%s*([^\n]+)")
        if rank then
            rank = rank:gsub("%(%d+%)",""):gsub("[%.%s]+$",""):match("^%s*(.-)%s*$")
        end

        local days      = clean:match("[Вв]ыбранное кол%-во дней:%s*(%d+)")
        local total_str = clean:match("Общая стоимость:%s*([^\n]+)")
        local profit_str= clean:match("[Вв]аш процент:%s*([^\n%(]+)")

        if buyer then buyer = buyer:gsub("[%.%s]+$", "") end

        local price  = total_str   and parseAmount(total_str)  or 0
        local profit = profit_str  and parseAmount(profit_str) or math.floor(price * PROFIT_PERCENT)

        if buyer and buyer ~= "" then
            Cache.buyer  = buyer
            Cache.rank   = rank  or "?"
            Cache.days   = days  or "?"
            Cache.price  = price
            Cache.profit = profit
            Cache.time   = os.time()
        end
    end)
end

-- ================= MESSAGE HANDLER =================
function sampev.onServerMessage(color, text)
    pcall(function()
        local clean = stripColors(text)

        if clean:find("Вы предложили игроку") and clean:find("ранг в организации") then
            local p_buyer, p_rank = clean:match("Вы предложили игроку ([%w_]+) .+ ранг в организации (.+)")
            if p_buyer then
                Cache.buyer = p_buyer
                Cache.rank  = p_rank or Cache.rank
                Cache.time  = os.time()
            end
        end

        if clean:find("принял покупку ранга") or clean:find("принял продление ранга") then
            local chat_buyer = clean:match("Игрок ([%w_]+)%(%d+%) принял")
                            or clean:match("Игрок ([%w_]+) принял")
            local price_str  = clean:match("ранга за (.+)$")

            if chat_buyer and price_str then
                price_str = price_str:gsub("[%.$]", ""):gsub("%s+", "")
                price_str = price_str:gsub("\xD0\x9A\xD0\x9A", "KK")
                price_str = price_str:gsub("\xCA\xCA", "KK")
                price_str = price_str:gsub(":KK:", "KK"):gsub(":K:", "K")

                local amount = parseAmount(price_str)
                if amount == 0 then
                    local n = price_str:match("(%d+)")
                    if n then amount = tonumber(n) * 1000000 end
                end

                local fresh       = (os.time() - Cache.time) < 120
                local matched     = fresh and Cache.buyer ~= "" and clean:find(Cache.buyer, 1, true)
                local final_rank  = matched and Cache.rank or "?"
                local final_days  = matched and Cache.days or "?"
                if amount == 0 then amount = Cache.price end

                local profit   = (Cache.profit and Cache.profit > 0) and Cache.profit or math.floor(amount * PROFIT_PERCENT)
                local op_title = clean:find("продление") and "ПРОДЛЕНИЕ РАНГА" or "ПОКУПКА РАНГА"

                sendLog(chat_buyer, final_rank, final_days, amount, profit, op_title)
                Cache = { buyer = "", rank = "?", days = "?", price = 0, profit = 0, time = 0 }
            end
        end
    end)
end

-- ================= GUI =================
-- ИСПРАВЛЕНИЕ: используем imgui.OnRender (работает и в MonetLoader, и в MoonLoader)
imgui.OnRender(function()
    if not show_menu[0] then return end

    -- Адаптивный размер окна
    local win_w = IS_MOBILE and 320 or 420
    local win_h = IS_MOBILE and 280 or 340
    imgui.SetNextWindowSize(imgui.ImVec2(win_w, win_h), imgui.Cond.FirstUseEver)

    -- Центрируем окно при первом открытии
    local sw = imgui.GetIO().DisplaySize.x
    local sh = imgui.GetIO().DisplaySize.y
    imgui.SetNextWindowPos(
        imgui.ImVec2(sw / 2 - win_w / 2, sh / 2 - win_h / 2),
        imgui.Cond.FirstUseEver
    )

    local opened, show = imgui.Begin("RankTracker v3.0", show_menu)
    if opened then
        -- Заголовок
        imgui.TextColored(imgui.ImVec4(0.26, 0.71, 0.51, 1), "RankTracker")
        imgui.SameLine()
        imgui.TextDisabled("v3.0")
        imgui.Separator()

        -- Текущий менеджер
        imgui.Text("Менеджер: ")
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(1, 0.8, 0.2, 1), getStoredName())
        imgui.Spacing()

        -- Поле ввода имени
        imgui.Text("Изменить имя:")
        imgui.SetNextItemWidth(IS_MOBILE and 200 or 260)
        imgui.InputText("##name", new_name_buf, 64)
        imgui.SameLine()
        if imgui.Button("OK##savename") then
            local name_str = ffi.string(new_name_buf)
            if name_str ~= "" then
                main_ini.Settings.MyName = name_str
                inicfg.save(main_ini, config_file)
                sampAddChatMessage("{2ecc71}[RankTracker] Имя сохранено: " .. name_str, -1)
                ffi.fill(new_name_buf, ffi.sizeof(new_name_buf), 0)
            end
        end
        imgui.Separator()

        -- Кэш последней операции
        imgui.Text("Последняя запись:")
        imgui.TextColored(imgui.ImVec4(0.6, 0.9, 1, 1),
            string.format("  %s | %s | %s дн. | %s KK",
                Cache.buyer ~= "" and Cache.buyer or "—",
                Cache.rank,
                Cache.days,
                fmt(Cache.price / 1000000)
            )
        )
        imgui.Separator()

        -- Лог
        imgui.Text("Лог (последние записи):")
        local child_h = IS_MOBILE and 80 or 100
        imgui.BeginChild("##logs", imgui.ImVec2(0, child_h), true)
        local logs = getLogs()
        -- Показываем только последние ~10 строк чтобы не грузить
        local lines = {}
        for l in logs:gmatch("[^\n]+") do lines[#lines+1] = l end
        local start = math.max(1, #lines - 9)
        for i = start, #lines do
            imgui.TextWrapped(lines[i])
        end
        if log_scroll_bottom then
            imgui.SetScrollHereY(1.0)
            log_scroll_bottom = false
        end
        imgui.EndChild()

        imgui.Separator()

        -- Кнопки внизу
        local btn_w = IS_MOBILE and 90 or 120
        if imgui.Button("Тест##test", imgui.ImVec2(btn_w, 0)) then
            sendLog("Test_User", "Media-Manager", "30", 60000000, 30000000, "ПОКУПКА РАНГА")
            log_scroll_bottom = true
        end
        imgui.SameLine()
        if imgui.Button("Обновить##update", imgui.ImVec2(btn_w, 0)) then
            lua_thread.create(updateFromGitHub)
        end
        imgui.SameLine()
        if imgui.Button("Закрыть##close", imgui.ImVec2(btn_w, 0)) then
            show_menu[0] = false
        end
    end
    imgui.End()
end)

-- ================= MAIN =================
function main()
    while not isSampAvailable() do wait(100) end
    wait(500)

    sampAddChatMessage("{43b581}[RankTracker v3.0] {ffffff}Запущен! Менеджер: " .. getStoredName(), -1)

    sampRegisterChatCommand("rtest", function()
        sampAddChatMessage("{f1c40f}[Test] Отправка теста в Discord...", -1)
        sendLog("Test_User", "Media-Manager", "30", 60000000, 30000000, "ПОКУПКА РАНГА")
    end)

    sampRegisterChatCommand("rname", function(args)
        if args and args ~= "" then
            main_ini.Settings.MyName = args
            inicfg.save(main_ini, config_file)
            sampAddChatMessage("{2ecc71}[RankTracker] Имя установлено: " .. args, -1)
        else
            sampAddChatMessage("{f1c40f}[RankTracker] Текущее имя: " .. getStoredName(), -1)
        end
    end)

    -- /fmenu — открыть/закрыть меню
    sampRegisterChatCommand("fmenu", function()
        show_menu[0] = not show_menu[0]
        sampAddChatMessage("[RankTracker] Меню: " .. (show_menu[0] and "открыто" or "закрыто"), -1)
    end)

    sampRegisterChatCommand("rupdate", function()
        lua_thread.create(updateFromGitHub)
    end)

    while true do
        wait(0)
    end
end
