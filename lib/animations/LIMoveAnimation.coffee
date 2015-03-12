# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Velocity = require 'velocity-animate'
Util = require '../Util'

module.exports =
class LIMoveAnimation

  @id = 'ItemLIMove'

  constructor: (id, item, outlineEditorElement) ->
    @_id = id
    @_item = item
    @outlineEditorElement = outlineEditorElement
    @_movingLIClone = null

  fastForward: ->

  beginMove: (LI, position) ->
    movingLIClone = @_movingLIClone

    unless movingLIClone
      movingLIClone = LI.cloneNode true
      movingLIClone.style.marginTop = 0
      movingLIClone.style.position = 'absolute'
      movingLIClone.style.top = position.top + 'px'
      movingLIClone.style.left = position.left + 'px'
      movingLIClone.style.width = position.width + 'px'
      movingLIClone.dataset.pLeft = position.pLeft
      movingLIClone.style.pointerEvents = 'none'

      # Add simulated selection if in text edit mode.
      outlineEditorElement = @outlineEditorElement
      selectionRange = outlineEditorElement.editor.selection

      if selectionRange.isTextMode and selectionRange.focusItem is @_item
        itemRect = LI.getBoundingClientRect()
        selectionRects = []

        # focusClientRect is more acurate in a number of collapsed cases,
        # so use it when possible. Otherwise just use
        # document.getSelection() rects.
        if selectionRange.isCollapsed
          selectionRects.push selectionRange.focusClientRect
        else
          domSelection = outlineEditorElement.editor.DOMGetSelection()
          if domSelection.rangeCount > 0
            selectionRects = domSelection.getRangeAt(0).getClientRects()

        for rect in selectionRects
          selectDIV = document.createElement('div')
          selectDIV.style.position = 'absolute'
          selectDIV.style.top = (rect.top - itemRect.top) + 'px'
          selectDIV.style.left = (rect.left - itemRect.left) + 'px'
          selectDIV.style.width = rect.width + 'px'
          selectDIV.style.height = rect.height + 'px'
          selectDIV.style.zIndex = '-1'

          if rect.width <= 1
            selectDIV.className = 'bsimulatedSelectionCursor'
            selectDIV.style.width = '1px'
          else
            selectDIV.className = 'bsimulatedSelection'

          movingLIClone.appendChild(selectDIV)

      @outlineEditorElement.animationLayerElement.appendChild movingLIClone
      @_movingLIClone = movingLIClone

  performMove: (LI, position, context) ->
    movingLIClone = @_movingLIClone
    pLeftDiff = parseInt(movingLIClone.dataset.pLeft, 10) - position.pLeft

    Velocity movingLIClone, 'stop', true

    properties =
      top: position.top
      left: position.left - pLeftDiff
      width: position.width + pLeftDiff

    Velocity movingLIClone, properties,
      easing: context.easing
      duration: context.duration
      begin: (elements) ->
        LI.style.opacity = '0'
      complete: (elements) =>
        LI.style.opacity = null
        Util.removeFromDOM movingLIClone
        @outlineEditorElement.completedAnimation @_id