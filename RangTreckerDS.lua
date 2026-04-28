script_name("RankTracker 3.3")
script_author("ROMAN KOVALENKO")
script_version("3.3")

require('lib.moonloader')
local IS_MOBILE = MONET_VERSION ~= nil
local sampev    = require 'lib.samp.events'
local requests  = require 'requests'
local imgui     = require 'mimgui'
local ffi       = require 'ffi'
local encoding  = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ================= SETTINGS =================
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1495625228959875264/pDdTB8lLaS4KmWyqTtMNeKOwSjjpvXFlTmXOMX5kHdGpzoIBtKO7g2sMrhckoHB1T8CR"
local PROFIT_PERCENT  = 0.5
local MANAGER_NAME    = "Nick_Name"

local GITHUB_VERSION_URL = "https://raw.githubusercontent.com/USER/REPO/main/Update.json"
local GITHUB_SCRIPT_URL  = "https://raw.githubusercontent.com/USER/REPO/main/RankTracker.lua"

-- ================= ПУТИ =================
local worked_dir = getWorkingDirectory():gsub('\\', '/')
local config_dir = worked_dir .. "/RankTracker/"
local config_file = config_dir .. "Settings.json"
local log_file    = config_dir .. "logs/rank_tracker.log"

if not doesDirectoryExist(config_dir) then createDirectory(config_dir) end
if not doesDirectoryExist(config_dir .. "logs") then createDirectory(config_dir .. "logs") end

-- ================= JSON КОНФИГ =================
local default_settings = {
    manager_name  = MANAGER_NAME,
    profit_pct    = 0.5,
    autofind_dpi  = true,
    custom_dpi    = 2.0,
    win_w         = 1500,
    win_h         = 900,
}

local settings = {}

local function merge_defaults(t, d)
    for k, v in pairs(d) do
        if t[k] == nil then t[k] = v end
    end
end

local function load_settings()
    if doesFileExist(config_file) then
        local f = io.open(config_file, 'r')
        if f then
            local ok, dec = pcall(decodeJson, f:read('*a'))
            f:close()
            settings = (ok and type(dec) == 'table') and dec or {}
        end
    else
        settings = {}
    end
    merge_defaults(settings, default_settings)
end

local function save_settings()
    local f = io.open(config_file, 'w')
    if f then
        local ok, enc = pcall(encodeJson, settings)
        f:write(ok and enc or '{}')
        f:close()
    end
end

-- ================= DPI =================
local sizeX, sizeY = getScreenResolution()

load_settings()

local function apply_dpi()
    if not settings.autofind_dpi then
        if IS_MOBILE then
            settings.custom_dpi = MONET_DPI_SCALE
        else
            settings.custom_dpi = ((sizeX/1366) + (sizeY/768)) / 2
        end
        settings.autofind_dpi = true
        settings.custom_dpi   = tonumber(string.format('%.3f', settings.custom_dpi))
        save_settings()
    end
end

apply_dpi()

local DPI = settings.custom_dpi or 1.0

-- Ползунки размера окна — читаем из конфига, imgui.new для ползунков
local slider_w = imgui.new.int(settings.win_w or 1500)
local slider_h = imgui.new.int(settings.win_h or 900)

-- S пересчитывается при изменении ползунков
local S = {}
local function recalcS()
    local w = slider_w[0]
    local h = slider_h[0]
    S.win_w  = w
    S.win_h  = h
    S.btn_h  = math.floor(34  * DPI)
    S.card_h = math.floor(80  * DPI)
    S.log_h  = h - math.floor(260 * DPI)  -- лог занимает оставшееся место
    if S.log_h < 80 then S.log_h = 80 end
    S.pad    = math.floor(10  * DPI)
end
recalcS()

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
        r[i] = (b >= 0x80) and (cp1251_map[b] or "?") or string.char(b)
    end
    return table.concat(r)
end

function toUI(str)
    if not str or str == "" then return "\xE2\x80\x94" end
    if str:find("\xD0[\x90-\xBF]") or str:find("\xD1[\x80-\x8F]") then return str end
    if str:find("[\x80-\xFF]") then return cp1251_utf8(str) end
    return str
end

-- ================= CACHE =================
local Cache = { buyer="", rank="?", days="?", price=0, profit=0, time=0 }

-- ================= LOG =================
local log_lines     = {}
local MAX_LOG_LINES = 50
local log_needs_scroll = false

function addLogLine(text)
    local f = io.open(log_file, "a")
    if f then f:write(os.date("[%d.%m.%Y %H:%M:%S] ") .. text .. "\n"); f:close() end
    table.insert(log_lines, os.date("[%H:%M] ") .. toUI(text))
    if #log_lines > MAX_LOG_LINES then table.remove(log_lines, 1) end
    log_needs_scroll = true
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
    log_needs_scroll = true
end

-- ================= GUI STATE =================
local show_menu    = imgui.new.bool(false)
local new_name_buf = ffi.new("char[64]")
ffi.fill(new_name_buf, 64, 0)

-- FIX 3: кэш для данных которые не меняются каждый кадр
local gui_time    = ""   -- обновляем раз в секунду
local last_time_t = 0

-- ================= UI СТРОКИ =================
local L = {
    tab_main     = u8("  Главная  "),
    tab_log      = u8("  Лог  "),
    tab_settings = u8("  Настройки  "),
    manager_lbl  = u8("Менеджер:"),
    last_entry   = u8("Последняя запись:"),
    curr_lbl     = u8("Текущее:"),
    name_lbl     = u8("Имя менеджера:"),
    hint_input   = u8("Новое имя:"),
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
    btn_send     = u8("Отправить в Discord"),
    btn_test     = u8("Тест"),
    btn_update   = u8("Обновить скрипт"),
    btn_close    = u8("Закрыть"),
    btn_save     = u8("Сохранить"),
    btn_reload   = u8("Обновить лог"),
    btn_reset_dpi= u8("Сбросить DPI"),
    op_buy       = u8("ПОКУПКА РАНГА"),
    op_ext       = u8("ПРОДЛЕНИЕ РАНГА"),
    manual_title = u8("РУЧНАЯ ОТПРАВКА"),
    no_cache     = u8("Нет данных — откройте диалог продажи ранга"),
}

-- ================= UTILS =================
function fmt(n)
    return string.format("%.0f", n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function fmtMoney(n)
    if n >= 1000000 then
        local kk = n / 1000000
        local kk_int  = math.floor(kk)
        local kk_rest = math.floor((kk - kk_int) * 1000)
        if kk_rest > 0 then
            return fmt(kk_int) .. " KK " .. fmt(kk_rest) .. " K"
        end
        return fmt(kk_int) .. " KK"
    elseif n >= 1000 then
        return fmt(n / 1000) .. " K"
    end
    return fmt(n)
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
    str = tostring(str):gsub("[\x80-\xFF]", "")
    str = str:gsub(":KK:","KK"):gsub(":K:","K"):gsub(":M:","M")
    str = str:match("^%s*(.-)%s*$") or str
    local kk_int, kk_frac = str:match("KK%s*(%d+)%s+(%d+)[%.,]%d*")
    if kk_int and kk_frac then
        return (tonumber(kk_int) or 0) * 1000000 + (tonumber(kk_frac) or 0) * 1000
    end
    local kk = str:match("KK%s*(%d+)")
    if kk then return (tonumber(kk) or 0) * 1000000 end
    local k = str:match("K%s*(%d+)")
    if k then return (tonumber(k) or 0) * 1000 end
    local m = str:match("M%s*(%d+)")
    if m then return (tonumber(m) or 0) * 1000000000 end
    str = str:gsub("[%.,%s]", "")
    return tonumber(str:match("%d+")) or 0
end

function getManagerName()
    return settings.manager_name or MANAGER_NAME
end

-- ================= DISCORD =================
function sendDiscord(buyer, rank, days, price, profit, title)
    local datetime   = os.date("%d.%m.%Y %H:%M")
    local price_fmt  = fmtMoney(price)
    local profit_fmt = fmtMoney(profit)
    local manager    = getManagerName()

    local buyer_u = escape_json(toUI(tostring(buyer)))
    local rank_u  = escape_json(toUI(tostring(rank)))
    local title_u = escape_json(tostring(title))

    local f_buyer  = "\xD0\x9F\xD0\xBE\xD0\xBA\xD1\x83\xD0\xBF\xD0\xB0\xD1\x82\xD0\xB5\xD0\xBB\xD1\x8C"
    local f_rank   = "\xD0\xA0\xD0\xB0\xD0\xBD\xD0\xB3"
    local f_sum    = "\xD0\xA1\xD1\x83\xD0\xBC\xD0\xBC\xD0\xB0"
    local f_profit = "\xD0\x94\xD0\xBE\xD1\x85\xD0\xBE\xD0\xB4 (50%)"
    local f_mgr    = "\xD0\x9C\xD0\xB5\xD0\xBD\xD0\xB5\xD0\xB4\xD0\xB6\xD0\xB5\xD1\x80"
    local dn       = "\xD0\xB4\xD0\xBD"

    local color = 3447003
    if tostring(title):find("ПРОДЛЕНИЕ") or tostring(title):find("\xD0\x9F\xD0\xA0\xD0\x9E\xD0\x94") then
        color = 3066993
    end
    if tostring(title):find("TEST") then color = 9807270 end

    local body = '{"embeds":[{"title":"' .. title_u .. '",' ..
        '"color":' .. color .. ',' ..
        '"fields":[' ..
            '{"name":"' .. f_buyer  .. '","value":"' .. buyer_u .. '","inline":true},' ..
            '{"name":"' .. f_rank   .. '","value":"' .. rank_u  .. ' (' .. escape_json(tostring(days)) .. ' ' .. dn .. '.)","inline":true},' ..
            '{"name":"' .. f_sum    .. '","value":"' .. escape_json(price_fmt)  .. '","inline":true},' ..
            '{"name":"' .. f_profit .. '","value":"' .. escape_json(profit_fmt) .. '","inline":true},' ..
            '{"name":"' .. f_mgr    .. '","value":"' .. escape_json(cp1251_utf8(manager)) .. '","inline":false}' ..
        '],' ..
        '"footer":{"text":"' .. escape_json(cp1251_utf8(manager)) .. ' | ' .. escape_json(datetime) .. '"}' ..
    '}]}'

    local ok, res = pcall(function()
        return requests.request("POST", DISCORD_WEBHOOK, {
            data = body, headers = { ["Content-Type"] = "application/json; charset=utf-8" }
        })
    end)
    local status = ok and res and tostring(res.status_code) or "ERR"
    local col    = (status == "204" or status == "200") and "{2ecc71}" or "{e74c3c}"
    sampAddChatMessage(col .. "[RankTracker] Discord: " .. status, -1)
end

function sendLog(buyer, rank, days, price, profit, title)
    lua_thread.create(function() sendDiscord(buyer, rank, days, price, profit, title) end)
    addLogLine(string.format("[%s] %s | %s | %s дн. | %s",
        tostring(title), tostring(buyer), tostring(rank),
        tostring(days), fmtMoney(price)))
    sampAddChatMessage("{43b581}[RankTracker] Sending to Discord...", -1)
end

-- ================= АВТООБНОВЛЕНИЕ =================
function updateScript()
    lua_thread.create(function()
        sampAddChatMessage("{f1c40f}[RankTracker] Checking updates...", -1)
        local ok, res = pcall(requests.get, GITHUB_VERSION_URL)
        if not ok or not res or res.status_code ~= 200 then
            sampAddChatMessage("{e74c3c}[RankTracker] No connection!", -1)
            return
        end
        local ok2, data = pcall(decodeJson, res.text)
        if not ok2 or not data or not data.version then
            sampAddChatMessage("{e74c3c}[RankTracker] Bad response!", -1)
            return
        end
        if data.version == thisScript().version then
            sampAddChatMessage("{2ecc71}[RankTracker] Already latest: " .. data.version, -1)
            return
        end
        local ok3, res2 = pcall(requests.get, data.url)
        if not ok3 or not res2 or res2.status_code ~= 200 then
            sampAddChatMessage("{e74c3c}[RankTracker] Download error!", -1)
            return
        end
        local f = io.open(thisScript().path, "wb")
        if f then
            f:write(res2.text); f:close()
            sampAddChatMessage("{2ecc71}[RankTracker] Updated to v" .. data.version .. "! Reloading...", -1)
            wait(500)
            thisScript():reload()
        end
    end)
end

-- ================= DIALOG HANDLER =================
function sampev.onShowDialog(id, style, title, button1, button2, text)
    pcall(function()
        local clean = stripColors(text)
        if not clean:find("Общая стоимость") then return end

        local buyer = clean:match("[Вв]ыбранный%s+игрок:%s*([%w_%-]+)%s*%(%d+%)")
                   or clean:match("([%w_%-]+)%(%d+%)")

        local rank = clean:match("[Вв]ыбранный%s+ранг:%s*(.-)%s*%(%d+%)")
                  or clean:match("[Рр]анг%s+игрока:%s*(.-)%s*%(%d+%)")
        if rank then rank = rank:gsub("[%.%s]+$",""):match("^%s*(.-)%s*$") end

        local days      = clean:match("[Вв]ыбранное%s+кол%-во%s+дней:%s*(%d+)")
        local total_str = clean:match("[Оо]бщая%s+стоимость:%s*(.-)%s*[\n%.]")
                       or clean:match("[Оо]бщая%s+стоимость:%s*([^\n]+)")
        local profit_str= clean:match("[Вв]аш%s+процент:%s*(.-)%s*%(")
                       or clean:match("[Вв]аш%s+процент:%s*([^\n%(]+)")

        if buyer then buyer = buyer:gsub("[%.%s]+$","") end

        local price  = total_str  and parseAmount(total_str)  or 0
        local profit = profit_str and parseAmount(profit_str) or math.floor(price * PROFIT_PERCENT)

        if buyer and buyer ~= "" then
            Cache = { buyer=buyer, rank=rank or "?", days=days or "?",
                      price=price, profit=profit, time=os.time() }
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

                local profit   = (Cache.profit > 0) and Cache.profit or math.floor(amount * PROFIT_PERCENT)
                local op_title = clean:find("продление") and L.op_ext or L.op_buy

                sendLog(chat_buyer, final_rank, final_days, amount, profit, op_title)
                Cache = { buyer="", rank="?", days="?", price=0, profit=0, time=0 }
            end
        end
    end)
end

-- ================= GUI =================
-- Цвета вынесены в константы — не пересоздаются каждый кадр
local C = {
    win_bg      = imgui.ImVec4(0.04, 0.04, 0.06, 0.98),
    title_bg    = imgui.ImVec4(0.08, 0.28, 0.48, 1.00),
    btn         = imgui.ImVec4(0.13, 0.40, 0.65, 0.90),
    btn_hov     = imgui.ImVec4(0.18, 0.52, 0.82, 1.00),
    btn_act     = imgui.ImVec4(0.09, 0.28, 0.47, 1.00),
    btn_grn     = imgui.ImVec4(0.09, 0.50, 0.26, 0.90),
    btn_grn_hov = imgui.ImVec4(0.12, 0.65, 0.33, 1.00),
    btn_red     = imgui.ImVec4(0.52, 0.10, 0.10, 0.90),
    btn_red_hov = imgui.ImVec4(0.70, 0.15, 0.15, 1.00),
    frame_bg    = imgui.ImVec4(0.08, 0.08, 0.12, 1.00),
    child_bg    = imgui.ImVec4(0.06, 0.06, 0.09, 1.00),
    card_bg     = imgui.ImVec4(0.07, 0.08, 0.12, 1.00),
    sep         = imgui.ImVec4(0.16, 0.16, 0.22, 1.00),
    tab         = imgui.ImVec4(0.06, 0.06, 0.09, 1.00),
    tab_hov     = imgui.ImVec4(0.18, 0.48, 0.76, 1.00),
    tab_act     = imgui.ImVec4(0.13, 0.40, 0.65, 1.00),
    -- Текст
    t_title     = imgui.ImVec4(0.28, 0.72, 1.00, 1.00),
    t_sub       = imgui.ImVec4(0.38, 0.38, 0.44, 1.00),
    t_label     = imgui.ImVec4(0.48, 0.48, 0.54, 1.00),
    t_value     = imgui.ImVec4(1.00, 0.82, 0.20, 1.00),
    t_buyer     = imgui.ImVec4(0.42, 0.74, 1.00, 1.00),
    t_rank      = imgui.ImVec4(1.00, 0.80, 0.32, 1.00),
    t_days      = imgui.ImVec4(0.55, 0.88, 0.55, 1.00),
    t_price     = imgui.ImVec4(0.32, 1.00, 0.52, 1.00),
    t_profit    = imgui.ImVec4(1.00, 0.70, 0.18, 1.00),
    t_sep       = imgui.ImVec4(0.28, 0.28, 0.34, 1.00),
    t_time      = imgui.ImVec4(0.32, 0.82, 0.42, 1.00),
    t_green     = imgui.ImVec4(0.20, 0.88, 0.28, 1.00),
    t_gray      = imgui.ImVec4(0.32, 0.32, 0.38, 1.00),
    t_log       = imgui.ImVec4(0.68, 0.88, 0.68, 1.00),
    t_log_ext   = imgui.ImVec4(0.38, 0.88, 0.54, 1.00),
    t_log_test  = imgui.ImVec4(0.48, 0.48, 0.54, 1.00),
    t_cmd       = imgui.ImVec4(0.32, 0.72, 1.00, 1.00),
    t_cmd_desc  = imgui.ImVec4(0.58, 0.58, 0.64, 1.00),
    t_white     = imgui.ImVec4(0.82, 0.82, 0.88, 1.00),
}

imgui.OnFrame(function() return show_menu[0] end, function()
    -- FIX 3: обновляем время раз в секунду
    local now = os.time()
    if now ~= last_time_t then
        gui_time    = os.date("%H:%M:%S")
        last_time_t = now
    end

    local sw = imgui.GetIO().DisplaySize.x
    local sh = imgui.GetIO().DisplaySize.y

    imgui.SetNextWindowSize(imgui.ImVec2(S.win_w, S.win_h), imgui.Cond.Always)    imgui.SetNextWindowPos(
        imgui.ImVec2(sw/2 - S.win_w/2, sh/2 - S.win_h/2),
        imgui.Cond.FirstUseEver
    )

    imgui.PushStyleColor(imgui.Col.WindowBg,      C.win_bg)
    imgui.PushStyleColor(imgui.Col.TitleBgActive, C.title_bg)
    imgui.PushStyleColor(imgui.Col.Button,        C.btn)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, C.btn_hov)
    imgui.PushStyleColor(imgui.Col.ButtonActive,  C.btn_act)
    imgui.PushStyleColor(imgui.Col.FrameBg,       C.frame_bg)
    imgui.PushStyleColor(imgui.Col.ChildBg,       C.child_bg)
    imgui.PushStyleColor(imgui.Col.Tab,           C.tab)
    imgui.PushStyleColor(imgui.Col.TabHovered,    C.tab_hov)
    imgui.PushStyleColor(imgui.Col.TabActive,     C.tab_act)
    imgui.PushStyleColor(imgui.Col.Separator,     C.sep)

    local has_cache = Cache.buyer ~= "" and Cache.time > 0

    local opened = imgui.Begin(u8("RankTracker v3.2###RTMain"), show_menu)
    if opened then
        imgui.Spacing()

        -- Шапка: название + версия + время + индикатор кэша
        imgui.TextColored(C.t_title, "RankTracker")
        imgui.SameLine()
        imgui.TextColored(C.t_sub, "v3.2")
        imgui.SameLine(S.win_w - 160)
        imgui.TextColored(C.t_time, gui_time)
        imgui.SameLine()
        if has_cache then
            imgui.TextColored(C.t_green, u8("  ДАННЫЕ ГОТОВЫ"))
        else
            imgui.TextColored(C.t_gray,  u8("  НЕТ ДАННЫХ"))
        end

        imgui.Separator()
        imgui.Spacing()

        if imgui.BeginTabBar("##tabs") then

            -- =================== ГЛАВНАЯ ===================
            if imgui.BeginTabItem(L.tab_main) then
                imgui.Spacing()

                -- Менеджер
                imgui.TextColored(C.t_label, L.manager_lbl)
                imgui.SameLine()
                imgui.TextColored(C.t_value, toUI(getManagerName()))
                imgui.Spacing()

                -- Метка карточки
                imgui.TextColored(C.t_label, L.last_entry)
                imgui.Spacing()

                -- Карточка данных
                imgui.PushStyleColor(imgui.Col.ChildBg, C.card_bg)
                imgui.BeginChild("##card", imgui.ImVec2(S.win_w - S.pad*2, S.card_h), true)
                imgui.Spacing()

                if has_cache then
                    local buyer_v  = toUI(Cache.buyer)
                    local rank_v   = Cache.rank ~= "?" and toUI(Cache.rank) or L.no_data
                    local days_v   = Cache.days ~= "?" and (Cache.days .. " " .. L.days_sfx) or L.no_data
                    local price_v  = Cache.price  > 0 and fmtMoney(Cache.price)  or L.no_data
                    local profit_v = Cache.profit > 0 and fmtMoney(Cache.profit) or L.no_data

                    -- Строка 1: ник | ранг
                    imgui.TextColored(C.t_buyer,  buyer_v)
                    imgui.SameLine()
                    imgui.TextColored(C.t_sep,    "  |  ")
                    imgui.SameLine()
                    imgui.TextColored(C.t_rank,   rank_v)

                    -- Строка 2: дни | сумма > доход
                    imgui.TextColored(C.t_days,   days_v)
                    imgui.SameLine()
                    imgui.TextColored(C.t_sep,    "  |  ")
                    imgui.SameLine()
                    imgui.TextColored(C.t_price,  price_v)
                    imgui.SameLine()
                    imgui.TextColored(C.t_sep,    "  >  ")
                    imgui.SameLine()
                    imgui.TextColored(C.t_profit, profit_v)
                else
                    imgui.Spacing()
                    imgui.TextColored(C.t_gray, L.no_cache)
                end

                imgui.EndChild()
                imgui.PopStyleColor()
                imgui.Spacing()

                -- Кнопка отправки (только если есть кэш)
                if has_cache then
                    imgui.PushStyleColor(imgui.Col.Button,        C.btn_grn)
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, C.btn_grn_hov)
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  C.btn_act)
                    if imgui.Button(L.btn_send, imgui.ImVec2(S.win_w - S.pad*2, S.btn_h)) then
                        sendLog(Cache.buyer, Cache.rank, Cache.days,
                                Cache.price, Cache.profit, L.manual_title)
                    end
                    imgui.PopStyleColor(3)
                    imgui.Spacing()
                end

                -- Кнопки тест / обновить
                local bw = math.floor((S.win_w - S.pad*2 - 8) / 2)
                if imgui.Button(L.btn_test, imgui.ImVec2(bw, S.btn_h)) then
                    sendLog("Test_Player", "Media-Manager", "30", 60000000, 30000000, "TEST")
                end
                imgui.SameLine()
                if imgui.Button(L.btn_update, imgui.ImVec2(bw, S.btn_h)) then
                    updateScript()
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                -- Кнопка закрыть
                imgui.PushStyleColor(imgui.Col.Button,        C.btn_red)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, C.btn_red_hov)
                imgui.PushStyleColor(imgui.Col.ButtonActive,  C.btn_act)
                if imgui.Button(L.btn_close, imgui.ImVec2(S.win_w - S.pad*2, S.btn_h)) then
                    show_menu[0] = false
                end
                imgui.PopStyleColor(3)

                imgui.EndTabItem()
            end

            -- =================== ЛОГ ===================
            if imgui.BeginTabItem(L.tab_log) then
                imgui.Spacing()

                imgui.PushStyleColor(imgui.Col.ChildBg, C.card_bg)
                imgui.BeginChild("##logbox", imgui.ImVec2(S.win_w - S.pad*2, S.log_h), true)
                if #log_lines == 0 then
                    imgui.Spacing()
                    imgui.TextColored(C.t_gray, L.log_empty)
                else
                    local st = math.max(1, #log_lines - 40)
                    for i = st, #log_lines do
                        local line = log_lines[i]
                        local col = C.t_log
                        if line:find("TEST") then
                            col = C.t_log_test
                        elseif line:find("\xD0\x9F\xD0\xA0\xD0\x9E\xD0\x94") or line:find("ПРОДЛ") then
                            col = C.t_log_ext
                        end
                        imgui.TextColored(col, line)
                    end
                    if log_needs_scroll then
                        imgui.SetScrollHereY(1.0)
                        log_needs_scroll = false
                    end
                end
                imgui.EndChild()
                imgui.PopStyleColor()

                imgui.Spacing()
                if imgui.Button(L.btn_reload, imgui.ImVec2(S.win_w - S.pad*2, S.btn_h)) then
                    loadLogsFromFile()
                end

                imgui.EndTabItem()
            end

            -- =================== НАСТРОЙКИ ===================
            if imgui.BeginTabItem(L.tab_settings) then
                imgui.Spacing()
                imgui.Spacing()

                -- Блок: имя менеджера
                imgui.TextColored(C.t_label, L.name_lbl)
                imgui.Spacing()
                imgui.TextColored(C.t_label, L.curr_lbl)
                imgui.SameLine()
                imgui.TextColored(C.t_value, toUI(getManagerName()))
                imgui.Spacing()
                imgui.TextColored(C.t_label, L.hint_input)
                imgui.SetNextItemWidth(S.win_w - S.pad*2 - 110)
                imgui.InputText("##nameinput", new_name_buf, 64)
                imgui.SameLine()
                imgui.PushStyleColor(imgui.Col.Button,        C.btn_grn)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, C.btn_grn_hov)
                if imgui.Button(L.btn_save .. "##sv", imgui.ImVec2(-1, 0)) then
                    local ns = ffi.string(new_name_buf):match("^%s*(.-)%s*$")
                    if ns ~= "" then
                        settings.manager_name = ns
                        save_settings()
                        sampAddChatMessage("{2ecc71}[RankTracker] Name set: " .. ns, -1)
                        ffi.fill(new_name_buf, 64, 0)
                    end
                end
                imgui.PopStyleColor(2)

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                -- Инфо-таблица
                local function row(lbl, val)
                    imgui.TextColored(C.t_label, lbl)
                    imgui.SameLine(math.floor(160 * DPI))
                    imgui.TextColored(C.t_white, val)
                end

                row(L.plat_lbl, IS_MOBILE and L.plat_mob or L.plat_pc)
                row(L.ver_lbl,  "3.2")
                row(L.pct_lbl,  tostring((settings.profit_pct or PROFIT_PERCENT) * 100) .. "%")
                row(L.dpi_lbl,  tostring(settings.custom_dpi or DPI))

                imgui.Spacing()

                -- Ползунки размера окна
                imgui.TextColored(C.t_label, u8("Ширина окна:"))
                imgui.SameLine(math.floor(160 * DPI))
                imgui.TextColored(C.t_white, tostring(slider_w[0]) .. " px")
                imgui.SetNextItemWidth(S.win_w - S.pad*2)
                if imgui.SliderInt("##win_w", slider_w, 340, 1500) then
                    recalcS()
                end
                imgui.Spacing()

                imgui.TextColored(C.t_label, u8("Высота окна:"))
                imgui.SameLine(math.floor(160 * DPI))
                imgui.TextColored(C.t_white, tostring(slider_h[0]) .. " px")
                imgui.SetNextItemWidth(S.win_w - S.pad*2)
                if imgui.SliderInt("##win_h", slider_h, 300, 1500) then
                    recalcS()
                end
                imgui.Spacing()

                imgui.PushStyleColor(imgui.Col.Button,        C.btn_grn)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, C.btn_grn_hov)
                if imgui.Button(u8("Сохранить размер##sz"), imgui.ImVec2(S.win_w - S.pad*2, S.btn_h)) then
                    settings.win_w = slider_w[0]
                    settings.win_h = slider_h[0]
                    save_settings()
                    sampAddChatMessage("{2ecc71}[RankTracker] " .. u8("Размер сохранён: ") .. slider_w[0] .. "x" .. slider_h[0], -1)
                end
                imgui.PopStyleColor(2)

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                if imgui.Button(L.btn_reset_dpi, imgui.ImVec2(S.win_w - S.pad*2, S.btn_h)) then
                    settings.autofind_dpi = false
                    save_settings()
                    apply_dpi()
                    DPI = settings.custom_dpi
                    sampAddChatMessage("{f1c40f}[RankTracker] DPI reset: " .. tostring(DPI), -1)
                end

                imgui.Spacing()
                imgui.Separator()
                imgui.Spacing()

                -- Команды
                imgui.TextColored(C.t_label, L.cmd_lbl)
                imgui.Spacing()
                local cmds = {
                    { "/fmenu",   u8("Открыть/закрыть меню") },
                    { "/rtest",   u8("Тестовая отправка в Discord") },
                    { "/rname X", u8("Установить имя менеджера") },
                    { "/rupdate", u8("Обновить скрипт") },
                }
                for _, c in ipairs(cmds) do
                    imgui.TextColored(C.t_cmd,      c[1])
                    imgui.SameLine(math.floor(130 * DPI))
                    imgui.TextColored(C.t_cmd_desc, c[2])
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

    DPI = settings.custom_dpi or 1.0
    loadLogsFromFile()

    sampAddChatMessage("{43b581}[RankTracker v3.2] Started! Manager: " .. getManagerName(), -1)

    sampRegisterChatCommand("rtest", function()
        sendLog("Test_Player", "Media-Manager", "30", 60000000, 30000000, "TEST")
    end)

    sampRegisterChatCommand("rname", function(args)
        if args and args ~= "" then
            settings.manager_name = args
            save_settings()
            sampAddChatMessage("{2ecc71}[RankTracker] Name set: " .. args, -1)
        else
            sampAddChatMessage("{f1c40f}[RankTracker] Current name: " .. getManagerName(), -1)
        end
    end)

    sampRegisterChatCommand("fmenu", function()
        show_menu[0] = not show_menu[0]
    end)

    sampRegisterChatCommand("rupdate", function()
        updateScript()
    end)

    -- FIX 1: wait(100) вместо wait(0) — нагрузка упала в разы
    while true do wait(100) end
end