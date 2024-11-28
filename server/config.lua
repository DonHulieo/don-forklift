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
    message = 'You have been kicked for leaving the range with a weapon.',
    distance = 2.5
  },
  ['Pay'] = {
    {
      min_per_pallet = 50,
      time_limit = 300
    }
  }
}