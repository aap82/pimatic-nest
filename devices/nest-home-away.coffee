module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'

  class NestHomeAwayPresence extends env.devices.PresenceSensor
    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      super()
      @_presence = lastState?.presence?.value or null
      @nestPresence = null
      @nestPresenceUpdates = null
      @plugin.nestApi.then(@init)

    init: (client) =>
      @nestPresence = client.child('structures').child(@config.structure_id).child('away')
      @nestPresenceUpdates = @nestPresence.ref().on('value', (update) => @_setPresence(update.val() is 'home'))

    destroy: () ->
      if @nestPresenceUpdates?
        @nestPresence.ref().off('value', @nestPresenceUpdates)
      super()

  class NestHomeAwayToggle extends env.devices.Device
    template: "nesthomeawaytoggle"
    _nestState: null
    _is_blocked: null
    attributes:
      nestState:
        description: "The current state of the switch"
        type: "string"
        enum: ['home', 'away']
      is_blocked:
        description: "If blocked from sending commanding, the time else null"
        type: "number"
    actions:
      setNestStateToHome:
        description: "Set the Nest State to Home"
      setNestStateToAway:
        description: "Set the Nest State to Away"

    getNestState: -> Promise.resolve(@_nestState)
    getIs_blocked: -> Promise.resolve(@_is_blocked)
    @property 'blocked',
      get: -> @_is_blocked
      set: (block) ->
        @_is_blocked = switch block
          when yes then Date.now() + @blockTime
          else null

    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @blockTime = 15 * 60000
      @unBlockTimeout = null
      @_nestState = lastState?.nestState?.value or null
      @_is_blocked = lastState?.is_blocked?.value or null
      @nestStructure = null
      @nestStateUpdates = null
      super()
      @plugin.nestApi.then(@init)

    init: (client) =>
      @nestStructure = client.child('structures').child(@config.structure_id)
      @nestStateUpdates = @nestStructure.child('away').ref().on('value', (update) => @_setNestState(update.val()))
      if @blocked isnt null
        if Date.now() < @blocked
          @unBlockTimeout = setTimeout((=> @_unBlockNestCommands()),(new Date(@blocked - Date.now())) )
        else
          @_unBlockNestCommands()
      return null

    _setNestState: (nestState) =>
      return if nestState is @_nestState
      @_nestState = nestState
      @emit 'nestState', nestState
      return null

    setNestStateToHome: -> @changeNestStateTo('home')
    setNestStateToAway: -> @changeNestStateTo('away')

    changeNestStateTo: (newState) =>
      promise = Promise.resolve()
      promise.then(=> @_sendNestCommand(newState))

    _blockNestCommands: =>
      if @unBlockTimeout is null
        @blocked = yes
        @emit "is_blocked", @blocked
        @unBlockTimeout = setTimeout((=> @_unBlockNestCommands()),@blockTime )
      return null

    _unBlockNestCommands: =>
      @unBlockTimeout = null
      @blocked = no
      @emit "is_blocked", null
      return null

    _sendNestCommand: (nestState) =>
      return unless @_isOkToSend(nestState)
      return new Promise (resolve, reject) =>
        @nestStructure.child('away').set nestState, (error) =>
          if error?
            if error.code is "BLOCKED"
              @_blockNestCommands()
            env.logger.error "Nest Command Error: #{error}"
            return reject(error.code)
          else
            return resolve("Nest state successfully set to #{nestState}")

    _isOkToSend: (nestState) =>
      if @nestStructure is null
        throw new Error("Nest not yet initialized")
      if nestState is @_nestState
        throw new Error("Nest state #{nestState} is same as current state")
      if @blocked isnt null
        if Date.now() < @blocked
          timeLeft = (new Date(@blocked - Date.now()))
          throw new Error("Sending commands blocked for #{timeLeft.getMinutes()}m#{timeLeft.getSeconds()}s")
      return yes
        
    destroy: () ->
      clearTimeout(@unBlockTimeout) if @unBlockTimeout?
      @nestStructure.child('away').ref().off('value', @nestStateUpdates) if @nestStateUpdates?
      super()

  return {
    NestHomeAwayPresence
    NestHomeAwayToggle
  }