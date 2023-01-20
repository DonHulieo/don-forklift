Config = {}

Config.UseTarget = true -- Set to false if you want to use 3DText instead of QBTarget

Config.Blips = true -- Enable blips on the map
Config.BlipName = "Warehouse Logistics"
Config.UniqueNames = true -- Enable unique names for each warehouse
Config.RequiresJob = false -- Enable if you want to require a job to an order
Config.Job = 'logistics' -- Job name
Config.PalletModel = `prop_boxpile_06a` -- Pallet model

Config.PayScales = {
	min = 50, -- Minimum payout
	max = 100, -- Maximum payout
	bonus = 150, -- Bonus payout if the pallet is below 500 health but higher than 250
	bonus2 = 200, -- Bonus payout if the pallet is below 750 health but higher than 500
	bonus3 = 250, -- Bonus payout if the pallet is below 1000 health but higher than 750
	fromSociety = false, -- Enable if you want to pay from the job's bank account
}

Config.Locations = {
	[1] = {
		jobStart = vector3(1206.38, -3258.93, 5.5), -- Where the player can take orders
		boxzone = { -- Boxzone settings to allow for the most configurabilty 
			length = 1.0,
			width = 2.5,
			heading = 0.0,
		},
		blipSettings = { -- Will use these settings for each blip if Config.UniqueNames is false, just not the label
			sprite = 525,
			color = 28,
			scale = 0.6,
			display = 4,
			label = 'PostOp Warehouse',
		},
		garage = { -- Garage settings
			model = `forklift`,
			coords = vector3(1201.55, -3287.51, 5.5),
			heading = 90.0,
			zone = {
				coords = vector3(1202.16, -3287.55, 5.5),
				length = 3.0,
				width = 2.0,
				heading = 90.0,
  
			},
		},
		pickup = { -- Pickup settings ~~ I wouldn't change the vehicle as the function for finding the back is only setup for the benson ~~
			coords = vector3(1113.12, -3334.41, 5.92),
			heading = 266.6,
			model = `benson`,
			ped = `s_m_m_security_01`,
		},
		delivery = {  -- Where the Pickup vehicle will pickup the pallet
			coords = vector3(1229.2, -3222.6, 5.8),
			heading = 269.37,
		},
		pallets = { -- Pallet locations
			[1] = vector3(1190.23, -3306.25, 5.5),
			[2] = vector3(1199.31, -3308.33, 5.5),
			[3] = vector3(1232.87, -3294.65, 5.5),
			[4] = vector3(1191.27, -3274.08, 5.5),
			[5] = vector3(1223.9, -3246.72, 5.5),
		},
		inUse = false, -- DO NOT TOUCH
		user = nil, -- DO NOT TOUCH
	},
}