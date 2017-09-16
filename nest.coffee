module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  Firebase = require 'firebase'
  paramCase = require('param-case')

  deviceConfigDef = require('./device-config-schema')
  NestThermostat = require('./devices/nest-thermostat')(env)
  NestPresence = require('./devices/nest-presence')(env)
  {NestTemperatureActionProvider, NestHVACModeActionProvider} = require('./actions/nest-actions')(env)

  class NestPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      env.logger.info("Initializing Nest Plugin")
      if @config.token is ""
        env.logger.error "No firebase token provided"
        return

      @client = new Firebase('wss://developer-api.nest.com')
      @framework.deviceManager.registerDeviceClass "NestThermostat", {
        configDef: deviceConfigDef.NestThermostat,
        createCallback: @callBackHandler("NestThermostat", NestThermostat) #(config) => new NestThermostat(config, @)
      }
      @framework.deviceManager.registerDeviceClass "NestPresence", {
        configDef: deviceConfigDef.NestPresence,
        createCallback: (config) => new NestPresence(config, @)
      }
      @framework.ruleManager.addActionProvider(new NestTemperatureActionProvider(@framework,@))
      @framework.ruleManager.addActionProvider(new NestHVACModeActionProvider(@framework,@))
      @framework.deviceManager.on "discover", @discover

      @nestApi = @connect(@config).catch((error) ->
        env.logger.error("Error in connecting Firebase Socket: #{error}")
      )


    callBackHandler: (className, classType) =>
      return (config, lastState) =>
        return new classType(config, @, lastState)

    connect: (config) =>
      env.logger.info 'Connecting to Nest Firebase'
      return new Promise (resolve, reject) =>
        @client.authWithCustomToken config.token, (error) =>
          if (error)
            return reject(error)
          else
            env.logger.info  'Firebase socket is connected.'
            return resolve(@client)

    discover: =>
      env.logger.info "Starting Nest Discovery"
      @nestApi.then(=> @fetchNestData(@client)).then (snapshot) =>
        structurePromise = @discoverStructures(snapshot.child('structures'))
        thermostatPromise = @discoverThermostats(snapshot.child('devices/thermostats'))
        return Promise.all [structurePromise, thermostatPromise]
      .catch (err) =>
        env.logger.error(err)
        return Promise.reject()


    discoverStructures: (structures) =>
      return new Promise (resolve) =>
        env.logger.info "Checking for new Structures"
        nestPresences = (dev.structure_id for dev in @framework.deviceManager.devicesConfig when dev.class is 'NestPresence')
        for key, structure of structures.val() when key not in nestPresences
          config =
            class: "NestPresence"
            id: "nest-presence-#{paramCase(structure.name)}"
            name: structure.name
            structure_id: structure.structure_id
          @framework.deviceManager.discoveredDevice 'nest-presence', "#{config.name}", config
        return resolve()

    discoverThermostats: (thermostats) =>
      return new Promise (resolve) =>
        env.logger.info "Checking for new Thermostats"
        nestThermostats = (dev.device_id for dev in @framework.deviceManager.devicesConfig when dev.class is 'NestThermostat')
        for key, thermostat of thermostats.val() when key not in nestThermostats
          config =
            class: "NestThermostat"
            id: "nest-thermostat-#{paramCase(thermostat.name)}"
            name: thermostat.name
            device_id: thermostat.device_id
            temp_scale: thermostat.temperature_scale
            show_temp_scale: no
          @framework.deviceManager.discoveredDevice 'nest-thermostat', "#{config.name}", config
        return resolve()

    fetchNestData: (ref) =>
      return new Promise (resolve) =>
        ref.once 'value', (snapshot) =>
          return resolve(snapshot)


  nestPlugin = new NestPlugin

  return nestPlugin