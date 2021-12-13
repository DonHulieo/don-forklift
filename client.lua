local QBCore = exports['qb-core']:GetCoreObject()
--------------------------------------------------------
local PlayerData = {}
local PalletSelected = false
local PalletPoint
local Cancelled = false
local Response = false
local EngineOn = false
local DeliveryCar = 0
local DeliveryTime = 0
local deliveryTimer = false
local OwnsHangar = 0
local bonus1 = 12
local bonus2 = 10
local bonus3 = 8

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData.job = QBCore.Functions.GetPlayerData().job
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function()
    PlayerData.job = QBCore.Functions.GetPlayerData().job
end)

function PalletSelect()
    DeliveryTime = 0
    deliveryTimer = true
	PalletPoint = Randomize(Config.Forklift['Pallets'])
	
	PalletBlip = AddBlipForCoord(PalletPoint.x, PalletPoint.y, PalletPoint.z)
    package = CreateObject(GetHashKey('prop_boxpile_06a'),PalletPoint.x, PalletPoint.y, PalletPoint.z-0.95,true,true,true)
	SetBlipSprite (PalletBlip, 478)
	SetBlipDisplay(PalletBlip, 4)
	SetBlipScale  (PalletBlip, 0.8)
	SetBlipColour (PalletBlip, 0)
	SetBlipAsShortRange(PalletBlip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString('Pallet')
	EndTextCommandSetBlipName(PalletBlip)
    PalletSelected = true
end
  
RegisterNetEvent('anzdelivery:GetDelivery')
AddEventHandler('anzdelivery:GetDelivery',function()
    DeliveryCarSpawn = (Config.Forklift['PickUpCar'])
    DeliveryCoords = (Config.Forklift['PickUpPoint'])
    
    Cancelled = false
    if PalletSelect == true then
        if response == true then
            QBCore.Functions.Notify('Complete the previous order!', 'error')
            return
        end
        RequestModel(GetHashKey('benson'))
        while not HasModelLoaded(GetHashKey('benson'))do
            Citizen.Wait(0)end
        ClearAreaOfVehicles(DeliveryCarSpawn.x,DeliveryCarSpawn.y,DeliveryCarSpawn.z,15.0,false,false,false,false,false)
        QBCore.Functions.SpawnVehicle(Config.Courier['PickUpCar'].Model, function(transport)
        SetEntityAsMissionEntity(transport)
        SetEntityHeading(transport,266.6)
        SetVehicleDoorsLocked(transport,2)
        SetVehicleDoorsLockedForAllPlayers(transport,true)
        SetVehicleExtra(transport,1,true)
        SetVehicleExtra(transport,2,true)
        SetVehicleExtra(transport,3,true)
        SetVehicleExtra(transport,4,true)
        SetVehicleExtra(transport,5,true)
        SetVehicleExtra(transport,6,true)
        SetVehicleExtra(transport,7,true)
        RequestModel("s_m_m_security_01")
        while not HasModelLoaded("s_m_m_security_01")do
            Wait(10)end
        pilot = CreatePedInsideVehicle(transport,1,"s_m_m_security_01",-1,true,true)
        SetBlockingOfNonTemporaryEvents(pilot,true)
        SetEntityInvincible(pilot,true)
        TaskVehiclePark(pilot,transport,DeliveryCoords.x,DeliveryCoords.y,DeliveryCoords.z,266.0,1,1.0,false)
        SetDriveTaskDrivingStyle(pilot,263100)
        SetPedKeepTask(pilot,true)
        QBCore.Functions.Notify('The driver is enroute...')
        Response = true
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
        SetVehicleDoorOpen(transport,5,false,false)
        backOpened = true
        local d,e,f = table.unpack(GetOffsetFromEntityInWorldCoords(transport,0.0,-6.0,-1.0))
        while backOpened do
            Citizen.Wait(2)
            DrawMarker(1,d,e,f,0,0,0,0,0,0,1.7,1.7,1.7,135,31,35,150,1,0,0,0)
            local g = GetEntityCoords(package)
            local h = Vdist(d,e,f,g.x,g.y,g.z)
            if h <= 2.0 then
                SetVehicleDoorShut(transport,5,false)
                DeleteEntity(package)backOpened=false
            end
        end
        if Cancelled == true then
            return
        end
        QBCore.Functions.Notify('Package loaded...', 'success')
        Citizen.Wait(2500)
        QBCore.Functions.Notify('Package loaded in '..DeliveryTime..' seconds.')
        if DeliveryTime<60 then
            QBCore.Functions.Notify('Bonus $'..bonus1 ..' for fast delivery', 'success')
            TriggerServerEvent("anzdelivery:executionmission",bonus1)
            Citizen.Wait(200)
        elseif DeliveryTime>=60 and DeliveryTime<=120 then
           QBCore.Functions.Notify('Bonus $'..bonus2 ..' for fast delivery', 'success')
            TriggerServerEvent("anzdelivery:executionmission",bonus2)
            Citizen.Wait(200)
        elseif DeliveryTime>=120 and DeliveryTime<=180 then
            QBCore.Functions.Notify('Bonus $'..bonus3 ..' for fast delivery', 'success')
            TriggerServerEvent("anzdelivery:executionmission",bonus3)
            Citizen.Wait(200)
        elseif DeliveryTime>180 then
            QBCore.Functions.Notify('No bonus', 'error')
        end
        DeliveryTime=0
        deliveryTimer=false
        TriggerServerEvent("anzdelivery:executionmission",'nie')
        TaskVehicleDriveWander(pilot,transport,50.0,263100)
        Citizen.Wait(15000)
        DeleteEntity(transport)
        DeleteEntity(pilot)response=0
        QBCore.Functions.Notify('Next order ready')
    end
end)
 
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
    if deliveryTimer == true then
        DeliveryTime = DeliveryTime +1
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
        local paczkCoord = GetEntityCoords(package)
            DrawMarker(0, paczkCoord.x, paczkCoord.y, paczkCoord.z+2.1, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 135, 31, 35, 150, 1, 0, 0, 0)
        else
            Citizen.Wait(2500)
        end
    end
end)

RegisterNetEvent('anzdelivery:ownHangar')
AddEventHandler('anzdelivery:ownHangar', function()
    OwnsHangar = 1
end)

RegisterNetEvent('anzdelivery:leftHangar')
AddEventHandler('anzdelivery:leftHangar', function()
  OwnsHangar = 0
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3)
        
            local plyCoords = GetEntityCoords(GetPlayerPed(-1), false)
            local distCar = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, Config.Forklift['Forlift'].Pos.x, Config.Forklift['Forlift'].Pos.y, Config.Forklift['Forlift'].Pos.z)
            local zlecDist = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z)
            
            if PlayerData.job ~= nil and PlayerData.job.name == 'logistics' then
                    if distCar <= 25.0 or zlecDist <= 25.0 then
                        DrawMarker(27, Config.Forklift['Forlift'].Pos.x, Config.Forklift['Forlift'].Pos.y, Config.Forklift['Forlift'].Pos.z-0.90, 0, 0, 0, 0, 0, 0, 1.301, 1.3001, 1.3001, 255, 255, 255, 200, 0, 0, 0, 0)
                        DrawMarker(27, Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z-0.90, 0, 0, 0, 0, 0, 0, 1.301, 1.3001, 1.3001, 255, 255, 255, 200, 0, 0, 0, 0)
                    else
                        Citizen.Wait(1500)
                    end
                  
                if distCar <= 1.0 then
                    DrawText3D(Config.Forklift['Forlift'].Pos.x, Config.Forklift['Forlift'].Pos.y, Config.Forklift['Forlift'].Pos.z, "[E] Forklift")
                    if IsControlJustPressed(0, Keys['E']) then 
                        LendVehicle('1')
                    end
                end

                if zlecDist <= 1.0 and OwnsHangar == 1 then
                    DrawText3D(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z, '[E] Take Order')
                    DrawText3D(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z-0.13, '[G] Clock on')
                    if IsControlJustPressed(0, Keys['G']) then
                        TriggerServerEvent("anzdelivery:leaveHangar", '1')
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
                          TriggerEvent('anzdelivery:deliverypickup','1')
                          TaskStartScenarioInPlace(GetPlayerPed(-1), "WORLD_HUMAN_CLIPBOARD", 0, false)
                          Citizen.Wait(2000)
                          ClearPedTasks(GetPlayerPed(-1))
                          QBCore.Functions.Notify('Delivery is marked...')
                      end
                  end

                  if zlecDist <= 1.0 and OwnsHangar == 0 then
                        DrawText3D(Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z, "[G] Go on Duty")
                        if IsControlJustPressed(0, Keys['G']) then 
                            TriggerServerEvent("anzdelivery:takeoverHangar", '1')
                            Citizen.Wait(500)
                        end
                  end
              end
  end
end)

local VehicleTaken = 0
local Forklift

function LendVehicle(a)
    if PalletSelect == true then
        if VehicleTaken==0 then
            RequestModel(GetHashKey('forklift'))
            while not HasModelLoaded(GetHashKey('forklift'))do
                Citizen.Wait(0)
            end
            ClearAreaOfVehicles(Config.Forklift['Forklift'].Pos.x, Config.Forklift['Forklift'].Pos.y, Config.Forklift['Forklift'].Pos.z,15.0,false,false,false,false,false)
            QBCore.Functions.SpawnVehicle(Config.Forklift['Forklift'].Model, function(forklift)
            SetVehicleNumberPlateText(forklift, "ECLW"..tostring(math.random(1000, 9999)))
            SetEntityHeading(forklift, Config.Forklift['Forklift'].Heading)
            exports['LegacyFuel']:SetFuel(forklift, 100.0)
            TaskWarpPedIntoVehicle(GetPlayerPed(-1),forklift,-1)
            SetEntityAsMissionEntity(forklift, true, true)
            SetVehicleColours(forklift,111,111)VehicleTaken=1
            TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(forklift))
            SetVehicleEngineOn(forklift, true, true)
            CurrentPlate = GetVehicleNumberPlateText(forklift)
        else
            VehicleTaken=0
            QBCore.Functions.DeleteVehicle(forklift)
            QBCore.Functions.Notify('Forklift returned to the garage...')
        end
    end
end
  
----
  
Citizen.CreateThread(function()
      while true do 
          Citizen.Wait(1500)
          local a = GetEntityCoords(GetPlayerPed(-1),false)
          local c = Vdist(a.x,a.y,a.z,Config.Forklift['Jobstart'].Pos.x, Config.Forklift['Jobstart'].Pos.y, Config.Forklift['Jobstart'].Pos.z)
          if OwnsHangar == 1 then 
              if c > 205.0 then 
                  QBCore.Functions.Notify('Too far away from the warehouse...', 'error')
                  TriggerServerEvent("anzdelivery:toofar")
                  OwnsHangar = 0
                  Citizen.Wait(1500)
              else 
                  Citizen.Wait(3500)
              end 
          end 
      end 
  end)
end

function DrawText3D(x, y, z, text)
    local onScreen,_x,_y=World3dToScreen2d(x, y, z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    SetTextScale(0.37, 0.37)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 370
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 33, 33, 33, 133)
end