# don-forklift

Warehousing script for QBCore

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core)

## Preview

- [don-forklift](https://youtu.be/_WErvl12J_w)

## Features

- Optimised Code, running at 0.0ms at rest and peaking at 0.2ms whilst using QBTarget, 0.5ms whilst using DrawText
- Can be used for a specific job (set in the config) or for anyone as an activity
- Can be configured for multiple warehouses (set in the config) ~ Supports 3 warehouses by default and Ultrunz's Warehouse
- Earn Bonus Money for completing the job without damaging the pallets
- A percentage of money earned through deliveries is sent to the business society

## Installation

- Download the latest release from [here]()
- Extract the don-forklift folder to your resources folder
- Add `ensure don-forklift` to your server.cfg
- Edit the config.lua to your liking

- **Note:** If RequiresJob is set to true, the job can be set in the config, if set to false, the job is not required.

### When using the Job Requirement

- You don't need to add the job to your qb-core config, as it will be added automatically
- Find the following code in qb-cityhall/server/main.lua, in the 'qb-cityhall:server:ApplyJob' Event

```lua
  if QBCore.Shared.QBJobsStatus then
    exports["qb-jobs"]:submitApplication(data, "Jobs")
  else
    local JobInfo = QBCore.Shared.Jobs[job]
    Player.Functions.SetJob(data.job, 0)
    TriggerClientEvent('QBCore:Notify', data.src, Lang:t('info.new_job', { job = JobInfo.label }))
  end
```

- Replace it with the following code

```lua
  if QBCore.Shared.QBJobsStatus then
    exports["qb-jobs"]:submitApplication(data, "Jobs")
  else
    local JobInfo = QBCore.Shared.Jobs[job] or availableJobs[job]
    Player.Functions.SetJob(data.job, 0)
    TriggerClientEvent('QBCore:Notify', data.src, Lang:t('info.new_job', { job = JobInfo.label }))
  end
```

## Job Locations

- For the Warehouse used in the preview:

- [Warehouse](https://ultrunz.com/store/warehouse)

- Keep in mind this is an expensive MLO and this newest update means you can change and add locations very easily.

## Support

This is not a QBCore script nor is it maintained by them, please refer to my discord for any issues!

- [discord](https://discord.gg/tVA58nbBuk)

## Changelog

- v1.1.2 - Fixed issue with Player not being able to take a 2nd job and Cleaned the Benson Rear Doors shutting thanks to @ChickenDipper
- v1.1.1 - Added Blips to the pickup vehicle, and fixed the issue with Config.RequiresJob blips.
- v1.1.0 - Started Changelog like a noob // Huge Update, now supports multiple warehouses, QBTarget and is much more optimised.
