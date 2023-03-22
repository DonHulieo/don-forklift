local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local response, cancelled, jobFinished, vehicleOut = false, false, false, false

---@alias vector3 table
---| 'x' number X Coordinate
---| 'y' number Y Coordinate
---| 'z' number Z Coordinate

-------------------------------- FUNCTIONS --------------------------------

---@param min number
---@param max number
---@return number
local function getRandomNumber(min, max)
  return math.floor(math.random() * (max - min) + min)
end

---@param coords vector3
---@param text string
---@param sprite number
---@param color number
---@param scale number
---@return number|nil blip Blip Handle or nil if coords are nil
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

---@param entity number Entity Handle
---@return number blip Blip Handle
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

---@param entity number Entity Handle
---@return number blip Blip Handle
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

---@param model string|number
local function reqMod(model)
  if type(model) ~= 'number' then model = joaat(model) end
  if HasModelLoaded(model) or not model then return end
  RequestModel(model)
  repeat Wait(0) until HasModelLoaded(model)
end

---@param x number|vector3
---@param y number|string
---@param z number|nil
---@param text string|nil 
local function drawText3D(x, y, z, text)
  if type(x) == 'vector3' then
    text = y
    x, y, z = x.x, x.y, x.z
  end

  local onScreen, _x, _y = World3dToScreen2d(x, y, z)
  local coords = GetFinalRenderedCamCoord()
  local dist = #(coords - vector3(x, y, z))
  local scale = (1 / dist) * 1.25
  local fov = (1 / GetGameplayCamFov()) * 100
  local scale = scale * fov

  if onScreen then
    SetTextScale(0.0 * scale, 0.55 * scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    EndTextCommandDisplayText(_x, _y)
  end
end

local marker = false
---@param entity number Entity Handle to create marker for
local function createMarker(entity)
  if not DoesEntityExist(entity) then return end
  marker = true
  CreateThread(function()
    while marker do
      Wait(0)
      local coords = GetEntityCoords(entity)
      DrawMarker(Config.PalletMarkers.type, coords.x, coords.y, coords.z + 2, 0, 0, 0, 0, 0, 0, Config.PalletMarkers.scale.x, Config.PalletMarkers.scale.y, Config.PalletMarkers.scale.z, Config.PalletMarkers.color.r, Config.PalletMarkers.color.g, Config.PalletMarkers.color.b, Config.PalletMarkers.color.a, true, true, 2, true, nil, nil, false)
      if #(GetEntityCoords(PlayerPedId()) - coords) < 3.5 then
        marker = false
      end
      if not DoesEntityExist(entity) then
        marker = false
      end
    end
  end)
end

---@param ped number
---@param coords vector3
---@return number, number current, dist
local function getClosestWarehouse(ped, coords)
  local ped = PlayerPedId() or ped
  local coords = GetEntityCoords(ped) or coords
  local current = nil
  local dist = nil
  for id, warehouse in pairs(Config.Locations) do
    if current then
      if #(coords - warehouse['Start'].coords) < dist then
        current = id
        dist = #(coords - warehouse['Start'].coords)
      end
    else
      dist = #(coords - warehouse['Start'].coords)
      current = id
    end
  end
  return current, dist
end

---@return boolean isUser
local function isCurrentUserUsingWarehouse()
  local identifier = PlayerData.citizenid
  local current, dist = getClosestWarehouse()
  if Config.Locations[current].inUse and Config.Locations[current].user == identifier then return true end
  return false
end

---@return number|nil current
local function getUsersCurrentWarehouse()
  local identifier = PlayerData.citizenid
  for current = 1, #Config.Locations do
    if Config.Locations[current].inUse and Config.Locations[current].user == identifier then return current end
  end
  return nil
end

---@param location number
local function lendVehicle(location)
  local ped = PlayerPedId()
  local coords = Config.Locations[location]['Garage']['Spawn'].coords
  local heading = Config.Locations[location]['Garage']['Spawn'].heading
  local model = Config.Locations[location]['Garage'].model
  local isUser = isCurrentUserUsingWarehouse()
  if isUser then
    if Config.RequiresJob then 
      if not PlayerData.job then 
        QBCore.Functions.Notify("You are not a "..Config.Job.."...", "error") 
        return 
      end
    end
    local lastVeh = GetPlayersLastVehicle()
    local lastMod = GetEntityModel(lastVeh)
    if not vehicleOut and (not IsPedInAnyVehicle(ped, false) or ((DoesEntityExist(lastVeh) and lastMod ~= Config.Locations[location]['Garage'].model))) then
      QBCore.Functions.SpawnVehicle(model, function(vehicle)
        SetVehicleNumberPlateText(vehicle, "FORK"..tostring(getRandomNumber(1000, 9999)))
        SetEntityHeading(vehicle, heading)
        exports[Config.FuelSystem]:SetFuel(vehicle, 100.0)
        TaskEnterVehicle(ped, vehicle, -1, -1, 1.0, 1, 0)
        SetEntityAsMissionEntity(vehicle, true, true)
        TriggerEvent("vehiclekeys:client:SetOwner", GetVehicleNumberPlateText(vehicle))
        SetVehicleEngineOn(vehicle, true, true)
        QBCore.Functions.Notify("Forklift retrieved from garage...", "success")
        vehicleOut = true
      end, coords, true)
    else
      if vehicleOut and lastMod ~= Config.Locations[location]['Garage'].model then lastVeh = GetClosestObjectOfType(coords, 5.0, model, false, false, false) end
      local plate = GetVehicleNumberPlateText(lastVeh)
      if DoesEntityExist(lastVeh) and plate:sub(1, 4) == "FORK" then
        QBCore.Functions.DeleteVehicle(lastVeh)
        QBCore.Functions.Notify("Forklift returned to garage...", "success")
        vehicleOut = false
      else
        QBCore.Functions.Notify("You are not in a forklift...", "error")
      end
    end
  end
end

---@param index number
---@param warehouse table
local function createWarehousePeds(index, warehouse)
  local start = warehouse['Start']
  local model = start.ped
  reqMod(model)
  local ped = CreatePed(4, model, start.coords, start.heading, false, false)
  local garage = warehouse['Garage']
  local model1 = garage.ped
  reqMod(model)
  local ped1 = CreatePed(4, model, garage.coords, garage.heading, false, false)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetBlockingOfNonTemporaryEvents(ped1, true)
  SetPedDiesWhenInjured(ped, false)
  SetPedDiesWhenInjured(ped1, false)
  SetPedCanPlayAmbientAnims(ped, true)
  SetPedCanPlayAmbientAnims(ped1, true)
  SetPedCanRagdollFromPlayerImpact(ped, false)
  SetPedCanRagdollFromPlayerImpact(ped1, false)
  SetEntityInvincible(ped, true)
  SetEntityInvincible(ped1, true)
  SetPedFleeAttributes(ped, 0, 0)
  SetPedFleeAttributes(ped1, 0, 0)
  FreezeEntityPosition(ped, true)
  FreezeEntityPosition(ped1, true)
  if tostring(start.scenario):find("SEAT") then
    local chair = GetClosestObjectOfType(start.coords, 5.0, start.chair, false, false, false)
    if DoesEntityExist(chair) then
      AttachEntityToEntity(chair, ped, GetPedBoneIndex(ped, 0x0), 0.0, 0.0, 0.0, 0.0, 0.0, 180.0, false, false, false, false, 2, true)
    end
  end
  TaskStartScenarioInPlace(ped, start.scenario, 0, true)
  TaskStartScenarioInPlace(ped1, garage.scenario, 0, true)
  if Config.UseTarget then 
    exports['qb-target']:AddTargetEntity(ped, {
      options = {
        {
          icon = 'fas fa-truck-fast',
          label = 'Take Order',
          action = function ()
            TriggerEvent('don-forklift:client:StartJob', index)   
          end,
          canInteract = function() -- Checks if the warehouse is in use
          if warehouse.inUse and not jobFinished then return false end
            return true
          end
        },
        {
          icon = 'fas fa-sign-out-alt',
          label = 'Cancel Order',
          action = function ()
            TriggerEvent('don-forklift:client:CancelJob', index)   
          end,
          canInteract = function() -- Checks if the warehouse is in use
          if not isCurrentUserUsingWarehouse() or jobFinished then return false end
            return true
          end
        }
      },
      distance = 2.0 -- This is the distance for you to be at for the target to turn blue, this is in GTA units and has to be a float value
    })
    exports['qb-target']:AddTargetEntity(ped1, {
      options = {
        {
          type = 'client',
          icon = 'fas fa-warehouse',
          label = 'Take Forklift',
          action = function()
            lendVehicle(index)
          end,
          canInteract = function() -- Checks if the warehouse is in use
          if vehicleOut or not warehouse.inUse then return false end
            return true
          end
        },
        {
          type = "client",
          icon = 'fas fa-warehouse',
          label = 'Return Forklift',
          action = function()
            lendVehicle(index)
          end,
          canInteract = function() -- Checks if the warehouse is in use
          if not vehicleOut or not warehouse.inUse then return false end
            return true
          end
        }
      },
      distance = 2.0 -- This is the distance for you to be at for the target to turn blue, this is in GTA units and has to be a float value
    })
  end
end

---@return table Array of all blip handles
local function GetAllBlips() 
    local blips = {}
    for i = 1, 826 do 
        local blip = GetFirstBlipInfoId(i) 
        local found = DoesBlipExist(blip)    
        while found do 
            blips[#blips + 1] = blip
            blip = GetNextBlipInfoId(i)
            found = DoesBlipExist(blip)
            if not found then 
                break
            end 
        end 
    end 
    return blips
end

---@param sprite number
---@param coords vector3 
local function deleteBlipForCoord(sprite, coords)
  local blips = GetAllBlips()
  for i = 1, #blips do
    local blip = blips[i]
    local blipSprite = GetBlipSprite(blip)
    local blipCoords = GetBlipCoords(blip)
    if blipSprite == sprite and blipCoords == coords then
      RemoveBlip(blip)
    end
  end
end

---@param sprite number Blip Sprite
---@param entity number Entity Handle
local function deleteBlipForEntity(sprite, entity)
  local blip = GetFirstBlipInfoId(sprite)
  local blipEntity = GetBlipInfoIdEntityIndex(blip)
  if blipEntity == entity then
    RemoveBlip(blip)
  end
end

local function removePeds()
  for i = 1, #Config.Locations do
    local start = Config.Locations[i]['Start'].coords
    local garage = Config.Locations[i]['Garage'].coords
    local startPed = GetClosestObjectOfType(start, 1.0, Config.Locations[i]['Start'].ped, false, false, false)
    local garagePed = GetClosestObjectOfType(garage, 1.0, Config.Locations[i]['Garage'].ped, false, false, false)
    if DoesEntityExist(startPed) then DeleteEntity(startPed) end
    if DoesEntityExist(garagePed) then DeleteEntity(garagePed) end
  end
end

---@param location number
---@return number pallet Object Handle
local function spawnPallet(location)
  local rand = getRandomNumber(1, #Config.Locations[location]['Pallets'])
  local coords = Config.Locations[location]['Pallets'][rand]
  local model = Config.PalletModel
  reqMod(model)
  pallet = CreateObject(model, coords.x, coords.y, coords.z - 0.95, true, true, true)
  SetEntityAsMissionEntity(pallet)
  SetEntityCanBeDamaged(pallet, true)
  SetEntityDynamic(pallet, true)
  SetEntityCollision(pallet, true, true)
  createPalletBlip(pallet)
  if Config.PalletMarkers then createMarker(pallet) end
  return pallet
end

---@param entity number Entity Handle
---@return boolean, number isDamaged, health
local function isEntityDamaged(entity)
  local health = GetEntityHealth(entity)
  if health < 1000 then
    return true, health
  else
    return false
  end
end

---@return table coords Table of all player coords known to this client
local function getPlayerCoords()
  local players = GetActivePlayers()
  local coords = {}
  for k, v in ipairs(players) do
    local ped = GetPlayerPed(v)
    local pedCoords = GetEntityCoords(ped)
    coords[#coords + 1] = pedCoords
  end
  return coords
end

---@param coords vector3
---@return boolean isSafe
local function isSafe(coords)
  local players = getPlayerCoords()
  for i = 1, #players do
    local dist = #(coords - players[i])
    if dist < 150 then
      return false
    end
  end
  return true
end

---@return vector3 newCoords
local function getSafeDelivCoords()
  local coords = GetEntityCoords(PlayerPedId())
  newCoords = coords + vector3(getRandomNumber(1, 100), getRandomNumber(1, 100), getRandomNumber(1, 20))
  repeat 
    Wait(0) 
    newCoords = newCoords + vector3(getRandomNumber(1, 100), getRandomNumber(1, 100), getRandomNumber(1, 20))
  until isSafe(newCoords)
  local _, node = GetClosestVehicleNode(newCoords.x, newCoords.y, newCoords.z, 1, 3.0, 0)
  newCoords = node
  return newCoords
end

local loaded = false
---@param ped number Ped Handle
---@param veh number Vehicle Handle
local function listen4Load(ped, veh)
  local deliv = getSafeDelivCoords()
  local sleep = 5000
  local count = 0
  local lastCoords = nil
  loaded = true
  TaskVehicleDriveToCoordLongrange(ped, veh, deliv, 20.0, 538968487, 5.0)
  CreateThread(function()
    while loaded do
      Wait(sleep)
      local coords = GetEntityCoords(veh)
      local dist = #(coords - deliv)
      sleep = 5000
      lastCoords = coords
      if dist < 10.0 then
        if isSafe(coords) then
          DeleteEntity(veh)
          DeleteEntity(ped)
          loaded = false
        else 
          deliv = getSafeDelivCoords()
          TaskVehicleDriveToCoordLongrange(ped, veh, deliv, 20.0, 538968487, 5.0)
          sleep = 30000
        end
      end
      -- print(coords, deliv, dist)
      if lastCoords == coords or #(coords - lastCoords) < 5.0 then
        count = count + 1
        if count > 10 then
          deliv = getSafeDelivCoords()
          TaskVehicleDriveToCoordLongrange(ped, veh, deliv, 20.0, 538968487, 5.0)
          sleep = 30000
        end
      else
        count = 0
      end
    end
  end)
end

-------------------------------- HANDLERS --------------------------------

---@param resource string
AddEventHandler('onResourceStart', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  for id, warehouse in pairs(Config.Locations) do
    TriggerServerEvent('don-forklift:server:Unreserve', id)
    if (not Config.RequiresJob and Config.Blips) then
      createBlip(warehouse['Start'].coords, warehouse['Blips'].label, warehouse['Blips'].sprite, warehouse['Blips'].color, warehouse['Blips'].scale)
    end
    createWarehousePeds(id, warehouse)
  end
end)

---@param resource string
AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  for id, warehouse in pairs(Config.Locations) do
    TriggerServerEvent("don-forklift:server:Unreserve", id)
    if Config.ShowBlips then
      deleteBlipForCoord(warehouse['Blips'].sprite, warehouse.jobStart)
    end
  end
  if response then cancelled = true end
  if vehicleOut then lendVehicle(getUsersCurrentWarehouse()) end
  Wait(1000)
  response, cancelled, jobFinished, vehicleOut = false, false, false, false
  removePeds()
end)

-------------------------------- EVENTS --------------------------------

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  PlayerData = QBCore.Functions.GetPlayerData()
  if Config.RequiresJob and PlayerData.job.name ~= Config.Job then return end
  QBCore.Functions.TriggerCallback('don-forklift:server:GetLocations', function(locations)
    Config.Locations = locations
    for id, warehouse in pairs(Config.Locations) do
      createBlip(warehouse['Start'].coords, warehouse['Blips'].label, warehouse['Blips'].sprite, warehouse['Blips'].color, warehouse['Blips'].scale)
      createWarehousePeds(id, warehouse)
    end
  end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
  PlayerData = {}
  if Config.Blips then
    for id, warehouse in pairs(Config.Locations) do
      deleteBlipForCoord(warehouse['Blips'].sprite, warehouse['Start'].coords)
    end
  end
  if isCurrentUserUsingWarehouse() then
    local current = getUsersCurrentWarehouse()
    if response then cancelled = true end
    if vehicleOut then lendVehicle(current) end
    TriggerServerEvent('don-forklift:server:Unreserve', current)
  end
  removePeds()
end)

---@param JobInfo table
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
  for id, warehouse in pairs(Config.Locations) do
    if Config.RequiresJob then
      if JobInfo.name == Config.Job then
        PlayerData.job = JobInfo 
        if Config.Blips then 
          createBlip(warehouse['Start'].coords, warehouse['Blips'].label, warehouse['Blips'].sprite, warehouse['Blips'].color, warehouse['Blips'].scale)
        end
      else
        deleteBlipForCoord(warehouse['Blips'].sprite, warehouse['Start'].coords)
      end
    else
      if Config.Blips then 
        createBlip(warehouse['Start'].coords, warehouse['Blips'].label, warehouse['Blips'].sprite, warehouse['Blips'].color, warehouse['Blips'].scale)
      end
    end
  end
end)

---@param location number
RegisterNetEvent('don-forklift:client:StartJob', function(location)
  local ped = PlayerPedId()
  local identifier = PlayerData.citizenid
  local inUse = Config.Locations[location].inUse
  local user = Config.Locations[location].user
  if not inUse or user == identifier then
    if response then QBCore.Functions.Notify('Complete the previous order!', 'error') return end
    if Config.RequiresJob then 
      if not PlayerData.job then 
        QBCore.Functions.Notify("You are not a "..Config.Job.."...", "error") 
        return 
      end
    end
    TriggerServerEvent('don-forklift:server:Reserve', location)
    local pallet = spawnPallet(location)
    jobFinished = false
    cancelled = false
    response = true
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, false)
    QBCore.Functions.Notify('Delivery is marked...', 'success', 2500)
    Wait(1000)
    ClearPedTasks(ped)
    createBlip(Config.Locations[location]['Garage'].coords, 'Forklift', 357, 28, 0.5)
    TriggerEvent('don-forklift:client:SpawnPickupVehicle', location, pallet)
  else
    QBCore.Functions.Notify('Someone is already doing this order!', 'error')
  end
end)

---@param location number
---@param pallet number Object Handle
RegisterNetEvent('don-forklift:client:SpawnPickupVehicle', function(location, pallet)
  local coords = Config.Locations[location]['Pickup']['Spawn'].coords
  local deliv = Config.Locations[location]['Pickup']['Delivery'].coords
  local model = Config.Locations[location]['Pickup'].model
  local pedMod = Config.Locations[location]['Pickup'].ped
  local driving = false
  local doorOpened = false
  reqMod(model)
  ClearAreaOfVehicles(coords, 15.0, false, false, false, false,  false)
  local pickup = CreateVehicle(model, coords, Config.Locations[location]['Pickup']['Spawn'].heading, true, true)
  createPickupBlip(pickup)
  SetEntityAsMissionEntity(pickup)
  SetVehicleDoorsLocked(pickup, 2)
  SetVehicleDoorsLockedForAllPlayers(pickup, true)
  reqMod(pedMod)
  local pilot = CreatePedInsideVehicle(pickup, 1, pedMod, -1, true, true)
  SetBlockingOfNonTemporaryEvents(pilot, true)
  SetEntityInvincible(pilot, true)
  SetDriverAbility(pilot, 1.0) 
  SetDriverAggressiveness(pilot, 0.0)
  TaskVehiclePark(pilot, pickup, deliv, Config.Locations[location]['Pickup']['Delivery'].heading, 1, 20.0, false)
  SetDriveTaskDrivingStyle(ped, 538968487)
  SetPedKeepTask(pilot, true)
  driving = true
  Wait(500)
  while driving do
    Wait(1000)
    local eng = GetIsVehicleEngineRunning(pickup)
    if eng and not cancelled then
      Wait(500)
    elseif cancelled then
      deleteBlipForEntity(67, pickup)
      listen4Load(pilot, pickup)
      DeleteEntity(pallet)
      deleteBlipForEntity(478, pallet)
      driving = false
      return
    else
      driving = false
    end
  end
  QBCore.Functions.Notify('The driver has arrived...')
  SetVehicleDoorOpen(pickup, 5, false, false)
  doorOpened = true
  local doorCoords = GetOffsetFromEntityInWorldCoords(pickup, 0.0, -6.0, -1.0)
  while doorOpened do
    Wait(0)
    DrawMarker(1, doorCoords, 0, 0, 0, 0, 0, 0, 1.7, 1.7, 1.7, 135, 31, 35, 150, 1, 0, 0, 0)
    local palletCoords = GetEntityCoords(pallet)
    local dist = #(doorCoords - palletCoords)
    if dist <= 2.0 then
      local isDamaged, health = isEntityDamaged(pallet)
      if isDamaged then
        TriggerEvent('don-forklift:client:FinishDelivery', location, isDamaged, health)
      else
        TriggerEvent('don-forklift:client:FinishDelivery', location, isDamaged)
      end
      DeleteEntity(pallet)
      deleteBlipForEntity(478, pallet)
      Wait(2000)
      SetVehicleDoorShut(pickup, 5, false)
      deleteBlipForEntity(67, pickup)
      listen4Load(pilot, pickup)
      doorOpened = false
    end
    if cancelled then
      SetVehicleDoorShut(pickup, 5, false)
      deleteBlipForEntity(67, pickup)
      deleteBlipForEntity(478, pallet)
      DeleteEntity(pallet)
      doorOpened = false
      return
    end
  end
end)

---@param current number
---@param isDamaged boolean
---@param health number
RegisterNetEvent('don-forklift:client:FinishDelivery', function(current, isDamaged, health)
  jobFinished = true
  response = false 
  QBCore.Functions.Notify('Package loaded..', 'success', 1500)
  if isDamaged then
    Wait(2500)
    if health < 1000 and health > 750 then
      QBCore.Functions.Notify('The product is almost pristine', 'success', 2000)
      TriggerServerEvent('don-forklift:server:PayPlayer', current, Config.PayScales.bonus3)
    elseif health < 750 and health > 500 then
      QBCore.Functions.Notify('The product is damaged, but still usable..', 'error', 2000)
      TriggerServerEvent('don-forklift:server:PayPlayer', current, Config.PayScales.bonus2)
    elseif health < 500 and health > 250 then
      QBCore.Functions.Notify('The products pretty banged up..', 'error', 2000)
      TriggerServerEvent('don-forklift:server:PayPlayer', current, Config.PayScales.bonus)
    elseif health < 250 then
      QBCore.Functions.Notify('The product is badly damaged, you will not be paid for this delivery..', 'error', 3500)
    end
  else
    QBCore.Functions.Notify('The product is pristine', 'success')
    TriggerServerEvent('don-forklift:server:PayPlayer', current, Config.PayScales.bonus3 + Config.PayScales.bonus2 + Config.PayScales.bonus)
  end
end)

---@param location number
RegisterNetEvent('don-forklift:client:CancelJob', function(location)
  if location then
    if isCurrentUserUsingWarehouse() then
      response = false
      cancelled = true
      QBCore.Functions.Notify('You have cancelled the order', 'error')
      TriggerServerEvent('don-forklift:server:Unreserve', location)
      deleteBlipForCoord(357, Config.Locations[location]['Garage'].coords)
    else
      QBCore.Functions.Notify('You are not doing this order', 'error')
    end
  end
end)

---@param location number
---@param identifier string
RegisterNetEvent('don-forklift:client:Reserve', function(location, identifier)
  if location then
    if Config.Locations[location] then
      if not Config.Locations[location].user and not Config.Locations[location].inUse then
        Config.Locations[location].inUse = true
        Config.Locations[location].user = identifier
      end
    end
  end
end)

---@param k number
RegisterNetEvent('don-forklift:client:Unreserve', function(k)
  if k then
    Config.Locations[k].inUse = false
    Config.Locations[k].user = nil
  end
end)

-------------------------------- DRAWTEXT --------------------------------

CreateThread(function()
  while not Config.UseTarget do 
    Wait(sleep)
    local sleep = 3000
    local current, dist = getClosestWarehouse()
    if Config.Locations[current] then
      if dist < 5.0 then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        if not Config.Locations[current].inUse or jobFinished then
          sleep = 0
          drawText3D(Config.Locations[current]['Start'].coords.x, Config.Locations[current]['Start'].coords.y, Config.Locations[current]['Start'].coords.z + 1.25, '[~g~E~w~] - Take Order')
          if IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
            TriggerEvent('don-forklift:client:StartJob', current)
          end
        elseif isCurrentUserUsingWarehouse() and not jobFinished then
          sleep = 0
          drawText3D(Config.Locations[current]['Start'].coords.x, Config.Locations[current]['Start'].coords.y, Config.Locations[current]['Start'].coords.z + 1.25, '[~r~E~w~] - Cancel Order')
          if IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
            TriggerEvent('don-forklift:client:CancelJob', current)
          end
        elseif not isCurrentUserUsingWarehouse() and not jobFinished then
          sleep = 0
          drawText3D(Config.Locations[current]['Start'].coords.x, Config.Locations[current]['Start'].coords.y, Config.Locations[current]['Start'].coords.z + 1.25, '~r~Warehouse in Use~w~')
        end
        if isCurrentUserUsingWarehouse() then
          drawText3D(Config.Locations[current]['Start'].coords.x, Config.Locations[current]['Start'].coords.y, Config.Locations[current]['Start'].coords.z + 1.05, '[~r~F~w~] - Clock Off')
          if (IsControlJustReleased(0, 23) or IsDisabledControlJustReleased(0, 23)) and GetVehiclePedIsEntering(ped) == 0 then
            if not jobFinished then
              TriggerEvent('don-forklift:client:CancelJob', current)
            else
              TriggerServerEvent('don-forklift:server:Unreserve', current)
              deleteBlipForCoord(357, Config.Locations[current]['Garage'].coords)
            end
          end
        end
      else
        Wait(sleep)
      end
    end
  end
end)

CreateThread(function()
  while not Config.UseTarget do
    Wait(0)
    local sleep = 3000
    local current, dist = getClosestWarehouse()
    if Config.Locations[current] then
      if isCurrentUserUsingWarehouse() then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - Config.Locations[current]['Garage'].coords)
        if dist < 5.0 then
          sleep = 0
          if not vehicleOut then
            drawText3D(Config.Locations[current]['Garage'].coords.x, Config.Locations[current]['Garage'].coords.y, Config.Locations[current]['Garage'].coords.z + 1.25, '[~g~E~w~] - Take Forklift')
            if IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
              lendVehicle(current)
            end
          elseif vehicleOut then
            drawText3D(Config.Locations[current]['Garage'].coords.x, Config.Locations[current]['Garage'].coords.y, Config.Locations[current]['Garage'].coords.z + 1.25, '[~r~E~w~] - Return Forklift')
            if IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
              lendVehicle(current)
            end
          end
        else
          Wait(sleep)
        end
      else
        Wait(sleep)
      end
    end
  end
end)