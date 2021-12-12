
--------------------------------------------------------
local Keys = {
    ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, 
    ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, 
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70, 
    ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
    ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
    ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
  }
  
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
  
  local PlayerData = {}
  local Anulowano = false
  local DeliveryCarSpawn = {x = 1113.12, y = -3334.41, z = 5.92} --vector3(1113.12, -3334.41, 5.92)
  local DeliveryCoords = {x = 1225.5, y = -3222.97, z = 5.8} --vector3(1223.87, -3222.97, 5.8)
  local ForkliftSpawn = {x = 1201.55, y = -3287.51, z = 5.5}
  local zlecenieDist = {x = 1206.22, y = -3259.78, z = 5.5}
  local zrespione = false
  local silnikOn = false
  local rodzajVehicleu = nil
  local naklejkaAuto = 0
  
  local PalletCoord1 = {x = 1190.23, y = -3306.25, z = 5.5}
  local PalletCoord2 = {x = 1199.31, y = -3308.33, z = 5.5}
  local PalletCoord3 = {x = 1232.87, y = -3294.65, z = 5.5}
  local PalletCoord4 = {x = 1191.27, y = -3274.08, z = 5.5}
  local PalletCoord5 = {x = 1223.9, y = -3246.72, z = 5.5}
  local DeliveryTime = 0
  local deliveryTimer = false
  local PrzejetyHangar = 0
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
  
  function ZrespPaczuszke(a)
      DeliveryTime=0
      deliveryTimer=true
      if a=='deski'then 
          package=CreateObject(GetHashKey('prop_boxpile_06a'),PalletCoord1.x,PalletCoord1.y,PalletCoord1.z-0.95,true,true,true)
          SetEntityAsMissionEntity(package)
          SetEntityDynamic(package,true)
          FreezeEntityPosition(package,false)
          SetNewWaypoint(PalletCoord1.x,PalletCoord1.y)
      elseif a=='lody'then 
          package=CreateObject(GetHashKey('prop_boxpile_06a'),PalletCoord2.x,PalletCoord2.y,PalletCoord2.z-0.95,true,true,true)
          SetEntityAsMissionEntity(package)
          SetEntityDynamic(package,true)
          FreezeEntityPosition(package,false)
          SetNewWaypoint(PalletCoord2.x,PalletCoord2.y)
      elseif a=='leki'then 
          package=CreateObject(GetHashKey('prop_boxpile_06a'),PalletCoord3.x,PalletCoord3.y,PalletCoord3.z-0.95,true,true,true)
          SetEntityAsMissionEntity(package)
          SetEntityDynamic(package,true)
          FreezeEntityPosition(package,false)
          SetNewWaypoint(PalletCoord3.x,PalletCoord3.y)
      elseif a=='napoje'then 
          package=CreateObject(GetHashKey('prop_boxpile_06a'),PalletCoord4.x,PalletCoord4.y,PalletCoord4.z-0.95,true,true,true)
          SetEntityAsMissionEntity(package)
          SetEntityDynamic(package,true)
          FreezeEntityPosition(package,false)
          SetNewWaypoint(PalletCoord4.x,PalletCoord4.y)
      elseif a=='kawa'then 
          package=CreateObject(GetHashKey('prop_boxpile_06a'),PalletCoord5.x,PalletCoord5.y,PalletCoord5.z-0.95,true,true,true)
          SetEntityAsMissionEntity(package)
          SetEntityDynamic(package,true)
          FreezeEntityPosition(package,false)
          SetNewWaypoint(PalletCoord5.x,PalletCoord5.y)
      end 
  end
  
  
  RegisterNetEvent('anzdelivery:rampanpcdawaj')
  AddEventHandler('anzdelivery:rampanpcdawaj',function(a)
      Anulowano=false
      if a=='1'then
          if zrespione==true then
              TriggerEvent(Notify,'Complete the previous order!')
              return
          end
          local b=math.random(1,5)
          if b==1 then
              naklejkaAuto=3
              TriggerEvent(Notify,'The driver awaits loading...')
              ZrespPaczuszke('deski')
          elseif b==2 then
              naklejkaAuto=4
              TriggerEvent(Notify,'The driver awaits loading...')
              ZrespPaczuszke('lody')
          elseif b==3 then
              naklejkaAuto=6
              TriggerEvent(Notify,'The driver awaits loading...')
              ZrespPaczuszke('leki')
          elseif b==4 then
              naklejkaAuto=2
              TriggerEvent(Notify,'The driver awaits loading...')
              ZrespPaczuszke('napoje')
          elseif b==5 then
              naklejkaAuto=1
              TriggerEvent(Notify,'The driver awaits loading...')
              ZrespPaczuszke('kawa')
          end
          RequestModel(GetHashKey('benson'))
          while not HasModelLoaded(GetHashKey('benson'))do
              Citizen.Wait(0)end
          ClearAreaOfVehicles(DeliveryCarSpawn.x,DeliveryCarSpawn.y,DeliveryCarSpawn.z,15.0,false,false,false,false,false)
          transport=CreateVehicle(GetHashKey('benson'),DeliveryCarSpawn.x,DeliveryCarSpawn.y,DeliveryCarSpawn.z,-2.436,996.786,25.1887,true,true)
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
          SetVehicleExtra(transport,naklejkaAuto,false)
          RequestModel("s_m_m_security_01")
          while not HasModelLoaded("s_m_m_security_01")do
              Wait(10)end
          pilot=CreatePedInsideVehicle(transport,1,"s_m_m_security_01",-1,true,true)
          SetBlockingOfNonTemporaryEvents(pilot,true)
          SetEntityInvincible(pilot,true)
          TaskVehiclePark(pilot,transport,DeliveryCoords.x,DeliveryCoords.y,DeliveryCoords.z,266.0,1,1.0,false)
          SetDriveTaskDrivingStyle(pilot,263100)
          SetPedKeepTask(pilot,true)
          TriggerEvent(Notify,'The driver is enroute...')
          zrespione=true
          silnikOn=true
          Citizen.Wait(900)
          while silnikOn do
              Citizen.Wait(1000)
              local c=GetIsVehicleEngineRunning(transport)
              if c==1 then
                  Citizen.Wait(200)
              else
                  silnikOn=false
              end
          end
          TriggerEvent(Notify,'The driver has arrived...')
          SetVehicleDoorOpen(transport,5,false,false)
          backOpened=true
          local d,e,f=table.unpack(GetOffsetFromEntityInWorldCoords(transport,0.0,-6.0,-1.0))
          while backOpened do
              Citizen.Wait(2)
              DrawMarker(1,d,e,f,0,0,0,0,0,0,1.7,1.7,1.7,135,31,35,150,1,0,0,0)
              local g=GetEntityCoords(package)
              local h=Vdist(d,e,f,g.x,g.y,g.z)
              if h<=2.0 then
                  SetVehicleDoorShut(transport,5,false)
                  DeleteEntity(package)backOpened=false
              end
          end
          if Anulowano==true then
              return
          end
          TriggerEvent(Notify,'Package loaded...')
          TriggerEvent(Notify,'Package loaded in '..DeliveryTime..' seconds.')
          if DeliveryTime<60 then
              TriggerEvent(Notify,'Bonus $'..bonus1 ..' for fast delivery')
              TriggerServerEvent("anzdelivery:executionmission",bonus1)
              Citizen.Wait(200)
          elseif DeliveryTime>=60 and DeliveryTime<=120 then
              TriggerEvent(Notify,'Bonus $'..bonus2 ..' for fast delivery')
              TriggerServerEvent("anzdelivery:executionmission",bonus2)
              Citizen.Wait(200)
          elseif DeliveryTime>=120 and DeliveryTime<=180 then
              TriggerEvent(Notify,'Bonus $'..bonus3 ..' for fast delivery')
              TriggerServerEvent("anzdelivery:executionmission",bonus3)
              Citizen.Wait(200)
          elseif DeliveryTime>180 then
              TriggerEvent(Notify,'No bonus')
          end
          DeliveryTime=0
          deliveryTimer=false
          TriggerServerEvent("anzdelivery:executionmission",'nie')
          TaskVehicleDriveWander(pilot,transport,50.0,263100)
          Citizen.Wait(15000)
          DeleteEntity(transport)
          DeleteEntity(pilot)zrespione=0
          TriggerEvent(Notify,'Next order ready')
        end
    end)
 
  
  
  
  
  
  Citizen.CreateThread(function()
      while true do
          Citizen.Wait(1000)
          
          if deliveryTimer == true then
          DeliveryTime = DeliveryTime +1
              if DeliveryTime > 240 then
              Anulowano = true
              zrespione = 0
              DeliveryTime = 0
              deliveryTimer = false
              backOpened = false
              silnikOn = false
              DeleteEntity(transport)
              DeleteEntity(pilot)
              DeleteEntity(package)
              TriggerEvent(Notify,'The order was cancelled...')
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
  PrzejetyHangar = 1
  end)
  
  Citizen.CreateThread(function()
      while true do
          Citizen.Wait(3)
          
              local plyCoords = GetEntityCoords(GetPlayerPed(-1), false)
              local distCar = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, ForkliftSpawn.x, ForkliftSpawn.y, ForkliftSpawn.z)
              local zlecDist = Vdist(plyCoords.x, plyCoords.y, plyCoords.z, zlecenieDist.x, zlecenieDist.y, zlecenieDist.z)
              
                if PlayerData.job ~= nil and PlayerData.job.name == 'logistics' then
                    if distCar <= 25.0 or zlecDist <= 25.0 then
                        DrawMarker(27, ForkliftSpawn.x, ForkliftSpawn.y, ForkliftSpawn.z-0.90, 0, 0, 0, 0, 0, 0, 1.301, 1.3001, 1.3001, 255, 255, 255, 200, 0, 0, 0, 0)
                        DrawMarker(27, zlecenieDist.x, zlecenieDist.y, zlecenieDist.z-0.90, 0, 0, 0, 0, 0, 0, 1.301, 1.3001, 1.3001, 255, 255, 255, 200, 0, 0, 0, 0)
                    else
                        Citizen.Wait(1500)
                    end
                    
                    if distCar <= 1.0 then
                            DrawText3D(ForkliftSpawn.x, ForkliftSpawn.y, ForkliftSpawn.z, "[E] Forklift")
                        if IsControlJustPressed(0, Keys['E']) then 
                            LendVehicle('1')
                        end
                    end
                    
                    if zlecDist <= 1.0 then
                        DrawText3D(zlecenieDist.x, zlecenieDist.y, zlecenieDist.z, "[E] Take order")
                        DrawText3D(zlecenieDist.x, zlecenieDist.y, zlecenieDist.z-0.13, "[G] Go on Duty")
                        if IsControlJustPressed(0, Keys['E']) then 
                            if PrzejetyHangar == 1 then
                                TriggerEvent('anzdelivery:rampanpcdawaj','1')
                                TaskStartScenarioInPlace(GetPlayerPed(-1), "WORLD_HUMAN_CLIPBOARD", 0, false)
                                Citizen.Wait(2000)
                                ClearPedTasks(GetPlayerPed(-1))
                                TriggerEvent(Notify,'Delivery is marked...')
                            else
                                TriggerEvent(Notify,'You must be on duty')
                            end
                        elseif IsControlJustPressed(0, Keys['G']) then
                            if PrzejetyHangar == 1 then
                                TriggerEvent(Notify,'You are already employed')
                            else
                                TriggerServerEvent("anzdelivery:takeoverHangar", '1')
                                Citizen.Wait(500)
                            end
                        end
                    end
                end
    end
  end)
  
  local VehicleTaken = 0
  local wozek
  
  function LendVehicle(a)
    if a=='1'then
        if VehicleTaken==0 then
            RequestModel(GetHashKey('forklift'))
            while not HasModelLoaded(GetHashKey('forklift'))do
                Citizen.Wait(0)
            end
            ClearAreaOfVehicles(ForkliftSpawn.x,ForkliftSpawn.y,ForkliftSpawn.z,15.0,false,false,false,false,false)
            wozek=CreateVehicle(GetHashKey('forklift'),ForkliftSpawn.x,ForkliftSpawn.y,ForkliftSpawn.z,-2.436,996.786,25.1887,true,true)
            SetVehicleNumberPlateText(wozek, "ECLW"..tostring(math.random(1000, 9999)))
            SetEntityHeading(wozek,86.00)
            exports['LegacyFuel']:SetFuel(wozek, 100.0)
            TaskWarpPedIntoVehicle(GetPlayerPed(-1),wozek,-1)
            SetEntityAsMissionEntity(wozek, true, true)
            SetVehicleColours(wozek,111,111)VehicleTaken=1
            TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(wozek))
            SetVehicleEngineOn(veh, true, true)
            CurrentPlate = GetVehicleNumberPlateText(wozek)
        else
            VehicleTaken=0
            DeleteEntity(wozek)TriggerEvent(Notify,'Forklift returned to the garage...')
        end
    end
  
  ----
  
  Citizen.CreateThread(function()
      while true do 
          Citizen.Wait(1500)
          local a=GetEntityCoords(GetPlayerPed(-1),false)
          local c=Vdist(a.x,a.y,a.z,zlecenieDist.x,zlecenieDist.y,zlecenieDist.z)
          if PrzejetyHangar==1 then 
              if c>205.0 then 
                  TriggerEvent(Notify,'Too far away from the warehouse...')
                  TriggerServerEvent("anzdelivery:toofar")
                  PrzejetyHangar = 0
                  Citizen.Wait(1500)
              else 
                  Citizen.Wait(3500)
              end 
          end 
      end 
  end)
end
  