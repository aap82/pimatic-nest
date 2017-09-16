module.exports = (env) ->

  Promise = env.require "bluebird"
  M = env.matcher

  class NestActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @plugin, {@thermostat, @attrName, @targetTemp}) ->

    executeAction: (simulate) =>
      if simulate
        Promise.resolve(__("would do one of many things"))
      else
        _action = switch @attrName
          when "target_temperature_high"
            @thermostat.changeTargetTempHighTo(@targetTemp)
          when "target_temperature_low"
            @thermostat.changeTargetTempLowTo(@targetTemp)
          else
            @thermostat.changeTargetTempTo(@targetTemp)
        _action

    hasRestoreAction: -> no


  class NestTemperatureActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->

    parseAction: (input, context) ->
      thermostats = (device for id, device of @framework.deviceManager.devices when device.config.class is "NestThermostat")
      thermostat = null
      targetType = null
      targetTemp = null
      m = M(input, context)
        .match("set target temperature of nest thermostat ")
      m = m.matchDevice(thermostats, (next, d) =>
        thermostat = d
      )
      m = m.match(' to ').matchNumber (next, ts) =>
        targetTemp = ts
      m = m.match('°')
      match = m.getFullMatch()
      if match?
        attrName = "target_temperature" + if targetType? then "_#{targetType}" else ""
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new NestActionHandler(
            @framework, @plugin, { thermostat, attrName, targetTemp }
          )
        }


  return NestTemperatureActionProvider