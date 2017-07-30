module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  {attributes, getAttributeNames, updateAttributes} = require './nest-thermostat-attributes'
  actions = require './nest-thermostat-actions'

  unitChange = (unit) -> if unit is 'c' then 0.5 else 1


  logErrMsg = (msg) ->
    env.logger.error(msg)
    return msg

  class NestThermostat extends env.devices.Device
    attributes: attributes
    actions: actions

    _is_online: null
    _can_cool: null
    _can_heat: null
    _hvac_mode: null
    _hvac_state: null
    _has_leaf: null
    _humidity: null
    _ambient_temperature: null
    _is_locked: null
    _target_temperature: null
    _target_temperature_low: null
    _target_temperature_high: null
    _locked_temp_min: null
    _locked_temp_max: null
    _eco_temperature_low: null
    _eco_temperature_high: null


    getIs_online: ->  Promise.resolve(@_is_online)
    getCan_cool: ->  Promise.resolve(@_can_cool)
    getCan_heat: ->  Promise.resolve(@_can_heat)
    getHvac_mode: -> Promise.resolve(@_hvac_mode)
    getHvac_state: -> Promise.resolve(@_hvac_state)
    getHas_leaf: -> Promise.resolve(@_has_leaf)
    getIs_locked: -> Promise.resolve(@_is_locked)
    getHumidity: ->  Promise.resolve(@_humidity)
    getAmbient_temperature: ->  Promise.resolve(@_ambient_temperature)
    getTarget_temperature: ->  Promise.resolve(@_target_temperature)
    getTarget_temperature_low: ->  Promise.resolve(@_target_temperature_low)
    getTarget_temperature_high: ->  Promise.resolve(@_target_temperature_high)
    getLocked_temp_min: -> Promise.resolve(@_locked_temp_min)
    getLocked_temp_max: -> Promise.resolve(@_locked_temp_max)
    getEco_temperature_low: ->  Promise.resolve(@_eco_temperature_low)
    getEco_temperature_high: ->  Promise.resolve(@_eco_temperature_high)

#

    setToCool: -> @setModeTo("cool")
    setToHeat: -> @setModeTo("heat")
    setToOff: ->  @setModeTo("off")
    setModeTo: (mode) ->
      return Promise.reject(logErrMsg  "Thermostat must be Locked to change the mode") if not @_is_locked
      return Promise.reject(logErrMsg  "Mode bust be either heat, cool or off, but #{mode} was requested") if mode not in ["heat", "cool", "off"]
      @updateNest("hvac_mode", mode)

    increment: (attr) =>
      console.log attr
      @setTempTo(attr, "#{@["_#{attr}"] + unitChange(@unit)}")
    decrement: (attr) => @setTempTo(attr, "#{@["_#{attr}"] - unitChange(@unit)}")
    setTempTo: (attr, val) =>
      temp = parseFloat(val)
      msg = @checkTempMsg(attr, temp)
      return Promise.reject(logErrMsg msg) if msg?
      return @updateNest(attr, temp)



    constructor: (@config, @plugin) ->
      @id = @config.id
      @name = @config.name
      super()
      @blocked = null
      @unit = @plugin.config.unit
      @thermostat = null
      @attrNames = null
      @plugin.nestApi.then =>
        @thermostat = @plugin.client.child('devices/thermostats').child(@config.device_id)
        return @plugin
      .then => @plugin.fetchData(@thermostat.ref())
      .then(@init)
      .catch (err) =>
        env.logger.error(err)

    init: (snap) =>
      data = snap.val()
      @unit = data.temperature_scale.toLowerCase()
      @attributes = updateAttributes(@attributes, @unit) if @plugin.config.displayTempScale
      @attrNames = getAttributeNames(@unit)
      @updateState(key, value) for key, value of data when key in @attrNames
      @thermostat.ref().on 'child_changed', @handleUpdate
      return Promise.resolve()

    handleUpdate: (update) =>
      key = update.name()
      return unless key in @attrNames
      @updateState(key, update.val())
      return

    updateState: (key, value) ->
      attr = if key.includes("temp") then key.substring(0, key.length-2) else key
      return unless @["_#{attr}"] isnt value or @["_#{attr}"] isnt undefined
      @["_#{attr}"] = value
      @emit attr, value
      return

    updateNest: (attr, value) =>
      if @blocked? and Date.now() > @blocked then @blocked = null
      msg = @checkNestUpdateMsg(attr, value)
      return Promise.reject(logErrMsg msg) if msg?
      return new Promise (resolve, reject) =>
        @plugin.lastCommandTime = Date.now()
        key = attr + if attr.includes("temp") then "_#{@unit}" else ""
        @thermostat.child(key).set value, (error) =>
          if error
            if error.code is "BLOCKED" and not @blocked?
              @blocked = Date.now() + (@plugin.blockTimeout * 60000)
            reject(logErrMsg "Nest Update Error: #{error.code}")
          else
            resolve()

    checkNestUpdateMsg: (attr, value) ->
      return switch
        when @blocked? then               "#{@name} is blocked for #{parseInt((@blocked-Date.now())/60000+1,10)}m"
        when not @["_#{attr}"]? then      "Param #{attr} doesnt exist"
        when not @_is_online then         "#{@name} is not online"
        when value is null then           "Can not send null value"
        when @["_#{attr}"] is value then  "Device #{@name} has #{attr} already set to #{value}."
        when ((Date.now() - @plugin.lastCommandTime) / 1000) < @plugin.commandBuffer
          "Wait #{@plugin.commandBuffer}s between requests"
        else null

    checkTempMsg: (attr, temp) ->
      switch
        when attr not in @plugin.changeableTemps then "Invalid param: #{attr}"
        when attr is "target_temperature"
          if @_hvac_mode not in ["heat", "cool"] then "hvac_mode must be heat or cool to change target temp"
          else if @_is_locked and not(@_locked_temp_min <= temp <= @_locked_temp_max)
            "#{@name} allowed range: #{@_locked_temp_min}-#{@_locked_temp_max}. Requested: #{temp}"
          else null
        when attr in ["target_temperature_low","target_temperature_high"] and @_hvac_mode isnt "heat-cool"
          "Attr #{attr} can only be changed when hvac_mode is heat-cool"
        else null


    destroy: () ->
      @thermostat.ref().off 'child_changed', @handleUpdate
      super()



  return NestThermostat



