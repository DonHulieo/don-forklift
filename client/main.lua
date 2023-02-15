local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local response, cancelled, jobFinished, vehicleOut = false, false, false, false

-------------------------------- FUNCTIONS --------------------------------

---@param dict string
local function reqAnimDict(dict)
  if HasAnimDictLoaded(dict) or not dict then return end
  RequestAnimDict(dict)
  repeat Wait(0) until HasAnimDictLoaded(dict)
end

---@param model string|number
local function reqMod(model)
  if type(model) ~= 'number' then model = joaat(model) end
  if HasModelLoaded(model) or not model then return end
  RequestModel(model)
  repeat Wait(0) until HasModelLoaded(model)
end

---@param x number @x coord
---@param y number @y coord
---@param z number @z coord
---@param text string @text to draw
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
---@param entity Entity @entity to create marker for
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

---@param coords vector3
---@param text string
---@param sprite number
---@param color number
---@param scale number
---@return number|nil blip 
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

---@param sprite number
---@param coords vector3
local function deleteBlipForCoord(sprite, coords)
  local blip = GetFirstBlipInfoId(sprite)
  local blipCoords = GetBlipInfoIdCoord(blip)
  if #(vector3(coords.x, coords.y, coords.z) - vector3(blipCoords.x, blipCoords.y, blipCoords.z)) < 1.0 then
    RemoveBlip(blip)
  end
end

---@param sprite number
---@param entity number
local function deleteBlipForEntity(sprite, entity)
  local blip = GetFirstBlipInfoId(sprite)
  local blipEntity = GetBlipInfoIdEntityIndex(blip)
  if blipEntity == entity then
    RemoveBlip(blip)
  end
end

---@param entity number
---@return number blip
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

---@param entity number
---@return number blip
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

---@param location number
---@return number
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
  if Config.PalletMarkers then createMarker(pallet) end
  return pallet
end

---@param entity number
---@return boolean, number isDamaged, health
local function isEntityDamaged(entity)
  local health = GetEntityHealth(entity)
  if health < 1000 then
    return true, health
  else
    return false
  end
end

---@return table
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
---@return boolean
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

---@return vector3
local function getSafeDelivCoords()
  local coords = GetEntityCoords(PlayerPedId())
  newCoords = coords + vector3(math.random(1, 100), math.random(1, 100), math.random(1, 20))
  repeat 
    Wait(0) 
    newCoords = newCoords + vector3(math.random(1, 100), math.random(1, 100), math.random(1, 20))
  until isSafe(newCoords)
  local _, node = GetClosestVehicleNode(newCoords.x, newCoords.y, newCoords.z, 1, 3.0, 0)
  newCoords = node
  return newCoords
end

local loaded = false
---@param ped number
---@param veh number
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
      print(coords, deliv, dist)
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

---@param location number
---@param pallet number
local function spawnPickupVeh(location, pallet)
  local coords = Config.Locations[location].pickup.coords
  local deliv = Config.Locations[location].delivery.coords
  local model = Config.Locations[location].pickup.model
  local pedMod = Config.Locations[location].pickup.ped
  local driving = false
  local doorOpened = false
  reqMod(model)
  ClearAreaOfVehicles(coords, 15.0, false, false, false, false,  false)
  local pickup = CreateVehicle(model, coords, Config.Locations[location].pickup.heading, true, true)
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
  TaskVehiclePark(pilot, pickup, deliv, Config.Locations[location].delivery.heading, 1, 20.0, false)
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
  listen4Load(pilot, pickup)
end

---@param ped number
---@param coords vector3
---@return boolean, number 
local function getClosestWarehouse(ped, coords)
  local ped = PlayerPedId() or ped
  local coords = GetEntityCoords(ped) or coords
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

---@return number|nil current
local function getUsersCurrentWarehouse()
  local identifier = PlayerData.citizenid
  for current = 1, #Config.Locations do
    if Config.Locations[current].inUse and Config.Locations[current].user == identifier then return current end
  end
  return nil
end

---@return boolean isUser
local function isCurrentUserUsingWarehouse()
  local identifier = PlayerData.citizenid
  local current, dist = getClosestWarehouse()
  if Config.Locations[current].inUse and Config.Locations[current].user == identifier then return true end
  return false
end

---@param location number
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
        exports['don-fuel']:SetFuel(vehicle, 100.0)
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

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  for id, warehouse in pairs(Config.Locations) do
    TriggerServerEvent("don-forklift:server:Unreserve", id)
    if Config.ShowBlips then
      deleteBlipForCoord(warehouse.blipSettings.sprite, warehouse.jobStart)
    end
  end
  if response then cancelled = true end
  if vehicleOut then lendVehicle(getUsersCurrentWarehouse()) end
  Wait(1000)
  response, cancelled, jobFinished, vehicleOut = false, false, false, false
end)

AddEventHandler('onResourceStart', function(resource)
  if resource ~= GetCurrentResourceName() then return end
  for id, warehouse in pairs(Config.Locations) do
    TriggerServerEvent('don-forklift:server:Unreserve', id)
    if (not Config.RequiresJob and Config.Blips) then
      createBlip(warehouse.jobStart, warehouse.blipSettings.label, warehouse.blipSettings.sprite, warehouse.blipSettings.color, warehouse.blipSettings.scale)
    end
  end
end)

-------------------------------- EVENTS --------------------------------

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  PlayerData = QBCore.Functions.GetPlayerData()
  if Config.RequiresJob and PlayerData.job.name ~= Config.Job then return end
  QBCore.Functions.TriggerCallback('don-forklift:server:GetLocations', function(locations)
    Config.Locations = locations
    for id, warehouse in pairs(Config.Locations) do
      createBlip(warehouse.jobStart, warehouse.blipSettings.label, warehouse.blipSettings.sprite, warehouse.blipSettings.color, warehouse.blipSettings.scale)
    end
  end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
  PlayerData = {}
  if Config.Blips then
    for id, warehouse in pairs(Config.Locations) do
      deleteBlipForCoord(warehouse.blipSettings.sprite, warehouse.jobStart)
    end
  end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
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
    createBlip(Config.Locations[location].garage.coords, 'Forklift', 357, 28, 0.5)
    spawnPickupVeh(location, pallet)
  else
    QBCore.Functions.Notify('Someone is already doing this order!', 'error')
  end
end)

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

RegisterNetEvent('don-forklift:client:CancelJob', function(location)
  if location then
    if isCurrentUserUsingWarehouse() then
      response = false
      cancelled = true
      QBCore.Functions.Notify('You have cancelled the order', 'error')
      TriggerServerEvent('don-forklift:server:Unreserve', location)
    else
      QBCore.Functions.Notify('You are not doing this order', 'error')
    end
  end
end)

RegisterNetEvent('don-forklift:client:Reserve', function(k, identifier)
  if k then
    if Config.Locations[k] then
      if not Config.Locations[k].user and not Config.Locations[k].inUse then
        Config.Locations[k].inUse = true
        Config.Locations[k].user = identifier
      end
    end
  end
end)

RegisterNetEvent('don-forklift:client:Unreserve', function(k)
  if k then
    Config.Locations[k].inUse = false
    Config.Locations[k].user = nil
  end
end)

-------------------------------- TARGET --------------------------------

if Config.UseTarget then
  for k, v in pairs(Config.Locations) do
    exports['qb-target']:AddBoxZone('garage' ..k, v.garage.zone.coords, v.garage.zone.length, v.garage.zone.width, {
      name = 'garage' ..k,
      heading = v.garage.zone.heading,
      debugPoly = false,
      minZ= v.garage.zone.coords.z - 1,
      maxZ= v.garage.zone.coords.z + 1
      }, {
        options = {
          {
          type = 'client',
          icon = 'fas fa-warehouse',
          label = 'Take Forklift',
          action = function()
            lendVehicle(k)
          end,
          canInteract = function() -- Checks if the warehouse is in use
            if vehicleOut or not v.inUse then return false end
              return true
            end
          },
          {
          type = "client",
          icon = 'fas fa-warehouse',
          label = 'Return Forklift',
          action = function()
            lendVehicle(k)
          end,
          canInteract = function() -- Checks if the warehouse is in use
            if not vehicleOut or not v.inUse then return false end
              return true
            end
          }
        },
        distance = 2.0 -- This is the distance for you to be at for the target to turn blue, this is in GTA units and has to be a float value
      }
    )
    exports['qb-target']:AddBoxZone('warehouse' ..k, v.jobStart, v.boxzone.length, v.boxzone.width, {
      name = 'warehouse' ..k,
      heading = v.boxzone.heading,
      debugPoly = false,
      minZ= v.jobStart.z - 1,
      maxZ= v.jobStart.z + 1
      }, {
        options = {
          {
          icon = 'fas fa-truck-fast',
          label = 'Take Order',
          action = function ()
              TriggerEvent('don-forklift:client:StartJob', k)   
            end,
          canInteract = function() -- Checks if the warehouse is in use
            if v.inUse and not jobFinished then return false end
              return true
            end
          },
          {
          icon = 'fas fa-sign-out-alt',
          label = 'Cancel Order',
          action = function ()
              TriggerEvent('don-forklift:client:CancelJob', k)   
            end,
          canInteract = function() -- Checks if the warehouse is in use
            if not isCurrentUserUsingWarehouse() or jobFinished then return false end
              return true
            end
          }
        },
        distance = 2.0 -- This is the distance for you to be at for the target to turn blue, this is in GTA units and has to be a float value
      }
    )
  end
end

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
          drawText3D(Config.Locations[current].jobStart.x, Config.Locations[current].jobStart.y, Config.Locations[current].jobStart.z, '[~g~E~w~] - Take Order')
          if IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
            TriggerEvent('don-forklift:client:StartJob', current)
          end
        elseif isCurrentUserUsingWarehouse() and not jobFinished then
          sleep = 0
          drawText3D(Config.Locations[current].jobStart.x, Config.Locations[current].jobStart.y, Config.Locations[current].jobStart.z, '[~r~E~w~] - Cancel Order')
          if IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
            TriggerEvent('don-forklift:client:CancelJob', current)
          end
        elseif not isCurrentUserUsingWarehouse() and not jobFinished then
          sleep = 0
          drawText3D(Config.Locations[current].jobStart.x, Config.Locations[current].jobStart.y, Config.Locations[current].jobStart.z, '~r~Warehouse in Use~w~')
        end
        if isCurrentUserUsingWarehouse() then
          drawText3D(Config.Locations[current].jobStart.x, Config.Locations[current].jobStart.y, Config.Locations[current].jobStart.z - 0.2, '[~r~F~w~] - Clock Off')
          if (IsControlJustReleased(0, 23) or IsDisabledControlJustReleased(0, 23)) and GetVehiclePedIsEntering(ped) == 0 then
            if not jobFinished then
              TriggerEvent('don-forklift:client:CancelJob', current)
            else
              TriggerServerEvent('don-forklift:server:Unreserve', current)
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
        local dist = #(coords - Config.Locations[current].garage.coords)
        if dist < 5.0 then
          sleep = 0
          if not vehicleOut then
            drawText3D(Config.Locations[current].garage.coords.x, Config.Locations[current].garage.coords.y, Config.Locations[current].garage.coords.z, '[~g~E~w~] - Take Forklift')
            if IsControlJustReleased(0, 38) or IsDisabledControlJustReleased(0, 38) then
              lendVehicle(current)
            end
          elseif vehicleOut then
            drawText3D(Config.Locations[current].garage.coords.x, Config.Locations[current].garage.coords.y, Config.Locations[current].garage.coords.z, '[~r~E~w~] - Return Forklift')
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