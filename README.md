# don-forklift

Warehousing System with Forklift Logistics for FiveM!

## Features

- Optimised Code, Resmon of 0~0.02ms. Peaking Whilst Creating the Pallets, and Worst Case Reaching 0.06ms if Using DrawText.
- Fully Configurable Warehousing System.
- Configurable Locations which Allow for Multiple Warehouses, each with their Own Vehicles, Themes and Job Requirements.
- Configurable Test Types, Display Times, Target Limits, Required Weapons and Rewarded Licenses.
- Payments for Deliveries, with Penalties for Late Deliveries and Damaged Pallets.
- Strong Exploit Protection, with all Sensitive Data being Stored on the Server.
- 3 Locations Pre-Configured, with the Ability to Add More.
- Discord Logs for Payments and Exploits.

## Table of Contents

- [don-forklift](#don-forklift)
  - [Features](#features)
  - [Table of Contents](#table-of-contents)
    - [Preview](#preview)
    - [Installation](#installation)
      - [Dependencies](#dependencies)
      - [Initial Setup](#initial-setup)
    - [Configuration](#configuration)
      - [Shared](#shared)
        - [Debug Mode](#debug-mode)
        - [Marker](#marker)
        - [Fuel](#fuel)
        - [Keys](#keys)
        - [Locations](#locations)
        - [Notifications](#notifications)
        - [Target](#target)
      - [Server](#server)
        - [DiscordLogs](#discordlogs)
        - [Kick](#kick)
        - [Pay](#pay)
    - [Support](#support)
    - [Changelog](#changelog)

### Preview

- [don-forklift](https://youtu.be/_WErvl12J_w)

### Installation

#### Dependencies

**This script requires the following scripts to be installed:**

- [duff](https://github.com/DonHulieo/duff)
- [iblips](https://github.com/DonHulieo/iblips)

**Depending on your Framework, Inventory and if you use a Targetting system, you will need to have installed either of the following dependencies:**

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [es_extended](https://github.com/esx-framework/esx_core)
- [ox_target](https://github.com/overextended/ox_target)
- [qb-target](https://github.com/qbcore-framework/qb-target)
- [ox_lib](https://github.com/overextended/ox_lib)

#### Initial Setup

- Always use the latest FiveM artifacts (tested on 6683), you can find them [here](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/).
- Download the latest release from [Realeases](https://github.com/DonHulieo/don-forklift/releases).
- Extract the contents of the zip file into your resources folder, into a folder which starts after your framework & `duff` or;
- Ensure the script in your `server.cfg` after your framework & `duff`.
- Configure `shared/config.lua` & `server/config.lua` to your liking, see [Configuration](#configuration) for more information.

**Note:** This script automatically configures it's Core functions to work with your framework.

### Configuration

#### Shared

##### Debug Mode

```lua
['DebugMode'] = false
```

- `DebugMode` boolean, whether to show debug messages in the console.

##### Marker

```lua
['Marker'] = {
  enabled = true,
  pallet = {
    type = 0,
    colour = {r = 240, g = 160, b = 1, a = 255},
    scale = vector3(1.0, 1.0, 1.0)
  },
  pickup = {
    type = 1,
    colour = {r = 135, g = 30, b = 35, a = 155},
    scale = vector3(1.5, 1.5, 1.5)
  }
}
```

- `enabled` boolean, whether to enable the markers.
- `pallet|pickup` table, the marker settings for the pallets and pickups.
  - `type` integer, the marker type. More information can be found [here](https://docs.fivem.net/docs/game-references/markers/).
  - `colour` table, the colour of the marker.
    - `r` integer, the red value.
    - `g` integer, the green value.
    - `b` integer, the blue value.
    - `a` integer, the alpha value.
  - `scale` vector3, the scale of the marker.

##### Fuel

```lua
['Fuel'] = function(vehicle)
  if IsDuplicityVersion() == 1 then return end
  exports['ps-fuel']:SetFuel(vehicle, 100.0)
end
```

- `Fuel` function, this is used to set the fuel of the vehicle when it is spawned. You can use this to set the fuel in your own way. Whether that be ps-fuel, LegacyFuel or some other fuel resource.

##### Keys

```lua
['Keys'] = function(plate)
  if IsDuplicityVersion() == 1 then return end
  TriggerEvent('vehiclekeys:client:SetOwner', plate)
end
```

- `Keys` function, this is used to set the owner of the vehicle when it is spawned. You can use this to set the owner in your own way.

##### Locations

```lua
['Locations'] = {
  {
    name = 'Walker Logistics',
    coords = vector3(153.81, -3214.6, 4.93),
    job = false,
    blip = {
      enabled = true,
      options = {
        main = {
          name = 'Walker Logistics',
          colours = {
            opacity = 255,
            primary = 28
          },
          display = {
            category = 'jobs',
            display = 'all_select'
          },
          style = {
            sprite = 525,
            scale = 0.5,
            short_range = true
          }
        },
        garage = {
          name = 'Garage',
          colours = {
            opacity = 255,
            primary = 28
          },
          display = {
            category = 'mission',
            display = 'all_select'
          },
          style = {
            sprite = 357,
            scale = 0.6,
            short_range = true
          },
          distance = 250.0,
        },
        pallet = {
          colours = {
            opacity = 255,
            primary = 70
          },
          display = {
            category = 'mission',
            display = 'radar_only'
          },
          style = {
            sprite = 478,
            scale = 0.8,
            -- short_range = true
          }
        },
        pickup = {
          colours = {
            opacity = 255,
            primary = 2
          },
          display = {
            category = 'mission',
            display = 'radar_only'
          },
          style = {
            sprite = 67,
            scale = 0.8,
            short_range = true
          }
        }
      }
    },
    ['Peds'] = {
      { -- Sign In
        model = `s_m_y_airworker`,
        coords = vector4(153.81, -3214.6, 5.86, 87.71),
        scenario = 'WORLD_HUMAN_CLIPBOARD'
      }, { -- Garage
        model = `s_m_y_dockwork_01`,
        coords = vector4(120.89, -3184.05, 5.92, 271.27),
        scenario = 'WORLD_HUMAN_AA_COFFEE'
      }
    },
    ['Garage'] = {
      model = `forklift`,
      coords = vector4(128.15, -3183.94, 5.87, 269.27)
    },
    ['Pickup'] = {
      vehicle = `benson`,
      driver = `s_m_m_security_01`,
      coords = {
        vector4(305.12, -2831.82, 6.0, 91.27), -- Start
        vector4(159.18, -3196.7, 6.01, 90.43) -- Stop
      }
    },
    ['Pallets'] = {
      coords = {
        vector4(160.38, -3141.0, 5.99, 270.0),
        vector4(160.65, -3153.77, 5.98, 270.0),
        vector4(160.43, -3165.1, 5.99, 270.0),
        vector4(162.71, -3211.25, 5.95, 270.0),
        vector4(142.92, -3210.27, 5.86, 270.0),
        vector4(133.71, -3210.35, 5.86, 180.0),
        vector4(117.83, -3217.85, 6.02, 180.0),
        vector4(114.89, -3190.58, 6.01, 90.0),
      },
      models = {
        'prop_boxpile_02b',
        'prop_boxpile_02c',
        'prop_boxpile_03a',
        'prop_boxpile_06a',
        'prop_boxpile_07a',
        'prop_boxpile_07d',
        'prop_boxpile_09a'
      }
    }
  }
}
```

- `name` string, the name of the location.
- `coords` vector4, the coordinates of the location.
- `blip.enabled` boolean, whether to show a blip for the location.
- `blip.options` table, blip_options, see [here](https://github.com/DonHulieo/iblips?tab=readme-ov-file#options) for more information.
  - `main` blip_options, the main blip options.
  - `garage` blip_options, the garage blip options.
  - `pallet` blip_options, the pallet blip options.
  - `pickup` blip_options, the pickup blip options.
- `['Peds']` table[], the ped settings for the location.
  - `model` integer, the model of the ped.
  - `coords` vector4, the coordinates of the ped.
  - `scenario` string, the scenario of the ped.
- `['Garage']` table, the garage settings for the location.
  - `model` integer, the model of the garage.
  - `coords` vector4, the coordinates of the garage.
- `['Pickup']` table, the pickup settings for the location.
  - `vehicle` integer, the model of the pickup vehicle.
  - `driver` integer, the model of the driver.
  - `coords` vector4[], the coordinates of the pickup vehicle.
- `['Pallets']` table, the pallet settings for the location.
  - `coords` vector4[], the coordinates of the pallets.
  - `models` string[], the models of the pallets.

##### Notifications

```lua
['Notify'] = function(source, text, type, time)
  local src = source
  local types = {['error'] = 'error', ['success'] = 'success', ['primary'] = 'primary'}
  -- Use the above table to change notify types to suit your notification resource
  local is_server = IsDuplicityVersion() == 1
  if is_server and not src then return end
  -- ServerSide Notification
  if is_server then
    -- local Player = duff.bridge.getplayer(src)
    -- if not Player then return end
    -- Player.showNotification(text)
    TriggerClientEvent('QBCore:Notify', src, text, types[type] or 'primary', time)
  else
    -- ClientSide Notification
    local Core = duff.bridge.getcore()
    -- Core.ShowNotification(text, types[type] or 'primary', time)
    Core.Functions.Notify(text, types[type] or 'primary', time)
  end
end
```

- `Notify` function, this is used to send notifications to the player. You can use this to send notifications to the player in your own way. Whether that be okok, base QB or ox_lib!
- `types` table, this is used to change the notification types to suit your notification resource. The default is set to `qb`'s notification types. To change this, simply change the value of the key to the type of notification you want to send. (ie. for okok, change `['primary'] = 'primary'` to `['primary'] = 'info'`).

##### Target

```lua
['Target'] = {
  enabled = true,
  distance = 1.5,
  icon = {
    sign_up = 'fas fa-clipboard-list',
    garage = 'fas fa-warehouse'
  }
}
```

- `enabled` boolean, whether to use a target system or drawtext.
- `distance` float, the distance the player has to be within to see the target.
- `icon` table, the icons for the target. You can find the icons [here](https://fontawesome.com/icons).
  - `sign_up` string, the icon for the sign up target.
  - `garage` string, the icon for the garage target.

#### Server

##### DiscordLogs

```lua
['DiscordLogs'] = {
  enabled = true,
  image = '',
  colour = 65309,
  webhook = ''
}
```

- `enabled` boolean, whether to log to discord.
- `image` string, the image to use for the logs.
- `colour` integer, the colour of the embed, you can find the colours [here](https://www.spycolor.com/).
- `webhook` string, the webhook to send the logs to.

##### Kick

```lua
['Kick'] = {
  message = 'You have been kicked for misusing forklift events.'
}
```

- `message` string, the message to send to the player when they are kicked.

##### Pay

```lua
['Pay'] = {
  { -- Walker Logistics
    min_per_pallet = 50,
    time_limit = 180,
    max_loads = 5
  }
}
```

- `Pay` table[], the payment settings for the locations. The index of the table should match the index of the location in the `Locations` table.
  - `min_per_pallet` integer, the minimum payment per pallet.
  - `time_limit` integer, the time limit for the job.
  - `max_loads` integer, the maximum loads for the job.

### Support

- Join my [discord](https://discord.gg/tVA58nbBuk) and use the relative support channels.

### Changelog

- [Releases](https://github.com/DonHulieo/don-shootingrange/compare/1.2...v1.3.0)
