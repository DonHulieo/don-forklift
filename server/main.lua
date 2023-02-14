local QBCore = exports['qb-core']:GetCoreObject()

-------------------------------- EVENTS --------------------------------

RegisterServerEvent('don-forklift:server:reserve', function(k)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	if Config.RequiresJob and Player.PlayerData.job.name ~= Config.Job then return end
	local identifier = Player.PlayerData.citizenid
  	TriggerClientEvent('don-forklift:client:reserve', -1, k, identifier)
	Config.Locations[k].inUse = true
	Config.Locations[k].user = identifier
end)

RegisterServerEvent('don-forklift:server:unreserve', function(k)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player then return end
	if Config.RequiresJob and Player.PlayerData.job.name ~= Config.Job then return end
	local identifier = Player.PlayerData.citizenid
	if Config.Locations[k].user ~= identifier then return end
  	TriggerClientEvent('don-forklift:client:unreserve', -1, k)
	Config.Locations[k].inUse = false
	Config.Locations[k].user = nil
end)

RegisterServerEvent('don-forklift:server:payPlayer', function(bonus)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local payRate = math.random(Config.PayScales.min, Config.PayScales.max)
	local societypay = math.ceil(payRate * 4)
	local job = Player.PlayerData.job.name
	if bonus then
		payRate = payRate + bonus
	end
	Player.Functions.AddMoney('cash', payRate, "forklift-job")
	TriggerClientEvent('QBCore:Notify', src, 'You get $'..payRate..' for delivery', 'success')
	if Config.RequiresJob then
		exports['qb-management']:AddMoney(job, societypay)
		if Config.PayScales.fromSociety then
			exports['qb-management']:RemoveMoney(job, payRate)
		end
	end
end)
