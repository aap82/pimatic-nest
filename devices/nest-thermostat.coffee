module.exports = (env) ->
  _ = require '../utils'
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  nestThermostatAttributes = require './nest-thermostat-attributes'
  nestThermostatActions = require './nest-thermostat-actions'
  tempAttrs = [
    'ambient_temperature'
    'target_temperature'
    'target_temperature_low'
    'target_temperature_high'
    'locked_temp_min'
    'locked_temp_max'
    'eco_temperature_low'
    'eco_temperature_high'
  ]


  class NestThermostat extends env.devices.Device
    actions: nestThermostatActions
    @property 'blocked',
      get: -> @thermState.is_blocked
      set: (block) ->
        @thermState.is_blocked = switch block
          when yes then Date.now() + @blockTime
          else null


    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @unit = @config.temp_scale.toLowerCase()
      @unitChange =  if @unit is 'c' then 0.5 else 1
      @blockTime = 20 * 60000
      @thermostat = null
      @thermState = {}
      @attributes = _.clone(@attributes)
      @attrNames = []
      for attrName, attrProps of nestThermostatAttributes
        do (attrName, attrProps) =>
          @attrNames.push attrName
          @attributes[attrName] = _.clone(attrProps)
          if attrName in tempAttrs
            if @config.show_temp_scale
              @attributes[attrName].unit = "°#{@config.temp_scale}"
          @thermState[attrName] = null
          if attrName is 'is_blocked' and lastState.is_blocked?.value?
            @thermState.is_blocked = lastState.is_blocked.value
          @_createGetter(attrName, => return Promise.resolve(@thermState[attrName]))
      super()
      @plugin.nestApi.then(@init)

    init: (client) =>
      @thermostat = client.child('devices/thermostats').child(@config.device_id)
      @plugin.fetchNestData(@thermostat.ref()).then (snap) =>
        @_setState(key, value) for key, value of snap.val()
        @thermostat.ref().on 'child_changed', @handleNestUpdate
        return Promise.resolve()

    handleNestUpdate: (update) => @_setState(update.name(), update.val())

    setHVACModeToCool: ->     @changeHVACModeTo("cool")
    setHVACModeToHeat: ->     @changeHVACModeTo("heat")
    setHVACModeToHeatCool: -> @changeHVACModeTo("heat-cool")
    setHVACModeToOff: ->      @changeHVACModeTo("off")
    changeHVACModeTo: (hvac_mode) =>
      if hvac_mode not in ["heat-cool", "heat", "cool", "off"]
        throw new Error("Invalid hvac_mode: #{hvac_mode}")
      else if hvac_mode is 'eco'
        throw new Error("Setting hvac_mode to eco is not allowed")
      else if hvac_mode is 'heat' and @thermState.can_heat is no
        throw new Error("HVAC unit cannot heat")
      else if hvac_mode is 'cool' and @thermState.can_cool is no
        throw new Error("HVAC unit cannot cool")
      else if hvac_mode is 'heat-cool'
        throw new Error("HVAC unit cannot heat and cool") unless @thermState.can_heat is yes and @thermState.can_cool is yes
      else @_sendNestCommand("hvac_mode", hvac_mode)

    decrementTargetTemp: -> @changeTargetTempTo("-1")
    incrementTargetTemp: -> @changeTargetTempTo("+1")
    changeTargetTempTo: (temp) => @_sendTemperatureCommand("target_temperature", @_getNewTemp("target_temperature", temp))

    decrementTargetTempLow: -> @changeTargetTempLowTo("-1")
    incrementTargetTempLow: -> @changeTargetTempLowTo("+1")
    changeTargetTempLowTo: (temp) =>
      newTempLow = @_getNewTemp("target_temperature_low" , temp)
      unless (newTempLow + 1) < @thermState.target_temperature_high
        throw new Error("Target temp low must be less target temp high")
      @_sendTemperatureCommand("target_temperature_low", newTempLow)

    incrementTargetTempHigh: -> @changeTargetTempHighTo("+1")
    decrementTargetTempHigh: -> @changeTargetTempHighTo("-1")
    changeTargetTempHighTo: (temp) =>
      newTempHigh = @_getNewTemp("target_temperature_high" , temp)
      unless newTempHigh > (@thermState.target_temperature_low + 1)
        throw new Error("Target temp high must be greater than target temp low")
      @_sendTemperatureCommand("target_temperature_high", newTempHigh)

    _sendTemperatureCommand: (attrName, newTemp) =>
      @_isHVACModeOk(attrName)
      @_isValidTemp(newTemp)
      @_sendNestCommand(attrName, newTemp)

    _sendNestCommand: (attrName, value) =>
      @_isOkToSend() if @blocked isnt null
      throw new Error("New value for #{attrName} is same as current") if @thermState[attrName] is value
      return new Promise (resolve, reject) =>
        @thermostat.child(@_getNestName(attrName)).set value, (error) =>
          return resolve() unless error?
          if error.code is "BLOCKED"
            @blocked = yes
            @emit "is_blocked", @blocked
          env.logger.error "Nest Command Error: #{error}"
          return reject(error.code)

    _setState: (key, newValue) =>
      if key is "temperature_scale"
        if @config.temp_scale isnt newValue
          @config.temp_scale = newValue
          return
      attrName = @_getAttrName(key)
      return unless attrName?
      return if @thermState[attrName] is newValue
      @thermState[attrName] = newValue
      @emit attrName, newValue

    _getNewTemp: (tempAttr, newTemp) =>
      if @thermState[tempAttr] is null
        throw new Error("Not ready")
      else
        return switch newTemp
          when "-1" then @thermState[tempAttr] - @unitChange
          when "+1" then @thermState[tempAttr] + @unitChange
          else parseFloat(newTemp)

    _getNestName: (attrName) -> return attrName + if attrName in tempAttrs then "_#{@unit}" else ""
    _getAttrName: (nestAttr) ->
      isTemp = nestAttr.substring(nestAttr.length-2, nestAttr.length)
      if isTemp in ["_c", "_f"]
        return nestAttr.substring(0, nestAttr.length-2) if isTemp is "_#{@unit}"
      else if nestAttr in @attrNames
        return nestAttr
      else return null

    _isHVACModeOk: (attr) ->
      if @thermState.hvac_mode is 'eco' or
      (attr is 'target_temperature' and @thermState.hvac_mode not in ['heat', 'cool']) or
      ((attr is 'target_temperature_low' or attr is 'target_temperature_high') and @thermState.hvac_mode isnt 'heat-cool')
        throw new Error "can not change #{attr} when hvac_mode is #{@thermState.hvac_mode}"
      else return yes

    _isValidTemp: (temp) ->
      if @thermState.locked_temp_min <= temp <= @thermState.locked_temp_max
        return yes
      else
        throw new Error "#{temp} is outside valid range of #{@thermState.locked_temp_min}-#{@thermState.locked_temp_max}."

    _isOkToSend: ->
      throw new Error("No thermostat device") if @thermostat is null
      throw new Error("Thermostat not online") unless @thermState.is_online is yes
      throw new Error("Thermostat not locked") unless @thermState.is_locked is yes
      if Date.now() < @blocked
        timeLeft = (new Date(@blocked - Date.now()))
        throw new Error("Sending commands blocked for #{timeLeft.getMinutes()}m#{timeLeft.getSeconds()}s")
      @blocked = no
      @emit "is_blocked", @blocked
      return null

    destroy: () ->
      @thermostat.ref().off 'child_changed', @handleNestUpdate
      super()

  return NestThermostat

