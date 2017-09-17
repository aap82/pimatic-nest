module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher

  class NestHomeAwayPredicateHandler extends env.predicates.PredicateHandler
    constructor: (@device, @nestState) ->
      @dependOnDevice(@device)

    setup: ->
      @nestStateListener = ((s)  => @emit 'change', (s is @nestState))
      @device.on "nestState", @nestStateListener
      super()

    getValue: -> @device.getUpdatedAttributeValue('nestState').then( (s) => (s is @nestState) )
    destroy: ->
      console.log 'destroy'
      @device.removeListener "nestState", @nestStateListener
      super()
    getType: -> 'state'

  class NestHomeAwayPredicateProvider extends env.predicates.PredicateProvider
    presets: [{
      name: "nest home/away"
      input: "{device} changes to {home/away}"
    }]

    constructor: (@framework) ->
    parsePredicate: (input, context) ->
      device = null
      nestState = null
      match = null
      nestStateToggles = (dev for id, dev of @framework.deviceManager.devices when dev.config.class is 'NestHomeAwayToggle')
      M(input, context)
        .matchDevice(nestStateToggles, (next, d) =>
          next.match(" changes to ", type: "static")
            .match(
              ['home', 'away'],
              type: 'select',
              param: 'nestState'
              wildcard: '{home/away}',
              (m, s) =>
                if device? and device.id isnt d.id
                  context?.addError(""""#{input.trim()}" is ambiguous.""")
                  return
                assert d?
                device = d
                nestState = s
                match = m.getFullMatch()
          )
        )

      if match?
        assert nestState?
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new NestHomeAwayPredicateHandler(device, nestState)
        }
      else
        return null

  return NestHomeAwayPredicateProvider