module.exports = (env) ->

  Promise = env.require 'bluebird'
  M = env.matcher

  class NestActionHandler extends env.actions.ActionHandler
    constructor: (@framework, @plugin, @thermostat) ->
    executeAction: (simulate) ->
      @framework.variableManager.evaluateStringExpression(@thermostat).then (thermostat) =>
        console.log thermostat
        return Promise.resolve()

  class NestActionProvider extends env.actions.ActionProvider
    constructor: (@framework, @plugin) ->

    parseAction: (input, context) ->
      thermostats = (device.name for device in @framework.deviceManager.devicesConfig when device.class is "NestThermostat")
      thermostat = null
      valueTokens = null
      match = M(input, context)
        .match("increment temp of nest thermostat ")
        .matchDevice thermostats, (next, d) =>
          console.log d
          thermostat = d

      if match.hadMatch()
        return {
          token: match.getFullMatch()
          nextInput: input.substring(match.length)
          actionHandler: new NestActionHandler(
            @framework, @plugin, thermostat
          )
        }


  return NestActionProvider