Config = {}

Config.UseTarget = false -- Set to false if you want to use 3DText instead of QBTarget

Config.Blips = true -- Enable blips on the map
Config.BlipName = "Warehouse Logistics"
Config.UniqueNames = true -- Enable unique names for each warehouse
Config.RequiresJob = false -- Enable if you want to require a job to an order
Config.Job = 'logistics' -- Job name
Config.PalletModel = `prop_boxpile_06a` -- Pallet model
Config.PalletMarkers = { -- Pallet markers | https://docs.fivem.net/docs/game-references/markers/ | Set to false to disable markers
	type = 0,
	color = {r = 240, g = 160, b = 1, a = 255},
	scale = {x = 1.0, y = 1.0, z = 1.0}
}

Config.PayScales = {
	min = 50, -- Minimum payout
	max = 100, -- Maximum payout
	bonus = 150, -- Bonus payout if the pallet is below 500 health but higher than 250
	bonus2 = 200, -- Bonus payout if the pallet is below 750 health but higher than 500
	bonus3 = 250, -- Bonus payout if the pallet is below 1000 health but higher than 750
	fromSociety = false -- Enable if you want to pay from the job's bank account
}

Config.Locations = {
	[1] = {
		['Start'] = {
			ped = `s_m_y_airworker`,
			coords = vector3(1206.38, -3258.93, 4.5), -- Where the player can take orders
			heading = 90.0,
			scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		['Blips'] = { -- Will use these settings for each blip if Config.UniqueNames is false, just not the label
			sprite = 525,
			color = 28,
			scale = 0.6,
			display = 4,
			label = 'PostOp Warehouse'
		},
		['Garage'] = { -- Garage settings
			model = `forklift`,
			ped = `s_m_m_dockwork_01`,
			coords = vector3(1201.55, -3287.51, 5.5),
			heading = 90.0,
			scenario = 'WORLD_HUMAN_AA_COFFEE',
			['Spawn'] = {
				coords = vector3(1202.16, -3287.55, 5.5),
				length = 3.0,
				width = 2.0,
				heading = 90.0
  
			}
		},
		['Pickup'] = { -- Pickup settings ~~ I wouldn't change the vehicle as the function for finding the back is only setup for the benson ~~
			model = `benson`,
			ped = `s_m_m_security_01`,
			['Spawn'] = {
				coords = vector3(1113.12, -3334.41, 4.92),
				heading = 266.6
			},
			['Delivery'] = {
				coords = vector3(1229.2, -3222.6, 5.8),
				heading = 269.37
			}
		},
		['Pallets'] = { -- Pallet locations
			[1] = vector3(1190.23, -3306.25, 5.5),
			[2] = vector3(1199.31, -3308.33, 5.5),
			[3] = vector3(1232.87, -3294.65, 5.5),
			[4] = vector3(1191.27, -3274.08, 5.5),
			[5] = vector3(1223.9, -3246.72, 5.5)
		},
		inUse = false, -- DO NOT TOUCH
		user = nil -- DO NOT TOUCH
	},
	[2] = {
		['Start'] = {
			ped = `s_m_y_airworker`,
			coords = vector3(153.81, -3214.6, 4.93), -- Where the player can take orders vector4(153.81, -3214.6, 5.93, 87.71)
			heading = 87.71,
			scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		['Blips'] = { -- Will use these settings for each blip if Config.UniqueNames is false, just not the label
			sprite = 525,
			color = 28,
			scale = 0.6,
			display = 4,
			label = 'Walker Logistics'
		},
		['Garage'] = { -- Garage settings
			model = `forklift`,
			ped = `s_m_y_dockwork_01`,
			coords = vector3(120.89, -3184.05, 4.99), 
			heading = 265.37,
			scenario = 'WORLD_HUMAN_AA_COFFEE',
			['Spawn'] = {
				coords = vector3(128.15, -3183.94, 5.87),
				heading = 269.27

			}
		},
		['Pickup'] = { -- Pickup settings ~~ I wouldn't change the vehicle as the function for finding the back is only setup for the benson ~~
			model = `benson`,
			ped = `s_m_m_security_01`,
			['Spawn'] = {
				coords = vector3(305.12, -2831.82, 6.0),
				heading = 91.27
			},
			['Delivery'] = {
				coords = vector3(159.18, -3196.7, 6.01), -- vector3(239.94, -3055.34, 5.86),
				heading = 90.43 -- 81.6,
			},
		},
		['Pallets'] = { -- Pallet locations
			[1] = vector3(147.43, -3210.50, 5.86),
			[2] = vector3(143.17, -3210.38, 5.86),
			[3] = vector3(134.61, -3210.25, 5.86),
			[4] = vector3(125.64, -3210.20, 5.91),
			[5] = vector3(160.31, -3048.72, 5.99),
			[6] = vector3(134.59, -3183.82, 5.86),
			[7] = vector3(141.33, -3183.54, 5.86),
			[8] = vector3(146.61, -3183.73, 5.86),
			[9] = vector3(140.61, -3190.46, 5.86),
			[10] = vector3(116.4, -3141.36, 6.01),
			[11] = vector3(117.53, -3217.86, 6.02),
			[12] = vector3(157.57, -3220.12, 7.03) 
		},
		inUse = false, -- DO NOT TOUCH
		user = nil -- DO NOT TOUCH
	},
	[3] = {
		['Start'] = {
			ped = `s_m_y_airworker`,
			coords = vector3(-69.09, -2654.16, 6.00), -- Where the player can take orders
			heading = 90.0,
			scenario = 'WORLD_HUMAN_CLIPBOARD'
		},
		['Blips'] = { -- Will use these settings for each blip if Config.UniqueNames is false, just not the label
			sprite = 525,
			color = 28,
			scale = 0.6,
			display = 4,
			label = 'ALRP Warehouse'
		},
		['Garage'] = { -- Garage settings
			model = `forklift`,
			ped = `s_m_y_dockwork_01`,
			coords = vector3(-61.47, -2653.63, 5.00),
			heading = 8.0,
			scenario = 'WORLD_HUMAN_AA_COFFEE',
			['Spawn'] = {
				coords = vector3(-61.47, -2653.63, 6.00),
				length = 3.0,
				width = 2.0,
				heading = 8.0

			}
		},
		['Pickup'] = { -- Pickup settings ~~ I wouldn't change the vehicle as the function for finding the back is only setup for the benson ~~
			coords = vector3(-197.98, -2598.65, 6.0), -- vector3(-197.98, -2598.65, 6.0),
			heading = 176.56, -- 176.56,
			model = `benson`,
			ped = `s_m_m_security_01`,
			['Spawn'] = {
				coords = vector3(-197.98, -2598.65, 6.0), -- vector3(-197.98, -2598.65, 6.0),
				heading = 176.56 -- 176.56,
			},
			['Delivery'] = {
				coords = vector3(-16.77, -2638.06, 5.48), -- vector3(-13.96, -2659.44, 6.00),
				heading = 182.33 -- 182.33,
			}
		},
		['Pallets'] = { -- Pallet locations
			[1] = vector3(-111.65, -2692.01, 6.01),
			[2] = vector3(-115.09, -2707.64, 6.02),
			[3] = vector3(-128.16, -2705.70, 6.01),
			[4] = vector3(-127.63, -2699.01, 6.01),
			[5] = vector3(-105.28, -2684.25, 6.00),
			[6] = vector3(-128.53, -2676.68, 6.04),
			[7] = vector3(-128.17, -2662.53, 6.00),
			[8] = vector3(-115.97, -2660.89, 6.01),
			[9] = vector3(-116.96, -2639.18, 6.05)
		},
		inUse = false, -- DO NOT TOUCH
		user = nil -- DO NOT TOUCH
	}
}