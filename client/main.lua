local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local Cancelled, response, EngineOn, deliveryTimer = false, false, false, false
local VehicleTaken, CarLivery, DeliveryTime, OwnsHangar = 0, 0, 0, 0
local bonus1 = 12
local bonus2 = 10
local bonus3 = 8

-------------------- EVENTS --------------------

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData.job = QBCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function()
    PlayerData.job = QBCore.Functions.GetPlayerData().job
end)
  
RegisterNetEvent('don-forklift:deliverypickup')
AddEventHandler('don-forklift:deliverypickup',function(a)
    local DeliveryCarSpawn = {x = 1113.12, y = -3334.41, z = 5.92} 
    local DeliveryCoords = {x = 1229.2, y = -3222.6, z = 5.8} 

    Cancelled = false

    if a == '1'then
        if response == true then
            QBCore.Functions.Notify('Complete the previous order!', 'error')
            return
        end

        local b = math.random(1, 5)

            if b == 1 then
                CarLivery = 3
                SelectPallet('1st')
            elseif b == 2 then
                CarLivery = 4
                SelectPallet('2nd')
            elseif b == 3 then
                CarLivery = 6
                SelectPallet('3rd')
            elseif b == 4 then
                CarLivery = 2
                SelectPallet('4th')
            elseif b == 5 then
                CarLivery = 1
                SelectPallet('5th')
            end
            
        RequestModel(GetHashKey('benson'))
            while not HasModelLoaded(GetHashKey('benson'))do
                Citizen.Wait(0)
            end

        ClearAreaOfVehicles(Config.Forklift['DeliverySpawn'].Pos.x, Config.Forklift['DeliverySpawn'].Pos.y, Config.Forklift['DeliverySpawn'].Pos.z, 15.0, false, false, false, false,  false)
            transport = CreateVehicle(GetHashKey('benson'), Config.Forklift['DeliverySpawn'].Pos.x, Config.Forklift['DeliverySpawn'].Pos.y, Config.Forklift['DeliverySpawn'].Pos.z, -2.436, 996.786, 25.1887, true, true)
            SetEntityAsMissionEntity(transport)
            SetEntityHeading(transport, 266.6)
            SetVehicleDoorsLocked(transport, 2)
            SetVehicleDoorsLockedForAllPlayers(transport, true)
            SetVehicleExtra(transport, 1, true)
            SetVehicleExtra(transport, 2, true)
            SetVehicleExtra(transport, 3, true)
            SetVehicleExtra(transport, 4, true)
            SetVehicleExtra(transport, 5, true)
            SetVehicleExtra(transport, 6, true)
            SetVehicleExtra(transport, 7, true)
            SetVehicleExtra(transport, CarLivery, false)

        RequestModel("s_m_m_security_01")
            while not HasModelLoaded("s_m_m_security_01")do
                Wait(10)
            end

        pilot = CreatePedInsideVehicle(transport, 1, "s_m_m_security_01", -1, true, true)
        SetBlockingOfNonTemporaryEvents(pilot, true)
        SetEntityInvincible(pilot, true)
        TaskVehiclePark(pilot, transport, Config.Forklift['DeliveryLoc'].Pos.x, Config.Forklift['DeliveryLoc'].Pos.y, Config.Forklift['DeliveryLoc'].Pos.z, 269.37, 1, 1.0, false)
        SetDriveTaskDrivingStyle(pilot, 263100)
        SetPedKeepTask(pilot, true)
        response = true
        EngineOn = true
        Citizen.Wait(900)

            while EngineOn do
                Citizen.Wait(1000)
                local c = GetIsVehicleEngineRunning(transport)
                if c == 1 then
                    Citizen.Wait(200)
                else
                    EngineOn = false
                end
            end

        QBCore.Functions.Notify('The driver has arrived...')
        SetVehicleDoorOpen(transport, 5, false, false)
        backOpened = true

            local d, e, f = table.unpack(GetOffsetFromEntityInWorldCoords(transport, 0.0, -6.0, -1.0))
        
            while backOpened do
                Citizen.Wait(2)
                DrawMarker(1, d, e, f, 0, 0, 0, 0, 0, 0, 1.7, 1.7, 1.7, 135, 31, 35, 150, 1, 0, 0, 0)
                local g = GetEntityCoords(package)
                local h = Vdist(d, e, f, g.x, g.y, g.z)
                if h <= 2.0 then
                    SetVehicleDoorShut(transport, 5, false)
                    DeleteEntity(package)
                    backOpened = false
                end
            end

            if Cancelled == true then
                return
            end

        QBCore.Functions.Notify('Package loaded...', 'success')
        Citizen.Wait(2500)
        QBCore.Functions.Notify('Package loaded in '..DeliveryTime..' seconds.')

            if DeliveryTime < 60 then
                QBCore.Functions.Notify('Bonus $'..bonus1 ..' for fast delivery', 'success')
                TriggerServerEvent("don-forklift:executionmission", bonus1)
                Citizen.Wait(200)
            elseif DeliveryTime >= 60 and DeliveryTime <= 120 then
                QBCore.Functions.Notify('Bonus $'..bonus2 ..' for fast delivery', 'success')
                TriggerServerEvent("don-forklift:executionmission", bonus2)
                Citizen.Wait(200)
            elseif DeliveryTime >= 120 and DeliveryTime <= 180 then
                QBCore.Functions.Notify('Bonus $'..bonus3 ..' for fast delivery', 'success')
                TriggerServerEvent("don-forklift:executionmission", bonus3)
                Citizen.Wait(200)
            elseif DeliveryTime > 180 then
                QBCore.Functions.Notify('No bonus', 'error')
            end

        DeliveryTime = 0
        deliveryTimer = false
        TriggerServerEvent("don-forklift:executionmission", 'bonus')
        TaskVehicleDriveWander(pilot, transport, 50.0, 263100)
        Citizen.Wait(15000)
        DeleteEntity(transport)
        DeleteEntity(pilot)
        response = 0
    end
end)

RegisterNetEvent('don-forklift:ownHangar')
AddEventHandler('don-forklift:ownHangar', function()
    OwnsHangar = 1
end)

RegisterNetEvent('don-forklift:leftHangar')
AddEventHandler('don-forklift:leftHangar', function()
    OwnsHangar = 0
end)

-------------------- FUNCTIONS --------------------

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())

    SetTextScale(0.37, 0.37)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)

    local factor = (string.len(text)) / 370

    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 33, 33, 33, 133)
end

function SelectPallet(a)
    DeliveryTime = 0
    deliveryTimer = true
    if a == '1st'then 
        package = CreateObject(GetHashKey('prop_boxpile_06a'), Config.Pallet['1'].Pos.x, Config.Pallet['1'].Pos.y, Config.Pallet['1'].Pos.z-0.95, true, true, true)
        SetEntityAsMissionEntity(package)
        SetEntityDynamic(package, true)
        FreezeEntityPosition(package, false)
    elseif a == '2nd'then 
        package = CreateObject(GetHashKey('prop_boxpile_06a'), Config.Pallet['2'].Pos.x, Config.Pallet['2'].Pos.y, Config.Pallet['2'].Pos.z-0.95, true, true, true)
        SetEntityAsMissionEntity(package)
        SetEntityDynamic(package, true)
        FreezeEntityPosition(package, false)
    elseif a == '3rd'then 
        package = CreateObject(GetHashKey('prop_boxpile_06a'), Config.Pallet['3'].Pos.x, Config.Pallet['3'].Pos.y, Config.Pallet['3'].Pos.z-0.95, true, true, true)
        SetEntityAsMissionEntity(package)
        SetEntityDynamic(package, true)
        FreezeEntityPosition(package, false)
    elseif a == '4th'then 
        package = CreateObject(GetHashKey('prop_boxpile_06a'), Config.Pallet['4'].Pos.x, Config.Pallet['4'].Pos.y, Config.Pallet['4'].Pos.z-0.95, true, true, true)
        SetEntityAsMissionEntity(package)
        SetEntityDynamic(package, true)
        FreezeEntityPosition(package, false)
    elseif a == '5th'then 
        package = CreateObject(GetHashKey('prop_boxpile_06a'), Config.Pallet['5'].Pos.x, Config.Pallet['5'].Pos.y, Config.Pallet['5'].Pos.z-0.95, true, true, true)
        SetEntityAsMissionEntity(package)
        SetEntityDynamic(package, true)
        FreezeEntityPosition(package, false)
    end 
end

function LendVehicle(a)
    if OwnsHangar == 1 then
        if VehicleTaken == 0 then
            QBCore.Functions.SpawnVehicle(Config.Forklift['Forklift'].Model, function(vehicle)
                SetVehicleNumberPlateText(vehicle, "ECLW"..tostring(math.random(1000, 9999)))
                SetEntityHeading(vehicle, 90.0)
                exports['LegacyFuel']:SetFuel(vehicle, 100.0)
                TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
                SetEntityAsMissionEntity(vehicle, true, true)
                TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(vehicle))
                SetVehicleEngineOn(vehicle, true, true)
                VehicleTaken = 1
                QBCore.Functions.Notify("Your vehicle has arrived", "success")
            end, Config.Forklift['Forklift'].Pos, true)
        elseif IsPedInAnyVehicle(PlayerPedId(), false) then
            if GetPedInVehicleSeat(GetVehiclePedIsIn(PlayerPedId()), -1) == PlayerPedId() then
                DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
                QBCore.Functions.Notify('Forklift returned to the garage...', 'success')
                Citizen.Wait(500)
            else
                QBCore.Functions.Notify('You must be the driver to do this...', 'error')
            end
        end
        Citizen.Wait(1500)
    end
end

-------------------- THREADS -------------------- 

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        if deliveryTimer == true then
            DeliveryTime = DeliveryTime + 1
            if DeliveryTime > 240 then
                Cancelled = true
                response = 0
                DeliveryTime = 0
                deliveryTimer = false
                backOpened = false
                EngineOn = false
                DeleteEntity(transport)
                DeleteEntity(pilot)
                DeleteEntity(package)
                DeleteEntity(vehicle)
                QBCore.Functions.Notify('The order was cancelled...', 'error')
            end
        else
            Citizen.Wait(2000)
        end
    end
end)	
          
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(4)
        
        if DoesEntityExist(package) then
            local packCoord = GetEntityCoords(package)
            DrawMarker(0, packCoord.x, packCoord.y, packCoord.z+2.1, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 135, 31, 35, 150, 1, 0, 0, 0)
        else
            Citizen.Wait(2500)
        end
    end
end)  
  
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3)
        
        local ped = PlayerPedId()
        local pos = GetEntityCoords(PlayerPedId(), true)
        
        if PlayerData.job ~= nil and PlayerData.job.name == 'logistics' then
            if #(pos - vector3(Config.Forklift['Forklift'].Pos.x, Config.Forklift['Forklift'].Pos.y, Config.Forklift['Forklift'].Pos.z)) <= 25.0 or #(pos - vector3(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z)) <= 25.0 then
                DrawMarker(27, Config.Forklift['Forklift'].Pos.x, Config.Forklift['Forklift'].Pos.y, Config.Forklift['Forklift'].Pos.z-1, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 143, 235, 77, 100, false, true, 2, false, false, false, false)
                DrawMarker(27, Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z-1, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.0, 1.0, 1.0, 143, 235, 77, 100, false, true, 2, false, false, false, false)
            else
                Citizen.Wait(1500)
            end
            
            if #(pos - vector3(Config.Forklift['Forklift'].Pos.x, Config.Forklift['Forklift'].Pos.y, Config.Forklift['Forklift'].Pos.z)) <= 1.0 then
                DrawText3D(Config.Forklift['Forklift'].Pos.x, Config.Forklift['Forklift'].Pos.y, Config.Forklift['Forklift'].Pos.z, "[E] Forklift")
                if IsControlJustPressed(0, Keys['E']) then 
                    LendVehicle('1')
                    Citizen.Wait(500)
                end                  
            end

            if #(pos - vector3(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z)) <= 1.0 and OwnsHangar == 1 then
                DrawText3D(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z, "[E] Take order")
                DrawText3D(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z-0.13, "[G] Go off Duty")
                if IsControlJustPressed(0, Keys['G']) then
                    TriggerServerEvent("don-forklift:leaveHangar", '1')
                    TriggerServerEvent("QBCore:ToggleDuty")
                    OwnsHangar = 0
                    Citizen.Wait(500)
                    if response == true then
                        Cancelled = true
                        response = 0
                        DeliveryTime = 0
                        deliveryTimer = false
                        backOpened = false
                        EngineOn = false
                        DeleteEntity(transport)
                        DeleteEntity(pilot)
                        DeleteEntity(package)
                    end 
                elseif IsControlJustPressed(0, Keys['E']) then 
                    TriggerEvent('don-forklift:deliverypickup','1')
                    TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_CLIPBOARD", 0, false)
                    Citizen.Wait(2000)
                    ClearPedTasks(PlayerPedId())
                    QBCore.Functions.Notify('Delivery is marked...')
                end
            end

            if #(pos - vector3(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z)) <= 1.0 and OwnsHangar == 0 then
                DrawText3D(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z, "[G] Go on Duty")
                if IsControlJustPressed(0, Keys['G']) then 
                    TriggerServerEvent("don-forklift:takeoverHangar", '1')
                    TriggerServerEvent("QBCore:ToggleDuty")
                    Citizen.Wait(500)
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do 
        Citizen.Wait(1500)

        local pos = GetEntityCoords(PlayerPedId(), true)

        if OwnsHangar == 1 then 
            if #(pos - vector3(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z)) >= 205.0 then 
                QBCore.Functions.Notify('Too far away from the warehouse...', 'error')
                TriggerServerEvent("don-forklift:toofar")
                TriggerServerEvent("QBCore:ToggleDuty")
                OwnsHangar = 0
                Citizen.Wait(1500)
            else 
                Citizen.Wait(3500)
            end 
        end 
    end 
end)