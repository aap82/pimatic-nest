module.exports = (env) ->

  Promise = env.require "bluebird"
  M = env.matcher

  class NestActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @plugin, {@thermostat, @attrName, @targetTemp}) ->

    setup: ->
      @dependOnDevice(@thermostat)
      super()


    executeAction: (simulate) =>
      return (
        if simulate
          Promise.resolve(__("would do one of many things"))
        else
          switch @attrName
            when "target_temperature_high"
              @thermostat.changeTargetTempHighTo(@targetTemp).then(=> __("done"))
            when "target_temperature_low"
              @thermostat.changeTargetTempLowTo(@targetTemp).then(=> __("done"))
            else
              @thermostat.changeTargetTempTo(@targetTemp).then(=> __("done"))
      )

    hasRestoreAction: -> no


  class NestTemperatureActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->

    parseAction: (input, context) ->
      thermostats = (device for id, device of @framework.deviceManager.devices when device.config.class is "NestThermostat")
      thermostat = null
      targetType = null
      targetTemp = null
      m = M(input, context)
        .match("set target temperature ")
      m.match("low ", optional: yes, (next,a) => targetType = "low"; m = next)
      m.match("high ", optional: yes, (next,a) => targetType = "high"; m = next)
      m = m.match("of nest thermostat ").matchDevice(thermostats, (next, d) =>
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