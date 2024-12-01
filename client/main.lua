local duff, Citizen = duff, Citizen
local iblips = exports.iblips
local array, await, bridge, math, require, streaming = duff.array, duff.await, duff.bridge, duff.math, duff.package.require, duff.streaming
---@module 'don-forklift.shared.config'
local config = require 'shared.config'
local DEBUG_MODE <const> = config.DebugMode
local MARKER <const> = config.Marker
local MARKER_ENABLED <const> = MARKER.enabled
local PALLET_MARKER <const>, PICKUP_MARKER <const> = MARKER.pallet, MARKER.pickup
local SET_FUEL <const> = config.Fuel
local SET_KEYS <const> = config.Keys
local LOCATIONS <const> = config.Locations
local TARGET <const> = config.Target
local USE_TARGET <const> = TARGET.enabled
local TARGET_DIST <const> = TARGET.distance
local TARGET_ICON <const> = TARGET.icon
local NOTIFY = config.Notify
local LOAD_EVENT <const>, UNLOAD_EVENT <const>, JOB_EVENT <const> = bridge['_DATA']['EVENTS'].LOAD, bridge['_DATA']['EVENTS'].UNLOAD, bridge['_DATA']['EVENTS'].JOBDATA
local RES_NAME <const> = GetCurrentResourceName()
local entered_thread, entered_warehouse, isLoggedIn = false, false, false
local Warehouses, Zones = {}, {}
local game_timer = GetGameTimer
local cit_await = Citizen.Await

-------------------------------- FUNCTIONS --------------------------------

---@param key string
---@param label string
local function add_label(key, label)
  if DoesTextLabelExist(key) and GetLabelText(key) == label then return end
  AddTextEntry(key, label)
end

---@param text string
local function debug_print(text)
  if not DEBUG_MODE then return end
  print('^3[don^7-^3forklift]^7 - '..text)
end

---@return integer? location
local function get_warehouse_player_is_using()
  local identifier = bridge.getidentifier()
  for i = 1, #LOCATIONS do
    if GlobalState['forklift:warehouse:'..i] == identifier then return i end
  end
end

---@param location integer
---@param type 'main'|'garage'|'pallet'|'pickup'
---@return boolean? removed
local function remove_blip(location, type)
  if not LOCATIONS[location] then return end
  local warehouse = Warehouses[location]
  local blip = warehouse.blips[type]
  warehouse.blips[type] = nil
  return iblips:remove(blip)
end

---@param x number
---@param y number
---@param z number
---@param label string
local function draw_text_3DS(x, y, z, label)
  local on_screen, _x, _y = World3dToScreen2d(x, y, z)
  local scale = 0.35
  local text = GetLabelText(label)
  if on_screen then
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText(label)
    EndTextCommandDisplayText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 100)
  end
end

---@param location integer
---@return boolean?
local function is_player_using_warehouse(location)
  local identifier = bridge.getidentifier()
  location = location or GetClosestWarehouse()
  if not LOCATIONS[location] then return end
  return GetStateBagValue('global', 'forklift:warehouse:'..location) == identifier
end

---@param location integer
---@param ped_type 'sign_up'|'garage'
---@param entity integer?
---@return number? distance, vector3? coords
local function get_dist_warehouse_ped(location, ped_type, entity)
  if not LOCATIONS[location] then return end
  local warehouse = LOCATIONS[location]
  local ped = warehouse.Peds[ped_type == 'sign_up' and 1 or 2]
  local coords = ped.coords.xyz
  entity = entity or PlayerPedId()
  return #(GetEntityCoords(entity) - coords), coords
end

---@param location integer
---@return boolean? is_using
local function is_any_player_using_warehouse(location)
  location = location or GetClosestWarehouse()
  if not LOCATIONS[location] then return end
  return GetStateBagValue('global', 'forklift:warehouse:'..location) --[[@as integer]] ~= nil
end

local function entry_thread()
  if entered_thread then return end
  local sleep = 5000
  local ped = PlayerPedId()
  if not DoesEntityExist(ped) then repeat Wait(100) until DoesEntityExist(ped) or not isLoggedIn end
  local coords = GetEntityCoords(ped)
  entered_thread = true
  while isLoggedIn do
    Wait(sleep)
    if Zones[GetZoneAtCoords(coords.x, coords.y, coords.z)] then
      sleep = 2500
      local current = GetClosestWarehouse(ped)
      local dist = get_dist_warehouse_ped(current, 'sign_up')
      local location = LOCATIONS[current]
      if location and dist <= 100.0 then
        sleep = 500
        if dist <= 5.0 and not IsNuiFocused() then
          sleep = 0
          local not_user = is_any_player_using_warehouse(current)
          local in_use = is_player_using_warehouse(current)
          local signup_coords = location.coords
          draw_text_3DS(signup_coords.x, signup_coords.y, signup_coords.z + 1.0, not_user and not in_use and 'In Use' or in_use and 'forklift_quit' or 'forklift_signup')
          if dist <= 2.0 then
            if IsControlJustPressed(0, 38) then TriggerEvent('forklift:client:SetupOrder', current, not in_use, in_use) end
          end
        else
          sleep = 500
        end
      else
        sleep = 2500
      end
    else
      sleep = 5000
    end
    coords = GetEntityCoords(ped)
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
        warehouse.blips.main = iblips:initblip('coord', {coords = coords}, blip_data.options.main)
      else
        remove_blip(i, 'main')
      end
    end
    if not USE_TARGET then
      Zones[GetZoneAtCoords(coords.x, coords.y, coords.z)] = i
    end
  end
  return Warehouses
end

---@param resource string? Starting resource name or nil.
local function init_script(resource)
  if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
  if not USE_TARGET then
    add_label('forklift_signup', '[~g~E~w~] - Take Order')
    add_label('forklift_quit', '[~g~E~w~] - Cancel Order')
    add_label('forklift_retrieve', '[~g~E~w~] - Take Forklift')
    add_label('forklift_return', '[~g~E~w~] - Return Forklift')
  end
  init_warehouses()
  isLoggedIn = LocalPlayer.state.isLoggedIn or IsPlayerPlaying(PlayerId())
  if not USE_TARGET then CreateThread(entry_thread) end
end

---@param entity integer The entity ID.
---@param condition (fun(entity: integer): boolean?)? The condition to check if the marker should be drawn.
---@param position vector3? The position to draw the marker at.
local function draw_marker(entity, condition, position)
  if not MARKER_ENABLED then return end
  if not DoesEntityExist(entity) then return end
  local ped = PlayerPedId()
  local coords = position or GetEntityCoords(entity)
  local ply_coords = GetEntityCoords(ped)
  local dist = #(coords - ply_coords)
  local marker_data = GetEntityType(entity) == 3 and PALLET_MARKER or PICKUP_MARKER
  local function draw()
    if not condition then return DoesEntityExist(entity) == 1 end
    return condition(entity)
  end
  CreateThread(function()
    local location = GetClosestWarehouse(ped)
    local mk_type = marker_data.type
    local scale, colour = marker_data.scale, marker_data.colour
    local sleep = 0
    while draw() do
      Wait(sleep)
      coords, ply_coords = position or GetEntityCoords(entity), GetEntityCoords(ped)
      coords = not position and vector3(coords.x, coords.y, coords.z + 2.5) or coords
      dist = #(coords - ply_coords)
      if not isLoggedIn then return end
      if not is_player_using_warehouse(location) then return end
      if dist <= 15.0 then
        sleep = 0
        ---@diagnostic disable-next-line: param-type-mismatch
        DrawMarker(mk_type, coords.x, coords.y, coords.z, 0, 0, 0, 0, 0, 0, scale.x, scale.y, scale.z, colour.r, colour.g, colour.b, colour.a, true, true, 2, false, nil, nil, false)
      else
        sleep = 1000
      end
    end
  end)
end

---@param obj integer
---@param initiate boolean
---@param cancelled boolean
local function setup_mission_obj(obj, initiate, cancelled)
  if not DoesEntityExist(obj) then return end
  if initiate then Wait(100) end
  local netID = ObjToNet(obj)
  local location = GetStateBagValue('entity:'..netID, 'forklift:object:warehouse')
  local warehouse = Warehouses[location]
  local coords = GetEntityCoords(obj)
  local model = GetEntityModel(obj)
  if LOCATIONS[location].job and not bridge.doesplayerhavegroup(nil, LOCATIONS[location].job --[[@as string|string[]=]]) then return end
  if initiate then
    if not NetworkDoesEntityExistWithNetworkId(netID) then return end
    warehouse.objs = warehouse.objs or {}
    warehouse.objs[#warehouse.objs + 1] = obj
    streaming.await.loadmodel(model)
    SetModelAsNoLongerNeeded(model)
    NetworkUseHighPrecisionBlending(netID, true)
    NetworkSetObjectForceStaticBlend(obj, true)
    PlaceObjectOnGroundProperly(obj)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCanBeDamaged(obj, true)
    SetEntityDynamic(obj, true)
    warehouse.blips.objs = warehouse.blips.objs or {}
    warehouse.blips.objs[#warehouse.blips.objs + 1] = iblips:initblip('entity', {entity = obj}, LOCATIONS[location].blip.options.pallet)
    draw_marker(obj)
  else
    TriggerServerEvent('forklift:server:RemoveEntity', location, netID)
    if cancelled then
      local min, max = GetModelDimensions(model)
      local diff = max - min
      local radius = math.sqrt(diff.x^2 + diff.y^2 + diff.z^2) * 0.5
      ClearAreaOfObjects(coords.x, coords.y, coords.z, radius, 2)
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
  local identifier = bridge.getidentifier()
  for i = 1, #objs do
    local obj = objs[i]
    if obj and DoesEntityExist(obj) and Entity(obj).state['forklift:object:owner'] == identifier then return obj end
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
  local identifier = bridge.getidentifier()
  local veh = garage.veh
  if veh and DoesEntityExist(veh) and Entity(veh).state['forklift:vehicle:owner'] == identifier then return veh end
end

---@param vehicle integer
---@param plate string
---@param is_ai boolean?
local function init_vehicle(vehicle, plate, is_ai)
  if not DoesEntityExist(vehicle) then return end
  local model = GetEntityModel(vehicle)
  streaming.await.loadmodel(model)
  SetModelAsNoLongerNeeded(model)
  SetEntityAsMissionEntity(vehicle, true, true)
  SetVehicleNumberPlateText(vehicle, plate)
  SetVehicleEngineOn(vehicle, true, false, false)
  if not is_ai then
    SET_FUEL(vehicle)
    SET_KEYS(plate)
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
  local veh = get_owned_vehicle(location)
  if not is_player_using_warehouse(location) and not get_owned_vehicle(location) then return end
  if job and not bridge.doesplayerhavegroup(nil, job --[[@as string|string[]=]]) then NOTIFY(nil, 'You are not a '..job..'...', 'error') return end
  local ped = PlayerPedId()
  if initiate then
    bridge.triggercallback(nil, 'forklift:server:CreateVehicle', function(netID)
      veh = NetToVeh(netID)
      local plate = 'FORK'..tostring(math.random(1000, 9999))
      Warehouses[location].garage.veh = veh
      init_vehicle(veh, plate)
      TaskEnterVehicle(ped, veh, 5000, -1, 1.0, 1, 0)
      NOTIFY(nil, 'Forklift retrieved from garage...', 'success')
    end, model, coords, location)
  else
    if veh then
      if GetVehiclePedIsIn(ped, false) == veh then
        SetVehicleEngineOn(veh, false, false, false)
        TaskLeaveVehicle(ped, veh, 0)
        repeat Wait(100) until not IsPedInVehicle(ped, veh, false)
      end
      TriggerServerEvent('forklift:server:RemoveEntity', location, VehToNet(veh))
      NOTIFY(nil, 'Forklift returned to garage...', 'success')
      if not is_player_using_warehouse(location) then remove_blip(location, 'garage') end
    else
      NOTIFY(nil, 'You have no forklift to return...', 'error')
    end
  end
end

---@param location integer?
---@return integer? vehicle, integer? driver
local function get_owned_pickup(location)
  location = location or get_warehouse_player_is_using() or GetClosestWarehouse()
  local warehouse = Warehouses[location]
  if not warehouse then return end
  local pickup = warehouse.pickup
  if not pickup then return end
  local identifier = bridge.getidentifier()
  local veh = pickup.veh
  if veh and DoesEntityExist(veh) and Entity(veh).state['forklift:vehicle:owner'] == identifier then return veh, pickup.ped end
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

---@param model string|integer
---@param ped integer
---@param is_driver boolean?
local function init_ped(model, ped, is_driver)
  streaming.await.loadmodel(model)
  SetModelAsNoLongerNeeded(model)
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
    repeat Wait(sleep) until GetSequenceProgress(ped) == progress or not DoesEntityExist(ped) or not isLoggedIn
    cb(ped)
    ClearSequenceTask(sequence)
    return progress
  end)
end

---@param vehicle integer
---@return vector3 coords
local function get_boot_coords(vehicle)
  local height = 0.0
  local coords = vector3(0.0, 0.0, 0.0)
  if GetIsDoorValid(vehicle, 5) then
    coords = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, 'boot'))
  else
    local rr_l, rr_r = GetEntryPositionOfDoor(vehicle, 2), GetEntryPositionOfDoor(vehicle, 3)
    local x, y = (rr_l.x + rr_r.x) * 0.5, (rr_l.y + rr_r.y) * 0.5
    local fnd, z = GetGroundZFor_3dCoord(x, y, rr_l.z, false)
    coords = vector3(x, y, fnd and z or rr_l.z)
    height = GetEntityHeightAboveGround(vehicle) * 0.25
  end
  return GetOffsetFromCoordAndHeadingInWorldCoords(coords.x, coords.y, coords.z, GetEntityHeading(vehicle), 0.0, -1.0, height)
end

---@param coords vector3
---@param dist number
---@return vector3 node
local function get_random_node(coords, dist)
  ---@diagnostic disable-next-line: redundant-parameter, param-type-mismatch
  local _, node = GetRandomVehicleNode(coords.x, coords.y, coords.z, dist, 1, false, true, true)
  return node
end

---@param vehicle integer
---@param state boolean
local function toggle_vehicle_boot(vehicle, state)
  if GetIsDoorValid(vehicle, 5) then
    if not state then
      SetVehicleDoorShut(vehicle, 5, false)
    else
      SetVehicleDoorOpen(vehicle, 5, false, false)
    end
  else
    if not state then
      SetVehicleDoorShut(vehicle, 2, false)
      SetVehicleDoorShut(vehicle, 3, false)
    else
      SetVehicleDoorOpen(vehicle, 2, false, false)
      SetVehicleDoorOpen(vehicle, 3, false, false)
    end
  end
end

---@param location integer
---@param coords vector3
---@param vehicle integer
---@param driver integer
local function deliver_load(location, coords, vehicle, driver)
  if vehicle == 0 or driver == 0 then return end
  if not DoesEntityExist(vehicle) or not DoesEntityExist(driver) then return end
  local netID, ped_netID = VehToNet(vehicle), PedToNet(driver)
  local sequence = init_driving_task(get_random_node(coords, 500.0), vehicle)
  toggle_vehicle_boot(vehicle, false)
  TaskPerformSequence(driver, sequence)
  SetPedKeepTask(driver, true)
  await_sequence(driver, sequence, function()
    TaskVehicleDriveWander(driver, vehicle, 20.0, 2640055)
    SetPedKeepTask(driver, true)
    SetEntityCleanupByEngine(vehicle, true); SetEntityCleanupByEngine(driver, true)
    SetEntityAsMissionEntity(vehicle, false, false); SetEntityAsMissionEntity(driver, false, false)
    TriggerServerEvent('forklift:server:RemoveEntity', location, netID); TriggerServerEvent('forklift:server:RemoveEntity', location, ped_netID)
  end)
end

---@param entity integer
---@return number health_ratio
local function get_damage_ratio(entity)
  return GetEntityHealth(entity) / GetEntityMaxHealth(entity)
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

---@param models (string|integer)[]
---@param coords vector4[]
---@param location integer
---@return integer object
local function init_mission_obj(models, coords, location)
  math.seedrng()
  local rdm_a, rdm_b = math.random(1, #coords), math.random(1, #models)
  local pnt, mdl = coords[rdm_a], models[rdm_b]
  debug_print('Creating Pallet: '..mdl..' at '..pnt)
  return NetToObj(create_object(mdl, pnt, location))
end

---@param location integer
---@param coords vector3
---@param driver integer
---@param vehicle integer
---@param loads integer?
local function await_load(location, coords, driver, vehicle, loads)
  local pallet = get_owned_object(location)
  if not pallet then return end
  local plt_coords = GetEntityCoords(pallet)
  local does_entity_exist = DoesEntityExist
  local dr_coords = get_boot_coords(vehicle)
  local door = GetIsDoorValid(vehicle, 5) and 5 or 3
  local dist = #(dr_coords - plt_coords)
  local warehouse = LOCATIONS[location]
  local Pallets = warehouse.Pallets
  local pnts, mdls = Pallets.coords, Pallets.models
  loads = loads or 1
  return await(function()
    local exists = does_entity_exist(vehicle)
    local cancelled = not is_player_using_warehouse(location)
    local delivered = 0
    local healths = {}
    repeat Wait(500) until GetVehicleDoorAngleRatio(vehicle, door) >= 0.75
    draw_marker(vehicle, function(entity) return GetVehicleDoorAngleRatio(entity, door) >= 0.75 end, dr_coords)
    repeat
      Wait(500)
      if not DoesEntityExist(pallet) then pallet = get_owned_object(location) end
      if not pallet then break end
      plt_coords = GetEntityCoords(pallet)
      dist = #(dr_coords - plt_coords)
      if dist <= 3.0 then
        healths[#healths + 1] = get_damage_ratio(pallet)
        setup_mission_obj(pallet, false, false)
        delivered += 1
        if delivered < loads then
          setup_mission_obj(init_mission_obj(mdls, pnts, location), true, false)
          NOTIFY(nil, 'I still need to deliver '..loads - delivered..' more pallets...', 'info')
        end
      end
      cancelled = not is_player_using_warehouse(location)
      exists = does_entity_exist(vehicle)
    until not exists or delivered >= loads or cancelled or not isLoggedIn
    if not cancelled and delivered >= loads then TriggerServerEvent('forklift:server:FinishMission', location, bridge.getidentifier(), array.foldright(healths, function(a, b) return a + b end, 0) / #healths, loads) end -- Pay player based on health (& possibly time taken).
    remove_blip(location, 'pickup')
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
  local wh_data = Warehouses[location]
  if initiate then
    local _, node = GetClosestVehicleNode(fin.x, fin.y, fin.z, 1, 3.0, 0)
    SetFocusPosAndVel(start.x, start.y, start.z, 0.0, 0.0, 0.0)
    ClearAreaOfVehicles(start.x, start.y, start.z, 10.0, false, false, false, false, false)
    bridge.triggercallback(nil, 'forklift:server:CreateVehicle', function(net_id, driver)
      local veh = NetToVeh(net_id)
      local ped = NetToPed(driver)
      local plate = 'FORK'..tostring(math.random(1000, 9999))
      local sequence = init_driving_task(node, veh, fin)
      wh_data.pickup = wh_data.pickup or {}
      wh_data.pickup.veh = veh
      wh_data.pickup.ped = ped
      init_vehicle(veh, plate, true)
      init_ped(ped_mod, ped, true)
      TaskPerformSequence(ped, sequence)
      SetPedKeepTask(ped, true)
      ClearFocus()
      wh_data.blips.pickup = iblips:initblip('vehicle', {vehicle = veh}, warehouse.blip.options.pickup)
      await_sequence(ped, sequence, function()
        if not DoesEntityExist(veh) or not is_player_using_warehouse(location) then return end
        toggle_vehicle_boot(veh, true)
        NOTIFY(nil, 'The delivery driver has arrived...', 'info')
        await_load(location, start, ped, veh, GetStateBagValue('entity:'..net_id, 'forklift:vehicle:loads') --[[@as integer]])
      end, 4)
    end, veh_mod, start, location, ped_mod)
  else
    if cancelled then
      NOTIFY(nil, 'Notifying dispatch of cancelled order...', 'info')
      remove_blip(location, 'pickup')
    end
    local identifier = bridge.getidentifier()
    local veh, driver = get_owned_pickup(location)
    deliver_load(location, start, veh --[[@as integer]], driver --[[@as integer]])
    TriggerServerEvent('forklift:server:ReserveWarehouse', location, identifier, false)
  end
end

---@param resource string? Stopping resource name or nil.
local function deinit_script(resource)
  if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
  for i = 1, #LOCATIONS do
    local location = LOCATIONS[i]
    local warehouse = Warehouses[i]
    if USE_TARGET then bridge.removezone('forklift_sign_up_target_'..i); bridge.removezone('forklift_garage_target_'..i) end
    if location.blip.enabled and warehouse.blips.main then remove_blip(i, 'main') end
    if warehouse.blips?.garage then remove_blip(i, 'garage') end
    if warehouse.blips?.objs then
      for j = #warehouse.blips.objs, 1, -1 do
        iblips:remove(warehouse.blips.objs[j])
        table.remove(warehouse.blips.objs, j)
      end
    end
    if warehouse.blips?.pickup then remove_blip(i, 'pickup') end
    if is_player_using_warehouse(i) then TriggerServerEvent('forklift:server:ReserveWarehouse', location, bridge.getidentifier(), false) end
    table.wipe(warehouse)
  end
  local current = get_warehouse_player_is_using() or GetClosestWarehouse()
  local obj = get_owned_object(current)
  if obj then setup_mission_obj(obj, false, true) end
  local veh = get_owned_vehicle(current)
  if veh then setup_vehicle(current, false) end
  local pickup = get_owned_pickup(current)
  if pickup then setup_mission_ai(current, false, true) end
  entered_thread, entered_warehouse, isLoggedIn = false, false, false
  Warehouse, Zones = {}, {}
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
      if not isLoggedIn then return end
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
  init_ped(GetEntityModel(entity), entity)
  setup_ped_scenario(entity, LOCATIONS[wh_key]['Peds'][ped_key])
  Warehouses[wh_key] = Warehouses[wh_key] or {}
  Warehouses[wh_key][wh_type] = Warehouses[wh_key][wh_type] or {}
  if not USE_TARGET then return end
  Warehouses[wh_key][wh_type].target = bridge.addlocalentity(entity, {
    {
      name = 'forklift_'..wh_type:lower()..'_target_'..wh_key,
      label = is_start and 'Take Order' or 'Take Forklift',
      icon = TARGET_ICON[wh_type],
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
          return is_player_using_warehouse(wh_key) and get_owned_vehicle(wh_key) == nil
        end
      end,
      distance = TARGET_DIST
    },
    {
      name = 'forklift_'..wh_type:lower()..'_target_cancel_'..wh_key,
      label = is_start and 'Cancel Order' or 'Return Forklift',
      icon = TARGET_ICON[wh_type],
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
      end,
      distance = TARGET_DIST
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

---@param location integer
local function display_garage_texts(location)
  if USE_TARGET then return end
  if not LOCATIONS[location] or entered_warehouse or not isLoggedIn then return end
  entered_warehouse = true
  local ped = PlayerPedId()
  local sleep = 2500
  CreateThread(function()
    local dist, coords = get_dist_warehouse_ped(location, 'garage', ped) --[[@cast dist -?]] --[[@cast coords -?]]
    while entered_warehouse do
      Wait(sleep)
      local has_vehicle = get_owned_vehicle(location)
      if dist <= 5.0 then
        sleep = 0
        draw_text_3DS(coords.x, coords.y, coords.z, not has_vehicle and 'forklift_retrieve' or 'forklift_return')
        if dist <= 2.0 then
          if IsControlJustPressed(0, 38) then TriggerEvent('forklift:client:SetupVehicle', location, not has_vehicle) end
        end
      else
        sleep = 2500
      end
      dist = get_dist_warehouse_ped(location, 'garage', ped)
    end
  end)
end

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
  local wrh_data = Warehouses[location]
  local identifier = bridge.getidentifier()
  TriggerServerEvent('forklift:server:ReserveWarehouse', location, identifier, initiate)
  setup_mission_ai(location, initiate, cancelled)
  if initiate then
    local job = does_warehouse_require_job(location)
    local pallets = warehouse.Pallets
    if job and not bridge.doesplayerhavegroup(nil, job --[[@as string|string[]=]]) then NOTIFY(nil, 'You are not a '..job..'...', 'error') return end
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    setup_mission_obj(init_mission_obj(pallets.models, pallets.coords, location), true, false)
    wrh_data.blips.garage = iblips:initblip('coord', {coords = warehouse.Peds[2].coords.xyz}, warehouse.blip.options.garage)
    if not USE_TARGET then display_garage_texts(location) end
    NOTIFY(nil, 'Delivery is marked...', 'success', 2500)
    Wait(1000)
    ClearPedTasks(ped)
  else
    setup_mission_obj(get_owned_object(location) --[[@as integer]], false, cancelled)
    if cancelled then
      if get_owned_vehicle(location) then setup_vehicle(location, false) end
      NOTIFY(nil, 'Order cancelled...', 'error')
    end
  end
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
  if warehouse.pickup and warehouse.pickup.veh == entity then
    remove_blip(location, 'pickup')
    table.wipe(warehouse.pickup)
  end
  if DoesEntityExist(entity) then
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
  end
  debug_print('Entity removed from warehouse: '..location)
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
AddEventHandler('forklift:client:SetupVehicle', setup_vehicle)
AddStateBagChangeHandler('forklift:ped:init', '', catch_ped_state)

RegisterNetEvent(LOAD_EVENT, init_script)
RegisterNetEvent(UNLOAD_EVENT, deinit_script)
RegisterNetEvent(JOB_EVENT, init_warehouses)
RegisterNetEvent('forklift:client:SetupOrder', setup_order)
RegisterNetEvent('forklift:client:RemoveEntity', remove_entity)
