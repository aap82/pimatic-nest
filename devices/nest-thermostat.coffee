module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  {attributes} = require './nest-thermostat-attributes'
  actions = require './nest-thermostat-actions'

  class NestThermostat extends env.devices.Device
    attributes: attributes
    actions: actions

    _ambient_temperature: null
    _can_cool: null
    _can_heat: null
    _eco_temperature_high: null
    _eco_temperature_low: null
    _humidity: null
    _has_leaf: null
    _hvac_mode: null
    _hvac_state: null
    _is_locked: null
    _is_online: null
    _previous_hvac_state: null
    _target_temperature: null




    getAmbient_temperature: ->  Promise.resolve(@_ambient_temperature)
    getCan_cool: ->  Promise.resolve(@_can_cool)
    getCan_heat: ->  Promise.resolve(@_can_heat)
    getEco_temperature_high: ->  Promise.resolve(@_eco_temperature_high)
    getEco_temperature_low: ->  Promise.resolve(@_eco_temperature_low)
    getHumidity: ->  Promise.resolve(@_humidity)
    getHas_leaf: -> Promise.resolve(@_has_leaf)
    getHvac_mode: -> Promise.resolve(@_hvac_mode)
    getHvac_state: -> Promise.resolve(@_hvac_state)
    getIs_locked: -> Promise.resolve(@_is_locked)
    getIs_online: ->  Promise.resolve(@_is_online)
    getPrevious_hvac_state: -> Promise.resolve(@_previous_hvac_state)
    getTarget_temperature: ->  Promise.resolve(@_target_temperature)
#

    setToCool: ->
      @setHVACModeTo("cool")
      return Promise.resolve()
    setToHeat: ->
      @setHVACModeTo("heat")
      return Promise.resolve()
    setToOff: ->
      @setHVACModeTo("off")
      return Promise.resolve()
    setHVACModeTo: (mode) ->
      assert(not @_is_locked)
      assert(mode in ["heat", "cool", "off"])
      @updateNest("hvac_mode", mode).then(=>return Promise.resolve())

    constructor: (@config, @plugin) ->
      @id = @config.id
      @name = @config.name
      super()

      @unit = @plugin.config.unit
      @thermostat = null

      for attr,data of @attributes when data.unit is "°"
        @attributes[attr].unit = "°#{@unit.toUpperCase()}"


      @plugin.nestApi.then =>
        @init()
        return Promise.resolve()
      .catch (err) =>
        env.logger.error(err)



    init: =>
      @thermostat = @plugin.thermostats.child(@config.device_id)
      @updateState(key, value) for key, value of @thermostat.val() when key in @plugin.attrNames
      @thermostat.ref().on 'child_changed', @handleUpdate


    handleUpdate: (update) =>
      key = update.name()
      return unless key in @plugin.attrNames
      @updateState(key, update.val())


    updateState: (key, value) ->
      attr = if key.includes("temperature") then key.substring(0, key.length-2) else key
      return unless @["_#{attr}"] isnt value
      @["_#{attr}"] = value
      @emit attr, value

    updateNest: (attr, value) =>
      assert(@_is_online)
      assert(value isnt null)
      @thermostat.child(attr).set(value)
      return Promise.resolve()

    unitChange: -> if @unit is 'c' then 0.5 else 1


    increment: ->
      newTemp = @_target_temperature + @unitChange()
      @changeTemperatureTo("#{newTemp}")

    decrement: ->
      newTemp = @_target_temperature - @unitChange()
      @changeTemperatureTo("#{newTemp}")

    changeTemperatureTo: (temp) ->
      assert(@_hvac_mode in ['heat', 'cool'])
      newTemp = parseFloat(temp)
      @updateNest("target_temperature_#{@unit}", newTemp).then(=> return Promise.resolve())



    destroy: () ->
      @thermostat.ref().off()
      super()



  return NestThermostat