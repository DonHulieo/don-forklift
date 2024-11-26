local duff = duff
local bridge, require = duff.bridge, duff.package.require
---@module 'don-forklift.shared.config'
local config = require 'shared.config'
local DEBUG_MODE <const> = config.DebugMode
local LOCATIONS <const> = config.Locations

local QBCore = exports['qb-core']:GetCoreObject()
local RES_NAME <const> = GetCurrentResourceName()
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
	Warehouses.peds = {}
	local wh_peds = Warehouses.peds
	for i = 1, #LOCATIONS do
		local location = LOCATIONS[i]
		local peds = location['Peds']
		Warehouses[i] = Warehouses[i] or {}
		for j = 1, #peds do
			local ped_data = peds[j]
			---@diagnostic disable-next-line: param-type-mismatch
			wh_peds[#wh_peds + 1] = create_ped(ped_data.model, ped_data.coords, i, j == 1 and 'sign_up' or 'garage')
		end
	end
end

---@param resource string?
local function deinit_script(resource)
	if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
	for i = 1, #LOCATIONS do GlobalState:set('forklift:warehouse:'..i, nil, true) end
	for i = 1, #Warehouses.peds do DeleteEntity(Warehouses.peds[i]) end
end

---@param warehouse integer
---@param identifier string
---@param reserve boolean
local function reserve_warehouse(warehouse, identifier, reserve)
	if not LOCATIONS[warehouse] then return end
	local src = source
	if identifier ~= bridge.getidentifier(src) then return end
	GlobalState:set('forklift:warehouse:'..warehouse, reserve and identifier or nil, true)
	if not reserve then GlobalState:set('forklift:warehouse:'..warehouse..':last', identifier, true) end
	debug_print((reserve and 'Reserved' or 'Unreserved')..' warehouse '..warehouse..' for '..bridge.getplayername(src)..' ('..identifier..')')
end

---@param location integer
---@return boolean?, integer?
local function is_player_using_warehouse(location, identifier)
  location = location or GetClosestWarehouse(source)
  if not LOCATIONS[location] then return end
  return GlobalState['forklift:warehouse:'..location] == identifier
end

---@param player string|integer
---@param model string
---@param coords vector3
---@return integer? object
local function create_object_cb(player, model, coords)
  if not bridge.getplayer(player) then return end
	if not is_player_using_warehouse(GetClosestWarehouse(player), bridge.getidentifier(player)) then return end -- Possible exploit banning
	model = type(model) == 'string' and joaat(model) & 0xFFFFFFFF or model
  local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, false, false)
  repeat Wait(100) until DoesEntityExist(obj)
  Entity(obj).state:set('forklift:object:init', true, true)
  SetEntityIgnoreRequestControlFilter(obj, true)
  return NetworkGetNetworkIdFromEntity(obj)
end

---@param player string|integer?
---@return number, number
function GetClosestWarehouse(player)
  local coords = GetEntityCoords(GetPlayerPed(player or source))
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
-------------------------------- CALLBACKS --------------------------------
bridge.createcallback('forklift:server:CreateObject', create_object_cb)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
	if source ~= '' then return false end
	QBCore = exports['qb-core']:GetCoreObject()
end)

---@param k number
RegisterServerEvent('don-forklift:server:Reserve', function(k)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	if Config.RequiresJob and Player.PlayerData.job.name ~= Config.Job then return end
	local identifier = Player.PlayerData.citizenid
	TriggerClientEvent('don-forklift:client:Reserve', -1, k, identifier)
	Config.Locations[k].inUse = true
	Config.Locations[k].user = identifier
end)

---@param k number
RegisterServerEvent('don-forklift:server:Unreserve', function(k)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	if Config.RequiresJob and Player.PlayerData.job.name ~= Config.Job then return end
	if Config.Locations[k].user ~= Player.PlayerData.citizenid then return end
	TriggerClientEvent('don-forklift:client:Unreserve', -1, k)
	Config.Locations[k].inUse = false
	Config.Locations[k].user = nil
end)

---@param current number
---@param bonus number
RegisterServerEvent('don-forklift:server:PayPlayer', function(current, bonus)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	if Config.RequiresJob and Player.PlayerData.job.name ~= Config.Job then return end
	if Config.Locations[current].user ~= Player.PlayerData.citizenid then return end
	local payRate = math.random(Config.PayScales.min, Config.PayScales.max)
	local societypay = math.ceil(payRate * 4)
	if bonus then payRate = payRate + bonus end
	Player.Functions.AddMoney('cash', payRate, "forklift-job")
	TriggerClientEvent('QBCore:Notify', src, 'You get $'..payRate..' for delivery', 'success')
	if Config.RequiresJob then
		local job = Player.PlayerData.job.name
		exports['qb-management']:AddMoney(job, societypay)
		if Config.PayScales.fromSociety then
			exports['qb-management']:RemoveMoney(job, payRate)
		end
	end
end)

-------------------------------- QBCORE --------------------------------

---@param cb function
---@return table
QBCore.Functions.CreateCallback('don-forklift:server:GetLocations', function(source, cb)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	if Config.RequiresJob and Player.PlayerData.job.name ~= Config.Job then return end
	cb(Config.Locations)
end)

if Config.RequiresJob then
	local function getK()
		for k in pairs(Config.Job) do return k end
	end
	local tableName = getK()
	QBCore.Functions.AddJob(tableName, Config.Job[tableName])
	exports['qb-cityhall']:AddCityJob(tableName, {label = Config.Job[tableName].label, isManaged = Config.IsManaged})
end

-------------------------------- THREADS --------------------------------

local sleep = 1
CreateThread(function()
	while true do
		Wait(1000 * 60 * sleep)
		for i = 1, #Config.Locations do
			if Config.Locations[i].inUse then
				sleep = 0.5
				local Player = QBCore.Functions.GetPlayerByCitizenId(Config.Locations[i].user)
				local ped = GetPlayerPed(Player.PlayerData.source)
				local coords = GetEntityCoords(ped)
				local distance = #(coords - Config.Locations[i]['Start'].coords)
				if distance > 500 then
					sleep = 1
					TriggerClientEvent('don-forklift:client:Unreserve', -1, i)
					Config.Locations[i].inUse = false
					Config.Locations[i].user = nil
				end
			end
		end
	end
end)