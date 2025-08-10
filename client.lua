local coreLoaded = false
local nuiFocus = false
local tab = 0
local PlayerData = {}
QBCore = exports['qb-core']:GetCoreObject()

local Config = Config or {}
if not Config.AllowedJobs then
    Config = require('config')
end

local function isAllowedJob()
    return PlayerData.job and Config.AllowedJobs and Config.AllowedJobs[PlayerData.job.name]
end

Citizen.CreateThread(function()
    while QBCore == nil do
        Citizen.Wait(100)
    end
    coreLoaded = true
    while QBCore.Functions.GetPlayerData().job == nil do Citizen.Wait(100) end
    firstLogin()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    firstLogin()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
    firstLogin()
end)

function firstLogin()
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback("tgiann-mdtv2:ilk-data", function(players, items, playerName, bank)
        local firstData = {}
        firstData.name = playerName
        firstData.rank = PlayerData.job and PlayerData.job.label or "Polis"
        firstData.items = items or {}
        firstData.players = players
        firstData.bank = bank      
        firstData.lang = lang[langSetting]
        firstData.resourceName = GetCurrentResourceName()
        firstData.accounts = accounts or {}
        SendNUIMessage({type = 'ilk-bilgi', data = firstData})
    end)
end

RegisterNUICallback('sorgula', function(data, cb)
    QBCore.Functions.TriggerCallback("tgiann-mdtv2:sorgula", function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('photo', function(data, cb)
    QBCore.Functions.TriggerCallback("tgiann-mdtv2:photo", function(result)
        cb(result)
    end, data)
end)

RegisterNUICallback('cezakaydetclient', function(data)
    TriggerServerEvent("tgiann-mdtv2:ceza-kaydet", data.data)
end)

local olaylarDataLast = nil
local olaylarDataTime = 0
RegisterNUICallback('olaylardata', function(data, cb)
    if GetGameTimer() > olaylarDataTime or olaylarDataTime == 0 then
        olaylarDataTime = GetGameTimer() + 30000
        QBCore.Functions.TriggerCallback("tgiann-mdtv2:olaylardata", function(result)
            olaylarDataLast = result
            cb(result)
        end)
    else
        cb(olaylarDataLast)
    end
end)

local sabikaDataLast = nil
local sabikaDataTime = 0
RegisterNUICallback('sabikadata', function(data, cb)
    if GetGameTimer() > sabikaDataTime or sabikaDataTime == 0 then
        sabikaDataTime = GetGameTimer() + 30000
        QBCore.Functions.TriggerCallback("tgiann-mdtv2:sabikadata", function(result)
            sabikaDataLast = result
            cb(result)
        end, data.id)
    else
        cb(sabikaDataLast)
    end
end)

RegisterNUICallback('sabikasil', function(data, cb)
    TriggerServerEvent("tgiann-mdtv2:sabikasil", data.id)
end)

RegisterNUICallback('resim', function(data, cb)
    if data.url then
        TriggerServerEvent("tgiann-mdtv2:setavatar", data.url, data.id)
    else
        CreateMobilePhone(1)
        CellCamActivate(true, true)
        takePhoto = true
        if nuiFocus then openClose() end
        while takePhoto do
            Citizen.Wait(0)
            if IsControlJustPressed(1, 177) then
                DestroyMobilePhone()
                CellCamActivate(false, false)
                takePhoto = false
            elseif IsControlJustPressed(1, 176) then
                local url = screenShot()
                if url then
                    SendNUIMessage({type = 'user-avatar', url = url})
                    TriggerServerEvent("tgiann-mdtv2:setavatar", url, data.id)
                else
                    local text = lang[langSetting]["photoError"]
                    if Config.Notify == 'qb' then
                        QBCore.Functions.Notify(text, "error")
                    elseif Config.Notify == 'mythic' then
                        exports['mythic_notify']:SendAlert('error', text, 2500)
                    end
                end
                openClose()
                DestroyMobilePhone()
                CellCamActivate(false, false)
                takePhoto = false
            end
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(19)
            HideHudAndRadarThisFrame()
        end
    end
end)

local screenShotCD = 0
function screenShot()
    local callbackData = nil
    screenShotCD = 0
    exports['screenshot-basic']:requestScreenshotUpload(Config.Webhook, "files[]", function(data)
        callbackData = json.decode(data)
    end)
    while callbackData == nil do
        Citizen.Wait(1000)
        screenShotCD = screenShotCD + 1
        if screenShotCD > 10 then
            break
        end
    end
    if callbackData then
        if callbackData.message then
            print(lang[langSetting]["f8error"].." "..callbackData.message)
            return false
        else
            return callbackData.attachments[1].proxy_url
        end
    else
        print(lang[langSetting]["f8error"].." "..lang[langSetting]["photoError"])
        return lang[langSetting]["photoError"]
    end
end

function openClose()
    nuiFocus = not nuiFocus
    SetNuiFocus(nuiFocus, nuiFocus)
    if nuiFocus then
        startAnim()
        SendNUIMessage({type = 'open'})
    else
        stopAnim()
        SendNUIMessage({type = 'close'})
    end
end

function stopAnim()
    StopAnimTask(PlayerPedId(), "amb@code_human_in_bus_passenger_idles@female@tablet@idle_a", "idle_a", 8.0, -8.0, -1, 50, 0, false, false, false)
    DeleteObject(tab)
end

function startAnim()
    RequestAnimDict("amb@code_human_in_bus_passenger_idles@female@tablet@idle_a")
    while not HasAnimDictLoaded("amb@code_human_in_bus_passenger_idles@female@tablet@idle_a") do
        Citizen.Wait(0)
    end
    TaskPlayAnim(PlayerPedId(), "amb@code_human_in_bus_passenger_idles@female@tablet@idle_a", "idle_a", 8.0, -8.0, -1, 50, 0, false, false, false)
    tab = CreateObject(GetHashKey("prop_cs_tablet"), 0, 0, 0, true, true, true)
    AttachEntityToEntity(tab, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 28422), -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
end

RegisterNUICallback('aranma', function(data, cb)
    TriggerServerEvent("tgiann-mdtv2:aranma", data, true)
end)

RegisterNUICallback('aranmakaldir', function(data, cb)
    TriggerServerEvent("tgiann-mdtv2:aranma", data, false)
end)

RegisterNUICallback('arananlar', function(data, cb)
    QBCore.Functions.TriggerCallback("tgiann-mdtv2:arananlar", function(result)
        cb(result)
    end)
end)

RegisterNUICallback('ev', function(data, cb)
    QBCore.Functions.TriggerCallback("tgiann-mdtv2:ev", function(result)
        cb(result)
    end, data.id)
end)

RegisterNUICallback('olaysil', function(data, cb)
    TriggerServerEvent("tgiann-mdtv2:olaysil", data.id)
end)

-- *** DİNAMİK KOMUT SİSTEMİ ***

-- MDT açma komutu ve tuşu
RegisterCommand(Config.MDTCommand, function()
    if isAllowedJob() then
        openClose()
    end
end)
RegisterKeyMapping(Config.MDTCommand, lang[langSetting]["keyMappingHelp"], 'keyboard', Config.MDTKey)

-- Zoom ayar komutu ve tuşu
RegisterCommand(Config.ZoomCommand, function(source, args)
    if isAllowedJob() then
        if args[1] == nil then
            local text = lang[langSetting]["zoomSettingNilError"]
            if Config.Notify == 'qb' then
                QBCore.Functions.Notify(text, "error")
            elseif Config.Notify == 'mythic' then
                exports['mythic_notify']:SendAlert('error', text, 2500)
            end
            return
        end
        if tonumber(args[1]) < 50 then
            local text = lang[langSetting]["zoomSettingMinError"]
            if Config.Notify == 'qb' then
                QBCore.Functions.Notify(text, "error")
            elseif Config.Notify == 'mythic' then
                exports['mythic_notify']:SendAlert('error', text, 2500)
            end
        elseif tonumber(args[1]) > 100 then
            local text = lang[langSetting]["zoomSettingMaxError"]
            if Config.Notify == 'qb' then
                QBCore.Functions.Notify(text, "error")
            elseif Config.Notify == 'mythic' then
                exports['mythic_notify']:SendAlert('error', text, 2500)
            end
        else
            local text = lang[langSetting]["zoomSettingConfirm"]
            if Config.Notify == 'qb' then
                QBCore.Functions.Notify(text, "success")
            elseif Config.Notify == 'mythic' then
                exports['mythic_notify']:SendAlert('success', text, 2500)
            end
            SendNUIMessage({type = 'zoom', val = args[1]})
        end
    else
        local text = lang[langSetting]["zoomSettingNotPolice"]
        if Config.Notify == 'qb' then
            QBCore.Functions.Notify(text, "error")
        elseif Config.Notify == 'mythic' then
            exports['mythic_notify']:SendAlert('error', text, 2500)
        end
    end
end)
if Config.ZoomKey and Config.ZoomKey ~= '' then
    RegisterKeyMapping(Config.ZoomCommand, lang[langSetting]["zoomSetting"], 'keyboard', Config.ZoomKey)
end

RegisterNetEvent("tgiann-mdtv2:open")
AddEventHandler("tgiann-mdtv2:open", function()
    if isAllowedJob() then
        openClose()
    end
end)

RegisterNUICallback('kapat', function(data, cb)
    if nuiFocus then openClose() end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() == resourceName) then
        if nuiFocus then openClose() end
    end
end)

RegisterNUICallback('olayara', function(data, cb)
    QBCore.Functions.TriggerCallback("tgiann-mdtv2:olayara", function(result)
        cb(result)
    end, data.id)
end)

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/'..Config.ZoomCommand, lang[langSetting]["zoomSetting"], {{ name=lang[langSetting]["zoomSettingName"], help=lang[langSetting]["zoomSettingHelp"]}})
end)
