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
local Warehouses = {}

-------------------------------- FUNCTIONS --------------------------------

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
    iblips:remove(warehouse.blips.pickup)
    warehouse.blips.pickup = nil
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
