-- Restart consumer resources that had active target registrations when
-- LastMenu stopped, so they re-run their init and re-register their targets.
RegisterNetEvent('LastMenu:__restartConsumers')
AddEventHandler('LastMenu:__restartConsumers', function(consumers)
    for _, res in ipairs(consumers or {}) do
        if type(res) == 'string' and GetResourceState(res) == 'started' then
            ExecuteCommand('restart ' .. res)
        end
    end
end)
