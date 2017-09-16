module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'

  class NestPresence extends env.devices.PresenceSensor
    constructor: (@config, @plugin) ->
      @id = @config.id
      @name = @config.name
      super()
      @_presence = null
      @nestPresence = null
      @onNestUpdates = null
      @plugin.nestApi.then =>
        @init()
        return Promise.resolve()
      .catch (err) =>
        env.logger.error(err)

    init: =>
      @nestPresence = @plugin.client
        .child('structures')
        .child(@config.structure_id)
        .child('away')

      @onNestUpdates = @nestPresence.ref().on 'value', (update) =>
        @_setPresence(update.val() is 'home')

    destroy: () ->
      @nestPresence.ref().off('value', @onNestUpdates)
      super()

  return NestPresence