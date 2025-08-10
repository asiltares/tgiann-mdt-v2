local QBCore = exports['qb-core']:GetCoreObject()
local players = {}
local ox_items = {}

local Config = Config or {}
if not Config.AllowedJobs then
    Config = require('config')
end

local function SendLog(title, desc, color, data)
    if not Config.Logs or not Config.Logs.enabled or not Config.Logs.webhook or Config.Logs.webhook == "" then return end
    local embed = {
        {
            ["title"] = title or "MDT Log",
            ["description"] = desc or "",
            ["color"] = color or 5814783,
            ["fields"] = {},
            ["footer"] = {["text"] = os.date("%d.%m.%Y %H:%M:%S")}
        }
    }
    if data then
        for k,v in pairs(data) do
            table.insert(embed[1].fields, { name = tostring(k), value = tostring(v), inline = true })
        end
    end
    PerformHttpRequest(Config.Logs.webhook, function() end, "POST", json.encode({ embeds = embed }), {["Content-Type"]="application/json"})
end

local function isAllowedJob(jobName)
    return jobName and Config.AllowedJobs and Config.AllowedJobs[jobName]
end

local function refreshPlayers()
    exports.oxmysql:execute('SELECT charinfo, job FROM players', {}, function(result)
        players.police = {}
        players.user = {}
        for i=1, #result do
            local charinfo = {}
            pcall(function() charinfo = json.decode(result[i].charinfo or '{}') end)
            local name = ((charinfo.firstname or '') .. " " .. (charinfo.lastname or '')):gsub("^%s*(.-)%s*$", "%1")
            local jobName = result[i].job
            if jobName and type(jobName) == "string" and jobName:sub(1,1) == "{" then
                local jobData = {}
                pcall(function() jobData = json.decode(jobName) end)
                jobName = jobData and jobData.name or ""
            end
            if isAllowedJob(jobName) then
                table.insert(players.police, name)
            else
                table.insert(players.user, name)
            end
        end
    end)
end

Citizen.CreateThread(function()
    refreshPlayers()
end)

local function getAllOxItemLabels()
    local items = exports.ox_inventory:Items()
    local labels = {}
    for name, item in pairs(items or {}) do
        table.insert(labels, item.label or name)
    end
    return labels
end

QBCore.Functions.CreateCallback("tgiann-mdtv2:ilk-data", function(source, cb)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    exports.oxmysql:execute('SELECT charinfo, job, money FROM players WHERE citizenid = ?', { xPlayer.PlayerData.citizenid }, function(result)
        if result[1] then
            local charinfo = {}
            pcall(function() charinfo = json.decode(result[1].charinfo or '{}') end)
            local name = ((charinfo.firstname or '') .. " " .. (charinfo.lastname or '')):gsub("^%s*(.-)%s*$", "%1")
            local bank = 0
            if result[1].money then
                local moneyData = {}
                pcall(function() moneyData = json.decode(result[1].money or '{}') end)
                bank = moneyData.bank or 0
            end
            cb(players, QBCore.Shared.Items, name, bank)
        end
    end)
end)

RegisterCommand("mdt", function(source, args)
    TriggerClientEvent('tgiann-mdtv2:open', source)
end)

local function translateGender(gender)
    local g = tonumber(gender)
    if g ~= nil then
        if g == 0 then
            return "Erkek"
        elseif g == 1 then
            return "Kadın"
        end
    end
    local s = tostring(gender):lower()
    if s == "male" or s == "m" then
        return "Erkek"
    elseif s == "female" or s == "f" then
        return "Kadın"
    end
    return "Bilinmiyor"
end

local function GetDiscord(source)
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:find("discord:") then
            return "<@" .. id:gsub("discord:", "") .. ">"
        end
    end
    return "*Bağlı değil*"
end

QBCore.Functions.CreateCallback("tgiann-mdtv2:sorgula", function(source, cb, data)
    if Config.Logs.sorgula then
        local name = GetPlayerName(source)
        local discordMention = GetDiscord(source)
        SendLog(
            "MDT Sorgulama",
            ("Tür: `%s`, Sorgu: `%s`, Yapan: `%s` (`%s`) %s"):format(
                data.tip or "-", data.data or "-", name, source, discordMention
            ),
            2123412,
            {
                Sorgulayan = name,
                ID = source,
                Discord = discordMention,
                ["Sorgu Türü"] = data.tip,
                Sorgu = data.data
            }
        )
    end

    if data.tip == "isim" then
        exports.oxmysql:execute('SELECT citizenid, charinfo, job, money, aranma FROM players', {}, function(result)
            local matches = {}
            for _, row in ipairs(result) do
                local charinfo = {}
                pcall(function() charinfo = json.decode(row.charinfo or '{}') end)
                local fullname = ((charinfo.firstname or '') .. " " .. (charinfo.lastname or '')):gsub("^%s*(.-)%s*$", "%1")
                if fullname:lower():find(data.data:lower()) then
                    row.fullname = fullname
                    row.firstname = charinfo.firstname or ""
                    row.lastname = charinfo.lastname or ""
                    row.phone_number = charinfo.phone or ""
                    row.sex = translateGender(charinfo.gender)
                    row.dateofbirth = charinfo.birthdate or ""
                    if row.money then
                        local moneyData = {}
                        pcall(function() moneyData = json.decode(row.money or '{}') end)
                        row.bank = moneyData.bank or 0
                    else
                        row.bank = 0
                    end
                    table.insert(matches, row)
                end
            end
            cb(matches)
        end)

    elseif data.tip == "arac" then
        exports.oxmysql:execute('SELECT * FROM player_vehicles WHERE citizenid = ?', { data.data }, function(result)
            for _, row in ipairs(result) do
                local veh = {}
                if row.vehicle and type(row.vehicle) == "string" and row.vehicle ~= "" then
                    local ok, decoded = pcall(function() return json.decode(row.vehicle) end)
                    if ok and type(decoded) == "table" then veh = decoded end
                end
                row.model = veh.model or row.model or "Unknown.."
                row.plate = veh.plate or row.plate or "Unknown.."
            end
            cb(result)
        end)

    elseif data.tip == "numara" then
        exports.oxmysql:execute('SELECT citizenid, charinfo, job, money, aranma FROM players', {}, function(result)
            local matches = {}
            for _, row in ipairs(result) do
                local charinfo = {}
                pcall(function() charinfo = json.decode(row.charinfo or '{}') end)
                local phone = tostring(charinfo.phone or "")
                if phone:find(data.data) then
                    row.fullname = ((charinfo.firstname or "") .. " " .. (charinfo.lastname or "")):gsub("^%s*(.-)%s*$", "%1")
                    row.firstname = charinfo.firstname or ""
                    row.lastname = charinfo.lastname or ""
                    row.phone_number = charinfo.phone or ""
                    row.sex = translateGender(charinfo.gender)
                    row.dateofbirth = charinfo.birthdate or ""
                    if row.money then
                        local moneyData = {}
                        pcall(function() moneyData = json.decode(row.money or '{}') end)
                        row.bank = moneyData.bank or 0
                    else
                        row.bank = 0
                    end
                    table.insert(matches, row)
                end
            end
            cb(matches)
        end)

    elseif data.tip == "plaka" then
        exports.oxmysql:execute(
            [[SELECT player_vehicles.*, players.charinfo, players.money, players.aranma
              FROM player_vehicles
              LEFT JOIN players ON player_vehicles.citizenid = players.citizenid
              WHERE player_vehicles.plate LIKE ? LIMIT 30]],
            { '%'..data.data..'%' },
            function(result)
                for _, row in ipairs(result) do
                    local charinfo = {}
                    if row.charinfo then
                        pcall(function() charinfo = json.decode(row.charinfo or '{}') end)
                    end
                    row.fullname = ((charinfo.firstname or '') .. " " .. (charinfo.lastname or '')):gsub("^%s*(.-)%s*$", "%1")
                    row.sex = translateGender(charinfo.gender)
                    row.phone_number = charinfo.phone or ""

                    local veh = {}
                    if row.vehicle and row.vehicle ~= "" then
                        local ok, decode = pcall(function() return json.decode(row.vehicle) end)
                        if ok and type(decode) == "table" then
                            veh = decode
                        end
                    end
                    row.model = veh.model or row.model or "Unknown.."
                    row.plate = veh.plate or row.plate or "Unknown.."

                    if row.money then
                        local ok, moneyData = pcall(function() return json.decode(row.money or '{}') end)
                        if ok and type(moneyData) == "table" then
                            row.bank = moneyData.bank or 0
                        else
                            row.bank = 0
                        end
                    else
                        row.bank = 0
                    end
                end
                cb(result)
            end
        )
    end
end)

QBCore.Functions.CreateCallback("tgiann-mdtv2:photo", function(source, cb, data)
    exports.oxmysql:execute('SELECT photo FROM players WHERE citizenid = ?', { data.data }, function(result)
        if result and result[1] then
            cb(result[1].photo)
        else
            cb(nil)
        end
    end)
end)

RegisterNetEvent('tgiann-mdtv2:ceza-kaydet', function(data)
    local src = source
    if Config.Logs.ceza then
        SendLog(
            "Ceza Kaydı",
            ("Polis: `%s`, Zanlı: `%s`, Açıklama: `%s`"):format(json.encode(data.polis), json.encode(data.zanli), data.aciklama or ""),
            15158332,
            { Polisler = json.encode(data.polis), Zanlilar = json.encode(data.zanli), Aciklama = data.aciklama }
        )
    end
    exports.oxmysql:insert(
        'INSERT INTO tgiann_mdt_olaylar (aciklama, polis, zanli, esyalar) VALUES (?, ?, ?, ?)',
        { data.aciklama, json.encode(data.polis), json.encode(data.zanli), json.encode(data.esyalar) },
        function(insertId)
            for i=1, #data.zanli do
                exports.oxmysql:execute('SELECT citizenid, charinfo FROM players', {}, function(result)
                    for _, row in ipairs(result) do
                        local charinfo = {}
                        pcall(function() charinfo = json.decode(row.charinfo or '{}') end)
                        local fullname = ((charinfo.firstname or '') .. " " .. (charinfo.lastname or '')):gsub("^%s*(.-)%s*$", "%1")
                        if fullname:lower() == data.zanli[i]:lower() then
                            exports.oxmysql:insert(
                                'INSERT INTO tgiann_mdt_cezalar (citizenid, aciklama, ceza, polis, cezalar, zanli, olayid) VALUES (?, ?, ?, ?, ?, ?, ?)',
                                { row.citizenid, data.aciklama, json.encode(data.ceza), json.encode(data.polis), data.cezaisim, json.encode(data.zanli), insertId }
                            )
                            break
                        end
                    end
                end)
            end
        end
    )
end)

QBCore.Functions.CreateCallback("tgiann-mdtv2:olaylardata", function(source, cb)
    exports.oxmysql:execute('SELECT * FROM tgiann_mdt_olaylar ORDER BY id DESC LIMIT 100', {}, function(result)
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback("tgiann-mdtv2:sabikadata", function(source, cb, data)
    exports.oxmysql:execute('SELECT * FROM tgiann_mdt_cezalar WHERE citizenid = ? ORDER BY id DESC', { data }, function(result)
        cb(result)
    end)
end)

RegisterNetEvent('tgiann-mdtv2:sabikasil', function(data)
    local src = source
    if Config.Logs.sabika then
        local name = GetPlayerName(src)
        SendLog(
            "SABIKA SİLME",
            ("Silen: `%s` (`%s`), SabıkaID: `%s`"):format(name, src, data),
            16760576,
            { ["Silen"] = name, ["Silen ID"] = src, ["Sabika ID"] = data }
        )
    end
    exports.oxmysql:execute('DELETE FROM tgiann_mdt_cezalar WHERE id = ?', { data })
end)

RegisterNetEvent('tgiann-mdtv2:setavatar', function(url, citizenid)
    local src = source
    if Config.Logs.avatar then
        local name = GetPlayerName(src)
        SendLog(
            "Avatar Değişikliği",
            ("Değiştiren: `%s` (`%s`), Kişi ID: `%s`, Yeni URL: %s"):format(name, src, citizenid, url),
            15844367,
            { Degistiren = name, ID = src, ["Kişi ID"] = citizenid, URL = url }
        )
    end
    exports.oxmysql:execute('UPDATE players SET photo=? WHERE citizenid = ?', { url, citizenid })
end)

RegisterNetEvent('tgiann-mdtv2:olaysil', function(id)
    local src = source
    if Config.Logs.olaylar then
        local name = GetPlayerName(src)
        SendLog(
            "OLAY SİLME",
            ("Silen: `%s` (`%s`), OlayID: `%s`"):format(name, src, id),
            16760576,
            { ["Silen"] = name, ["Silen ID"] = src, ["Olay ID"] = id }
        )
    end
    exports.oxmysql:execute('DELETE FROM tgiann_mdt_olaylar WHERE id = ?', { id })
    exports.oxmysql:execute('DELETE FROM tgiann_mdt_cezalar WHERE olayid = ?', { id })
end)

RegisterNetEvent('tgiann-mdtv2:aranma', function(data, durum)
    local src = source
    local name = GetPlayerName(src)
    if durum then
        if Config.Logs.aranan then
            SendLog(
                "ARANMA EKLEME",
                ("Ekleyen: `%s` (`%s`), Kişi: `%s`, Sebep: `%s`"):format(name, src, data.isim or data.id, data.neden or "-"),
                9109504,
                { Ekleyen = name, ID = src, ["Aranan Kişi"] = data.isim or data.id, Sebep = data.neden or "-" }
            )
        end
        local saat = os.time() + (tonumber(data.saat) or 0) * 86400
        exports.oxmysql:execute('UPDATE players SET aranma=? WHERE citizenid = ?', {
            json.encode({durum = true, sebep = data.neden, suansaat = os.time(), saat = saat}),
            data.id
        })
        exports.oxmysql:insert(
            'INSERT INTO tgiann_mdt_arananlar (citizenid, sebep, baslangic, bitis, isim) VALUES (?, ?, ?, ?, ?)',
            { data.id, data.neden, os.time(), saat, data.isim }
        )
    else
        if Config.Logs.aranan then
            SendLog(
                "ARANMA KALDIRMA",
                ("Kaldıran: `%s` (`%s`), Kişi: `%s`"):format(name, src, data.isim or data.id),
                9109504,
                { Kaldiran = name, ID = src, ["Aranan Kişi"] = data.isim or data.id }
            )
        end
        exports.oxmysql:execute('UPDATE players SET aranma=? WHERE citizenid = ?', {
            json.encode({durum = false, sebep = "", suansaat = "", saat = ""}),
            data.id
        })
        exports.oxmysql:execute('DELETE FROM tgiann_mdt_arananlar WHERE citizenid = ?', { data.id })
    end
end)

QBCore.Functions.CreateCallback("tgiann-mdtv2:arananlar", function(source, cb)
    exports.oxmysql:execute('SELECT * FROM tgiann_mdt_arananlar', {}, function(result)
        cb(result)
    end)
end)

QBCore.Functions.CreateCallback("tgiann-mdtv2:olayara", function(source, cb, data)
    exports.oxmysql:execute('SELECT * FROM tgiann_mdt_olaylar WHERE id = ?', { tonumber(data) }, function(result)
        cb(result)
    end)
end)
