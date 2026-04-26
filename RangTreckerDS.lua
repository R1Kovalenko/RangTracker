script_name("RankTracker 3.3")
script_author("ROMAN KOVALENKO")
script_version("3.2")

require('lib.moonloader')
local IS_MOBILE = MONET_VERSION ~= nil
local sampev    = require 'lib.samp.events'
local requests  = require 'requests'
local imgui     = require 'mimgui'
local ffi       = require 'ffi'
local encoding  = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

if IS_MOBILE then
    print('[RankTracker] Mobile via MonetLoader')
else
    print('[RankTracker] PC version')
end

-- ================= SETTINGS =================
local DISCORD_WEBHOOK = "сюда_ссылка_на_веб_хук"
local PROFIT_PERCENT  = 0.5
local MANAGER_NAME    = "Nick_Name"

-- ================= GITHUB ССЫЛКИ =================
-- TODO: замени USER и REPO на свои данные GitHub
local GITHUB_VERSION_URL = "https://raw.githubusercontent.com/USER/REPO/main/Update.json"
local GITHUB_SCRIPT_URL  = "https://raw.githubusercontent.com/USER/REPO/main/RankTracker.lua"

-- ================= ПУТИ =================
local worked_dir  = getWorkingDirectory():gsub('\\', '/')
local config_dir  = worked_dir .. "/RankTracker/"
local config_file = config_dir .. "Settings.json"
local log_file    = config_dir .. "logs/rank_tracker.log"

if not doesDirectoryExist(config_dir) then createDirectory(config_dir) end
if not doesDirectoryExist(config_dir .. "logs") then createDirectory(config_dir .. "logs") end

-- ================= JSON КОНФИГ =================
local default_settings = {
    manager_name = MANAGER_NAME,
    profit_pct   = PROFIT_PERCENT,
    autofind_dpi = false,
    custom_dpi   = 1.0,
}

local settings = {}

local function merge_defaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            target[k] = v
            print('[RankTracker] Новый параметр конфига: ' .. tostring(k) .. ' = ' .. tostring(v))
        end
    end
end

local function load_settings()
    if doesFileExist(config_file) then
        local f = io.open(config_file, 'r')
        if f then
            local content = f:read('*a')
            f:close()
            local ok, decoded = pcall(decodeJson, content)
            if ok and type(decoded) == 'table' then
                settings = decoded
            else
                settings = {}
            end
        end
    else
        settings = {}
    end
    merge_defaults(settings, default_settings)
end

local function save_settings()
    local f = io.open(config_file, 'w')
    if f then
        local ok, encoded = pcall(encodeJson, settings)
        f:write(ok and encoded or '{}')
        f:close()
    end
end

-- ================= АВТО-DPI =================
local sizeX, sizeY = getScreenResolution()

-- Загружаем конфиг ДО объявления DPI, чтобы авто-масштаб применился при первом запуске
load_settings()

local function apply_dpi()
    if not settings.autofind_dpi then
        print('[RankTracker] Применение авто-размера интерфейса...')
        if IS_MOBILE then
            settings.custom_dpi = MONET_DPI_SCALE
        else
            local ws = sizeX / 1366
            local hs = sizeY / 768
            settings.custom_dpi = (ws + hs) / 2
        end
        settings.autofind_dpi = true
        settings.custom_dpi   = tonumber(string.format('%.3f', settings.custom_dpi))
        print('[RankTracker] Масштаб интерфейса: ' .. settings.custom_dpi)
        save_settings()
    end
end

apply_dpi()  -- применяется сразу при загрузке, до main()

local DPI = settings.custom_dpi or 1.0

-- Размеры с учётом DPI (+20% от базы)
local function S()
    local d = DPI
    return {
        win_w  = math.floor(576 * d),
        win_h  = math.floor(600 * d),
        btn_h  = math.floor(38  * d),
        card_h = math.floor(92  * d),
        log_h  = math.floor(156 * d),
    }
end

-- ================= КОДИРОВКА =================
local cp1251_map = {
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
    [0xA8]="\xD0\x81",[0xB8]="\xD1\x91",
    [0x80]="\xE2\x82\xAC",[0xA0]="\xC2\xA0",
}

function cp1251_utf8(str)
    if not str then return "" end
    local r = {}
    for i = 1, #str do
        local b = str:byte(i)
        r[#r+1] = (b >= 0x80) and (cp1251_map[b] or "?") or string.char(b)
    end
    return table.concat(r)
end

function toUI(str)
    if not str or str == "" then return "\xE2\x80\x94" end
    if str:find("\xD0[\x90-\xBF]") or str:find("\xD1[\x80-\x8F]") then
        return str
    end
    if str:find("[\x80-\xFF]") then
        return cp1251_utf8(str)
    end
    return str
end

-- ================= CACHE =================
local Cache = { buyer="", rank="?", days="?", price=0, profit=0, time=0 }

-- ================= LOG BUFFER =================
local log_lines     = {}
local MAX_LOG_LINES = 50

-- ================= GUI STATE =================
local show_menu    = imgui.new.bool(false)
local new_name_buf = ffi.new("char[64]")
ffi.fill(new_name_buf, 64, 0)

-- Конвертация UTF-8 строки обратно в CP1251 для sampAddChatMessage
local utf8_to_cp1251_map = {}
for cp, utf in pairs(cp1251_map) do utf8_to_cp1251_map[utf] = string.char(cp) end

function toChat(str)
    if not str then return "" end
    -- Если строка чистый ASCII — не трогаем
    if not str:find("[\x80-\xFF]") then return str end
    -- Заменяем UTF-8 последовательности на CP1251
    local result = str:gsub("[\xD0-\xD1][\x80-\xBF]", function(seq)
        return utf8_to_cp1251_map[seq] or "?"
    end)
    return result
end

-- ================= UI СТРОКИ UTF-8 =================
local L = {
    tab_main     = u8("  Главная  "),
    tab_log      = u8("  Лог  "),
    tab_settings = u8("  Настройки  "),
    manager_lbl  = u8("Менеджер:"),
    last_entry   = u8("Последняя запись:"),
    curr_lbl     = u8("Текущее:"),
    name_lbl     = u8("Имя менеджера:"),
    hint_input   = u8("Введите новое имя:"),
    plat_lbl     = u8("Платформа:"),
    ver_lbl      = u8("Версия:"),
    pct_lbl      = u8("Доход %:"),
    dpi_lbl      = u8("Масштаб DPI:"),
    cmd_lbl      = u8("Команды:"),
    days_sfx     = u8("дн."),
    no_data      = "\xE2\x80\x94",
    log_empty    = u8("Лог пуст"),
    plat_mob     = "MonetLoader (Mobile)",
    plat_pc      = "MoonLoader (PC)",
    btn_send     = u8(" Отправить в Discord"),
    btn_test     = u8("Тест"),
    btn_update   = u8("Обновить скрипт"),
    btn_close    = u8("Закрыть"),
    btn_save     = u8("Сохранить"),
    btn_reload   = u8("Обновить лог"),
    btn_reset_dpi = u8("Сбросить DPI"),
    op_buy       = u8("ПОКУПКА РАНГА"),
    op_ext       = u8("ПРОДЛЕНИЕ РАНГА"),
    manual_title = u8("РУЧНАЯ ОТПРАВКА"),
    -- Строки для чата: только ASCII, кириллицу не используем
    chat_start   = "[RankTracker] Started! Manager: ",
    chat_sending = "[RankTracker] Sending to Discord...",
    chat_name_set= "[RankTracker] Name set: ",
    chat_name_cur= "[RankTracker] Current name: ",
    chat_upd_chk = "[RankTracker] Checking updates...",
    chat_upd_ok  = "[RankTracker] Already latest: ",
    chat_upd_new = "[RankTracker] Updated to v",
    chat_upd_rel = " - reloading!",
    chat_upd_err = "[RankTracker] Download error!",
    chat_upd_con = "[RankTracker] No connection!",
    chat_dis_ok  = "[RankTracker] Discord: ",
}

-- ================= UTILS =================
function fmt(n)
    return string.format("%.0f", n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Форматирование суммы: >= 1kk -> "X KK", иначе -> "X K"
function fmtMoney(n)
    if n >= 1000000 then
        local kk = n / 1000000
        -- Если целое число KK
        if kk == math.floor(kk) then
            return fmt(kk) .. " KK"
        else
            -- Дробное: например 17.5 KK -> "17 KK 500 K"
            local kk_int  = math.floor(kk)
            local kk_rest = math.floor((kk - kk_int) * 1000)
            if kk_rest > 0 then
                return fmt(kk_int) .. " KK " .. fmt(kk_rest) .. " K"
            end
            return string.format("%.3f", kk) .. " KK"
        end
    elseif n >= 1000 then
        return fmt(n / 1000) .. " K"
    else
        return fmt(n)
    end
end

function escape_json(str)
    str = tostring(str)
    return str:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
end

function stripColors(str)
    return (str or ""):gsub("{%x%x%x%x%x%x}", "")
end

function parseAmount(str)
    if not str then return 0 end
    str = tostring(str)

    -- Убираем все не-ASCII байты (иконки КК, звёздочки-иконки игры)
    str = str:gsub("[\x80-\xFF]", "")
    str = str:gsub(":KK:", "KK"):gsub(":K:", "K"):gsub(":M:", "M")
    -- Убираем пробелы по краям
    str = str:match("^%s*(.-)%s*$") or str

    -- Формат "KK X * Y" или "KK X Y" где Y = дробная часть через точку
    -- Пример: "KK 35" = 35,000,000
    -- Пример: "KK 17 500.000" = 17,500,000 (17 KK + 500,000)
    -- Пример: "KK 4 500.000" = 4,500,000
    local kk_int, kk_frac = str:match("KK%s*(%d+)%s+(%d+)[%.,]%d*")
    if kk_int and kk_frac then
        -- KK 17 500.000 -> 17*1000000 + 500000
        local frac = tonumber(kk_frac) or 0
        -- frac это тысячи (500 = 500,000; 100 = 100,000)
        return (tonumber(kk_int) or 0) * 1000000 + frac * 1000
    end

    local kk = str:match("KK%s*(%d+)")
    if kk then return (tonumber(kk) or 0) * 1000000 end

    local k = str:match("K%s*(%d+)")
    if k then return (tonumber(k) or 0) * 1000 end

    local m = str:match("M%s*(%d+)")
    if m then return (tonumber(m) or 0) * 1000000000 end

    -- Просто число с точкой как разделителем тысяч: "100.100" = 100100
    str = str:gsub("[%.,%s]", "")
    return tonumber(str:match("%d+")) or 0
end

function getManagerName()
    return settings.manager_name or MANAGER_NAME
end

-- ================= ЛОГ =================
function addLogLine(text)
    local f = io.open(log_file, "a")
    if f then
        f:write(os.date("[%d.%m.%Y %H:%M:%S] ") .. text .. "\n")
        f:close()
    end
    local ui_line = os.date("[%H:%M] ") .. toUI(text)
    table.insert(log_lines, ui_line)
    if #log_lines > MAX_LOG_LINES then table.remove(log_lines, 1) end
end

function loadLogsFromFile()
    if not doesFileExist(log_file) then return end
    local f = io.open(log_file, "r")
    if not f then return end
    log_lines = {}
    for line in f:lines() do
        table.insert(log_lines, toUI(line))
    end
    f:close()
    while #log_lines > MAX_LOG_LINES do table.remove(log_lines, 1) end
end

-- ================= DISCORD =================
function sendDiscord(buyer, rank, days, price, profit, title)
    local datetime  = os.date("%d.%m.%Y %H:%M")
    local price_fmt  = fmtMoney(price)
    local profit_fmt = fmtMoney(profit)
    local manager   = getManagerName()

    -- title уже UTF-8 (из таблицы L), buyer/rank из SAMP — CP1251
    local buyer_u  = escape_json(toUI(tostring(buyer)))
    local rank_u   = escape_json(toUI(tostring(rank)))
    local title_u  = escape_json(tostring(title))

    local f_buyer  = "\xD0\x9F\xD0\xBE\xD0\xBA\xD1\x83\xD0\xBF\xD0\xB0\xD1\x82\xD0\xB5\xD0\xBB\xD1\x8C"
    local f_rank   = "\xD0\xA0\xD0\xB0\xD0\xBD\xD0\xB3"
    local f_sum    = "\xD0\xA1\xD1\x83\xD0\xBC\xD0\xBC\xD0\xB0"
    local f_profit = "\xD0\x94\xD0\xBE\xD1\x85\xD0\xBE\xD0\xB4 (50%)"
    local f_mgr    = "\xD0\x9C\xD0\xB5\xD0\xBD\xD0\xB5\xD0\xB4\xD0\xB6\xD0\xB5\xD1\x80"
    local dn       = "\xD0\xB4\xD0\xBD"

    local color = 3447003
    local ts = tostring(title)
    if ts:find("ПРОДЛЕНИЕ") or ts:find("\xD0\x9F\xD0\xA0\xD0\x9E\xD0\x94") then color = 3066993 end
    if ts:find("TEST") then color = 9807270 end

    local body = '{"embeds":[{"title":"' .. title_u .. '",' ..
        '"color":' .. color .. ',' ..
        '"fields":[' ..
            '{"name":"' .. f_buyer  .. '","value":"' .. buyer_u .. '","inline":true},' ..
            '{"name":"' .. f_rank   .. '","value":"' .. rank_u  .. ' (' .. escape_json(tostring(days)) .. ' ' .. dn .. '.)","inline":true},' ..
            '{"name":"' .. f_sum    .. '","value":"' .. escape_json(price_fmt)  .. '","inline":true},' ..
            '{"name":"' .. f_profit .. '","value":"' .. escape_json(profit_fmt) .. '","inline":true},' ..
            '{"name":"' .. f_mgr   .. '","value":"' .. escape_json(cp1251_utf8(manager)) .. '","inline":false}' ..
        '],' ..
        '"footer":{"text":"' .. escape_json(cp1251_utf8(manager)) .. ' | ' .. escape_json(datetime) .. '"}' ..
    '}]}'

    local ok, res = pcall(function()
        return requests.request("POST", DISCORD_WEBHOOK, {
            data    = body,
            headers = { ["Content-Type"] = "application/json; charset=utf-8" }
        })
    end)
    local status = ok and res and tostring(res.status_code) or "ERR"
    local col    = (status == "204" or status == "200") and "{2ecc71}" or "{e74c3c}"
    sampAddChatMessage(col .. L.chat_dis_ok .. status, -1)
    if not ok then print("[RankTracker] Discord ERROR: " .. tostring(res)) end
end

function sendLog(buyer, rank, days, price, profit, title)
    lua_thread.create(function() sendDiscord(buyer, rank, days, price, profit, title) end)
    local log_text = string.format("[%s] %s | %s | %s дн. | %s KK",
        tostring(title), tostring(buyer), tostring(rank),
        tostring(days), fmt(price / 1000000))
    addLogLine(log_text)
    sampAddChatMessage("{43b581}" .. L.chat_sending, -1)
end

-- ================= АВТООБНОВЛЕНИЕ =================
function updateScript()
    lua_thread.create(function()
        sampAddChatMessage("{f1c40f}" .. L.chat_upd_chk, -1)

        local ok, res = pcall(requests.get, GITHUB_VERSION_URL)
        if not ok or not res or res.status_code ~= 200 then
            sampAddChatMessage("{e74c3c}" .. L.chat_upd_con, -1)
            return
        end

        local ok2, data = pcall(decodeJson, res.text)
        if not ok2 or not data or not data.version or not data.url then
            sampAddChatMessage("{e74c3c}[RankTracker] " .. u8("Некорректный ответ сервера!"), -1)
            return
        end

        if data.version == thisScript().version then
            sampAddChatMessage("{2ecc71}" .. L.chat_upd_ok .. data.version, -1)
            return
        end

        local ok3, res2 = pcall(requests.get, data.url)
        if not ok3 or not res2 or res2.status_code ~= 200 then
            sampAddChatMessage("{e74c3c}" .. L.chat_upd_err, -1)
            return
        end

        local path = thisScript().path
        local f = io.open(path, "wb")
        if f then
            f:write(res2.text)
            f:close()
            sampAddChatMessage("{2ecc71}" .. L.chat_upd_new .. data.version .. L.chat_upd_rel, -1)
            wait(500)
            thisScript():reload()
        else
            sampAddChatMessage("{e74c3c}" .. L.chat_upd_err, -1)
        end
    end)
end

-- ================= DIALOG HANDLER =================
function sampev.onShowDialog(id, style, title, button1, button2, text)
    pcall(function()
        local clean = stripColors(text)
        if not clean:find("Общая стоимость") then return end

        -- Игрок: "Выбранный игрок: Name(ID)."
        local buyer = clean:match("[Вв]ыбранный%s+игрок:%s*([%w_%-]+)%s*%(%d+%)")
                   or clean:match("([%w_%-]+)%(%d+%)")

        -- Ранг: два варианта поля
        local rank = clean:match("[Вв]ыбранный%s+ранг:%s*(.-)%s*%(%d+%)")
                  or clean:match("[Рр]анг%s+игрока:%s*(.-)%s*%(%d+%)")
        if rank then rank = rank:gsub("[%.%s]+$",""):match("^%s*(.-)%s*$") end

        -- Дни: "Выбранное кол-во дней: 1 дн."
        local days = clean:match("[Вв]ыбранное%s+кол%-во%s+дней:%s*(%d+)")

        -- Суммы: "Общая стоимость: * 100.100." / "Ваш процент: * 50.050 (50%)."
        local total_str  = clean:match("[Оо]бщая%s+стоимость:%s*(.-)%s*[\n%.]")
                        or clean:match("[Оо]бщая%s+стоимость:%s*([^\n]+)")
        local profit_str = clean:match("[Вв]аш%s+процент:%s*(.-)%s*%(")
                        or clean:match("[Вв]аш%s+процент:%s*([^\n%(]+)")

        if buyer then buyer = buyer:gsub("[%.%s]+$","") end

        local price  = total_str  and parseAmount(total_str)  or 0
        local profit = profit_str and parseAmount(profit_str) or math.floor(price * PROFIT_PERCENT)

        print('[RankTracker] Dialog: buyer=' .. tostring(buyer)
            .. ' rank=' .. tostring(rank) .. ' days=' .. tostring(days)
            .. ' price=' .. tostring(price) .. ' profit=' .. tostring(profit))

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
                price_str = price_str:gsub("[%.$]",""):gsub("%s+","")
                price_str = price_str:gsub("\xD0\x9A\xD0\x9A","KK"):gsub("\xCA\xCA","KK")
                                     :gsub(":KK:","KK"):gsub(":K:","K")

                local amount = parseAmount(price_str)
                if amount == 0 then
                    local n = price_str:match("(%d+)")
                    if n then amount = tonumber(n) * 1000000 end
                end

                local fresh      = (os.time() - Cache.time) < 120
                local matched    = fresh and Cache.buyer ~= "" and clean:find(Cache.buyer, 1, true)
                local final_rank = matched and Cache.rank or "?"
                local final_days = matched and Cache.days or "?"
                if amount == 0 then amount = Cache.price end

                local profit   = (Cache.profit and Cache.profit > 0)
                                  and Cache.profit or math.floor(amount * PROFIT_PERCENT)
                local op_title = clean:find("продление") and L.op_ext or L.op_buy

                sendLog(chat_buyer, final_rank, final_days, amount, profit, op_title)
                Cache = { buyer="", rank="?", days="?", price=0, profit=0, time=0 }
            end
        end
    end)
end

-- ================= GUI =================
imgui.OnFrame(function() return show_menu[0] end, function()
    local sw = imgui.GetIO().DisplaySize.x
    local sh = imgui.GetIO().DisplaySize.y
    local s  = S()

    imgui.SetNextWindowSize(imgui.ImVec2(s.win_w, s.win_h), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(
        imgui.ImVec2(sw/2 - s.win_w/2, sh/2 - s.win_h/2),
        imgui.Cond.FirstUseEver
    )

    imgui.PushStyleColor(imgui.Col.WindowBg,      imgui.ImVec4(0.09, 0.09, 0.12, 0.98))
    imgui.PushStyleColor(imgui.Col.TitleBgActive, imgui.ImVec4(0.13, 0.40, 0.65, 1.00))
    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.15, 0.42, 0.68, 0.90))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20, 0.55, 0.85, 1.00))
    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.10, 0.30, 0.50, 1.00))
    imgui.PushStyleColor(imgui.Col.FrameBg,       imgui.ImVec4(0.15, 0.15, 0.20, 1.00))
    imgui.PushStyleColor(imgui.Col.Tab,           imgui.ImVec4(0.12, 0.12, 0.16, 1.00))
    imgui.PushStyleColor(imgui.Col.TabHovered,    imgui.ImVec4(0.20, 0.50, 0.80, 1.00))
    imgui.PushStyleColor(imgui.Col.TabActive,     imgui.ImVec4(0.15, 0.42, 0.68, 1.00))
    imgui.PushStyleColor(imgui.Col.Separator,     imgui.ImVec4(0.25, 0.25, 0.30, 1.00))
    imgui.PushStyleColor(imgui.Col.ChildBg,       imgui.ImVec4(0.12, 0.12, 0.16, 1.00))

    local opened = imgui.Begin(u8("RankTracker v3.2###RTMain"), show_menu)

    if opened then
        imgui.Spacing()
        imgui.TextColored(imgui.ImVec4(0.25, 0.75, 1.00, 1), "RankTracker")
        imgui.SameLine()
        imgui.TextColored(imgui.ImVec4(0.40, 0.40, 0.45, 1), "v3.2")
        imgui.SameLine(s.win_w - 130)
        imgui.TextColored(imgui.ImVec4(0.35, 0.85, 0.45, 1), os.date("%H:%M:%S"))
        imgui.SameLine()
        local has_cache = Cache.buyer ~= "" and Cache.time > 0
        if has_cache then
            imgui.TextColored(imgui.ImVec4(0.20, 0.90, 0.30, 1), u8(" []"))
        else
            imgui.TextColored(imgui.ImVec4(0.35, 0.35, 0.40, 1), u8(" []"))
        end
        imgui.Separator()
        imgui.Spacing()

        if imgui.BeginTabBar("##tabs") then

            -- ===== ГЛАВНАЯ =====
            if imgui.BeginTabItem(L.tab_main) then
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.50, 0.50, 0.55, 1), L.manager_lbl)
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(1.00, 0.82, 0.20, 1), toUI(getManagerName()))
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.55, 0.55, 0.60, 1), L.last_entry)
                imgui.Spacing()

                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.11, 0.13, 0.17, 1))
                imgui.BeginChild("##card", imgui.ImVec2(0, s.card_h), true)
                imgui.Spacing()

                local buyer_v  = Cache.buyer ~= "" and toUI(Cache.buyer) or L.no_data
                local rank_v   = Cache.rank  ~= "?" and toUI(Cache.rank)  or L.no_data
                local days_v   = Cache.days  ~= "?" and (Cache.days .. " " .. L.days_sfx) or L.no_data
                local price_v  = Cache.price  > 0 and (fmt(Cache.price/1000000)  .. " KK") or L.no_data
                local profit_v = Cache.profit > 0 and (fmt(Cache.profit/1000000) .. " KK") or L.no_data

                imgui.TextColored(imgui.ImVec4(0.45, 0.75, 1.00, 1), buyer_v)
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.30, 0.30, 0.35, 1), "  |  ")
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(1.00, 0.82, 0.35, 1), rank_v)

                imgui.TextColored(imgui.ImVec4(0.60, 0.88, 0.60, 1), days_v)
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.30, 0.30, 0.35, 1), "  |  ")
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.35, 1.00, 0.55, 1), price_v)
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(0.30, 0.30, 0.35, 1), " > ")
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(1.00, 0.72, 0.20, 1), profit_v)

                imgui.EndChild()
                imgui.PopStyleColor()
                imgui.Spacing()

                if has_cache then
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10, 0.52, 0.28, 0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14, 0.68, 0.36, 1.00))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.08, 0.38, 0.20, 1.00))
                    if imgui.Button(L.btn_send, imgui.ImVec2(-1, s.btn_h)) then
                        sendLog(Cache.buyer, Cache.rank, Cache.days,
                                Cache.price, Cache.profit, L.manual_title)
                    end
                    imgui.PopStyleColor(3)
                    imgui.Spacing()
                end

                local bw = math.floor((s.win_w - 48) / 2)
                if imgui.Button(L.btn_test, imgui.ImVec2(bw, s.btn_h)) then
                    sendLog("Test_Player", "Media-Manager", "30", 60000000, 30000000, "TEST")
                end
                imgui.SameLine()
                if imgui.Button(L.btn_update, imgui.ImVec2(bw, s.btn_h)) then
                    updateScript()
                end

                imgui.Spacing()
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.55, 0.12, 0.12, 0.90))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.75, 0.18, 0.18, 1.00))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.40, 0.08, 0.08, 1.00))
                if imgui.Button(L.btn_close, imgui.ImVec2(-1, s.btn_h)) then
                    show_menu[0] = false
                end
                imgui.PopStyleColor(3)

                imgui.EndTabItem()
            end

            -- ===== ЛОГ =====
            if imgui.BeginTabItem(L.tab_log) then
                imgui.Spacing()

                imgui.BeginChild("##logbox", imgui.ImVec2(0, s.log_h), true)
                if #log_lines == 0 then
                    imgui.TextColored(imgui.ImVec4(0.40, 0.40, 0.45, 1), L.log_empty)
                else
                    local st = math.max(1, #log_lines - 40)
                    for i = st, #log_lines do
                        local line = log_lines[i]
                        local col  = imgui.ImVec4(0.70, 0.88, 0.70, 1)
                        if line:find("TEST") then
                            col = imgui.ImVec4(0.50, 0.50, 0.55, 1)
                        elseif line:find("\xD0\x9F\xD0\xA0\xD0\x9E\xD0\x94") then
                            col = imgui.ImVec4(0.40, 0.90, 0.55, 1)
                        end
                        imgui.TextColored(col, line)
                    end
                    imgui.SetScrollHereY(1.0)
                end
                imgui.EndChild()

                imgui.Spacing()
                if imgui.Button(L.btn_reload, imgui.ImVec2(-1, s.btn_h)) then
                    loadLogsFromFile()
                end

                imgui.EndTabItem()
            end

            -- ===== НАСТРОЙКИ =====
            if imgui.BeginTabItem(L.tab_settings) then
                imgui.Spacing()
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.55, 0.55, 0.60, 1), L.name_lbl)
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.45, 0.45, 0.50, 1), L.curr_lbl)
                imgui.SameLine()
                imgui.TextColored(imgui.ImVec4(1.00, 0.82, 0.20, 1), toUI(getManagerName()))
                imgui.Spacing()
                imgui.TextColored(imgui.ImVec4(0.45, 0.45, 0.50, 1), L.hint_input)
                imgui.SetNextItemWidth(s.win_w - 120)
                imgui.InputText("##nameinput", new_name_buf, 64)
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10, 0.52, 0.28, 0.90))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14, 0.68, 0.36, 1.00))
                if imgui.Button(L.btn_save .. "##sv", imgui.ImVec2(-1, 0)) then
                    local ns = ffi.string(new_name_buf):match("^%s*(.-)%s*$")
                    if ns ~= "" then
                        settings.manager_name = ns
                        save_settings()
                        sampAddChatMessage("{2ecc71}" .. L.chat_name_set .. ns, -1)
                        ffi.fill(new_name_buf, 64, 0)
                    end
                end
                imgui.PopStyleColor(2)

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                local function row(lbl, val)
                    imgui.TextColored(imgui.ImVec4(0.40, 0.40, 0.45, 1), lbl)
                    imgui.SameLine(160)
                    imgui.TextColored(imgui.ImVec4(0.70, 0.70, 0.75, 1), val)
                end

                row(L.plat_lbl, IS_MOBILE and L.plat_mob or L.plat_pc)
                row(L.ver_lbl,  "3.2")
                row(L.pct_lbl,  tostring((settings.profit_pct or PROFIT_PERCENT) * 100) .. "%")
                row(L.dpi_lbl,  tostring(settings.custom_dpi or DPI))

                imgui.Spacing()
                if imgui.Button(L.btn_reset_dpi, imgui.ImVec2(-1, s.btn_h)) then
                    settings.autofind_dpi = false
                    save_settings()
                    apply_dpi()
                    DPI = settings.custom_dpi
                    sampAddChatMessage("{f1c40f}[RankTracker] " .. u8("DPI сброшен и пересчитан: ") .. tostring(DPI), -1)
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                imgui.TextColored(imgui.ImVec4(0.50, 0.50, 0.55, 1), L.cmd_lbl)
                imgui.Spacing()
                local cmds = {
                    {"/fmenu",   u8("Открыть/закрыть меню")},
                    {"/rtest",   u8("Тестовая отправка")},
                    {"/rname X", u8("Установить имя")},
                    {"/rupdate", u8("Обновить скрипт | в будущем")},
                }
                for _, c in ipairs(cmds) do
                    imgui.TextColored(imgui.ImVec4(0.35, 0.75, 1.00, 1), c[1])
                    imgui.SameLine(120)
                    imgui.TextColored(imgui.ImVec4(0.65, 0.65, 0.70, 1), c[2])
                end

                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
    end
    imgui.End()
    imgui.PopStyleColor(11)
end)

-- ================= MAIN =================
function main()
    while not isSampAvailable() do wait(100) end
    wait(500)

    -- Конфиг и DPI уже загружены при старте скрипта (до main)
    -- Здесь только синхронизируем DPI на случай если wait изменил что-то
    DPI = settings.custom_dpi or 1.0

    loadLogsFromFile()

    sampAddChatMessage("{43b581}" .. toChat(L.chat_start) .. getManagerName(), -1)

    sampRegisterChatCommand("rtest", function()
        sendLog("Test_Player", "Media-Manager", "30", 60000000, 30000000, "TEST")
    end)

    sampRegisterChatCommand("rname", function(args)
        if args and args ~= "" then
            settings.manager_name = args
            save_settings()
            sampAddChatMessage("{2ecc71}" .. toChat(L.chat_name_set) .. args, -1)
        else
            sampAddChatMessage("{f1c40f}" .. toChat(L.chat_name_cur) .. getManagerName(), -1)
        end
    end)

    sampRegisterChatCommand("fmenu", function()
        show_menu[0] = not show_menu[0]
    end)

    sampRegisterChatCommand("rupdate", function()
        updateScript()
    end)

    while true do wait(0) end
end