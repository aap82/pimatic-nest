module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  {attributes, getAttributeNames, updateAttributes} = require './nest-thermostat-attributes'
  actions = require './nest-thermostat-actions'

  unitChange = (unit) -> if unit is 'c' then 0.5 else 1


  logErrMsg = (msg) ->
    env.logger.error(msg)
    return msg
  longInfoMsg = (msg) ->
    env.logger.info(msg)
    return msg

  class NestThermostat extends env.devices.Device
    attributes: attributes
    actions: actions
#    _blocked: null
    _is_online: null
    _can_cool: null
    _can_heat: null
    _hvac_mode: null
    _hvac_state: null
    _time_to_target: null
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

    getBlocked: -> Promise.resolve(@_blocked)
    getIs_online: ->  Promise.resolve(@_is_online)
    getCan_cool: ->  Promise.resolve(@_can_cool)
    getCan_heat: ->  Promise.resolve(@_can_heat)
    getHvac_mode: -> Promise.resolve(@_hvac_mode)
    getHvac_state: -> Promise.resolve(@_hvac_state)
    getTime_to_target: -> Promise.resolve(@_time_to_target)
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
      return Promise.resolve()
      @updateNest("hvac_mode", mode)

    increment: (attr) => @setTempTo(attr, "#{@["_#{attr}"] + unitChange(@unit)}")
    decrement: (attr) => @setTempTo(attr, "#{@["_#{attr}"] - unitChange(@unit)}")
    setTempTo: (attr, val) =>
      temp = parseFloat(val)
      msg = @checkTempMsg(attr, temp)
      return Promise.reject(logErrMsg msg) if msg?
      return @updateNest(attr, temp).then((msg) -> return msg)



    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      super()
      @_blocked = lastState.blocked?.value or null
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
      @updateState("blocked", null) if @_blocked? and Date.now() > @_blocked
      msg = checkNestMsg(@, attr, value)
      return Promise.reject(logErrMsg msg) if msg?
      key = attr + if attr.includes("temp") then "_#{@unit}" else ""
      @plugin.sendUpdate(@thermostat, key, value)
      .then => return Promise.resolve(longInfoMsg("#{@name} #{attr} set to #{value}"))
      .catch (error) =>
        if error?.code is "BLOCKED" and not @_blocked?
          @_blocked = Date.now() + (@plugin.blockTimeout * 60000)
          @emit "blocked", @_blocked
        return (logErrMsg "Nest Update Error: #{error.code}")

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


checkNestMsg = (therm, attr, value) ->
  return switch
    when therm._blocked? then              "#{therm.name} is blocked for #{parseInt((therm._blocked-Date.now())/60000,10)}m"
    when not therm._is_locked then         "Only locked thermostats may be updated"
    when not therm["_#{attr}"]? then      "Param #{attr} doesnt exist"
    when not therm._is_online then         "#{therm.name} is not online"
    when value is null then           "Can not send null value"
    when therm["_#{attr}"] is value then  "Device #{therm.name} has #{attr} already set to #{value}."
    else null

  



