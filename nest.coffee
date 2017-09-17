module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  Firebase = require 'firebase'
  paramCase = require('param-case')

  deviceConfigDef = require('./device-config-schema')
  NestThermostat = require('./devices/nest-thermostat')(env)
  {NestThermostatTargetTempActionProvider, NestThermostatHVACModeActionProvider} = require('./predicates_and_actions/thermostat-actions')(env)
  NestHomeAwayPredicateProvider = require('./predicates_and_actions/home-away-predicates')(env)
  {NestHomeAwayPresence,NestHomeAwayToggle} = require('./devices/nest-home-away')(env)

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
      @framework.deviceManager.registerDeviceClass "NestHomeAwayPresence", {
        configDef: deviceConfigDef.NestHomeAwayPresence,
        createCallback: @callBackHandler("NestHomeAwayPresence", NestHomeAwayPresence)
        prepareConfig: ((config) =>
          for dev in @framework.deviceManager.devicesConfig when dev.class in ['NestHomeAwayToggle', 'NestHomeAwayPresence']
            if dev.structure_id is config.structure_id
              throw new Error "#{dev.class} device already exists with same structure_id." unless config.id is dev.id
          config
        )
      }
      @framework.deviceManager.registerDeviceClass "NestHomeAwayToggle", {
        configDef: deviceConfigDef.NestHomeAwayToggle,
        createCallback: @callBackHandler("NestHomeAwayToggle", NestHomeAwayToggle)
        prepareConfig: ((config) =>
          for dev in @framework.deviceManager.devicesConfig when dev.class in ['NestHomeAwayToggle', 'NestHomeAwayPresence']
            if dev.structure_id is config.structure_id
              throw new Error "#{dev.class} device already exists with same structure_id."  unless config.id is dev.id
          config

        )

      }
      @framework.ruleManager.addPredicateProvider(new NestHomeAwayPredicateProvider(@framework))
      @framework.ruleManager.addActionProvider(new NestThermostatTargetTempActionProvider(@framework,@))
      @framework.ruleManager.addActionProvider(new NestThermostatHVACModeActionProvider(@framework,@))
      @framework.deviceManager.on "discover", @discover

      @nestApi = @connect(@config).catch((error) ->
        env.logger.error("Error in connecting Firebase Socket: #{error}")
      )

      @framework.on "after init", @afterInit


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
      @nestApi.then(=> @fetchNestData(@client)).then (snapshot) =>
        structurePromise = @discoverStructures(snapshot.child('structures'))
        thermostatPromise = @discoverThermostats(snapshot.child('devices/thermostats'))
        return Promise.all [structurePromise, thermostatPromise]
      .catch (err) =>
        env.logger.error(err)
        return Promise.reject()

    discoverStructures: (structures) =>
      return new Promise (resolve) =>
        @framework.deviceManager.discoverMessage 'pimatic-nest', "Checking for new Structures"
        nestHomeAwayToggles = []
        nestPresences = []
        for dev in @framework.deviceManager.devicesConfig
          nestHomeAwayToggles.push dev.structure_id if dev.class is 'NestHomeAwayToggle'
          nestPresences.push dev.structure_id if dev.class is 'NestHomeAwayPresence'
        for key, structure of structures.val()
          if key not in nestPresences and key not in nestHomeAwayToggles
            config =
              class: "NestHomeAwayPresence"
              id: "nest-presence-#{paramCase(structure.name)}"
              name: "Nest Home/Away - #{structure.name}"
              structure_id: structure.structure_id
            @framework.deviceManager.discoveredDevice 'nest-presence', "#{config.name}", config

          if key not in nestPresences and key not in nestHomeAwayToggles
            config =
              class: "NestHomeAwayToggle"
              id: "nest-state-toggle-#{paramCase(structure.name)}"
              name: "Nest Home/Away - #{structure.name}"
              structure_id: structure.structure_id
            @framework.deviceManager.discoveredDevice 'nest-state-toggle', "#{config.name}", config
        return resolve()

    discoverThermostats: (thermostats) =>
      return new Promise (resolve) =>
        @framework.deviceManager.discoverMessage 'pimatic-nest', "Checking for new Thermostats"
        nestThermostats = (dev.device_id for dev in @framework.deviceManager.devicesConfig when dev.class is 'NestThermostat')
        for key, thermostat of thermostats.val() when key not in nestThermostats
          config =
            class: "NestThermostat"
            id: "nest-thermostat-#{paramCase(thermostat.name)}"
            name: "Nest Thermostat - #{thermostat.name}"
            device_id: thermostat.device_id
            temp_scale: thermostat.temperature_scale
            show_temp_scale: no
          @framework.deviceManager.discoveredDevice 'nest-thermostat', "#{config.name}", config
        return resolve()

    fetchNestData: (ref) =>
      return new Promise (resolve) =>
        ref.once 'value', (snapshot) =>
          return resolve(snapshot)

    afterInit: =>
      mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
      if mobileFrontend?
        mobileFrontend.registerAssetFile 'js', "pimatic-nest/app/nest-home-away-toggle.coffee"
        mobileFrontend.registerAssetFile 'html', "pimatic-nest/app/nest-home-away-toggle.jade"
      else
        env.logger.warn "mobile-frontend not loaded, no gui will be available"

  nestPlugin = new NestPlugin

  return nestPlugin