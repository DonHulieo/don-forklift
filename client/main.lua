local duff, Citizen = duff, Citizen
local iblips = exports.iblips
local array, await, blips, bridge, math, require, streaming = duff.array, duff.await, duff.blips, duff.bridge, duff.math, duff.package.require, duff.streaming
---@module 'don-forklift.shared.config'
local config = require 'shared.config'
local DEBUG_MODE <const> = config.DebugMode
local MARKER <const> = config.Marker
local MARKER_ENABLED <const> = MARKER.enabled
local MARKER_TYPE <const> = MARKER.type
local MARKER_COLOUR <const> = MARKER.colour
local MARKER_SCALE <const> = MARKER.scale
local FUEL_SYSTEM <const> = config.FuelSystem
local LOCATIONS <const> = config.Locations
local NOTIFY = config.Notify
local LOAD_EVENT <const>, UNLOAD_EVENT <const>, JOB_EVENT <const> = bridge['_DATA']['EVENTS'].LOAD, bridge['_DATA']['EVENTS'].UNLOAD, bridge['_DATA']['EVENTS'].JOBDATA
local RES_NAME <const> = GetCurrentResourceName()
local entered_thread, entered_warehouse, isLoggedIn = false, false, false
local game_timer = GetGameTimer
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

---@return integer? location
local function get_warehouse_player_is_using()
  local identifier = bridge.getidentifier()
  for i = 1, #LOCATIONS do
    if GlobalState['forklift:warehouse:'..i] == identifier then return i end
  end
end

---@return table warehouses
local function init_warehouses()
  for i = 1, #LOCATIONS do
    local location = LOCATIONS[i]
    local coords = location.coords
    local blip_data = location.blip
    Warehouses[i] = Warehouses[i] or {}
    local warehouse = Warehouses[i]
    warehouse.blips = warehouse.blips or {}
    if blip_data.enabled then
      local main_blip = warehouse.blips.main
      local has_job = not location.job or location.job and bridge.doesplayerhavegroup(nil, location.job --[[@as string|string[]=]])
      if not main_blip and has_job then
        warehouse.blips.main = iblips:initblip('coord', {coords = coords}, blip_data.options)
      else
        iblips:remove(main_blip)
        warehouse.blips.main = nil
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
    -- short_range = true
  },
  -- distance = 250.0,
}

---@param entity integer The entity ID.
local function draw_marker(entity, condition, position)
  if not MARKER_ENABLED then return end
  if not DoesEntityExist(entity) then return end
  local ped = PlayerPedId()
  local coords = not position and GetEntityCoords(entity) or position
  local ply_coords = GetEntityCoords(ped)
  local dist = #(coords - ply_coords)
  CreateThread(function()
    local sleep = 0
    while condition and condition(entity) or DoesEntityExist(entity) do
      Wait(sleep)
      coords, ply_coords = not position and GetEntityCoords(entity) or position, GetEntityCoords(ped)
      dist = #(coords - ply_coords)
      if dist <= 15.0 then
        sleep = 0
        ---@diagnostic disable-next-line: param-type-mismatch
        DrawMarker(MARKER_TYPE, coords.x, coords.y, coords.z + 2.5, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, MARKER_COLOUR.r, MARKER_COLOUR.g, MARKER_COLOUR.b, MARKER_COLOUR.a, true, true, 2, false, nil, nil, false)
      else
        sleep = 1000
      end
    end
  end)
end

---@param obj integer
---@param initiate boolean
---@param cancelled boolean
---@param sync_state boolean
local function setup_mission_obj(obj, initiate, cancelled, sync_state)
  if not DoesEntityExist(obj) then return end
  if initiate then Wait(100) end
  local netID = ObjToNet(obj)
  local location = GetStateBagValue('entity:'..netID, 'forklift:object:warehouse')
  local warehouse = Warehouses[location]
  local coords = GetEntityCoords(obj)
  local model = GetEntityModel(obj)
  if initiate then
    if not NetworkDoesEntityExistWithNetworkId(netID) then return end
    warehouse.objs = warehouse.objs or {}
    warehouse.objs[#warehouse.objs + 1] = obj
    SetModelAsNoLongerNeeded(model)
    NetworkUseHighPrecisionBlending(netID, true)
    NetworkSetObjectForceStaticBlend(obj, true)
    PlaceObjectOnGroundProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCanBeDamaged(obj, true)
    SetEntityDynamic(obj, true)
    warehouse.blips.objs = warehouse.blips.objs or {}
    warehouse.blips.objs[#warehouse.blips.objs + 1] = iblips:initblip('entity', {entity = obj}, PALLET_BLIP)
    draw_marker(obj)
  else
    local ent = Entity(obj)
    if sync_state then ent.state:set('forklift:object:fin', true, true) end
    TriggerServerEvent('forklift:server:RemoveEntity', location, netID)
    if cancelled then
      local min, max = GetModelDimensions(model)
      local diff = max - min
      local radius = math.sqrt(diff.x^2 + diff.y^2 + diff.z^2) * 0.5
      ClearAreaOfObjects(coords.x, coords.y, coords.z, radius, 2)
    end
    for i = #warehouse.objs, 1, -1 do
      if warehouse.objs[i] == obj then
        table.remove(warehouse.objs, i)
        iblips:remove(warehouse.blips.objs[i])
        table.remove(warehouse.blips.objs, i)
        break
      end
    end
  end
end

---@param location integer?
---@return integer? object
local function get_owned_object(location)
  location = location or get_warehouse_player_is_using() or GetClosestWarehouse()
  local warehouse = Warehouses[location]
  if not warehouse then return end
  local objs = warehouse.objs
  if not objs then return end
  local server_id = GetPlayerServerId(PlayerId())
  for i = 1, #objs do
    local obj = objs[i]
    if obj and DoesEntityExist(obj) and Entity(obj).state['forklift:object:owner'] == server_id then return obj end
  end
end

---@param location integer?
---@return integer? vehicle
local function get_owned_vehicle(location)
  location = location or get_warehouse_player_is_using() or GetClosestWarehouse()
  local warehouse = Warehouses[location]
  if not warehouse then return end
  local garage = warehouse.garage
  if not garage then return end
  local server_id = GetPlayerServerId(PlayerId())
  local veh = garage.veh
  if veh and DoesEntityExist(veh) and Entity(veh).state['forklift:vehicle:owner'] == server_id then return veh end
end

local PICKUP_BLIP <const> = {
  name = 'Drop Off',
  colours = {
    opacity = 255,
    primary = 2
  },
  display = {
    category = 'mission',
    display = 'radar_only'
  },
  style = {
    sprite = 67,
    scale = 0.8,
    -- short_range = true
  },
  -- distance = 250.0,
}

---@param vehicle integer
---@param plate string
---@param is_ai boolean?
local function init_vehicle(vehicle, plate, is_ai)
  if not DoesEntityExist(vehicle) then return end
  SetEntityAsMissionEntity(vehicle, true, true)
  SetVehicleNumberPlateText(vehicle, plate)
  SetVehicleEngineOn(vehicle, true, false, false)
  if not is_ai then
    exports[FUEL_SYSTEM]:SetFuel(vehicle, 100.0)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
  else
    N_0x6ebfb22d646ffc18(vehicle, false)
    N_0x182f266c2d9e2beb(vehicle, 250.0)
    SetVehicleHandlingHashForAi(vehicle, -1103972294)
  end
end

---@param location integer
---@param initiate boolean
local function setup_vehicle(location, initiate)
  if not LOCATIONS[location] then return end
  local warehouse = LOCATIONS[location]
  local job = warehouse.job
  local garage = warehouse.Garage
  local model = garage.model
  local coords = garage.coords
  if not is_player_using_warehouse(location) then NOTIFY(nil, 'Someone is already doing this order!', 'error') return end
  if job and not bridge.doesplayerhavegroup(nil, job --[[@as string|string[]=]]) then NOTIFY(nil, 'You are not a '..job..'...', 'error') return end
  local ped = PlayerPedId()
  if initiate then
    bridge.triggercallback(nil, 'forklift:server:CreateVehicle', function(net_id)
      local veh = NetToVeh(net_id)
      local plate = 'FORK'..tostring(math.random(1000, 9999))
      Warehouses[location].garage.veh = veh
      init_vehicle(veh, plate)
      TaskEnterVehicle(ped, veh, 5000, -1, 1.0, 1, 0)
      NOTIFY(nil, 'Forklift retrieved from garage...', 'success')
    end, model, coords, location)
  else
    local veh = get_owned_vehicle(location)
    if veh then
      if GetVehiclePedIsIn(ped, false) == veh then
        SetVehicleEngineOn(veh, false, false, false)
        TaskLeaveVehicle(ped, veh, 0)
        repeat Wait(100) until not IsPedInVehicle(ped, veh, false)
      end
      TriggerServerEvent('forklift:server:RemoveEntity', location, VehToNet(veh))
      NOTIFY(nil, 'Forklift returned to garage...', 'success')
    else
      NOTIFY(nil, 'You have no forklift to return...', 'error')
    end
  end
end

local function get_owned_pickup(location)
  location = location or get_warehouse_player_is_using() or GetClosestWarehouse()
  local warehouse = Warehouses[location]
  if not warehouse then return end
  local pickup = warehouse.pickup
  if not pickup then return end
  local server_id = GetPlayerServerId(PlayerId())
  local veh = pickup.veh
  if veh and DoesEntityExist(veh) and Entity(veh).state['forklift:vehicle:owner'] == server_id then return veh, pickup.ped end
end

---@param location integer
---@return boolean? is_using
local function is_any_player_using_warehouse(location)
  location = location or GetClosestWarehouse()
  if not LOCATIONS[location] then return end
  return GlobalState['forklift:warehouse:'..location] ~= nil
end

---@param coords vector3
---@param vehicle integer
---@param park vector4?
---@return integer sequence
local function init_driving_task(coords, vehicle, park)
  local sequence = OpenSequenceTask()
  TaskSetBlockingOfNonTemporaryEvents(0, true)
  TaskEnterVehicle(0, vehicle, -1, -1, 1.0, 3, 0)
  TaskVehicleDriveToCoordLongrange(0, vehicle, coords.x, coords.y, coords.z, 20.0, 2640055, 30.0)
  if park then TaskVehiclePark(0, vehicle, park.x, park.y, park.z, park.w, 1, 20.0, true) end
  TaskPause(0, 1000)
  CloseSequenceTask(sequence)
  return sequence
end

---@param ped integer
---@param is_driver boolean?
local function init_ped(ped, is_driver)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetEntityInvincible(ped, true)
  SetPedDiesWhenInjured(ped, false)
  SetPedCanPlayAmbientAnims(ped, true)
  SetPedCanRagdollFromPlayerImpact(ped, false)
  FreezeEntityPosition(ped, not is_driver)
  if not is_driver then return end
  SetDriverAbility(ped, 1.0)
  SetDriverAggressiveness(ped, 0.0)
end

---@param ped integer
---@param sequence integer
---@param cb fun(ped)
---@param progress integer?
---@param sleep integer?
---@return integer progress
local function await_sequence(ped, sequence, cb, progress, sleep)
  progress = progress or -1
  sleep = sleep or 1000
  return await(function()
    repeat Wait(sleep) until GetSequenceProgress(ped) == progress or not DoesEntityExist(ped)
    cb(ped)
    ClearSequenceTask(sequence)
    return progress
  end)
end

---@param vehicle integer
---@return vector3 coords
local function get_door_coords(vehicle)
  local dr_coords = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, 'boot'))
  return GetOffsetFromCoordAndHeadingInWorldCoords(dr_coords.x, dr_coords.y, dr_coords.z, GetEntityHeading(vehicle), 0.0, -0.5, 0.0)
end

---@param coords vector3
---@param dist number
---@return vector3 node
local function get_random_node(coords, dist)
  ---@diagnostic disable-next-line: redundant-parameter, param-type-mismatch
  local _, node = GetRandomVehicleNode(coords.x, coords.y, coords.z, dist, 1, false, true, true)
  return node
end

local function deliver_load(location, coords, vehicle, driver)
  local netID, ped_netID = VehToNet(vehicle), PedToNet(driver)
  local sequence = init_driving_task(get_random_node(coords, 500.0), vehicle)
  SetVehicleDoorShut(vehicle, 5, false)
  TaskPerformSequence(driver, sequence)
  SetPedKeepTask(driver, true)
  await_sequence(driver, sequence, function()
    TaskVehicleDriveWander(driver, vehicle, 20.0, 2640055)
    SetPedKeepTask(driver, true)
    SetEntityCleanupByEngine(vehicle, true); SetEntityCleanupByEngine(driver, true)
    TriggerServerEvent('forklift:server:RemoveEntity', location, netID); TriggerServerEvent('forklift:server:RemoveEntity', location, ped_netID)
  end)
end

---@param entity integer
---@return number health_ratio
local function get_damage_ratio(entity)
  return GetEntityHealth(entity) / GetEntityMaxHealth(entity)
end

local function await_load(location, coords, driver, vehicle, loads)
  local pallet = get_owned_object(location)
  if not pallet then return end
  local plt_coords = GetEntityCoords(pallet)
  local does_entity_exist = DoesEntityExist
  local dr_coords = get_door_coords(vehicle)
  local dist = #(dr_coords - plt_coords)
  loads = loads or 1
  return await(function()
    local identifier = bridge.getidentifier()
    local exists = does_entity_exist(vehicle)
    local cancelled = not is_player_using_warehouse(location)
    local delivered = 0
    local healths = {}
    repeat
      Wait(1000)
      plt_coords = GetEntityCoords(pallet)
      dist = #(dr_coords - plt_coords)
      if dist <= 2.0 then
        healths[#healths + 1] = get_damage_ratio(pallet)
        setup_mission_obj(pallet, false, false, true)
        delivered += 1
      end
      cancelled = not is_player_using_warehouse(location)
      exists = does_entity_exist(vehicle)
    until not exists or delivered >= loads or cancelled
    TriggerServerEvent('forklift:server:FinishMission', location, identifier, array.foldright(healths, function(a, b) return a + b end, 0) / #healths, loads) -- Pay player based on health (& possibly time taken).
    iblips:remove(Warehouses[location].pickup.blip)
    deliver_load(location, coords, vehicle, driver)
  end)
end

---@param location integer
---@param initiate boolean
---@param cancelled boolean
local function setup_mission_ai(location, initiate, cancelled)
  local warehouse = LOCATIONS[location]
  if not warehouse then return end
  if is_any_player_using_warehouse(location) and not is_player_using_warehouse(location) then return end
  local pickup = warehouse.Pickup
  local veh_mod = pickup.vehicle
  local ped_mod = pickup.driver
  local start = pickup.coords[1]
  local fin = pickup.coords[2]
  if initiate then
    local _, node = GetClosestVehicleNode(fin.x, fin.y, fin.z, 1, 3.0, 0)
    SetFocusPosAndVel(start.x, start.y, start.z, 0.0, 0.0, 0.0)
    ClearAreaOfVehicles(start.x, start.y, start.z, 10.0, false, false, false, false, false)
    bridge.triggercallback(nil, 'forklift:server:CreateVehicle', function(net_id, driver)
      Wait(500)
      local veh = NetToVeh(net_id)
      local ped = NetToPed(driver)
      local plate = 'FORK'..tostring(math.random(1000, 9999))
      local sequence = init_driving_task(node, veh, fin)
      Warehouses[location].pickup = Warehouses[location].pickup or {}
      Warehouses[location].pickup.veh = veh
      Warehouses[location].pickup.ped = ped
      init_vehicle(veh, plate, true)
      init_ped(ped, true)
      TaskPerformSequence(ped, sequence)
      SetPedKeepTask(ped, true)
      ClearFocus()
      await_sequence(ped, sequence, function()
        SetVehicleDoorOpen(veh, 5, false, false)
        local coords = get_door_coords(vehicle)
        repeat Wait(100) until GetVehicleDoorAngleRatio(veh, 5) >= 0.75
        draw_marker(veh, function() return GetVehicleDoorAngleRatio(veh, 5) >= 0.75 end, coords)
        NOTIFY(nil, 'The delivery driver has arrived...', 'info')
      end, 4)
      await_load(location, start, ped, veh)
    end, veh_mod, start, location, ped_mod)
  else
    local identifier = bridge.getidentifier()
    local veh, driver = get_owned_pickup(location)
    deliver_load(location, start, veh, driver)
    TriggerServerEvent('forklift:server:ReserveWarehouse', location, identifier, false)
    if cancelled then
      iblips:remove(Warehouses[location].pickup.blip)
      table.wipe(Warehouses[location].pickup)
    end
  end
end

---@param resource string? Stopping resource name or nil.
local function deinit_script(resource)
  if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
  local current = get_warehouse_player_is_using() or GetClosestWarehouse()
  local obj = get_owned_object(current)
  if obj then setup_mission_obj(obj, false, true, true) end
  local veh = get_owned_vehicle(current)
  if veh then setup_vehicle(current, false) end
  local pickup = get_owned_pickup(current)
  if pickup then setup_mission_ai(current, false, true) end
  for i = 1, #LOCATIONS do
    local location = LOCATIONS[i]
    local warehouse = Warehouses[i]
    if location.blip.enabled and warehouse.blips.main then iblips:remove(warehouse.blips.main) end
    if warehouse.garage then iblips:remove(warehouse.garage.blip); table.wipe(warehouse.garage) end
    if warehouse.pickup then iblips:remove(warehouse.pickup.blip); table.wipe(warehouse.pickup) end
    if is_player_using_warehouse(i) then TriggerServerEvent('forklift:server:ReserveWarehouse', location, bridge.getidentifier(), false) end
    table.wipe(warehouse)
  end
end

---@param entity integer
---@return boolean
local function catch_entity(entity)
  local does_entity_exist = DoesEntityExist
  return await(function(ent)
    local time = game_timer()
    local exists = does_entity_exist(ent)
    while not exists and not math.timer(time, 60000) do
      Wait(250)
      time, exists = game_timer(), does_entity_exist(ent)
    end
    if exists then
      SetEntityCleanupByEngine(entity, true)
      N_0xb2e0c0d6922d31f2(entity, true)
    end
    return exists
  end, entity)
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
          TriggerEvent('forklift:client:SetupVehicle', wh_key, true)
        end
      end,
      canInteract = function()
        if is_start then
          return not is_any_player_using_warehouse(wh_key) and get_owned_object(wh_key) == nil
        else
          return is_any_player_using_warehouse(wh_key) and get_owned_vehicle(wh_key) == nil
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
          TriggerEvent('forklift:client:SetupVehicle', wh_key, false)
        end
      end,
      canInteract = function()
        if is_start then
          return is_player_using_warehouse(wh_key) and get_owned_object(wh_key) ~= nil
        else
          return get_owned_vehicle(wh_key) ~= nil
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
---@param cancelled boolean
local function setup_order(location, initiate, cancelled)
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local warehouse = LOCATIONS[location]
  local dist = #(coords - warehouse.coords)
  if dist > 50.0 then return end
  if is_any_player_using_warehouse(location) and not is_player_using_warehouse(location) then NOTIFY(nil, 'Someone is already doing this order!', 'error') return end
  local identifier = bridge.getidentifier()
  TriggerServerEvent('forklift:server:ReserveWarehouse', location, identifier, initiate)
  setup_mission_ai(location, initiate, cancelled)
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
    print('Pallet Model:', mdl)
    local pallet = NetToObj(create_object(mdl, pnt, location))
    -- setup_mission_obj(pallet, true, false, true)
    Warehouses[location].garage = Warehouses[location].garage or {}
    Warehouses[location].garage.blip = iblips:initblip('coord', {coords = warehouse.Garage.coords.xyz}, GARAGE_BLIP)
    NOTIFY(nil, 'Delivery is marked...', 'success', 2500)
    Wait(1000)
    ClearPedTasks(ped)
  else
    setup_mission_obj(get_owned_object(location) --[[@as integer]], false, cancelled, true)
    if cancelled then
      if get_owned_vehicle(location) then setup_vehicle(location, false) end
      NOTIFY(nil, 'Order canceled...', 'error')
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
    setup_mission_obj(obj, true, false, false)
  elseif key == 'forklift:object:fin' then
    -- local location = value
    -- DeleteObject(obj)
  end
end

---@param name string
---@param key string
---@param value any
---@param replicated boolean
local function catch_driver_state(name, key, value, _, replicated)
  if not value then return end
  local veh = GetEntityFromStateBagName(name)
  if not veh or veh == 0 or not DoesEntityExist(veh) or not catch_entity(veh) then return end
  local netID = VehToNet(veh)
  local location = GetStateBagValue('entity:'..netID, 'forklift:vehicle:warehouse')
  Warehouses[location] = Warehouses[location] or {}
  Warehouses[location].pickup = Warehouses[location].pickup or {}
  Warehouses[location].pickup.blip = iblips:initblip('vehicle', {vehicle = veh}, PICKUP_BLIP)
end

---@param location integer
---@param netID integer
local function remove_entity(location, netID)
  if not NetworkDoesEntityExistWithNetworkId(netID) then return end
  local entity = NetToObj(netID)
  local warehouse = Warehouses[location]
  if not warehouse then return end
  for i = 1, #warehouse.objs do
    if warehouse.objs[i] == entity then
      table.remove(warehouse.objs, i)
      iblips:remove(warehouse.blips.objs[i])
      table.remove(warehouse.blips.objs, i)
      break
    end
  end
  if warehouse.pallet and warehouse.pallet.obj == entity then
    iblips:remove(warehouse.pallet.blip)
    table.wipe(warehouse.pallet)
  end
  if warehouse.pickup and warehouse.pickup.veh == entity then
    iblips:remove(warehouse.pickup.blip)
    table.wipe(warehouse.pickup)
  end
  if DoesEntityExist(entity) then DeleteEntity(entity) end
end

---@param entity integer?
---@return number, number
function GetClosestWarehouse(entity)
  local ped = entity or PlayerPedId()
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
AddEventHandler('forklift:client:SetupVehicle', setup_vehicle)
AddStateBagChangeHandler('forklift:ped:init', '', catch_ped_state)
AddStateBagChangeHandler('', '', sync_object_state_bag)
AddStateBagChangeHandler('forklift:vehicle:driver', '', catch_driver_state)

RegisterNetEvent(LOAD_EVENT, init_script)
RegisterNetEvent(UNLOAD_EVENT, deinit_script)
RegisterNetEvent(JOB_EVENT, init_warehouses)
RegisterNetEvent('forklift:client:RemoveEntity', remove_entity)

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