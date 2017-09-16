module.exports = (env) ->

  Promise = env.require "bluebird"
  M = env.matcher

  class NestTemperatureActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @plugin, @thermostat, @targetTemp) ->
    executeAction: (simulate) =>
      if simulate
        Promise.resolve(__("would change target_temperature of #{@thermostat.id} to #{@targetTemp}"))
      else
        @thermostat.changeTargetTempTo(@targetTemp)
    hasRestoreAction: -> no

  class NestTemperatureActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->
    parseAction: (input, context) ->
      thermostats = (device for id, device of @framework.deviceManager.devices when device.config.class is "NestThermostat")
      thermostat = null
      targetTemp = null
      m = M(input, context).match("set target_temperature of nest thermostat ")
      m = m.matchDevice(thermostats, (next, d) => thermostat = d)
      m = m.match(' to ').matchNumber((next, ts) =>      targetTemp = ts)
      m = m.match('°')
      match = m.getFullMatch()
      if match?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new NestTemperatureActionHandler(
            @framework, @plugin, thermostat, targetTemp
          )
        }

  class NestHVACModeActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @plugin, @thermostat, @hvac_mode) ->
    executeAction: (simulate) =>
      if simulate
        Promise.resolve(__("would change hvac_mode of #{@thermostat.id} to #{@hvac_mode}"))
      else
        @thermostat.changeHVACModeTo(@hvac_mode)
    hasRestoreAction: -> no

  class NestHVACModeActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->
    parseAction: (input, context) ->
      thermostats = (device for id, device of @framework.deviceManager.devices when device.config.class is "NestThermostat")
      thermostat = null
      hvacModes = ["heat-cool", "heat", "cool", "off"]
      hvacMode = null
      m = M(input, context).match("set hvac_mode of nest thermostat ")
      m = m.matchDevice(thermostats, (next, d) => thermostat = d)
      m = m.match(' to ').match(hvacModes, (next, mode) => hvacMode = mode)
      match = m.getFullMatch()
      if match?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new NestHVACModeActionHandler(
            @framework, @plugin, thermostat, hvacMode
          )
        }        


  return {
    NestTemperatureActionProvider
    NestHVACModeActionProvider
  }