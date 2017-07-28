module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  {attributes} = require './nest-thermostat-attributes'

  class NestThermostat extends env.devices.Actuator
    attributes: attributes

    _ambient_temperature: null
    _away_temperature_high: null
    _away_temperature_low: null
    _can_cool: null
    _can_heat: null
    _humidity: null
    _hvac_mode: null
    _hvac_state: null
    _is_online: null
    _target_temperature: null
    _target_temperature_high: null
    _target_temperature_low: null
    
    getAmbient_temperature: ->  Promise.resolve(@_ambient_temperature)
    getAway_temperature_high: ->  Promise.resolve(@_away_temperature_high)
    getAway_temperature_low: ->  Promise.resolve(@_away_temperature_low)
    getCan_cool: ->  Promise.resolve(@_can_cool)
    getCan_heat: ->  Promise.resolve(@_can_heat)
    getHumidity: ->  Promise.resolve(@_humidity)
    getHvac_mode: -> Promise.resolve(@_hvac_mode)
    getHvac_state: -> Promise.resolve(@_hvac_state)
    getIs_online: ->  Promise.resolve(@_is_online)
    getTarget_temperature: ->  Promise.resolve(@_target_temperature)
    getTarget_temperature_high: ->  Promise.resolve(@_target_temperature_high)
    getTarget_temperature_low: ->  Promise.resolve(@_target_temperature_low)
    
    constructor: (@config, @plugin) ->
      @id = @config.id
      @name = @config.name
      super()
      @thermostat = null

      for attr,data of @attributes when data.unit is "°"
        @attributes[attr].unit = "°#{@plugin.config.unit.toUpperCase()}"

      @plugin.nestApi.then =>
        @init()
        return Promise.resolve()
      .catch (err) =>
        env.logger.error(err)



    init: =>
      therm = @plugin.thermostats.child(@config.device_id)
      @updateState(key, value) for key, value of therm.val() when key in @plugin.attrNames
      @thermostat = therm.ref()
      @thermostat.ref().on 'child_changed', @handleUpdate


    handleUpdate: (update) =>
      key = update.name()
      return unless key in @plugin.attrNames
      @updateState(key, update.val())


    updateState: (key, state) ->
      attr = if key.includes("temperature") then key.substring(0, key.length-2) else key
      return unless @["_#{attr}"] isnt state
      @["_#{attr}"] = state
      @emit attr, state


    changeStateTo: ->
      return Promise.resolve()

    destroy: () ->
      @thermostat.ref().off()
      super()



  return NestThermostat

