$(document).on 'templateinit', (event) ->
  class NestHomeAwayToggleItem extends pimatic.DeviceItem
    constructor: (templData, @device) ->
      super(templData, @device)
      @nestId = "switch-#{templData.deviceId}"
      nestStateAttribute = @getAttribute('nestState')
      isBlockedAttribute = @getAttribute('is_blocked')
      unless nestStateAttribute?
        throw new Error("Nest HomeAway toggle needs a nestState attribute!")

      @nestState = ko.observable(nestStateAttribute.value())
      @isBlocked = ko.observable(if isBlockedAttribute.value()? then yes else no)


      nestStateAttribute.value.subscribe((newState) =>
        @_restoringState = true
        @nestState(newState)
        pimatic.try => @toggleEle.flipswitch('refresh')
        @_restoringState = false
      )
      isBlockedAttribute.value.subscribe((newState) =>
        console.log newState
        @_restoringState = true
        @isBlocked(newState)
        if newState?
          pimatic.try => @toggleEle.flipswitch('disable')
        else
          pimatic.try => @toggleEle.flipswitch('enable')
        pimatic.try => @toggleEle.flipswitch('refresh')
        @_restoringState = false
      )
    afterRender: (elements) ->
      super(elements)
      @toggleEle = $(elements).find('select')
      @toggleEle.flipswitch()
      $(elements).find('.ui-flipswitch').addClass('no-carousel-slide')
      if @getAttribute("is_blocked").value()?
        pimatic.try => @toggleEle.flipswitch('disable')
        pimatic.try => @toggleEle.flipswitch('refresh')

    onSwitchChange: ->
      if @_restoringState then return
      stateToSet = @nestState()
      value = @getAttribute('nestState').value()
      if @getAttribute("is_blocked").value()?
        return
      if stateToSet is value
        return
      pimatic.try => @toggleEle.flipswitch('disable')
      deviceAction = (if @nestState() is 'home' then 'setNestStateToHome' else 'setNestStateToAway')

      doIt = (
        confirm __("""
          Do you really want set Nest to %s #{@nestState()}?
        """, @device.name())
      )
      restoreState = if @nestState() is 'home' then 'away' else 'home'
      console.log restoreState
      if doIt
        pimatic.loading "switch-on-#{@nestId}", "show", text: __("setting nest to #{@nestState()}")
        @device.rest[deviceAction]({}, global: no)
          .done(ajaxShowToast)
          .fail( =>
            @_restoringState = true
            @nestState(restoreState)
            pimatic.try => @toggleEle.flipswitch('refresh')
            @_restoringState = false
          ).always( =>
            pimatic.loading "switch-on-#{@nestId}", "hide"
            pimatic.try => @toggleEle.flipswitch('enable')
            pimatic.try => @toggleEle.flipswitch('refresh')
          ).fail(ajaxAlertFail)
      else
        @_restoringState = true
        @nestState(restoreState)
        pimatic.try => @toggleEle.flipswitch('enable')
        pimatic.try => @toggleEle.flipswitch('refresh')
        @_restoringState = false

  pimatic.templateClasses['nesthomeawaytoggle'] = NestHomeAwayToggleItem