local duff, Citizen = duff, Citizen
local iblips = exports.iblips
local await, blips, bridge, math, require, streaming = duff.await, duff.blips, duff.bridge, duff.math, duff.package.require, duff.streaming
---@module 'don-forklift.shared.config'
local config = require 'shared.config'
local DEBUG_MODE <const> = config.DebugMode
local LOCATIONS <const> = config.Locations
local NOTIFY = config.Notify
local LOAD_EVENT <const>, UNLOAD_EVENT <const>, JOB_EVENT <const> = bridge['_DATA']['EVENTS'].LOAD, bridge['_DATA']['EVENTS'].UNLOAD, bridge['_DATA']['EVENTS'].JOBDATA
local RES_NAME <const> = GetCurrentResourceName()
local entered_thread, entered_warehouse, isLoggedIn = false, false, false
local cit_await = Citizen.Await

local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local response, cancelled, jobFinished, vehicleOut = false, false, false, false

local Warehouses = {}

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

---@param key string
---@param label string
local function add_label(key, label)
  if DoesTextLabelExist(key) and GetLabelText(key) == label then return end
  AddTextEntry(key, label)
end

---@param blip integer
---@param sprite number
---@param scale number
---@param colour number
---@return number blip
local function setup_blip(blip, sprite, scale, colour, key)
  SetBlipSprite(blip, sprite)
  SetBlipCategory(blip, 1)
  SetBlipDisplay(blip, 4)
  SetBlipScale(blip, scale)
  SetBlipColour(blip, colour)
  SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName(key)
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

---@return table warehouses
local function init_warehouses()
  for i = 1, #LOCATIONS do
    local location = LOCATIONS[i]
    local coords = location.coords
    local blip_data = location.blip
    Warehouses[i] = Warehouses[i] or {}
    if blip_data.enabled then
      local has_job = not location.job or location.job and bridge.doesplayerhavegroup(nil, location.job --[[@as string|string[]=]])
      if not Warehouses[i].blip and has_job then
        Warehouses[i].blip = iblips:initblip('coord', {coords = coords}, blip_data.options)
      else
        iblips:remove(Warehouses[i].blip)
        Warehouses[i].blip = nil
      end
    end
  end
  return Warehouses
end

---@param resource string? Starting resource name or nil.
local function init_script(resource)
  if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
  init_warehouses()
  isLoggedIn = LocalPlayer.state.isLoggedIn or IsPlayerPlaying(PlayerId())
end

---@param location integer
---@return boolean?, integer?
local function is_player_using_warehouse(location)
  local identifier = bridge.getidentifier()
  location = location or GetClosestWarehouse()
  if not LOCATIONS[location] then return end
  return GlobalState['forklift:warehouse:'..location] == identifier
end

---@param location integer
---@param sync_state boolean?
local function remove_mission_obj(location, sync_state)
  local warehouse = Warehouses[location]
  if not warehouse then return end
  if warehouse.pallet then
    if sync_state then Entity(warehouse.pallet.obj).state:set('forklift:object:fin', true, true) end
    iblips:remove(warehouse.pallet.blip)
    table.wipe(warehouse.pallet)
  end
end

---@param resource string? Stopping resource name or nil.
local function deinit_script(resource)
  if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
  for i = 1, #LOCATIONS do
    local location = LOCATIONS[i]
    local warehouse = Warehouses[i]
    if location.blip.enabled then iblips:remove(warehouse.blip) end
    if response then cancelled = true end
    if vehicleOut and i then lendVehicle(i) end
    if warehouse.pallet then remove_mission_obj(i, true) end
    if warehouse.garage then iblips:remove(warehouse.garage.blip); table.wipe(warehouse.garage) end
    if is_player_using_warehouse(i) then TriggerServerEvent('forklift:server:ReserveWarehouse', location, bridge.getidentifier(), false) end
    table.wipe(warehouse)
  end
  removePeds()
end

---@param entity integer
---@return boolean
local function catch_entity(entity)
  local game_timer = GetGameTimer
  local does_entity_exist = DoesEntityExist
  return await(function(ent)
    local time = game_timer()
    local exists = does_entity_exist(ent)
    while not exists and not math.timer(time, 5000) do
      Wait(250)
      time, exists = game_timer(), does_entity_exist(ent)
    end
    return exists
  end, entity)
end

---@param ped integer
local function init_ped(ped)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetEntityInvincible(ped, true)
  SetPedDiesWhenInjured(ped, false)
  SetPedCanPlayAmbientAnims(ped, true)
  SetPedCanRagdollFromPlayerImpact(ped, false)
  FreezeEntityPosition(ped, true)
end

---@param ped integer
---@param ped_data {model: string, coords: vector4, scenario: string, chair: string|number?}
local function setup_ped_scenario(ped, ped_data)
  local coords = ped_data.coords
  local scenario = ped_data.scenario
  if ped_data.chair then
    local chair = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, ped_data.chair, false, false, false)
    ---@diagnostic disable-next-line: redundant-parameter
    if DoesEntityExist(chair) then AttachEntityToEntity(chair, ped, GetPedBoneIndex(ped, 0xE0FD), 0.0, 0.0, 0.5, 0.0, 0.0, coords.w, true, true, false, true, 2, true, false) end
    ProcessEntityAttachments(ped)
  end
  TaskStartScenarioInPlace(ped, scenario, 0, true)
end

---@param location integer
---@return boolean? is_using
local function is_any_player_using_warehouse(location)
  location = location or GetClosestWarehouse()
  if not LOCATIONS[location] then return end
  return GlobalState['forklift:warehouse:'..location] ~= nil
end

---@param name string
---@param key string
---@param value any
---@param replicated boolean
local function catch_ped_state(name, key, value, _, replicated)
  if not value then return end
  local entity = GetEntityFromStateBagName(name)
  if not entity or entity == 0 or not DoesEntityExist(entity) then return end
  if not catch_entity(entity) then return end
  local wh_key = value['wh_key']
  local wh_type = value['type']
  local is_start = wh_type == 'sign_up'
  local ped_key = is_start and 1 or 2
  init_ped(entity)
  setup_ped_scenario(entity, LOCATIONS[wh_key]['Peds'][ped_key])
  print('Ped created for '..wh_key..' '..wh_type)
  Warehouses[wh_key] = Warehouses[wh_key] or {}
  Warehouses[wh_key][wh_type] = Warehouses[wh_key][wh_type] or {}
  Warehouses[wh_key][wh_type].target = true and bridge.addlocalentity(entity, {
    {
      name = 'forklift_'..wh_type:lower()..'_target_'..wh_key,
      label = is_start and 'Take Order' or 'Take Forklift',
      icon = is_start and 'fas fa-truck-fast' or 'fas fa-warehouse',
      onSelect = function()
        if is_start then
          TriggerEvent('forklift:client:SetupOrder', wh_key, true, false)
        else
          lendVehicle(wh_key)
        end
      end,
      canInteract = function()
        if is_start then
          return not is_any_player_using_warehouse(wh_key) and not jobFinished
        else
          return is_any_player_using_warehouse(wh_key) and not vehicleOut
        end
      end
    },
    {
      name = 'forklift_'..wh_type:lower()..'_target_cancel_'..wh_key,
      label = is_start and 'Cancel Order' or 'Return Forklift',
      icon = 'fas fa-sign-out-alt',
      onSelect = function()
        if is_start then
          TriggerEvent('forklift:client:SetupOrder', wh_key, false, true)
        else
          lendVehicle(wh_key)
        end
      end,
      canInteract = function()
        if is_start then
          return is_player_using_warehouse(wh_key) and not jobFinished
        else
          return is_any_player_using_warehouse(wh_key) and vehicleOut
        end
      end
    }
  })
end

---@param location integer
---@return string|boolean? job
local function does_warehouse_require_job(location)
  local warehouse = LOCATIONS[location]
  if not warehouse then return end
  return warehouse.job and warehouse.job
end

---@param model string|integer
---@param coords vector4
---@param location integer
---@return integer netID
local function create_object(model, coords, location)
  Wait(0)
  local p = promise.new()
  bridge.triggercallback(nil, 'forklift:server:CreateObject', function(netID)
    p:resolve(netID)
  end, model, coords, location)
  return cit_await(p)
end

local PALLET_BLIP <const> = {
  name = 'Pallet',
  colours = {
    opacity = 255,
    primary = 70
  },
  display = {
    category = 'mission',
    display = 'radar_only'
  },
  style = {
    sprite = 478,
    scale = 0.8,
    short_range = true
  },
  distance = 250.0,
}

local GARAGE_BLIP <const> = {
  name = 'Forklift',
  colours = {
    opacity = 255,
    primary = 28
  },
  display = {
    category = 'mission',
    display = 'all_select'
  },
  style = {
    sprite = 357,
    scale = 0.6,
    short_range = true
  },
  distance = 250.0,
}

---@param location integer
---@param initiate boolean
---@param canceled boolean
local function setup_order(location, initiate, canceled)
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local warehouse = LOCATIONS[location]
  local dist = #(coords - warehouse.coords)
  if dist > 50.0 then return end
  if is_any_player_using_warehouse(location) and not is_player_using_warehouse(location) then NOTIFY(nil, 'Someone is already doing this order!', 'error') return end
  local identifier = bridge.getidentifier()
  TriggerServerEvent('forklift:server:ReserveWarehouse', location, identifier, initiate)
  if initiate then
    if response then NOTIFY(nil, 'Complete the previous order!', 'error') return end
    local job = does_warehouse_require_job(location)
    if job and not bridge.doesplayerhavegroup(nil, job --[[@as string|string[]=]]) then NOTIFY(nil, 'You are not a '..job..'...', 'error') return end
    local pallets = warehouse.Pallets
    local pnts, mdls = pallets.coords, pallets.models
    math.seedrng()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    local rdm_a, rdm_b = math.random(1, #pnts), math.random(1, #mdls)
    local pnt, mdl = pnts[rdm_a], mdls[rdm_b]
    if not Warehouses[location].pallet then Warehouses[location].pallet = {} end
    Warehouses[location].pallet.mod = mdl
    Warehouses[location].pallet.coords = pnt
    local pallet = NetToObj(create_object(mdl, pnt, location))
    Warehouses[location].pallet.obj = pallet
    Warehouses[location].pallet.blip = iblips:initblip('coord', {coords = pnt}, PALLET_BLIP)
    SetModelAsNoLongerNeeded(mdl)
    if not Warehouses[location].garage then Warehouses[location].garage = {} end
    Warehouses[location].garage.blip = iblips:initblip('coord', {coords = warehouse.Garage.coords.xyz}, GARAGE_BLIP)
    NOTIFY(nil, 'Delivery is marked...', 'success', 2500)
    Wait(1000)
    ClearPedTasks(ped)
  else
    if canceled then
      NOTIFY(nil, 'Order canceled...', 'error')
      remove_mission_obj(location, true)
      iblips:remove(Warehouses[location].garage.blip)
      table.wipe(Warehouses[location].garage)
    end
  end
end

---@param name string
---@param key string
---@param value any
---@param replicated boolean
local function sync_object_state_bag(name, key, value, _, replicated)
  if value == nil or name == 'global' then return end
  local obj = GetEntityFromStateBagName(name)
  if not obj or obj == 0 or not DoesEntityExist(obj) or not catch_entity(obj) then return end
  if key == 'forklift:object:init' then
    local netID = ObjToNet(obj)
    if not NetworkDoesEntityExistWithNetworkId(netID) then return end
    NetworkUseHighPrecisionBlending(netID, true)
    NetworkSetObjectForceStaticBlend(obj, true)
    PlaceObjectOnGroundProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCanBeDamaged(obj, true)
    SetEntityDynamic(obj, true)
    SetEntityCollision(obj, true, true)
  elseif key == 'forklift:object:fin' then
    -- local location = value
    -- DeleteObject(obj)
    -- remove_mission_obj(location, false)
  end
end

---@return number, number
function GetClosestWarehouse()
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local clst_pnt, dist = 0, math.huge
  for i = 1, #LOCATIONS do
    local location = LOCATIONS[i]
    local pnt = location.coords
    local new_dist = #(coords - pnt)
    if new_dist < dist then
      clst_pnt, dist = i, new_dist
    end
  end
  return clst_pnt, dist
end

-------------------------------- EVENTS --------------------------------
AddEventHandler('onResourceStart', init_script)
AddEventHandler('onResourceStop', deinit_script)
AddEventHandler('forklift:client:SetupOrder', setup_order)
AddStateBagChangeHandler('forklift:ped:init', '', catch_ped_state)
AddStateBagChangeHandler('', '', sync_object_state_bag)

RegisterNetEvent(LOAD_EVENT, init_script)
RegisterNetEvent(UNLOAD_EVENT, deinit_script)
RegisterNetEvent(JOB_EVENT, init_warehouses)

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