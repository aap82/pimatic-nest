module.exports = (env) ->
  Promise = env.require "bluebird"
  M = env.matcher

  class NestThermostatTargetTempActionHandler extends env.actions.ActionHandler
    constructor: (@thermostat, @actionType, @targetTemp=null) ->
    executeAction: (simulate) =>
      if simulate
        Promise.resolve(__("would change target_temperature of #{@thermostat.id} to #{@targetTemp}"))
      else
        switch @actionType
          when 'decrement' then @thermostat.decrementTargetTemp()
          when 'increment' then @thermostat.incrementTargetTemp()
          when 'set' then       @thermostat.changeTargetTempTo(@targetTemp) if @targetTemp?
          else return Promise.resolve()

    hasRestoreAction: -> no

  class NestThermostatTargetTempActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->
    parseAction: (input, context) ->
      thermostats = (device for id, device of @framework.deviceManager.devices when device.config.class is "NestThermostat")
      return null unless thermostats.length > 0
      thermostat = null
      actionType = null
      targetTemp = null
      m = M(input, context)
        .match([
          "decrement target_temperature of "
          "increment target_temperature of "
          "set target_temperature of "
        ], (next,s) => actionType = s?.split(" ")[0]
      )
      m = m.matchDevice(thermostats, (next, d) => thermostat = d)

      if actionType is 'set'
        m = m.match(' to ').matchNumber((next, ts) => targetTemp = ts)
        unit = '°' + if thermostat? then thermostat.config.temp_scale else ''
        m = m.match("#{unit}")
      match = m.getFullMatch()

      if match?
        thermostat._isValidTemp(targetTemp) if actionType is 'set'
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new NestThermostatTargetTempActionHandler(thermostat, actionType, targetTemp)
        }

  class NestHVACModeActionHandler extends env.actions.ActionHandler
    constructor: (@thermostat, @hvac_mode) ->
    executeAction: (simulate) =>
      if simulate
        Promise.resolve(__("would change hvac_mode of #{@thermostat.id} to #{@hvac_mode}"))
      else
        @thermostat.changeHVACModeTo(@hvac_mode)
    hasRestoreAction: -> no

  class NestThermostatHVACModeActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->
    parseAction: (input, context) ->
      thermostats = (device for id, device of @framework.deviceManager.devices when device.config.class is "NestThermostat")
      return null unless thermostats.length > 0
      thermostat = null
      hvacModes = ["heat-cool", "heat", "cool", "off"]
      hvacMode = null
      m = M(input, context).match("set hvac_mode of ")
      m = m.matchDevice(thermostats, (next, d) => thermostat = d)
      m = m.match(' to ').match(hvacModes, (next, mode) => hvacMode = mode)
      match = m.getFullMatch()
      if match?
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new NestHVACModeActionHandler(thermostat, hvacMode)
        }

  return {
    NestThermostatTargetTempActionProvider
    NestThermostatHVACModeActionProvider
  }