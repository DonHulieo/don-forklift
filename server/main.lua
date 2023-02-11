local QBCore = exports['qb-core']:GetCoreObject()

-------------------------------- EVENTS --------------------------------

RegisterServerEvent('don-forklift:server:reserve', function(k, ped)
  TriggerClientEvent('don-forklift:client:reserve', -1, k, ped)
end)

RegisterServerEvent('don-forklift:server:unreserve', function(k)
  TriggerClientEvent('don-forklift:client:unreserve', -1, k)
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
