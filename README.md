This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0
International License][cc-by-nc-sa].

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg

# don-forklift
Warehousing script for QBCore

## Dependencies
- [qb-core](https://github.com/qbcore-framework/qb-core)
- [lj-fuel](https://github.com/loljoshie/lj-fuel)

## Features
- Easily configurable locations and highly optimised
- Locked to a job and has automatic duty cycles
- A percantage of money earned through deliveries is sent to the business society

## Job (qb-core/shared/jobs.lua)
- Make sure to add below, or a similar version of, in your shared otherwise the job will not work.

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

All job locations are in the config, change these to your own MLO or use Ultrunz and Benz Warehouse, link below:

- [Warehouse](https://ultrunz.com/store/warehouse)

## Preview
- [Youtube](https://youtu.be/_WErvl12J_w)

## Discord
- [Join Discord](https://discord.gg/tVA58nbBuk)
