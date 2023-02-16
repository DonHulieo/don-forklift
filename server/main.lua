local QBCore = exports['qb-core']:GetCoreObject()

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
	QBCore.Functions.AddJobs(Config.Job['logistics'])
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