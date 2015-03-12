# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Velocity = require 'velocity-animate'
Constants = require '../Constants'
assert = require 'assert'
Util = require '../Util'

module.exports =
class ChildrenULAnimation

  @id = 'ChildrenUL'

  constructor: (id, item, outlineEditorElement) ->
    @outlineEditorElement = outlineEditorElement
    @_id = id
    @_expandingUL = null
    @_collapsingUL = null
    @_item = item
    @_targetHeight = 0

  fastForward: (context) ->
    if @_expandingUL
      @_expandingUL.style.height = @_targetHeight + 'px'
    else if @_collapsingUL
      @_collapsingUL.style.height = @_targetHeight + 'px'

  expand: (UL, context) ->
    startHeight = if @_collapsingUL then @_collapsingUL.clientHeight else 0
    targetHeight = UL.clientHeight

    if @_collapsingUL
      Velocity @_collapsingUL, 'stop', true
      Util.removeFromDOM @_collapsingUL
      @_collapsingUL = null

    @_expandingUL = UL
    @_targetHeight = targetHeight

    properties =
      height: targetHeight

    Velocity UL, properties,
      easing: context.easing
      duration: context.duration
      begin: (elements) ->
        UL.style.height = startHeight + 'px'
        UL.style.overflowY = 'hidden'
      complete: (elements) =>
        UL.style.height = null
        UL.style.marginBottom = null
        UL.style.overflowY = null
        @outlineEditorElement.completedAnimation @_id

  collapse: (UL, context) ->
    startHeight = UL.clientHeight
    targetHeight = 0

    if @_expandingUL
      Velocity @_expandingUL, 'stop', true
      @_expandingUL = null

    @_collapsingUL = UL
    @_targetHeight = targetHeight

    properties =
      tween: [targetHeight, startHeight],
      height: targetHeight

    Velocity UL, properties,
      easing: context.easing
      duration: context.duration
      begin: (elements) ->
        UL.style.overflowY = 'hidden'
        UL.style.pointerEvents = 'none'
        UL.style.height = startHeight + 'px'
      progress: (elements, percentComplete, timeRemaining, timeStart, tweenULHeight) ->
        if tweenULHeight < 0
          UL.style.height = '0px'
          UL.style.marginBottom = tweenULHeight + 'px'
        else
          UL.style.marginBottom = null
      complete: (elements) =>
        Util.removeFromDOM(UL)
        @outlineEditorElement.completedAnimation(@_id)