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
      get: -> @thermState.is_blocked.value
      set: (block) ->
        @thermState.is_blocked.value = switch block
          when yes then Date.now() + @blockTime
          else null

    _getNewTemp: (tempAttr, newTemp) =>
      val = null
      if @thermState[tempAttr]?.value?
        val = switch newTemp
          when "-1" then @thermState[tempAttr].value - @unitChange
          when "+1" then @thermState[tempAttr].value + @unitChange
          else parseFloat(newTemp)
      return val

    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @unit = @config.temp_scale.toLowerCase()
      @unitChange =  if @unit is 'c' then 0.5 else 1
      @blockTime = 20 * 60000
      @thermostat = null
      @thermState = {}
      @attributes = _.clone(@attributes)
      for attrName, attrProps of nestThermostatAttributes
        do (attrName, attrProps) =>
          @attributes[attrName] = _.clone(attrProps)
          stateKey = attrName
          if attrName in tempAttrs
            stateKey = stateKey + "_#{@unit}"
            if @config.show_temp_scale
              @attributes[attrName].unit = "°#{@config.temp_scale}"
          @thermState[stateKey] =
            attrName: attrName
            value: null
          if attrName is 'is_blocked' and lastState.is_blocked?.value?
            @thermState.is_blocked.value = lastState.is_blocked.value
          @_createGetter(attrName, => return Promise.resolve(@thermState[stateKey].value))
      super()
      @plugin.nestApi.then(@init)

    init: (client) =>
      @thermostat = client.child('devices/thermostats').child(@config.device_id)
      @plugin.fetchNestData(@thermostat.ref()).then (snap) =>
        @_setState(key, value) for key, value of snap.val()
        @thermostat.ref().on 'child_changed', @handleNestUpdate
        return Promise.resolve()
    handleNestUpdate: (update) => @_setState(update.name(), update.val())

    decrementTargetTemp: -> @changeTargetTempTo("-1")
    incrementTargetTemp: -> @changeTargetTempTo("+1")
    changeTargetTempTo: (temp) ->
      unless @thermState.hvac_mode.value in ['heat', 'cool']
        return Promise.reject("can not change target temp when hvac_mode is #{@thermState.hvac_mode.value}")
      attrName = "target_temperature_#{@unit}"
      newTemp = @_getNewTemp(attrName, temp)
      return Promise.reject("Not ready") if newTemp is null
      @_sendTemperatureCommand(attrName, newTemp)

    decrementTargetTempLow: -> @changeTargetTempLowTo("-1")
    incrementTargetTempLow: -> @changeTargetTempLowTo("+1")
    changeTargetTempLowTo: (temp) ->
      attrNameLow = "target_temperature_low_#{@unit}"
      newTempLow = @_getNewTemp(attrNameLow , temp)
      return Promise.reject("Not ready") if newTempLow is null
      unless (newTempLow + 1) < @thermState["target_temperature_high_#{@unit}"].value
        return Promise.reject("Target temp low much be less target temp high")
      @_changeTargetTempLowHighTo(attrNameLow, newTempLow)

    incrementTargetTempHigh: -> @changeTargetTempHighTo("+1")
    decrementTargetTempHigh: -> @changeTargetTempHighTo("-1")
    changeTargetTempHighTo: (temp) ->
      attrNameHigh = "target_temperature_high_#{@unit}"
      newTempHigh = @_getNewTemp(attrNameHigh , temp)
      return Promise.reject("Not ready") if newTempHigh is null
      unless newTempHigh > (@thermState["target_temperature_low_#{@unit}"].value + 1)
        return Promise.reject("Target temp high must be greater than target temp low")
      @_changeTargetTempLowHighTo(attrNameHigh, newTempHigh)

    _changeTargetTempLowHighTo: (attrName, newTemp) ->
      unless @thermState.hvac_mode.value is 'heat-cool'
        return Promise.reject("can not change #{attrName} when hvac_mode is #{@thermState.hvac_mode.value}")
      @_sendTemperatureCommand(attrName, newTemp)

    _sendTemperatureCommand: (attrName, newTemp) =>
      return Promise.resolve() if @thermState.hvac_mode.value is 'eco'
      return Promise.resolve() unless @thermState[attrName].value isnt newTemp
      unless @thermState["locked_temp_min_#{@unit}"].value <= newTemp <= @thermState["locked_temp_max_#{@unit}"].value
        return Promise.reject("#{newTemp} is outside valid range.")
      @_sendNestCommand(attrName, newTemp)

    setModeToCool: ->     @changeModeTo("cool")
    setModeToHeat: ->     @changeModeTo("heat")
    setModeToHeatCool: -> @changeModeTo("heat-cool")
    setModeToOff: ->      @changeModeTo("off")
    changeModeTo: (hvac_mode) =>
      return Promise.resolve() if hvac_mode is @thermState.hvac_mode.value
      if hvac_mode is 'eco'
        return Promise.reject("Setting hvac_mode to eco is not allowed")
      else if hvac_mode is 'heat' and @thermState.can_heat.value is no
        return Promise.reject()
      else if hvac_mode is 'cool' and @thermState.can_cool.value is no
        return Promise.reject()
      else if hvac_mode is 'heat-cool'
        return Promise.reject() unless @thermState.can_heat.value is yes and @thermState.can_cool.value is yes
      @_sendNestCommand("hvac_mode", hvac_mode)

    _sendNestCommand: (attrName, value) =>
      return Promise.reject("No thermostat device") if @thermostat is null
      return Promise.reject("Thermostat not online") unless @thermState.is_online.value is yes
      return Promise.reject("Thermostat not locked") unless @thermState.is_locked.value is yes
      if @blocked isnt null
        if Date.now() < @blocked
          timeLeft = (new Date(@blocked - Date.now()))
          return Promise.reject("Sending commands blocked for #{timeLeft.getMinutes()}m#{timeLeft.getSeconds()}s")
        @blocked = no
        @emit "is_blocked", @blocked

      return new Promise (resolve, reject) =>
        @thermostat.child(attrName).set value, (error) =>
          return resolve() unless error?
          if error.code is "BLOCKED"
            @blocked = yes
            @emit "is_blocked", @blocked
          env.logger.error "Nest Command Error: #{error}"
          return reject(error.code)

    _getAttrName: (nestAttr) ->
      isTemp = nestAttr.substring(nestAttr.length-2, nestAttr.length)
      return nestAttr unless isTemp in ["_c", "_f"]
      if isTemp is "_#{@unit}"
        return nestAttr.substring(0, nestAttr.length-2)
      else return null

    _setState: (key, newValue) =>
      if key is "temperature_scale"
        if @config.temp_scale isnt newValue
          @config.temp_scale = newValue
          return @plugin.framework.deviceManager.recreateDevice(@, @config)
      attrName = @_getAttrName(key)
      return if attrName is null
      return unless @thermState[key]?.attrName?
      return if @thermState[key].value is newValue
      @thermState[key].value = newValue
      @emit @thermState[key].attrName, newValue

    destroy: () ->
      @thermostat.ref().off 'child_changed', @handleNestUpdate
      super()



  return NestThermostat

