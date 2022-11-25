# don-forklift
Warehousing script for QBCore

## Dependencies
- [qb-core](https://github.com/qbcore-framework/qb-core)

## Preview
- [don-forklift](https://youtu.be/_WErvl12J_w)

## Features
- Optimised Code, running at 0.0ms at rest and peaking at 0.2ms whilst using QBTarget, 0.6ms whilst using DrawText
- Can be used for a specific job (set in the config) or for anyone as an activity
- Can be configured for multiple warehouses (set in the config) ~ Currently only 1 is configured
- Earn Bonus Money for completing the job without damaging the pallets
- A percantage of money earned through deliveries is sent to the business society

## Job (qb-core/shared/jobs.lua)
- Make sure to add below, or a similar version of, if using Config.RequiresJob.

```
	["logistics"] = { 
        label = "East Coast Inc.",
        defaultDuty = false,
		offDutyPay = false,
		bossmenu = vector3(152.45, -3105.86, 5.9),
        grades = {
            ['0'] = {
                name = "Trainee",
                payment = 1700
            },
            ['1'] = {
                name = "Storeman",
                payment = 1900
            },
            ['2'] = {
                name = "Labourer",
                payment = 1950
            },
            ['3'] = {
                name = "Team Leader",
                payment = 2000
            },
            ['4'] = {
                name = "Manager",
                payment = 2050
            },
            ['5'] = {
                name = "Delivery Driver",
                payment = 2100
			},	
            ['6'] = {
                name = "Truck Driver",
                payment = 2100
            },
            ['7'] = {
                name = "Foreman",
                payment = 2450
            },
            ['8'] = {
                name = "Owner",
				isboss = true,
                payment = 2800
            },
        },   
    },
```

## Job Locations

- For the Warehouse used in the preview:

- [Warehouse](https://ultrunz.com/store/warehouse)

- Keep in mind this is an expensive MLO and this newest update means you can change and add locations very easily.

# Support

This is not a QBCore script nor is it maintained by them, please refer to my discord for any issues! 
- [discord](https://discord.gg/tVA58nbBuk)

# Changelog
- v1.1.1 - Added Blips to the pickup vehicle, and fixed the issue with Config.RequiresJob blips.
- v1.1.0 - Started Changelog like a noob // Huge Update, now supports multiple warehouses, QBTarget and is much more optimised.
