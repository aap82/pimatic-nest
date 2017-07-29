module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  Firebase = require 'firebase'
  paramCase = require('param-case')

  deviceConfigDef = require('./device-config-schema')
  NestThermostat = require('./devices/nest-thermostat')(env)
  NestPresence = require('./devices/nest-presence')(env)
  {getAttributeNames} = require('./devices/nest-thermostat-attributes')



  class NestPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      env.logger.info("Initializing Nest Plugin")
      if @config.token is ""
        env.logger.error "No firebase token provided"
        return

      @attrNames = getAttributeNames(@config.unit)
      @client = new Firebase('wss://developer-api.nest.com')
      @nestApi = @connect(@config)

      @framework.deviceManager.registerDeviceClass "NestThermostat", {
        configDef: deviceConfigDef.NestThermostat,
        createCallback: (config) => new NestThermostat(config, @)
      }

      @framework.deviceManager.registerDeviceClass "NestPresence", {
        configDef: deviceConfigDef.NestPresence,
        createCallback: (config) => new NestPresence(config, @)
      }

      @framework.deviceManager.on "discover", @discover

    discover: =>
      env.logger.info "Starting Nest Discovery"
      @nestApi.then =>
        @discoverStructures()
      .then () =>
        @discoverThermostats()
      .catch (err) =>
        env.logger.error(err)


    connect: (config) =>
      env.logger.info 'Connecting to Nest Firebase'
      connectPromise = new Promise (resolve, reject) =>
        @client.authWithCustomToken config.token, (error) =>
          if (error)
            env.logger.error  'Error in connecting Firebase Socket.', error
            return reject()
          else
            env.logger.info  'Firebase socket is connected.'
            return resolve()
      return connectPromise.then(@fetchData)

    fetchData: =>
      return new Promise (resolve, reject) =>
        @client.once 'value', (snapshot) =>
          @thermostats = snapshot.child('devices/thermostats')
          @structures = snapshot.child('structures')
          return resolve(snapshot)


    discoverStructures: =>
      env.logger.info "Checking for new structures"
      nestStructures = {}
      for id, dev of @framework.deviceManager.devices
        if dev instanceof NestPresence
          nestStructures[dev.config.structure_id] = dev
      for key, structure of @structures.val()
        if not nestStructures[key]
          config =
            class: "NestPresence"
            id: "nest-presence-#{paramCase(structure.name)}"
            name: structure.name
            structure_id: structure.structure_id
          @framework.deviceManager.discoveredDevice 'nest-presence', "#{config.name}", config


      return

    discoverThermostats: =>
      env.logger.info "Checking for new Thermostats"
      nestThermostats = {}
      for id, dev of @framework.deviceManager.devices
        if dev instanceof NestThermostat
          nestThermostats[dev.config.device_id] = dev

      for key, device of @thermostats.val()
        if not nestThermostats[key]
          config =
            class: "NestThermostat"
            id: "nest-thermostat-#{paramCase(device.name)}"
            name: device.name
            device_id: device.device_id
            structure_id: device.structure_id
          @framework.deviceManager.discoveredDevice 'nest-thermostat', "#{config.name}", config




      return













  nestPlugin = new NestPlugin

  return nestPlugin