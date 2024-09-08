local QBCore = exports['qb-core']:GetCoreObject()
local LOCATIONS <const> = Config.Locations
local RES_NAME <const> = GetCurrentResourceName()
local Warehouses = {}

-------------------------------- FUNCTIONS --------------------------------

---@param model number|string
---@param coords vector4|{x: number, y: number, z: number, w: number}
---@param data {key: integer, type: string}
---@return integer ped
local function create_ped(model, coords, data)
	local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, true, true)
	SetPedRandomComponentVariation(ped, 0)
	Entity(ped).state['forklift'] = {spawn = true, wh_key = data.key, type = data.type}
	return ped
end

---@param resource string?
local function init_script(resource)
	if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
	Warehouses.peds = {}
	local peds = Warehouses.peds
	for i = 1, #LOCATIONS do
		local location = LOCATIONS[i]
		local start, garage = location['Start'], location['Garage']
		Warehouses[i] = Warehouses[i] or {}
		peds[#peds + 1] = create_ped(start.ped, vec(start.coords.xyz, start.heading), {key = i, type = 'Start'})
		peds[#peds + 1] = create_ped(garage.ped, vec(garage.coords.xyz, garage.heading), {key = i, type = 'Garage'})
	end
end

---@param resource string?
local function deinit_script(resource)
	if resource and type(resource) == 'string' and resource ~= RES_NAME then return end
	for i = 1, #Warehouses.peds do
		DeleteEntity(Warehouses.peds[i])
	end
end

-------------------------------- HANDLERS --------------------------------
AddEventHandler('onResourceStart', init_script)
AddEventHandler('onResourceStop', deinit_script)

-------------------------------- EVENTS --------------------------------

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