
local hangar1ID = nil
local pay = {a = 18, b = 22} -- zakres od ile do ile wynosi pay za execution mission
-----------------------------------
local MisjaAktywna = 0

AddEventHandler('playerDropped', function(DropReason)
	if hangar1ID == source then
		hangar1ID = nil
	end
end)

RegisterServerEvent('anzdelivery:takeoverHangar')
AddEventHandler('anzdelivery:takeoverHangar', function(ktory)
	if ktory == '1' then
		if hangar1ID == nil then
			hangar1ID = source
			TriggerClientEvent('QBCore:Notify', source, 'On duty...')
			TriggerClientEvent("anzdelivery:ownHangar", source)
		else
			TTriggerClientEvent('QBCore:Notify', source, 'There is already an employee, '..hangar1ID)
		end
	end
end)

RegisterServerEvent('anzdelivery:leaveHangar')
AddEventHandler('anzdelivery:leaveHangar', function(ktory)
	if ktory == '1' then
		if hangar1ID == source then
			hangar1ID = nil
			TriggerClientEvent('QBCore:Notify', source, 'Off duty...')
			TriggerClientEvent("anzdelivery:leftHangar", source)
		else
			TTriggerClientEvent('QBCore:Notify', source, 'There is already an employee, '..hangar1ID)
		end
	end
end)

RegisterServerEvent('anzdelivery:executionmission')
AddEventHandler('anzdelivery:executionmission', function(bonus)
	local _source = source
	local QBCore = exports['qb-core']:GetCoreObject()
	local PayRate = math.random(pay.a,pay.b)
	local Player = QBCore.Functions.GetPlayer(_source)

	if bonus == 'nie' then
		Player.Functions.AddMoney("cash", PayRate)
		TriggerClientEvent('QBCore:Notify', _source, 'You get $'..PayRate..' for delivery', 'success')
		Wait(2500)
	else
		Player.Functions.AddMoney("cash", bonus)
		Wait(2500)
	end
end)

RegisterServerEvent('anzdelivery:toofar')
AddEventHandler('anzdelivery:toofar', function()
	if hangar1ID == source then
		hangar1ID = nil
	end
end)


