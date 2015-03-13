# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Velocity = require 'velocity-animate'
Util = require '../Util'

module.exports =
class LIInsertAnimation

  @id = 'ItemLIInsert'

  constructor: (id, item, itemRenderer) ->
    @itemRenderer = itemRenderer
    @_id = id
    @_item = item
    @_insertLI = null
    @_targetHeight = 0

  fastForward: ->
    @_insertLI?.style.height = @_targetHeight + 'px'

  complete: ->
    @itemRenderer.completedAnimation @_id
    if @_insertLI
      Velocity @_insertLI, 'stop', true
      @_insertLI.style.height = null
      @_insertLI.style.overflowY = null

  insert: (LI, context) ->
    targetHeight = LI.clientHeight

    @_insertLI = LI
    @_targetHeight = targetHeight

    properties =
      height: targetHeight

    Velocity LI, properties,
      easing: context.easing
      duration: context.duration
      begin: (elements) ->
        LI.style.height = '0px'
        LI.style.overflowY = 'hidden'
      complete: (elements) =>
        @complete()