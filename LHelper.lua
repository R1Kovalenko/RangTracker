script_name("LHelper 0.2")
local CURRENT_VERSION = "0.4"
script_name("LHelper " .. CURRENT_VERSION)
script_author("ROMAN KOVALENKO")
script_version(CURRENT_VERSION)

require('lib.moonloader')
local IS_MOBILE = MONET_VERSION ~= nil
local jniOk, jniUtil = pcall(require, "android.jnienv-util")
local sampev  = require 'lib.samp.events'
local requests= require 'requests'
local imgui   = require 'mimgui'
local ffi     = require 'ffi'
local encoding= require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- ================= SETTINGS =================
local DISCORD_WEBHOOK      = "https://discord.com/api/webhooks/1499071031887925279/qh4RsfjR1VzlETTyT1HTl6_h2O5TzjOzVUpExq9tbM9d9pLKpzWiRqk7hD89ot1LOkIr"
local PROFIT_PERCENT       = 0.5
local MANAGER_NAME         = "Nick_Name"
local GITHUB_VERSION_URL   = "https://cdn.jsdelivr.net/gh/R1Kovalenko/RangTracker@main/Update.json"
local RANK_UPDATE_INTERVAL = 60

-- ================= ПУТИ =================
local worked_dir  = getWorkingDirectory():gsub('\\','/')
local config_dir  = worked_dir .. "/LHelper/"
local config_file = config_dir .. "Settings.json"
local log_file    = config_dir .. "logs/rank_tracker.log"
if not doesDirectoryExist(config_dir) then createDirectory(config_dir) end
if not doesDirectoryExist(config_dir.."logs") then createDirectory(config_dir.."logs") end

-- ================= КОНФИГ =================
local default_settings = {
    manager_name = MANAGER_NAME,
    profit_pct   = 0.5,
    autofind_dpi = true,
    custom_dpi   = 2.0,
    win_w        = 1500,
    win_h        = 900,
    use_proxy    = false,
    rank_prices  = {0, 0, 0, 0},
}
local settings = {}

local function merge_defaults(t, d)
    for k, v in pairs(d) do if t[k] == nil then t[k] = v end end
end

local function load_settings()
    if doesFileExist(config_file) then
        local f = io.open(config_file,'r')
        if f then
            local ok, dec = pcall(decodeJson, f:read('*a'))
            f:close()
            settings = (ok and type(dec)=='table') and dec or {}
        end
    else settings = {} end
    merge_defaults(settings, default_settings)
    -- rank_prices
    if type(settings.rank_prices) ~= 'table' then settings.rank_prices = {0,0,0,0} end
    for i = 1, 4 do if not settings.rank_prices[i] then settings.rank_prices[i] = 0 end end
    -- rank_vacancies
    if type(settings.rank_vacancies) ~= 'table' then settings.rank_vacancies = {} end
    for i = 1, 4 do
        if type(settings.rank_vacancies[i]) ~= 'table' then
            settings.rank_vacancies[i] = {used=0, total=0, updated=false}
        end
    end
    -- ranks_last_update
    if type(settings.ranks_last_update) ~= 'number' then settings.ranks_last_update = 0 end
    -- auto_update_ranks
    if settings.auto_update_ranks == nil then settings.auto_update_ranks = true end
end

local function save_settings()
    local f = io.open(config_file,'w')
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
        settings.custom_dpi = IS_MOBILE and MONET_DPI_SCALE
            or ((sizeX/1366)+(sizeY/768))/2
        settings.autofind_dpi = true
        settings.custom_dpi = tonumber(string.format('%.3f', settings.custom_dpi))
        save_settings()
    end
end
apply_dpi()

local DPI = settings.custom_dpi or 1.0

local slider_w = imgui.new.int(settings.win_w or 1500)
local slider_h = imgui.new.int(settings.win_h or 900)

local S = {}
local function recalcS()
    S.win_w = slider_w[0]
    S.win_h = slider_h[0]
    S.btn_h = math.floor(34 * DPI)
    S.pad   = math.floor(10 * DPI)
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
    [0xA8]="\xD0\x81",[0xB8]="\xD1\x91",[0x80]="\xE2\x82\xAC",[0xA0]="\xC2\xA0",
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

-- ================= БУФЕР ОБМЕНА =================
function copyToClipboard(text)
    if IS_MOBILE and jniOk and jniUtil then
        pcall(function() jniUtil.SetClipboardText(text) end)
    else
        imgui.SetClipboardText(text)
    end
end

-- ================= UTILS =================
function fmt(n)
    return string.format("%.0f",n):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
end
function fmtMoney(n)
    if n >= 1000000 then
        local kk=n/1000000; local ki=math.floor(kk); local kr=math.floor((kk-ki)*1000)
        if kr > 0 then return fmt(ki).." KK "..fmt(kr).." K" end
        return fmt(ki).." KK"
    elseif n >= 1000 then return fmt(n/1000).." K" end
    return fmt(n)
end
function escape_json(str)
    str = tostring(str)
    return str:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
end
function stripColors(str) return (str or ""):gsub("{%x%x%x%x%x%x}","") end
function parseAmount(str)
    if not str then return 0 end
    str = tostring(str):gsub("[\x80-\xFF]","")
    str = str:gsub(":KK:","KK"):gsub(":K:","K"):gsub(":M:","M")
    str = str:match("^%s*(.-)%s*$") or str
    local ki,kf = str:match("KK%s*(%d+)%s+(%d+)[%.,]%d*")
    if ki and kf then return (tonumber(ki) or 0)*1000000+(tonumber(kf) or 0)*1000 end
    local kk = str:match("KK%s*(%d+)") if kk then return (tonumber(kk) or 0)*1000000 end
    local k  = str:match("K%s*(%d+)")  if k  then return (tonumber(k)  or 0)*1000    end
    local m  = str:match("M%s*(%d+)")  if m  then return (tonumber(m)  or 0)*1000000000 end
    str = str:gsub("[%.,%s]","")
    return tonumber(str:match("%d+")) or 0
end
function getManagerName() return settings.manager_name or MANAGER_NAME end

-- ================= ПРОКСИ =================
function getDiscordUrl()
    if settings.use_proxy then
        return DISCORD_WEBHOOK:gsub("discord%.com","hooks.hyra.io")
    end
    return DISCORD_WEBHOOK
end

-- ================= ВАКАНСИИ (РАНГИ 5–8) =================
local ranks_info = {
    { dialog_index=5, rank_num=5, name=u8("Ведущий"),        used=0, total=0, updated=false, price=0 },
    { dialog_index=6, rank_num=6, name=u8("Репортёр"),       used=0, total=0, updated=false, price=0 },
    { dialog_index=7, rank_num=7, name=u8("Медиа-Менеджер"), used=0, total=0, updated=false, price=0 },
    { dialog_index=8, rank_num=8, name=u8("Арт-Директор"),   used=0, total=0, updated=false, price=0 },
}
local function load_rank_prices()
    for i, rv in ipairs(ranks_info) do
        rv.price = settings.rank_prices[i] or 0
    end
end
local function save_rank_prices()
    settings.rank_prices = {}
    for i, rv in ipairs(ranks_info) do
        settings.rank_prices[i] = rv.price or 0
    end
    save_settings()
end

-- Загружаем вакансии из конфига в ranks_info
local function load_rank_vacancies()
    for i, rv in ipairs(ranks_info) do
        local v = settings.rank_vacancies[i]
        if v then
            rv.used    = v.used    or 0
            rv.total   = v.total   or 0
            rv.updated = v.updated or false
        end
    end
    ranks_last_update = settings.ranks_last_update or 0
    if ranks_last_update > 0 then
        ranks_update_status = u8("Обновлено: ") .. os.date("%H:%M:%S", ranks_last_update)
    end
end

-- Сохраняем вакансии в конфиг
local function save_rank_vacancies()
    settings.rank_vacancies = {}
    for i, rv in ipairs(ranks_info) do
        settings.rank_vacancies[i] = {
            used    = rv.used,
            total   = rv.total,
            updated = rv.updated,
        }
    end
    settings.ranks_last_update = ranks_last_update
    save_settings()
end

local price_bufs = {}
for i = 1, #ranks_info do
    price_bufs[i] = ffi.new("char[32]")
    ffi.fill(price_bufs[i], 32, 0)
end
local edit_price_idx = 0

local lmenu_dialog_id = nil  -- сохраняем id первого диалога (/lmenu)
local ranks_last_update   = 0
local ranks_updating      = false
local ranks_update_status = u8("Ожидание первого обновления...")
local parse_state         = "idle"
local parse_step_ts       = 0
local PARSE_TIMEOUT       = 8
local ranks_updating      = false
local ranks_update_status = u8("Ожидание первого обновления...")
local parse_state         = "idle"
local parse_step_ts       = 0
local PARSE_TIMEOUT       = 8

local function resetParse(reason)
    ranks_updating      = false
    parse_state         = "idle"
    ranks_update_status = u8("Ошибка: ") .. (reason or "")
end

function startRankUpdate()
    if ranks_updating then return end
    ranks_updating      = true
    parse_state         = "wait_lmenu_dialog"
    parse_step_ts       = os.time()
    ranks_update_status = u8("Обновление...")
    sampSendChat("/lmenu")
end

-- ================= CACHE =================
local Cache = { buyer="", rank="?", days="?", price=0, profit=0, time=0 }

-- ================= СТАТИСТИКА =================
local Stats = { total_sales=0, total_income=0, total_profit=0, renewals=0, purchases=0 }
function statsAddDeal(price, profit, is_renewal)
    Stats.total_sales  = Stats.total_sales  + 1
    Stats.total_income = Stats.total_income + price
    Stats.total_profit = Stats.total_profit + profit
    if is_renewal then Stats.renewals = Stats.renewals+1
    else Stats.purchases = Stats.purchases+1 end
end

-- ================= ЛОГ =================
local log_lines = {}
local MAX_LOG_LINES = 50
local log_needs_scroll = false

function addLogLine(text)
    local f = io.open(log_file,"a")
    if f then f:write(os.date("[%d.%m.%Y %H:%M:%S] ")..text.."\n"); f:close() end
    table.insert(log_lines, os.date("[%H:%M] ")..toUI(text))
    if #log_lines > MAX_LOG_LINES then table.remove(log_lines,1) end
    log_needs_scroll = true
end
function loadLogsFromFile()
    if not doesFileExist(log_file) then return end
    local f = io.open(log_file,"r"); if not f then return end
    log_lines = {}
    for line in f:lines() do table.insert(log_lines, toUI(line)) end
    f:close()
    while #log_lines > MAX_LOG_LINES do table.remove(log_lines,1) end
    log_needs_scroll = true
end

-- ================= DISCORD =================
function sendDiscord(buyer, rank, days, price, profit, title)
    local datetime   = os.date("%d.%m.%Y %H:%M")
    local price_fmt  = fmtMoney(price)
    local profit_fmt = fmtMoney(profit)
    local manager    = getManagerName()
    local buyer_u  = escape_json(toUI(tostring(buyer)))
    local rank_u   = escape_json(toUI(tostring(rank)))
    local title_u  = escape_json(tostring(title))
    local f_buyer  = "\xD0\x9F\xD0\xBE\xD0\xBA\xD1\x83\xD0\xBF\xD0\xB0\xD1\x82\xD0\xB5\xD0\xBB\xD1\x8C"
    local f_rank   = "\xD0\xA0\xD0\xB0\xD0\xBD\xD0\xB3"
    local f_sum    = "\xD0\xA1\xD1\x83\xD0\xBC\xD0\xBC\xD0\xB0"
    local f_profit = "\xD0\x94\xD0\xBE\xD1\x85\xD0\xBE\xD0\xB4 (50%)"
    local f_mgr    = "\xD0\x9C\xD0\xB5\xD0\xBD\xD0\xB5\xD0\xB4\xD0\xB6\xD0\xB5\xD1\x80"
    local f_report = "\xE2\x80\x94\xE2\x80\x94\xE2\x80\x94 \xD0\x94\xD0\xBB\xD1\x8F \xD0\xBE\xD1\x82\xD1\x87\xD1\x91\xD1\x82\xD0\xB0 \xE2\x80\x94\xE2\x80\x94\xE2\x80\x94"
    local dn       = "\xD0\xB4\xD0\xBD"
    local f_bpfx   = "\xD0\x9F\xD0\xBE\xD0\xBA\xD1\x83\xD0\xBF\xD0\xB0\xD1\x82\xD0\xB5\xD0\xBB\xD1\x8C:"
    local report_val = escape_json(f_bpfx..buyer_u.." | "..datetime:sub(1,10).." | "..price_fmt)
    local color = 3447003
    if tostring(title):find("\xD0\x9F\xD0\xA0\xD0\x9E\xD0\x94") then color = 3066993 end
    if tostring(title):find("TEST") then color = 9807270 end
    local body = '{"embeds":[{"title":"'..title_u..'","color":'..color..',"fields":['..
        '{"name":"'..f_buyer..'","value":"'..buyer_u..'","inline":true},'..
        '{"name":"'..f_rank..'","value":"'..rank_u..' ('..escape_json(tostring(days))..' '..dn..'.)","inline":true},'..
        '{"name":"'..f_sum..'","value":"'..escape_json(price_fmt)..'","inline":true},'..
        '{"name":"'..f_profit..'","value":"'..escape_json(profit_fmt)..'","inline":true},'..
        '{"name":"'..f_mgr..'","value":"'..escape_json(cp1251_utf8(manager))..'","inline":false},'..
        '{"name":"'..f_report..'","value":"`'..report_val..'`","inline":false}'..
        '],"footer":{"text":"'..escape_json(cp1251_utf8(manager))..' | '..escape_json(datetime)..'"}}]}'
    local url = getDiscordUrl()
    local proxy_tag = settings.use_proxy and " [proxy]" or " [direct]"
    local ok, res = pcall(function()
        return requests.request("POST", url, {
            data=body, headers={["Content-Type"]="application/json; charset=utf-8"}
        })
    end)
    local status = ok and res and tostring(res.status_code) or "ERR"
    local col = (status=="204" or status=="200") and "{2ecc71}" or "{e74c3c}"
    sampAddChatMessage(col.."[LHelper] Discord: "..status..proxy_tag, -1)
end
function sendLog(buyer, rank, days, price, profit, title)
    lua_thread.create(function() sendDiscord(buyer,rank,days,price,profit,title) end)
    addLogLine(string.format("[%s] %s | %s | %s дн. | %s",
        tostring(title),tostring(buyer),tostring(rank),tostring(days),fmtMoney(price)))
    sampAddChatMessage("{43b581}[LHelper] Sending to Discord...", -1)
end

-- ================= АВТООБНОВЛЕНИЕ СКРИПТА =================
function updateScript()
    lua_thread.create(function()
        sampAddChatMessage("{f1c40f}[LHelper] Find UPDATE...", -1)
        local ok, res = pcall(requests.get, GITHUB_VERSION_URL)
        if not ok or not res or res.status_code ~= 200 then
            sampAddChatMessage("{e74c3c}[LHelper] Ошибка подключения!", -1); return
        end
        local ok2, data = pcall(decodeJson, res.text)
        if not ok2 or not data or not data.version then
            sampAddChatMessage("{e74c3c}[LHelper] Ошибка Сервера (Bad JSON)!", -1); return
        end
        if data.version == CURRENT_VERSION then
            sampAddChatMessage("{2ecc71}[LHelper] Already latest: "..data.version, -1); return
        end
        sampAddChatMessage("{f1c40f}[LHelper] Загрузка обновления v"..data.version.."...", -1)
        local ok3, res2 = pcall(requests.get, data.url)
        if not ok3 or not res2 or res2.status_code ~= 200 then
            sampAddChatMessage("{e74c3c}[LHelper] Ошибка загрузки файла!", -1); return
        end
        local scriptPath = thisScript().path
        local f = io.open(scriptPath, "wb")
        if f then
            f:write(res2.text); f:close()
            sampAddChatMessage("{2ecc71}[LHelper] Обновлен v"..data.version.."! Перезапускаюсь...", -1)
            wait(1000); thisScript():reload()
        else
            sampAddChatMessage("{e74c3c}[LHelper] Не удалось обновить!", -1)
        end
    end)
end

-- ================= ПАРСИНГ ВАКАНСИЙ ЧЕРЕЗ onShowDialog =================
-- Твой рабочий подход: return false скрывает диалог, sendDialogResponse отвечает серверу

local function process_vacancy_data(text)
    local clean_text = text:gsub("{%x%x%x%x%x%x}", "")
    for _, rv in ipairs(ranks_info) do rv.updated = false end

    for line in clean_text:gmatch("[^\n]+") do
        local clean_line = line:gsub("{%x%x%x%x%x%x}", "")
        local idx_s = clean_line:match("^%s*%[(%d+)%]")
        local idx   = idx_s and tonumber(idx_s)
        if idx then
            for _, rv in ipairs(ranks_info) do
                if rv.dialog_index == idx then
                    local used_s, total_s = clean_line:match("%[%s*(%d+)%s*/%s*([%d~]+)")
                    if used_s then
                        rv.used    = tonumber(used_s) or 0
                        rv.total   = tonumber(total_s) or rv.total
                        rv.updated = true
                    end
                end
            end
        end
    end
    -- Сразу пишем в конфиг
    save_rank_vacancies()
end

-- ================= DIALOG HANDLER (вакансии + продажа ранга) =================
function sampev.onShowDialog(id, style, title, button1, button2, text)
    if ranks_updating then
        local clean = text:gsub("{%x%x%x%x%x%x}", "")

        -- КРОК 1: Приховуємо /lmenu і тиснемо "Вакансії"
        if parse_state == "wait_lmenu_dialog" and clean:find("%[3%]") then
            lua_thread.create(function()
                wait(250) -- Затримка як у MH для імітації пінг
                sampSendDialogResponse(id, 1, 2, "") 
                parse_state = "wait_vacancy_dialog"
                parse_step_ts = os.time()
            end)
            return false -- Вікно не з'явиться
        end

        -- КРОК 2: Приховуємо список вакансій, парсимо і тиснемо "Назад"
        if parse_state == "wait_vacancy_dialog" and clean:find("/") then
            process_vacancy_data(text)
            ranks_last_update = os.time()
            ranks_update_status = u8("Оновлено: ") .. os.date("%H:%M:%S")
            
            lua_thread.create(function()
                wait(250)
                sampSendDialogResponse(id, 0, 0, "") -- Закриваємо (повертаємось в lmenu)
                parse_state = "close_final_lmenu"
                parse_step_ts = os.time()
            end)
            return false -- Вікно не з'явиться
        end

        -- КРОК 3: Приховуємо фінальне /lmenu, яке сервер "виштовхнув" назад
        if parse_state == "close_final_lmenu" and clean:find("%[3%]") then
            lua_thread.create(function()
                wait(200)
                sampSendDialogResponse(id, 0, 0, "") -- Закриваємо все остаточно
                ranks_updating = false
                parse_state = "idle"
            end)
            return false -- Вікно не з'явиться
        end
    end

    -- Блок продажу рангу (цей ми НЕ ПРИХОВУЄМО, бо гравцю треба натиснути кнопку)
    pcall(function()
        local clean_sale = stripColors(text)
        if clean_sale:find("Общая стоимость") then
            local buyer = clean_sale:match("[Вв]ыбранный%s+игрок:%s*([%w_%-]+)%s*%(%d+%)")
                       or clean_sale:match("([%w_%-]+)%(%d+%)")
            local rank  = clean_sale:match("[Вв]ыбранный%s+ранг:%s*(.-)%s*%(%d+%)")
                       or clean_sale:match("[Рр]анг%s+игрока:%s*(.-)%s*%(%d+%)")
            if rank then rank = rank:gsub("[%.%s]+$",""):match("^%s*(.-)%s*$") end
            local days       = clean_sale:match("[Вв]ыбранное%s+кол%-во%s+дней:%s*(%d+)")
            local total_str  = clean_sale:match("[Оо]бщая%s+стоимость:%s*(.-)%s*[\n%.]")
                            or clean_sale:match("[Оо]бщая%s+стоимость:%s*([^\n]+)")
            local profit_str = clean_sale:match("[Вв]аш%s+процент:%s*(.-)%s*%(")
                            or clean_sale:match("[Вв]аш%s+процент:%s*([^\n%(]+)")
            
            local price  = total_str and parseAmount(total_str) or 0
            local profit = profit_str and parseAmount(profit_str) or math.floor(price * PROFIT_PERCENT)
            
            if buyer and buyer ~= "" then
                Cache = {buyer=buyer, rank=rank or "?", days=days or "?",
                         price=price, profit=profit, time=os.time()}
            end
        end
    end)
end

-- Пустой хендлер ответа (как в твоём тесте — нужен чтобы не было конфликтов)
function sampev.onDialogResponse(id, button, listitem, input)
end

-- ================= MESSAGE HANDLER =================
function sampev.onServerMessage(color, text)
    pcall(function()
        local clean = stripColors(text)
        if clean:find("Вы предложили игроку") and clean:find("ранг в организации") then
            local pb, pr = clean:match("Вы предложили игроку ([%w_]+) .+ ранг в организации (.+)")
            if pb then Cache.buyer=pb; Cache.rank=pr or Cache.rank; Cache.time=os.time() end
        end
        if clean:find("принял покупку ранга") or clean:find("принял продление ранга") then
            local cb = clean:match("Игрок ([%w_]+)%(%d+%) принял") or clean:match("Игрок ([%w_]+) принял")
            local ps = clean:match("ранга за (.+)$")
            if cb and ps then
                ps = ps:gsub("[%.$]",""):gsub("%s+","")
                ps = ps:gsub("\xD0\x9A\xD0\x9A","KK"):gsub("\xCA\xCA","KK"):gsub(":KK:","KK"):gsub(":K:","K")
                local amount = parseAmount(ps)
                if amount == 0 then local n=ps:match("(%d+)"); if n then amount=tonumber(n)*1000000 end end
                local fresh   = (os.time()-Cache.time) < 60
                local matched = fresh and Cache.buyer ~= "" and clean:find(Cache.buyer,1,true)
                local frank   = matched and Cache.rank or "?"
                local fdays   = matched and Cache.days or "?"
                if amount == 0 then amount = Cache.price end
                local profit     = (Cache.profit > 0) and Cache.profit or math.floor(amount*PROFIT_PERCENT)
                local is_renewal = clean:find("продление") ~= nil
                local op_title   = is_renewal and u8("ПРОДЛЕНИЕ РАНГА") or u8("ПОКУПКА РАНГА")
                statsAddDeal(amount, profit, is_renewal)
                sendLog(cb, frank, fdays, amount, profit, op_title)
                Cache = {buyer="", rank="?", days="?", price=0, profit=0, time=0}
                lua_thread.create(function() wait(500); sampSendChat("/time") end)
            end
        end
    end)
end

-- ================= ТЕМА =================
local C = {}
imgui.OnInitialize(function()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    style.WindowPadding     = imgui.ImVec2(14,14)
    style.WindowRounding    = 16.0
    style.ChildRounding     = 12.0
    style.FramePadding      = imgui.ImVec2(8,6)
    style.FrameRounding     = 10.0
    style.ItemSpacing       = imgui.ImVec2(8,8)
    style.ItemInnerSpacing  = imgui.ImVec2(8,6)
    style.ScrollbarRounding = 10.0
    style.GrabRounding      = 6.0
    style.TabRounding       = 8.0
    style.WindowTitleAlign  = imgui.ImVec2(0.5,0.5)
    style.ButtonTextAlign   = imgui.ImVec2(0.5,0.5)
    local c = style.Colors
    c[imgui.Col.Text]                 = imgui.ImVec4(0.90,0.90,0.93,1.00)
    c[imgui.Col.TextDisabled]         = imgui.ImVec4(0.38,0.38,0.42,1.00)
    c[imgui.Col.WindowBg]             = imgui.ImVec4(0.07,0.07,0.09,1.00)
    c[imgui.Col.ChildBg]              = imgui.ImVec4(0.10,0.10,0.13,1.00)
    c[imgui.Col.PopupBg]              = imgui.ImVec4(0.10,0.10,0.13,1.00)
    c[imgui.Col.Border]               = imgui.ImVec4(0.20,0.20,0.26,1.00)
    c[imgui.Col.BorderShadow]         = imgui.ImVec4(0.00,0.00,0.00,0.00)
    c[imgui.Col.FrameBg]              = imgui.ImVec4(0.13,0.13,0.17,1.00)
    c[imgui.Col.FrameBgHovered]       = imgui.ImVec4(0.18,0.18,0.24,1.00)
    c[imgui.Col.FrameBgActive]        = imgui.ImVec4(0.22,0.22,0.30,1.00)
    c[imgui.Col.TitleBg]              = imgui.ImVec4(0.07,0.07,0.09,1.00)
    c[imgui.Col.TitleBgActive]        = imgui.ImVec4(0.07,0.07,0.09,1.00)
    c[imgui.Col.TitleBgCollapsed]     = imgui.ImVec4(0.07,0.07,0.09,1.00)
    c[imgui.Col.ScrollbarBg]          = imgui.ImVec4(0.07,0.07,0.09,1.00)
    c[imgui.Col.ScrollbarGrab]        = imgui.ImVec4(0.22,0.22,0.30,1.00)
    c[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.30,0.30,0.40,1.00)
    c[imgui.Col.ScrollbarGrabActive]  = imgui.ImVec4(0.38,0.38,0.50,1.00)
    c[imgui.Col.CheckMark]            = imgui.ImVec4(0.28,0.68,1.00,1.00)
    c[imgui.Col.SliderGrab]           = imgui.ImVec4(0.22,0.56,0.92,1.00)
    c[imgui.Col.SliderGrabActive]     = imgui.ImVec4(0.30,0.68,1.00,1.00)
    c[imgui.Col.Button]               = imgui.ImVec4(0.14,0.38,0.62,0.90)
    c[imgui.Col.ButtonHovered]        = imgui.ImVec4(0.20,0.52,0.84,1.00)
    c[imgui.Col.ButtonActive]         = imgui.ImVec4(0.10,0.28,0.48,1.00)
    c[imgui.Col.Header]               = imgui.ImVec4(0.14,0.38,0.62,0.80)
    c[imgui.Col.HeaderHovered]        = imgui.ImVec4(0.20,0.52,0.84,1.00)
    c[imgui.Col.HeaderActive]         = imgui.ImVec4(0.10,0.28,0.48,1.00)
    c[imgui.Col.Separator]            = imgui.ImVec4(0.18,0.18,0.24,1.00)
    c[imgui.Col.Tab]                  = imgui.ImVec4(0.10,0.10,0.13,1.00)
    c[imgui.Col.TabHovered]           = imgui.ImVec4(0.20,0.52,0.84,1.00)
    c[imgui.Col.TabActive]            = imgui.ImVec4(0.14,0.38,0.62,1.00)
    c[imgui.Col.ResizeGrip]           = imgui.ImVec4(0.14,0.38,0.62,0.60)
    c[imgui.Col.ResizeGripHovered]    = imgui.ImVec4(0.20,0.52,0.84,0.80)
    c[imgui.Col.ResizeGripActive]     = imgui.ImVec4(0.28,0.68,1.00,1.00)
    c[imgui.Col.TextSelectedBg]       = imgui.ImVec4(0.14,0.38,0.62,0.50)
    c[imgui.Col.ModalWindowDimBg]     = imgui.ImVec4(0.04,0.04,0.06,0.75)
    imgui.GetIO().IniFilename = nil
    C.t_title    = imgui.ImVec4(0.28,0.72,1.00,1.00)
    C.t_label    = imgui.ImVec4(0.48,0.48,0.54,1.00)
    C.t_value    = imgui.ImVec4(1.00,0.82,0.20,1.00)
    C.t_buyer    = imgui.ImVec4(0.42,0.74,1.00,1.00)
    C.t_rank     = imgui.ImVec4(1.00,0.80,0.32,1.00)
    C.t_days     = imgui.ImVec4(0.55,0.88,0.55,1.00)
    C.t_price    = imgui.ImVec4(0.32,1.00,0.52,1.00)
    C.t_profit   = imgui.ImVec4(1.00,0.70,0.18,1.00)
    C.t_sep      = imgui.ImVec4(0.28,0.28,0.34,1.00)
    C.t_time     = imgui.ImVec4(0.32,0.82,0.42,1.00)
    C.t_green    = imgui.ImVec4(0.20,0.88,0.28,1.00)
    C.t_red      = imgui.ImVec4(1.00,0.25,0.25,1.00)
    C.t_orange   = imgui.ImVec4(1.00,0.60,0.10,1.00)
    C.t_gray     = imgui.ImVec4(0.32,0.32,0.38,1.00)
    C.t_log      = imgui.ImVec4(0.68,0.88,0.68,1.00)
    C.t_log_ext  = imgui.ImVec4(0.38,0.88,0.54,1.00)
    C.t_log_test = imgui.ImVec4(0.48,0.48,0.54,1.00)
    C.t_cmd      = imgui.ImVec4(0.32,0.72,1.00,1.00)
    C.t_cmd_desc = imgui.ImVec4(0.58,0.58,0.64,1.00)
    C.t_white    = imgui.ImVec4(0.82,0.82,0.88,1.00)
end)

function imgui.CenterText(text, col)
    imgui.SetCursorPosX(imgui.GetWindowSize().x/2 - imgui.CalcTextSize(text).x/2)
    if col then imgui.TextColored(col,text) else imgui.Text(text) end
end
function imgui.RightText(text, padding, col)
    padding = padding or 0
    imgui.SetCursorPosX(imgui.GetWindowSize().x - imgui.CalcTextSize(text).x - padding)
    if col then imgui.TextColored(col,text) else imgui.Text(text) end
end

-- ================= GUI STATE =================
local show_menu    = imgui.new.bool(false)
local new_name_buf = ffi.new("char[64]"); ffi.fill(new_name_buf,64,0)
local gui_time = ""; local last_time_t = 0
local cb_proxy        = imgui.new.bool(false)
local cb_auto_ranks   = imgui.new.bool(true)

-- ================= GUI =================
imgui.OnFrame(function() return show_menu[0] end, function()
    local now = os.time()
    if now ~= last_time_t then gui_time = os.date("%H:%M:%S"); last_time_t = now end
    cb_proxy[0]      = settings.use_proxy == true
    cb_auto_ranks[0] = settings.auto_update_ranks ~= false
    local sw = imgui.GetIO().DisplaySize.x
    local sh = imgui.GetIO().DisplaySize.y
    imgui.SetNextWindowSize(imgui.ImVec2(S.win_w, S.win_h), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(sw/2-S.win_w/2, sh/2-S.win_h/2), imgui.Cond.FirstUseEver)

    local has_cache = Cache.buyer ~= "" and Cache.time > 0
    local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize

    if imgui.Begin("###RTMain", show_menu, flags) then

        -- Заголовок
        local hdr_h = math.floor(48*DPI)
        if imgui.BeginChild("##hdr", imgui.ImVec2(0,hdr_h), true) then
            imgui.SetCursorPos(imgui.ImVec2(math.floor(6*DPI), math.floor(8*DPI)))
            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.55,0.10,0.10,0.90))
            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.80,0.15,0.15,1.00))
            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.35,0.06,0.06,1.00))
            if imgui.Button("X##cls", imgui.ImVec2(math.floor(32*DPI), math.floor(32*DPI))) then
                show_menu[0] = false
            end
            imgui.PopStyleColor(3)
            imgui.SetCursorPos(imgui.ImVec2(0, math.floor(14*DPI)))
            imgui.CenterText(u8("LHelper v"..CURRENT_VERSION), C.t_title)
            imgui.SetCursorPos(imgui.ImVec2(0, math.floor(6*DPI)))
            imgui.RightText(gui_time, math.floor(10*DPI), C.t_time)
            imgui.SetCursorPos(imgui.ImVec2(0, math.floor(26*DPI)))
            if has_cache then imgui.RightText(u8(" ГОТОВО"), math.floor(10*DPI), C.t_green)
            else imgui.RightText(u8(" ОЖИДАНИЕ"), math.floor(10*DPI), C.t_gray) end
            imgui.EndChild()
        end
        imgui.Spacing()

        if imgui.BeginTabBar("##tabs") then

            -- ===== ГЛАВНАЯ =====
            if imgui.BeginTabItem(u8("  Главная  ")) then
                imgui.Spacing()
                imgui.TextColored(C.t_label, u8("Менеджер:"))
                imgui.SameLine()
                imgui.TextColored(C.t_value, toUI(getManagerName()))
                imgui.Spacing()
                imgui.TextColored(C.t_label, u8("Последняя запись:"))
                imgui.Spacing()

                -- Карточка (уменьшенная высота)
                local card_h = math.floor(54*DPI)
                if imgui.BeginChild("##card", imgui.ImVec2(0, card_h), true) then
                    imgui.Spacing()
                    if has_cache then
                        local bv = toUI(Cache.buyer)
                        local rv = Cache.rank ~= "?" and toUI(Cache.rank) or "\xE2\x80\x94"
                        local dv = Cache.days ~= "?" and (Cache.days.." "..u8("дн.")) or "\xE2\x80\x94"
                        local pv = Cache.price  > 0 and fmtMoney(Cache.price)  or "\xE2\x80\x94"
                        local fv = Cache.profit > 0 and fmtMoney(Cache.profit) or "\xE2\x80\x94"
                        imgui.TextColored(C.t_buyer, bv) imgui.SameLine()
                        imgui.TextColored(C.t_sep, "  |  ") imgui.SameLine()
                        imgui.TextColored(C.t_rank, rv) imgui.SameLine()
                        imgui.TextColored(C.t_sep, "  |  ") imgui.SameLine()
                        imgui.TextColored(C.t_days, dv) imgui.SameLine()
                        imgui.TextColored(C.t_sep, "  |  ") imgui.SameLine()
                        imgui.TextColored(C.t_price, pv) imgui.SameLine()
                        imgui.TextColored(C.t_sep, " > ") imgui.SameLine()
                        imgui.TextColored(C.t_profit, fv)
                        imgui.Spacing()
                        local report = u8("Покупатель:")..toUI(Cache.buyer).." | "..os.date("%d.%m.%Y").." | "..fmtMoney(Cache.price)
                        imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.20,0.20,0.26,0.90))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.14,0.38,0.62,1.00))
                        imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.10,0.26,0.44,1.00))
                        if imgui.Button(u8("Копировать отчёт").."##cp", imgui.ImVec2(-1, math.floor(24*DPI))) then
                            copyToClipboard(report)
                            sampAddChatMessage("{2ecc71}[LHelper] "..u8("Скопировано!"), -1)
                        end
                        imgui.PopStyleColor(3)
                    else
                        imgui.CenterText(u8("Нет данных — откройте диалог продажи ранга"), C.t_gray)
                    end
                    imgui.EndChild()
                end
                imgui.Spacing()

                if has_cache then
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.09,0.50,0.26,0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12,0.65,0.33,1.00))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.06,0.34,0.18,1.00))
                    if imgui.Button(u8("Отправить в Discord"), imgui.ImVec2(-1, S.btn_h)) then
                        sendLog(Cache.buyer,Cache.rank,Cache.days,Cache.price,Cache.profit,u8("РУЧНАЯ ОТПРАВКА"))
                    end
                    imgui.PopStyleColor(3)
                    imgui.Spacing()
                end

                -- ===== БЛОК ВАКАНСИЙ =====
                imgui.Separator()
                imgui.Spacing()

                local secs_left = RANK_UPDATE_INTERVAL - (now - ranks_last_update)
                local timer_str
                if ranks_updating then
                    timer_str = u8("   обновление...")
                elseif ranks_last_update == 0 then
                    timer_str = u8("   нет данных")
                else
                    timer_str = string.format(u8("   через %dс"), math.max(0,secs_left))
                end
                imgui.TextColored(C.t_title, u8("Вакансии (ранги 5–8)"))
                imgui.SameLine()
                imgui.TextColored(C.t_gray, timer_str)
                imgui.TextColored(C.t_gray, ranks_update_status)
                imgui.Spacing()

                -- Кнопка обновить
                if ranks_updating then
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.20,0.20,0.26,0.50))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20,0.20,0.26,0.50))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.20,0.20,0.26,0.50))
                else
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.10,0.30,0.52,0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.16,0.44,0.72,1.00))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.06,0.20,0.36,1.00))
                end
                if imgui.Button(u8("Обновить сейчас").."##ru", imgui.ImVec2(-1, math.floor(28*DPI))) then
                    if not ranks_updating then startRankUpdate() end
                end
                imgui.PopStyleColor(3)
                imgui.Spacing()

                -- Таблица рангов
                local avail_w  = S.win_w - S.pad*2 - math.floor(28*DPI)
                local col_num  = math.floor(avail_w * 0.06)
                local col_name = math.floor(avail_w * 0.27)
                local col_occ  = math.floor(avail_w * 0.46)
                local col_free = math.floor(avail_w * 0.60)
                local col_price= math.floor(avail_w * 0.74)
                local row_h    = math.floor(28*DPI)
                local rank_block_h = math.floor(row_h*(#ranks_info+1) + 24*DPI)

                if imgui.BeginChild("##ranks_block", imgui.ImVec2(0, rank_block_h), true) then
                    -- Заголовок
                    imgui.TextColored(C.t_label, "#")
                    imgui.SameLine(col_num)
                    imgui.TextColored(C.t_label, u8("Название"))
                    imgui.SameLine(col_name)
                    imgui.TextColored(C.t_label, u8("Занято/Макс"))
                    imgui.SameLine(col_occ)
                    imgui.TextColored(C.t_label, u8("Своб."))
                    imgui.SameLine(col_free)
                    imgui.TextColored(C.t_label, u8("Цена (30д)"))
                    imgui.Separator()

                    for i, rv in ipairs(ranks_info) do
                        local free_count = rv.total > 0 and (rv.total - rv.used) or 0
                        local row_col
                        if not rv.updated then
                            row_col = C.t_gray
                        elseif rv.used >= rv.total and rv.total > 0 then
                            row_col = C.t_red
                        elseif free_count <= 3 and rv.total > 0 then
                            row_col = C.t_orange
                        else
                            row_col = C.t_green
                        end

                        imgui.TextColored(C.t_gray, tostring(rv.rank_num)..".")
                        imgui.SameLine(col_num)
                        imgui.TextColored(C.t_rank, rv.name)
                        imgui.SameLine(col_name)

                        local used_str
                        if not rv.updated      then used_str = "— / —"
                        elseif rv.total == 0   then used_str = tostring(rv.used).." / ~"
                        else used_str = tostring(rv.used).." / "..tostring(rv.total) end
                        imgui.TextColored(row_col, used_str)
                        imgui.SameLine(col_occ)

                        local free_str
                        if not rv.updated           then free_str = "—"
                        elseif rv.total == 0        then free_str = "~"
                        elseif rv.used >= rv.total  then free_str = u8("Полн!")
                        else free_str = tostring(free_count) end
                        imgui.TextColored(row_col, free_str)
                        imgui.SameLine(col_free)

                        -- Цена + кнопка редактирования
                        if edit_price_idx == i then
                            imgui.SetNextItemWidth(math.floor(80*DPI))
                            if imgui.InputText("##ep"..i, price_bufs[i], 32,
                                imgui.InputTextFlags.EnterReturnsTrue) then
                                local ns = ffi.string(price_bufs[i]):match("^%s*(.-)%s*$")
                                local n = tonumber(ns)
                                if n then rv.price = math.floor(n*1000000); save_rank_prices() end
                                edit_price_idx = 0
                            end
                            imgui.SameLine()
                            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.09,0.50,0.26,0.90))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12,0.65,0.33,1.00))
                            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.06,0.34,0.18,1.00))
                            if imgui.Button("OK##ok"..i, imgui.ImVec2(math.floor(32*DPI), 0)) then
                                local ns = ffi.string(price_bufs[i]):match("^%s*(.-)%s*$")
                                local n = tonumber(ns)
                                if n then rv.price = math.floor(n*1000000); save_rank_prices() end
                                edit_price_idx = 0
                            end
                            imgui.PopStyleColor(3)
                        else
                            local price_str = rv.price > 0 and fmtMoney(rv.price) or "\xE2\x80\x94"
                            imgui.TextColored(C.t_value, price_str)
                            imgui.SameLine()
                            imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.18,0.18,0.24,0.80))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.28,0.28,0.38,1.00))
                            imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.12,0.12,0.18,1.00))
                            if imgui.Button(u8("##ed")..i, imgui.ImVec2(math.floor(26*DPI), math.floor(22*DPI))) then
                                edit_price_idx = i
                                local cur_mln = rv.price > 0 and string.format("%.0f", rv.price/1000000) or ""
                                ffi.fill(price_bufs[i], 32, 0)
                                for ci = 1, #cur_mln do
                                    price_bufs[i][ci-1] = string.byte(cur_mln, ci)
                                end
                            end
                            imgui.PopStyleColor(3)
                        end
                    end
                    imgui.EndChild()
                end

                imgui.EndTabItem()
            end

            -- ===== ЛОГ =====
            if imgui.BeginTabItem(u8("  Лог  ")) then
                imgui.Spacing()
                local log_h = math.max(80, S.win_h - math.floor(260*DPI))
                if imgui.BeginChild("##logbox", imgui.ImVec2(0, log_h), true) then
                    if #log_lines == 0 then
                        imgui.Spacing(); imgui.CenterText(u8("Лог пуст"), C.t_gray)
                    else
                        local st = math.max(1, #log_lines-40)
                        for i = st, #log_lines do
                            local line = log_lines[i]
                            local col = C.t_log
                            if line:find("TEST") then col = C.t_log_test
                            elseif line:find("\xD0\x9F\xD0\xA0\xD0\x9E\xD0\x94") then col = C.t_log_ext end
                            imgui.TextColored(col, line)
                        end
                        if log_needs_scroll then imgui.SetScrollHereY(1.0); log_needs_scroll=false end
                    end
                    imgui.EndChild()
                end
                imgui.Spacing()
                if imgui.Button(u8("Обновить лог"), imgui.ImVec2(-1, S.btn_h)) then loadLogsFromFile() end
                imgui.EndTabItem()
            end

            -- ===== СТАТИСТИКА =====
            if imgui.BeginTabItem(u8("  Статистика  ")) then
                imgui.Spacing()
                imgui.CenterText(u8("Статистика сессии"), C.t_title)
                imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                if imgui.BeginChild("##sc", imgui.ImVec2(0, math.floor(200*DPI)), true) then
                    imgui.Spacing()
                    local function sr(lbl, val, col)
                        imgui.TextColored(C.t_label, lbl)
                        imgui.SameLine(math.floor(220*DPI))
                        imgui.TextColored(col or C.t_white, val)
                    end
                    sr(u8("Всего сделок:"),      tostring(Stats.total_sales),  C.t_buyer)
                    sr(u8("Покупок:"),            tostring(Stats.purchases),    C.t_price)
                    sr(u8("Продлений:"),          tostring(Stats.renewals),     C.t_log_ext)
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                    sr(u8("Общая сумма продаж:"), fmtMoney(Stats.total_income), C.t_rank)
                    sr(u8("Общий доход (50%):"),  fmtMoney(Stats.total_profit), C.t_profit)
                    if Stats.total_sales > 0 then
                        imgui.Spacing(); imgui.Separator(); imgui.Spacing()
                        sr(u8("Средняя сделка:"), fmtMoney(math.floor(Stats.total_income/Stats.total_sales)), C.t_days)
                    end
                    imgui.Spacing()
                    imgui.EndChild()
                end
                imgui.Spacing()
                imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.52,0.10,0.10,0.90))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.70,0.15,0.15,1.00))
                imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.34,0.06,0.06,1.00))
                if imgui.Button(u8("Сбросить статистику"), imgui.ImVec2(-1, S.btn_h)) then
                    Stats = {total_sales=0,total_income=0,total_profit=0,renewals=0,purchases=0}
                    sampAddChatMessage("{f1c40f}[LHelper] Stats reset.", -1)
                end
                imgui.PopStyleColor(3)
                imgui.EndTabItem()
            end

            -- ===== НАСТРОЙКИ =====
            if imgui.BeginTabItem(u8("  Настройки  ")) then
                if imgui.BeginChild("##settings_scroll", imgui.ImVec2(0,0), false) then
                    imgui.Spacing(); imgui.Spacing()

                    -- Имя менеджера
                    imgui.TextColored(C.t_label, u8("Имя менеджера:"))
                    imgui.Spacing()
                    imgui.TextColored(C.t_label, u8("Текущее:"))
                    imgui.SameLine()
                    imgui.TextColored(C.t_value, toUI(getManagerName()))
                    imgui.Spacing()
                    imgui.TextColored(C.t_label, u8("Новое имя:"))
                    imgui.SetNextItemWidth(S.win_w - S.pad*2 - math.floor(130*DPI))
                    imgui.InputText("##ni", new_name_buf, 64)
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.09,0.50,0.26,0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12,0.65,0.33,1.00))
                    if imgui.Button(u8("Сохранить").."##sv", imgui.ImVec2(-1,0)) then
                        local ns = ffi.string(new_name_buf):match("^%s*(.-)%s*$")
                        if ns ~= "" then
                            settings.manager_name = ns; save_settings()
                            sampAddChatMessage("{2ecc71}[LHelper] Name set: "..ns, -1)
                            ffi.fill(new_name_buf, 64, 0)
                        end
                    end
                    imgui.PopStyleColor(2)
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                    -- Прокси
                    imgui.TextColored(C.t_title, u8("Настройки Discord"))
                    imgui.Spacing()
                    local pcol = settings.use_proxy and C.t_green or C.t_gray
                    local ptxt = settings.use_proxy and u8("ВКЛ") or u8("ВЫКЛ")
                    imgui.TextColored(C.t_label, u8("Прокси Discord (hooks.hyra.io)"))
                    imgui.SameLine()
                    imgui.TextColored(pcol, "["..ptxt.."]")
                    imgui.Spacing()
                    if imgui.Checkbox(u8("Использовать прокси (hooks.hyra.io)##px"), cb_proxy) then
                        settings.use_proxy = cb_proxy[0]; save_settings()
                        local msg = settings.use_proxy
                            and "{2ecc71}[LHelper] Прокси Discord: ВКЛ"
                            or  "{f1c40f}[LHelper] Прокси Discord: ВЫКЛ"
                        sampAddChatMessage(msg, -1)
                    end
                    imgui.Spacing()
                    imgui.TextColored(C.t_gray, u8("Текущий адрес:"))
                    imgui.SameLine()
                    imgui.TextColored(C.t_cmd, settings.use_proxy and "hooks.hyra.io/api/webhooks/..." or "discord.com/api/webhooks/...")
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                    -- Автообновление вакансий
                    imgui.TextColored(C.t_title, u8("Вакансии"))
                    imgui.Spacing()
                    local auto_col = settings.auto_update_ranks ~= false and C.t_green or C.t_gray
                    local auto_txt = settings.auto_update_ranks ~= false and u8("ВКЛ") or u8("ВЫКЛ")
                    imgui.TextColored(C.t_label, u8("Автообновление каждые 60с"))
                    imgui.SameLine()
                    imgui.TextColored(auto_col, "["..auto_txt.."]")
                    imgui.Spacing()
                    if imgui.Checkbox(u8("Автообновление вакансий##ar"), cb_auto_ranks) then
                        settings.auto_update_ranks = cb_auto_ranks[0]
                        save_settings()
                        local msg = settings.auto_update_ranks
                            and "{2ecc71}[LHelper] Автообновление вакансий: ВКЛ"
                            or  "{f1c40f}[LHelper] Автообновление вакансий: ВЫКЛ"
                        sampAddChatMessage(msg, -1)
                    end
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                    -- Тест
                    imgui.TextColored(C.t_title, u8("Тестирование"))
                    imgui.Spacing()
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.36,0.20,0.60,0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.50,0.28,0.80,1.00))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.24,0.12,0.42,1.00))
                    if imgui.Button(u8("Тест Discord").."##tst", imgui.ImVec2(-1, S.btn_h)) then
                        sendLog("Test_Player","Media-Manager","30",60000000,30000000,"TEST")
                    end
                    imgui.PopStyleColor(3)
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                    -- Инфо
                    local function row(lbl, val)
                        imgui.TextColored(C.t_label, lbl)
                        imgui.SameLine(math.floor(160*DPI))
                        imgui.TextColored(C.t_white, val)
                    end
                    row(u8("Платформа:"), IS_MOBILE and "MonetLoader (Mobile)" or "MoonLoader (PC)")
                    row(u8("Версия:"),    CURRENT_VERSION)
                    row(u8("Доход %:"),   tostring((settings.profit_pct or PROFIT_PERCENT)*100).."%")
                    row(u8("Масштаб DPI:"), tostring(settings.custom_dpi or DPI))
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                    -- Размер окна
                    imgui.TextColored(C.t_label, u8("Ширина окна:"))
                    imgui.SameLine(math.floor(160*DPI))
                    imgui.TextColored(C.t_white, tostring(slider_w[0]).." px")
                    imgui.SetNextItemWidth(-1)
                    if imgui.SliderInt("##ww", slider_w, 340, 1500) then recalcS() end
                    imgui.Spacing()
                    imgui.TextColored(C.t_label, u8("Высота окна:"))
                    imgui.SameLine(math.floor(160*DPI))
                    imgui.TextColored(C.t_white, tostring(slider_h[0]).." px")
                    imgui.SetNextItemWidth(-1)
                    if imgui.SliderInt("##wh", slider_h, 300, 1500) then recalcS() end
                    imgui.Spacing()
                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.09,0.50,0.26,0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.12,0.65,0.33,1.00))
                    if imgui.Button(u8("Сохранить размер##sz"), imgui.ImVec2(-1, S.btn_h)) then
                        settings.win_w = slider_w[0]; settings.win_h = slider_h[0]; save_settings()
                        sampAddChatMessage("{2ecc71}[LHelper] Size saved: "..slider_w[0].."x"..slider_h[0], -1)
                    end
                    imgui.PopStyleColor(2)
                    imgui.Spacing()
                    if imgui.Button(u8("Сбросить DPI"), imgui.ImVec2(-1, S.btn_h)) then
                        settings.autofind_dpi = false; save_settings(); apply_dpi()
                        DPI = settings.custom_dpi
                        sampAddChatMessage("{f1c40f}[LHelper] DPI reset: "..tostring(DPI), -1)
                    end
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                    -- Команды
                    imgui.TextColored(C.t_label, u8("Команды:"))
                    imgui.Spacing()
                    local cmds = {
                        {"/fmenu",   u8("Открыть/закрыть меню")},
                        {"/rtest",   u8("Тестовая отправка в Discord")},
                        {"/rname X", u8("Установить имя менеджера")},
                        {"/rupdate", u8("Обновить скрипт")},
                        {"/ruranks", u8("Принудительно обновить вакансии")},
                    }
                    for _, c in ipairs(cmds) do
                        imgui.TextColored(C.t_cmd, c[1])
                        imgui.SameLine(math.floor(130*DPI))
                        imgui.TextColored(C.t_cmd_desc, c[2])
                    end
                    imgui.Spacing(); imgui.Separator(); imgui.Spacing()

                    imgui.PushStyleColor(imgui.Col.Button,        imgui.ImVec4(0.14,0.38,0.62,0.90))
                    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18,0.48,0.78,1.00))
                    imgui.PushStyleColor(imgui.Col.ButtonActive,  imgui.ImVec4(0.10,0.28,0.46,1.00))
                    if imgui.Button(u8("Проверить обновления (v"..CURRENT_VERSION..")"), imgui.ImVec2(-1, S.btn_h)) then
                        updateScript()
                    end
                    imgui.PopStyleColor(3)
                    imgui.Spacing()
                    imgui.EndChild()
                end
                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
    end
    imgui.End()
end)

-- ================= MAIN =================
function main()
    while not isSampAvailable() do wait(100) end
    wait(500)
    DPI = settings.custom_dpi or 1.0
    load_rank_prices()
    load_rank_vacancies()
    loadLogsFromFile()
    local proxy_info = settings.use_proxy and " [proxy: ON]" or " [proxy: OFF]"
    sampAddChatMessage("{43b581}[LHelper v"..CURRENT_VERSION.."] Started! Manager: "..getManagerName()..proxy_info, -1)

    sampRegisterChatCommand("rtest", function()
        sendLog("Test_Player","Media-Manager","30",60000000,30000000,"TEST")
    end)
    sampRegisterChatCommand("rname", function(args)
        if args and args ~= "" then
            settings.manager_name = args; save_settings()
            sampAddChatMessage("{2ecc71}[LHelper] Name set: "..args, -1)
        else
            sampAddChatMessage("{f1c40f}[LHelper] Current name: "..getManagerName(), -1)
        end
    end)
    sampRegisterChatCommand("fmenu", function()
        show_menu[0] = not show_menu[0]
    end)
    sampRegisterChatCommand("rupdate", function() updateScript() end)
    sampRegisterChatCommand("ruranks", function()
        if not ranks_updating then
            startRankUpdate()
            sampAddChatMessage("{f1c40f}[LHelper] Обновление вакансий...", -1)
        else
            sampAddChatMessage("{e74c3c}[LHelper] Уже обновляется, подождите.", -1)
        end
    end)

    -- Автообновление вакансий раз в минуту
    lua_thread.create(function()
        wait(5000)
        while true do
            if not ranks_updating and settings.auto_update_ranks then
                startRankUpdate()
            end
            wait(RANK_UPDATE_INTERVAL * 1000)
        end
    end)

    -- Основной цикл с проверкой таймаута (как в Market Helper)
    while true do 
        wait(100)
        if ranks_updating and os.time() - parse_step_ts > PARSE_TIMEOUT then
            ranks_updating = false
            parse_state = "idle"
            ranks_update_status = u8("Ошибка: Тайм-аут обновления")
            -- Можно добавить лог в чат для отладки
            -- sampAddChatMessage("{e74c3c}[LHelper] Ошибка: Диалог вакансий не получен (Timeout)", -1)
        end
    end
end