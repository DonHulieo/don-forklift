local duff = duff
local bridge, interval, require = duff.bridge, duff.interval, duff.package.require
---@module 'don-forklift.shared.config'
local config = require 'shared.config'
local DEBUG_MODE <const> = config.DebugMode
local LOCATIONS <const> = config.Locations
---@module 'don-forklift.server.config'
local server_config = require 'server.config'
local DISCORD <const> = server_config.DiscordLogs
local LOGS_ENABLED <const> = DISCORD.enabled
local COLOUR <const> = DISCORD.colour
local IMAGE <const> = DISCORD.image
local WEBHOOK <const> = DISCORD.webhook
local PAY <const> = server_config.Pay

local QBCore = exports['qb-core']:GetCoreObject()
local RES_NAME <const> = GetCurrentResourceName()
---@type {peds: integer[], objs: integer[], vehs: integer[]}
local Warehouses = {}

-------------------------------- FUNCTIONS --------------------------------

---@param text string
local function debug_print(text)
  if not DEBUG_MODE then return end
  print('^3[don^7-^3forklift]^7 - '..text)
end

---@param model number|string
---@param coords vector4|{x: number, y: number, z: number, w: number}
---@param key integer
---@param ped_type 'sign_up'|'garage'
---@return integer ped
local function create_ped(model, coords, key, ped_type)
	local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, true, true)
	SetPedRandomComponentVariation(ped, 0)
	Entity(ped).state['forklift:ped:init'] = {spawn = true, wh_key = key, type = ped_type}
	return ped
end

---@param resource string?
local function init_script(resource)
	if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
	for i = 1, #LOCATIONS do
		local location = LOCATIONS[i]
		local peds = location['Peds']
		Warehouses[i] = Warehouses[i] or {}
		local warehouse = Warehouses[i]
		warehouse.peds = {}
		for j = 1, #peds do
			local ped_data = peds[j]
			---@diagnostic disable-next-line: param-type-mismatch
			warehouse.peds[#warehouse.peds + 1] = create_ped(ped_data.model, ped_data.coords, i, j == 1 and 'sign_up' or 'garage')
		end
	end
end

---@param resource string?
local function deinit_script(resource)
	if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
	for i = 1, #LOCATIONS do
		local warehouse = Warehouses[i]
		for j = 1, #warehouse.peds do
			local ped = warehouse.peds[j]
			if DoesEntityExist(ped) then DeleteEntity(ped) end
		end
		if warehouse.objs then
			for j = 1, #warehouse.objs do
				local obj = warehouse.objs[j]
				if DoesEntityExist(obj) then DeleteEntity(obj) end
			end
		end
		if warehouse.vehs then
			for j = 1, #warehouse.vehs do
				local veh = warehouse.vehs[j]
				if DoesEntityExist(veh) then DeleteEntity(veh) end
			end
		end
		GlobalState:set('forklift:warehouse:'..i, nil, true)
		GlobalState:set('forklift:warehouse:'..i..':last', nil, true)
	end
end

---@param location integer
---@return boolean?, integer?
local function is_player_using_warehouse(location, identifier)
  location = location or GetClosestWarehouse(GetPlayerPed(source))
  if not LOCATIONS[location] then return end
  return GlobalState['forklift:warehouse:'..location] == identifier
end

local function create_timer(location, identifier)
	local src = source
	if not LOCATIONS[location] then return end
	local warehouse = Warehouses[location]
	if warehouse[identifier] then return end
	CreateThread(function()
		local limit = PAY[location].time_limit
		warehouse[identifier] = GetGameTimer()
		repeat Wait(1000) until not warehouse[identifier] or not is_player_using_warehouse(location, identifier) or GetGameTimer() - warehouse[identifier] >= limit
		TriggerClientEvent('forklift:client:SetupOrder', src, location, false, true)
	end)
end

---@param warehouse integer
---@param identifier string
---@param reserve boolean
local function reserve_warehouse(warehouse, identifier, reserve)
	if not LOCATIONS[warehouse] then return end
	local src = source
	if identifier ~= bridge.getidentifier(src) then return end -- Possible exploit banning
	local _, dist = GetClosestWarehouse(GetPlayerPed(src))
	if dist >= 50.0 then return end -- Possible exploit banning
	GlobalState:set('forklift:warehouse:'..warehouse, reserve and identifier or nil, true)
	if not reserve then
		GlobalState:set('forklift:warehouse:'..warehouse..':last', identifier, true)
		Warehouses[warehouse][identifier] = nil
	else
		create_timer(warehouse, identifier)
	end
	debug_print((reserve and 'Reserved' or 'Unreserved')..' warehouse '..warehouse..' for '..bridge.getplayername(src)..' ('..identifier..')')
end

---@param model string|integer
---@return integer hash
local function hash_model(model)
	return type(model) == 'string' and joaat(model) & 0xFFFFFFFF or model --[[@as integer]]
end

---@param player string|integer
---@param model string
---@param coords vector3
---@param location integer
---@return integer? object
local function create_object_cb(player, model, coords, location)
  if not bridge.getplayer(player) then return end
	if not is_player_using_warehouse(GetClosestWarehouse(GetPlayerPed(player)), bridge.getidentifier(player)) then return end -- Possible exploit banning
  local obj = CreateObjectNoOffset(hash_model(model), coords.x, coords.y, coords.z, true, false, false)
  repeat Wait(100) until DoesEntityExist(obj)
	local ent = Entity(obj)
  Entity(obj).state:set('forklift:object:init', true, true)
	Entity(obj).state:set('forklift:object:owner', player, true)
	Entity(obj).state:set('forklift:object:warehouse', location, true)
  SetEntityIgnoreRequestControlFilter(obj, true)
	Warehouses[location].objs = Warehouses[location].objs or {}
	Warehouses[location].objs[#Warehouses[location].objs + 1] = obj
  return NetworkGetNetworkIdFromEntity(obj)
end

---@param model string|integer
---@return string vehicle_type
local function get_vehicle_type(model) -- Credits go to: [QBox](https://github.com/Qbox-project/qbx_core/blob/82cf765b80095293b2d6908be0576f1433a38ee8/modules/lib.lua#L268)
	local temp = CreateVehicle(hash_model(model), 0, 0, -200, 0, true, true)
	repeat Wait(0) until DoesEntityExist(temp)
	local veh_type = GetVehicleType(temp)
	DeleteEntity(temp)
	return veh_type
end

---@param player string|integer
---@param model string|integer
---@param coords vector3|vector4
---@param location integer
---@param driver string|integer?
---@return integer? netID, integer? ped_netID
local function create_vehicle_cb(player, model, coords, location, driver)
	if not bridge.getplayer(player) then return end
	if not is_player_using_warehouse(GetClosestWarehouse(GetPlayerPed(player)), bridge.getidentifier(player)) then return end -- Possible exploit banning
	local veh_type = get_vehicle_type(model)
	local veh = CreateVehicleServerSetter(model, veh_type, coords.x, coords.y, coords.z, coords.w or 0)
  repeat Wait(0) until DoesEntityExist(veh)
	local veh_state = Entity(veh).state
	veh_state:set('forklift:vehicle:init', true, true)
	veh_state:set('forklift:vehicle:owner', player, true)
	veh_state:set('forklift:vehicle:warehouse', location, true)
	SetEntityIgnoreRequestControlFilter(veh, true)
	Warehouses[location].vehs = Warehouses[location].vehs or {}
	Warehouses[location].vehs[#Warehouses[location].vehs + 1] = veh
	local netID = NetworkGetNetworkIdFromEntity(veh)
	local ped = driver and CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, true, true)
	local ped_netID
	if ped then
		repeat Wait(0) until DoesEntityExist(ped)
		local ped_state = Entity(ped).state
		ped_netID = NetworkGetNetworkIdFromEntity(ped)
		ped_state:set('forklift:ped:vehicle', netID, true)
		ped_state:set('forklift:ped:owner', player, true)
		ped_state:set('forklift:ped:warehouse', location, true)
		veh_state:set('forklift:vehicle:driver', ped_netID, true)
		SetPedRandomComponentVariation(ped, 0)
		SetVehicleDoorsLocked(veh, 3)
		SetEntityIgnoreRequestControlFilter(ped, true)
		Warehouses[location].peds[#Warehouses[location].peds + 1] = ped
	end
	return netID, ped and ped_netID
end

---@param location integer
---@param netID integer
local function remove_entity(location, netID)
	local src = source
	local entity = NetworkGetEntityFromNetworkId(netID)
	if not LOCATIONS[location] then return end
	if not DoesEntityExist(entity) then return end
	if not is_player_using_warehouse(GetClosestWarehouse(GetPlayerPed(src)), bridge.getidentifier(src)) then return end -- Possible exploit banning
	local ent_type = GetEntityType(entity)
	local entites = Warehouses[location][ent_type == 1 and 'peds' or ent_type == 2 and 'vehs' or 'objs'] --[[@as integer[]=]]
	DeleteEntity(entity)
	for i = #entites, 1, -1 do
		if entites[i] == entity then table.remove(entites, i) break end
	end
	TriggerClientEvent('forklift:client:RemoveEntity', -1, location, netID)
end

---@param pay number
---@param loads integer
---@param time integer
---@param max_time integer
---@return number score
local function get_pay(pay, loads, time, max_time) -- https://gamedev.stackexchange.com/questions/165604/score-multiplier-based-on-lowest-time
  local max, denom = pay - 1, loads * 0.01
  return (max / (denom ^ (time / max_time))) + 1
end

---@param location integer
---@param identifier string
---@param health number
---@param loads integer
local function finish_mission(location, identifier, health, loads)
	local src = source
	if not bridge.getplayer(src) then return end
	if identifier ~= bridge.getidentifier(src) then return end -- Possible exploit banning
	if not is_player_using_warehouse(location, identifier) then return end -- Possible exploit banning
	local time = Warehouses[location][identifier]
	if not time then return end
	local pay_rates = PAY[location]
	local pay = get_pay(pay_rates.min_per_pallet, loads, math.floor((GetGameTimer() - time) / 1000), pay_rates.time_limit) * health
	print('Time: '..time, 'GameTimer: '..GetGameTimer(), 'Difference: '..(GetGameTimer() - time), 'As Secs:'..math.floor((GetGameTimer() - time) / 1000), 'Health Ratio: '..health, 'Pay: '..pay)
end

---@param entity integer
---@return number, number
function GetClosestWarehouse(entity)
  local coords = GetEntityCoords(entity)
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
---@param name string
---@param key string
---@param value any
---@param replicated boolean
AddStateBagChangeHandler('forklift:object:fin', '', function(name, key, value, _, replicated)
  local obj = GetEntityFromStateBagName(name)
  if not obj or obj == 0 or not DoesEntityExist(obj) then return end
  DeleteEntity(obj)
end)

RegisterServerEvent('forklift:server:ReserveWarehouse', reserve_warehouse)
RegisterServerEvent('forklift:server:RemoveEntity', remove_entity)
RegisterServerEvent('forklift:server:FinishMission', finish_mission)
-------------------------------- CALLBACKS --------------------------------
bridge.createcallback('forklift:server:CreateObject', create_object_cb)
bridge.createcallback('forklift:server:CreateVehicle', create_vehicle_cb)
