local QBCore = exports['qb-core']:GetCoreObject()


Citizen.CreateThread(function() 
    while true do
        Citizen.Wait(1)
        if QBCore == nil then
            TriggerEvent("QBCore:GetObject", function(obj) QBCore = obj end)     ------//// Just change "QBCore:GetObject" to your respective QBCore. Example "QBCore:GetObject" etc.
			Citizen.Wait(200)
        end
	end
end)

Notify = "QBCore:Notify"
