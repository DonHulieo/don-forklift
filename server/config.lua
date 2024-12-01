return {
  ---@type {enabled: boolean, image: string, colour: number, webhook: string}
  ['DiscordLogs'] = {
    enabled = true, -- Whether to log to discord
    image = '', -- Set to the image you want to use for the logs
    colour = 65309, -- The colour of the embed | https://www.spycolor.com/
    webhook = '' -- The webhook to send the logs to.
  },
  ---@type {message: string, distance: number}
  ['Kick'] = {
    message = 'You have been kicked for misusing forklift events.' -- The message to send to the player when they are kicked
  },
  ['Pay'] = {
    { -- Walker Logistics
      min_per_pallet = 50,
      time_limit = 180,
      max_loads = 5
    }, { -- Pacific Shipyard
      min_per_pallet = 50,
      time_limit = 180,
      max_loads = 5
    }, { -- PostOp Depository
      min_per_pallet = 75,
      time_limit = 120,
      max_loads = 3
    }
  }
}