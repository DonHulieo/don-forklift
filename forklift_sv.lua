
local hangar1ID = nil
local payscale = {a = 18, b = 22} -- zakres od ile do ile wynosi payscale za execution mission
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
			TriggerClientEvent(Notify, source, 'On duty...')
			TriggerClientEvent("anzdelivery:ownHangar", source)
		else
			TriggerClientEvent(Notify, source, 'There is already an employee, '..hangar1ID)
		end
	end
end)

RegisterServerEvent('anzdelivery:executionmission')
AddEventHandler('anzdelivery:executionmission', function(bonus)
	local _source = source
	local QBCore = exports['qb-core']:GetCoreObject()
	local PayRate = math.random(payscale.a,payscale.b)
	local Player = QBCore.Functions.GetPlayer(_source)

	if bonus == 'nie' then
		Player.Functions.AddMoney("cash", PayRate)
		TriggerClientEvent(Notify, _source, 'You get $'..PayRate..' for delivery')
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


