---@diagnostic disable: undefined-global
local ivec3 = ivec3 --[[@as fun(x: number, y: number, z: number): vector3]] -- Applies integer-casting rules to the input values
---@diagnostic enable: undefined-global
local duff = duff

return {
  ---@type boolean
  ['DebugMode'] = false,
  ---@type {enabled: boolean, pallet: {type: number, colour: {r: number, g: number, b: number, a: number}, scale: vector3}, pickup: {type: number, colour: {r: number, g: number, b: number, a: number}, scale: vector3}}
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
  },
  ---@type fun(vehicle: integer)
  ['Fuel'] = function(vehicle)
    if IsDuplicityVersion() == 1 then return end
    exports['ps-fuel']:SetFuel(vehicle, 100.0)
  end,
  ---@type fun(plate: string)
  ['Keys'] = function(plate)
    if IsDuplicityVersion() == 1 then return end
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
  end,
  ---@type {name: string, coords: vector3, job: string|boolean?, blip: {enabled: boolean, options: {main: blip_options, garage: blip_options, pallet: blip_options, pickup: blip_options}}, Peds: {model: string, coords: vector4, scenario: string, chair: string|number?}[], Garage: {model: string, coords: vector4}, Pickup: {vehicle: string, driver: string, coords: vector4[]}, Pallets: {coords: vector4[], models: string[]}}[]
  ['Locations'] = {
    {
      name = 'Walker Logistics',
      coords = vector3(153.81, -3214.6, 4.93),
      job = 'police',
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
            name = 'Pallet',
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
              short_range = true
            }
          },
          pickup = {
            name = 'Delivery Truck',
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
          coords = vector4(153.81, -3214.6, 4.93, 87.71),
          scenario = 'WORLD_HUMAN_CLIPBOARD'
        }, { -- Garage
          model = `s_m_y_dockwork_01`,
          coords = vector4(120.89, -3184.05, 4.99, 271.27),
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
          vector3(160.38, -3141.0, 5.99),
          vector3(160.65, -3153.77, 5.98),
          vector3(160.43, -3165.1, 5.99),
          vector3(162.71, -3211.25, 5.95),
          vector3(142.92, -3210.27, 5.86),
          vector3(133.71, -3210.35, 5.86),
          vector3(117.83, -3217.85, 6.02),
          vector3(114.89, -3190.58, 6.01),
        },
        models = {
          -- 'prop_boxpile_01a',
          'prop_boxpile_02b',
          'prop_boxpile_02c',
          -- 'prop_boxpile_02d',
          'prop_boxpile_03a',
          -- 'prop_boxpile_04a', too heavy lol
          -- 'prop_boxpile_05a',
          'prop_boxpile_06a',
          -- 'prop_boxpile_06b',
          'prop_boxpile_07a',
          'prop_boxpile_07d',
          -- 'prop_boxpile_08a',
          'prop_boxpile_09a',
          -- 'prop_boxpile_10a',
          -- 'prop_boxpile_10b'
        }
      }
    }
  },
  ---@type fun(source: integer|string?, text: string, type: string, time: integer?)
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
  end,
  ---@type {enabled: boolean, distance: number, icon: {sign_up: string, garage: string}}
  ['Target'] = {
    enabled = true,
    distance = 1.5,
    icon = {
      sign_up = 'fas fa-clipboard-list',
      garage = 'fas fa-warehouse'
    }
  }
}