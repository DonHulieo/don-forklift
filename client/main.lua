local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}

local pallet, pilot, pickup = nil, nil, nil
local response, cancelled, jobFinished = false, false, false

-------------------------------- FUNCTIONS --------------------------------

local function reqAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end
    end
end

local function reqMod(model)
    if not HasModelLoaded(model) then
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(1)
        end
    end
end

local function DrawText3Ds(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local pX, pY, pZ = table.unpack(GetGameplayCamCoords())
    local scale = 0.35
    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 100)
    end
end

local function createBlip(coords, text, sprite, color, scale)
    if not coords then return end
    if Config.UniqueNames then
        text = text
    else
        text = Config.BlipName
    end
    local blip = AddBlipForCoord(coords)
    SetBlipSprite(blip, sprite)
    SetBlipCategory(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, true)
    AddTextEntry(text, text)
    BeginTextCommandSetBlipName(text)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function deleteBlipForCoord(sprite, coords)
    local blip = GetFirstBlipInfoId(sprite)
    local blipCoords = GetBlipInfoIdCoord(blip)
    if #(vector3(coords.x, coords.y, coords.z) - vector3(blipCoords.x, blipCoords.y, blipCoords.z)) < 1.0 then
        RemoveBlip(blip)
    end
end

local function deleteBlipForEntity(sprite, entity)
    local blip = GetFirstBlipInfoId(sprite)
    local blipEntity = GetBlipInfoIdEntityIndex(blip)
    if blipEntity == entity then
        RemoveBlip(blip)
    end
end

local function createPalletBlip(entity)
    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, 478)
    SetBlipCategory(blip, 2)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 70)
    SetBlipAsShortRange(blip, true)
    AddTextEntry('Pallet', 'Pallet')
    BeginTextCommandSetBlipName('Pallet')
    EndTextCommandSetBlipName(blip)
    return blip
end

local function createPickupBlip(entity)
    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, 67)
    SetBlipCategory(blip, 2)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, true)
    AddTextEntry('Drop Off', 'Drop Off')
    BeginTextCommandSetBlipName('Drop Off')
    EndTextCommandSetBlipName(blip)
    return blip
end

local function spawnPallet(location)
    local rand = math.random(1, #Config.Locations[location].pallets)
    local coords = Config.Locations[location].pallets[rand]
    local model = Config.PalletModel
    reqMod(model)
    pallet = CreateObject(model, coords.x, coords.y, coords.z-0.95, true, true, true)
    SetEntityAsMissionEntity(pallet)
    SetEntityCanBeDamaged(pallet, true)
    SetEntityDynamic(pallet, true)
    SetEntityCollision(pallet, true, true)
    createPalletBlip(pallet)
    return pallet
end

local function isEntityDamaged(entity)
    local health = GetEntityHealth(entity)
    if health < 1000 then
        return true, health
    else
        return false
    end
end

local loaded = false
local function listen4Load(location, ped, veh)
    local loaded = true
    local coords = Config.Locations[location].delivery.coords
    CreateThread(function()
        while loaded do
            Wait(500)
            TaskVehicleDriveWander(ped, veh, 50.0, 263100)
            local vehCoords = GetEntityCoords(veh)
            local dist = #(coords - vehCoords)
            if dist < 200 then
                Citizen.Wait(15000)
            else
                DeleteEntity(veh)
                DeleteEntity(ped)
            end
        end
    end)
end

local function spawnPickupVeh(location)
    local coords = Config.Locations[location].pickup.coords
    local deliv = Config.Locations[location].delivery.coords
    local model = Config.Locations[location].pickup.model
    local pedMod = Config.Locations[location].pickup.ped
    local driving = false
    local doorOpened = false
    reqMod(model)
    ClearAreaOfVehicles(coords, 15.0, false, false, false, false,  false)
    pickup = CreateVehicle(model, coords, Config.Locations[location].pickup.heading, true, true)
    createPickupBlip(entity)
    SetEntityAsMissionEntity(pickup)
    SetVehicleDoorsLocked(pickup, 2)
    SetVehicleDoorsLockedForAllPlayers(pickup, true)
    reqMod(pedMod)
    pilot = CreatePedInsideVehicle(pickup, 1, pedMod, -1, true, true)
    SetBlockingOfNonTemporaryEvents(pilot, true)
    SetEntityInvincible(pilot, true)
    TaskVehiclePark(pilot, pickup, deliv, Config.Locations[location].delivery.heading, 1, 20.0, false)
    SetDriveTaskDrivingStyle(ped, 263100)
    SetPedKeepTask(pilot, true)
    driving = true
    Citizen.Wait(500)
    while driving do
        Citizen.Wait(1000)
        local eng = GetIsVehicleEngineRunning(pickup)
        if eng then
            Citizen.Wait(500)
        else
            driving = false
        end
    end
    QBCore.Functions.Notify('The driver has arrived...')
    SetVehicleDoorOpen(pickup, 5, false, false)
    doorOpened = true
    local doorCoords = GetOffsetFromEntityInWorldCoords(pickup, 0.0, -6.0, -1.0)
    while doorOpened do
        Citizen.Wait(2)
        DrawMarker(1, doorCoords, 0, 0, 0, 0, 0, 0, 1.7, 1.7, 1.7, 135, 31, 35, 150, 1, 0, 0, 0)
        local palletCoords = GetEntityCoords(pallet)
        local dist = #(doorCoords - palletCoords)
        if dist <= 2.0 then
            local isDamaged, health = isEntityDamaged(pallet)
            SetVehicleDoorShut(pickup, 5, false)
            if isDamaged then
                TriggerEvent('don-forklift:client:finishDelivery', isDamaged, health)
            else
                TriggerEvent('don-forklift:client:finishDelivery', isDamaged)
            end
            DeleteEntity(pallet)
            deleteBlipForEntity(478, pallet)
            deleteBlipForEntity(67, pickup)
            listen4Load(location, pilot, pickup)
            doorOpened = false
        end
        if cancelled then
            SetVehicleDoorShut(pickup, 5, false)
            listen4Load(location, pilot, pickup)
            return 
        end
    end
end

local function getClosestWarehouse()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local current = nil
    local dist = nil
    for id, warehouse in pairs(Config.Locations) do
        if current then
            if #(coords - warehouse.jobStart) < dist then
                current = id
                dist = #(coords - warehouse.jobStart)
            end
        else
            dist = #(coords - warehouse.jobStart)
            current = id
        end
    end
    return current, dist
end

local function isCurrentUserUsingWarehouse()
    local ped = PlayerPedId()
    local current, dist = getClosestWarehouse()
    if Config.Locations[current].user == ped then return true end
    return false
end

local function lendVehicle(location)
    local ped = PlayerPedId()
    local coords = Config.Locations[location].garage.coords
    local heading = Config.Locations[location].garage.heading
    local model = Config.Locations[location].garage.model
    local isUser = isCurrentUserUsingWarehouse()
    if isUser then
        if Config.RequiresJob then 
            if not PlayerData.job then 
                QBCore.Functions.Notify("You are not a "..Config.Job.."...", "error") 
                return 
            end
        end
        if not IsPedInAnyVehicle(ped, false)  then
            QBCore.Functions.SpawnVehicle(model, function(vehicle)
                SetVehicleNumberPlateText(vehicle, "FORK"..tostring(math.random(1000, 9999)))
                SetEntityHeading(vehicle, heading)
                exports['LegacyFuel']:SetFuel(vehicle, 100.0)
                TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
                SetEntityAsMissionEntity(vehicle, true, true)
                TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(vehicle))
                SetVehicleEngineOn(vehicle, true, true)
                QBCore.Functions.Notify("Forklift retrieved from garage...", "success")
                vehicleOut = true
            end, coords, true)
        else
            local veh = GetVehiclePedIsIn(ped, false)
            local plate = GetVehicleNumberPlateText(veh)
            if plate:sub(1, 4) == "FORK" then
                QBCore.Functions.DeleteVehicle(veh)
                QBCore.Functions.Notify("Forklift returned to garage...", "success")
                vehicleOut = false
            else
                QBCore.Functions.Notify("You are not in a forklift...", "error")
            end
        end
    end
end

-------------------------------- HANDLERS --------------------------------

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    for id, warehouse in pairs(Config.Locations) do
        if Config.RequiresJob then
            if PlayerData.job.name == Config.Job and Config.Blips then
                createBlip(warehouse.jobStart, warehouse.blipSettings.label, warehouse.blipSettings.sprite, warehouse.blipSettings.color, warehouse.blipSettings.scale)
            end
        else
            if Config.Blips then
                createBlip(warehouse.jobStart, warehouse.blipSettings.label, warehouse.blipSettings.sprite, warehouse.blipSettings.color, warehouse.blipSettings.scale)
            end
        end
    end
    if Config.UseTarget then
        TriggerEvent('don-forklift:client:createTarget')
        TriggerEvent('don-forklift:client:createGarage')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload')
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    if Config.Blips then
        for id, warehouse in pairs(Config.Locations) do
            deleteBlipForCoord(warehouse.blipSettings.sprite, warehouse.jobStart)
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    for id, warehouse in pairs(Config.Locations) do
        if Config.RequiresJob then
            if JobInfo.name == Config.Job then
                PlayerData.job = JobInfo 
                if Config.Blips then 
                    createBlip(warehouse.jobStart, warehouse.blipSettings.label, warehouse.blipSettings.sprite, warehouse.blipSettings.color, warehouse.blipSettings.scale)
                end
            else
                deleteBlipForCoord(warehouse.blipSettings.sprite, warehouse.jobStart)
            end
        else
            if Config.Blips then 
                createBlip(warehouse.jobStart, warehouse.blipSettings.label, warehouse.blipSettings.sprite, warehouse.blipSettings.color, warehouse.blipSettings.scale)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for id, warehouse in pairs(Config.Locations) do
            TriggerServerEvent("don-forklift:server:unreserve", id)
            if Config.ShowBlips then
                deleteBlipForCoord(warehouse.blipSettings.sprite, warehouse.jobStart)
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        for id, warehouse in pairs(Config.Locations) do
            TriggerServerEvent('don-forklift:server:unreserve', id)
            if (not Config.RequiresJob and Config.Blips) then
                createBlip(warehouse.jobStart, warehouse.blipSettings.label, warehouse.blipSettings.sprite, warehouse.blipSettings.color, warehouse.blipSettings.scale)
            end
        end
        if Config.UseTarget then
            TriggerEvent('don-forklift:client:createTarget')
            TriggerEvent('don-forklift:client:createGarage')
        end
    end
end)

RegisterNetEvent('don-forklift:client:reserve')
AddEventHandler('don-forklift:client:reserve', function(k, ped)
    if k then
        if Config.Locations[k] then
            if not Config.Locations[k].user and not Config.Locations[k].inUse then
                Config.Locations[k].inUse = true
                Config.Locations[k].user = ped
            end
        end
    end
end)

RegisterNetEvent('don-forklift:client:unreserve')
AddEventHandler('don-forklift:client:unreserve', function(k)
    if k then
        Config.Locations[k].inUse = false
        Config.Locations[k].user = nil
    end
end)

-------------------------------- EVENTS --------------------------------

RegisterNetEvent('don-forklift:client:startJob', function(location)
    local ped = PlayerPedId()
    local inUse = Config.Locations[location].inUse
    if not inUse then
        if response then QBCore.Functions.Notify('Complete the previous order!', 'error') return end
        if Config.RequiresJob then 
            if not PlayerData.job then 
                QBCore.Functions.Notify("You are not a "..Config.Job.."...", "error") 
                return 
            end
        end
        TriggerServerEvent('don-forklift:server:reserve', location, ped)
        cancelled = false
        spawnPallet(location)
        response = true
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, false)
        QBCore.Functions.Notify('Delivery is marked...', 'success', 2500)
        TriggerServerEvent('don-forklift:server:reserve', location)
        Citizen.Wait(1000)
        ClearPedTasks(ped)
        spawnPickupVeh(location)
    else
        QBCore.Functions.Notify('Someone is already doing this order!', 'error')
    end
end)

RegisterNetEvent('don-forklift:client:finishDelivery', function(isDamaged, health)
    jobFinished = true
    response = false 
    QBCore.Functions.Notify('Package loaded..', 'success', 1500)
    if isDamaged then
        Citizen.Wait(2500)
        if health < 1000 and health > 750 then
            QBCore.Functions.Notify('The product is almost pristine', 'success', 2000)
            TriggerServerEvent('don-forklift:server:payPlayer', Config.PayScales.bonus3)
        elseif health < 750 and health > 500 then
            QBCore.Functions.Notify('The product is damaged, but still usable..', 'error', 2000)
            TriggerServerEvent('don-forklift:server:payPlayer', Config.PayScales.bonus2)
        elseif health < 500 and health > 250 then
            QBCore.Functions.Notify('The products pretty banged up..', 'error', 2000)
            TriggerServerEvent('don-forklift:server:payPlayer', Config.PayScales.bonus)
        elseif health < 250 then
            QBCore.Functions.Notify('The product is badly damaged, you will not be paid for this delivery..', 'error', 3500)
        end
    else
        QBCore.Functions.Notify('The product is pristine', 'success')
        TriggerServerEvent('don-forklift:server:payPlayer', Config.PayScales.bonus3+Config.PayScales.bonus2+Config.PayScales.bonus)
    end
end)

RegisterNetEvent('don-forklift:client:cancelJob', function(location)
    local ped = PlayerPedId()
    if location then
        if Config.Locations[location].inUse and Config.Locations[location].user == ped then
            response = false
            cancelled = true
            QBCore.Functions.Notify('You have cancelled the order', 'error')
            TriggerServerEvent('don-forklift:server:unreserve', location)
        else
            QBCore.Functions.Notify('You are not doing this order', 'error')
        end
    end
end)

RegisterNetEvent('don-forklift:client:spawnVeh', function(location)
    lendVehicle(location)
end)

RegisterNetEvent('don-forklift:client:createTarget', function()
    if Config.UseTarget then
        for k, v in pairs(Config.Locations) do
            exports['qb-target']:AddBoxZone('warehouse' ..k, v.jobStart, v.boxzone.length, v.boxzone.width, {
                name = 'warehouse' ..k,
                heading = v.boxzone.heading,
                debugPoly = false,
                minZ= v.jobStart.z-1,
                maxZ= v.jobStart.z+1,
                }, {
                    options = {
                        {
                        type = 'client',
                        icon = 'fas fa-truck-fast',
                        label = 'Take Order',
                        action = function ()
                                TriggerEvent('don-forklift:client:startJob', k)   
                            end,
                        canInteract = function() -- Checks if the gun range is in use
                            if v.inUse and not jobFinished then return false end
                                return true
                            end,
                        },
                        {
                        type = "client",
                        icon = 'fas fa-sign-out-alt',
                        label = 'Cancel Order',
                        action = function ()
                                TriggerEvent('don-forklift:client:cancelJob', k)   
                            end,
                        canInteract = function() -- Checks if the gun range is in use
                            if not isCurrentUserUsingWarehouse() then return false end
                                return true
                            end,
                        },
                    },
                    distance = 2.0, -- This is the distance for you to be at for the target to turn blue, this is in GTA units and has to be a float value
                })
            Citizen.Wait(3)
        end
    end
end)

RegisterNetEvent('don-forklift:client:createGarage', function()
    if Config.UseTarget then
        for k, v in pairs(Config.Locations) do
            exports['qb-target']:AddBoxZone('garage' ..k, v.garage.zone.coords, v.garage.zone.length, v.garage.zone.width, {
                name = 'garage' ..k,
                heading = v.garage.zone.heading,
                debugPoly = false,
                minZ= v.garage.zone.coords.z-1,
                maxZ= v.garage.zone.coords.z+1,
                }, {
                    options = {
                        {
                        type = 'client',
                        icon = 'fas fa-forklift',
                        label = 'Take Forklift',
                        action = function()
                            lendVehicle(k)
                        end,
                        canInteract = function() -- Checks if the gun range is in use
                            if vehicleOut or not v.inUse then return false end
                                return true
                            end,
                        },
                        {
                        type = "client",
                        icon = 'fas fa-forklift',
                        label = 'Return Forklift',
                        action = function()
                            lendVehicle(k)
                        end,
                        canInteract = function() -- Checks if the gun range is in use
                            if not vehicleOut or not v.inUse then return false end
                                return true
                            end,
                        },
                    },
                    distance = 2.0, -- This is the distance for you to be at for the target to turn blue, this is in GTA units and has to be a float value
                })
            Citizen.Wait(3)
        end
    end
end)

-------------------------------- THREADS --------------------------------

Citizen.CreateThread(function()
    while not Config.UseTarget do 
        Citizen.Wait(3)
        for k, v in pairs(Config.Locations) do
            local sleep = 2000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - v.jobStart)
            if dist < 2.0 and not v.inUse then
                DrawText3Ds(v.jobStart.x, v.jobStart.y, v.jobStart.z, '[~g~E~w~] - Take Order')
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('don-forklift:client:startJob', k)
                end
            elseif dist < 2.0 and v.inUse then
                DrawText3Ds(v.jobStart.x, v.jobStart.y, v.jobStart.z, '[~r~E~w~] - Cancel Order')
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('don-forklift:client:cancelJob', k)
                end
            else
                Citizen.Wait(sleep)
            end
        end
    end
end)

Citizen.CreateThread(function()
    while not Config.UseTarget do
        Citizen.Wait(3)
        for k, v in pairs(Config.Locations) do
            local sleep = 2000
            local ped = PlayerPedId()
            local isUser = isCurrentUserUsingWarehouse()
            local coords = GetEntityCoords(ped)
            local dist = #(coords - v.garage.coords)
            if isUser then
                if dist < 2.0 and not vehicleOut then
                    DrawText3Ds(v.garage.coords.x, v.garage.coords.y, v.garage.coords.z, '[~g~E~w~] - Take Forklift')
                    if IsControlJustReleased(0, 38) then
                        lendVehicle(k)
                    end
                elseif dist < 2.0 and vehicleOut then
                    DrawText3Ds(v.garage.coords.x, v.garage.coords.y, v.garage.coords.z, '[~r~E~w~] - Return Forklift')
                    if IsControlJustReleased(0, 38) then
                        lendVehicle(k)
                    end
                else
                    Citizen.Wait(sleep)
                end
            end
        end
    end
end)