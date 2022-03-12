QBCore = exports['qb-core']:GetCoreObject()
local hangar1ID = nil
-----------------------------------

AddEventHandler('playerDropped', function(DropReason)
	if hangar1ID == source then
		hangar1ID = nil
	end
end)

RegisterServerEvent('don-forklift:takeoverHangar')
AddEventHandler('don-forklift:takeoverHangar', function(duty)
	if duty == '1' then
		if hangar1ID == nil then
			hangar1ID = source
			TriggerClientEvent('QBCore:Notify', source, 'On duty...')
			TriggerClientEvent("don-forklift:ownHangar", source)
		else
			TTriggerClientEvent('QBCore:Notify', source, 'There is already an employee, '..hangar1ID)
		end
	end
end)

RegisterServerEvent('don-forklift:leaveHangar')
AddEventHandler('don-forklift:leaveHangar', function(duty)
	if duty == '1' then
		if hangar1ID == source then
			hangar1ID = nil
			TriggerClientEvent('QBCore:Notify', source, 'Off duty...')
			TriggerClientEvent("don-forklift:leftHangar", source)
		else
			TTriggerClientEvent('QBCore:Notify', source, 'There is already an employee, '..hangar1ID)
		end
	end
end)

RegisterServerEvent('don-forklift:executionmission')
AddEventHandler('don-forklift:executionmission', function(bonus)
	local src = source
	local PayRate = math.random(Config.MinPayout, Config.MaxPayout)
	local Player = QBCore.Functions.GetPlayer(src)
	local societypay = math.ceil(PayRate * 4)

	if bonus == 'bonus' then
		Player.Functions.AddMoney("cash", PayRate)
		TriggerClientEvent('QBCore:Notify', src, 'You get $'..PayRate..' for delivery', 'success')
		TriggerEvent('qb-bossmenu:server:addAccountMoney', Player.PlayerData.job.name, societypay)
		Wait(2500)
	else
		Player.Functions.AddMoney("cash", bonus)
		Wait(2500)
	end
end)

RegisterServerEvent('don-forklift:toofar')
AddEventHandler('don-forklift:toofar', function()
	if hangar1ID == source then
		hangar1ID = nil
	end
end)


