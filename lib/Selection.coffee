# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

shallowEquals = require 'shallow-equals'
Constants = require './Constants'
assert = require 'assert'
Item = require './Item'

class Selection

  @isUpstreamDirection: (direction) ->
    direction is 'backward' or direction is 'left' or direction is 'up'

  @isDownstreamDirection: (direction) ->
    direction is 'forward' or direction is 'right' or direction is 'down'

  constructor: (editor, focusItem, focusOffset, anchorItem, anchorOffset, selectionAffinity) ->
    if focusItem instanceof Selection
      selection = focusItem
      editor = selection.editor
      focusItem = selection.focusItem
      focusOffset = selection.focusOffset
      anchorItem = selection.anchorItem
      anchorOffset = selection.anchorOffset
      selectionAffinity = selection.selectionAffinity

    @editor = editor
    @focusItem = focusItem or null
    @focusOffset = focusOffset
    @selectionAffinity = selectionAffinity or null
    @anchorItem = anchorItem or null
    @anchorOffset = anchorOffset

    unless anchorItem
      @anchorItem = @focusItem
      @anchorOffset = @focusOffset

    unless @isValid
      @focusItem = null
      @focusOffset = undefined
      @anchorItem = null
      @anchorOffset = undefined

    @_calculateSelectionItems()

  Object.defineProperty @::, 'isValid',
    get: ->
      _isValidSelectionOffset(@editor, @focusItem, @focusOffset) and
      _isValidSelectionOffset(@editor, @anchorItem, @anchorOffset)

  Object.defineProperty @::, 'isCollapsed',
    get: -> @isTextMode and @focusOffset is @anchorOffset

  Object.defineProperty @::, 'isUpstreamAffinity',
    get: -> @selectionAffinity is Constants.SelectionAffinityUpstream

  Object.defineProperty @::, 'isItemMode',
    get: ->
      @isValid and (
        !!@anchorItem and
        !!@focusItem and
          (@anchorItem != @focusItem or
          @anchorOffset is undefined and @focusOffset is undefined)
      )

  Object.defineProperty @::, 'isTextMode',
    get: ->
      @isValid and (
        !!@anchorItem and
        @anchorItem is @focusItem and
        @anchorOffset != undefined and
        @focusOffset != undefined
      )

  Object.defineProperty @::, 'isReversed',
    get: ->
      focusItem = @focusItem
      anchorItem = @anchorItem

      if focusItem is anchorItem
        return (
          @focusOffset != undefined and
          @anchorOffset != undefined and
          @focusOffset < @anchorOffset
        )

      return (
        focusItem and
        anchorItem and
        !!(focusItem.comparePosition(anchorItem) & Node.DOCUMENT_POSITION_FOLLOWING)
      )

  Object.defineProperty @::, 'focusClientRect',
    get: -> @clientRectForItemOffset @focusItem, @focusOffset

  Object.defineProperty @::, 'anchorClientRect',
    get: -> @clientRectForItemOffset @anchorItem, @anchorOffset

  clientRectForItemOffset: (item, offset) ->
    outlineEditorElement = @editor.outlineEditorElement

    return undefined unless item
    viewP = outlineEditorElement.itemViewPForItem item
    return undefined unless viewP
    return undefined unless document.body.contains viewP

    bodyText = item.bodyText
    paddingBottom = 0
    paddingTop = 0
    computedStyle

    if offset != undefined
      positionedAtEndOfWrappingLine = false
      baseRect
      side

      if bodyText.length > 0
        domRange = document.createRange()
        startDOMNodeOffset
        endDOMNodeOffset

        if offset < bodyText.length
          startDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset)
          endDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset + 1)
          side = 'left'
        else
          startDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset - 1)
          endDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset)
          side = 'right'

        domRange.setStart(startDOMNodeOffset.node, startDOMNodeOffset.offset)
        domRange.setEnd(endDOMNodeOffset.node, endDOMNodeOffset.offset)

        # This is hacky, not sure what's going one, but seems to work.
        # The goal is to get a single zero width rect for cursor
        # position. This is complicated by fact that when a line wraps
        # two rects are returned, one for each possible location. That
        # ambiguity is solved by tracking selectionAffinity.
        #
        # The messy part is that there are other times that two client
        # rects get returned. Such as when the range start starts at the
        # end of a <b>. Seems we can just ignore those cases and return
        # the first rect. To detect those cases the check is
        # clientRects[0].top !== clientRects[1].top, because if that's
        # true then we can be at a line wrap.
        clientRects = domRange.getClientRects()
        baseRect = clientRects[0]
        #if clientRects.length > 1 and clientRects[0].top != clientRects[1].top
        if clientRects.length > 1
          alternateRect = clientRects[1]
          sameLine = baseRect.top is alternateRect.top
          if sameLine
            unless baseRect.width
              baseRect = alternateRect
          else if @selectionAffinity == Constants.SelectionAffinityUpstream
            positionedAtEndOfWrappingLine = true
          else
            baseRect = alternateRect
      else
        computedStyle = window.getComputedStyle(viewP)
        paddingTop = parseInt(computedStyle.paddingTop, 10)
        paddingBottom = parseInt(computedStyle.paddingBottom, 10)
        baseRect = viewP.getBoundingClientRect()
        side = 'left'

      return {} =
        positionedAtEndOfWrappingLine: positionedAtEndOfWrappingLine
        bottom: baseRect.bottom - paddingBottom
        height: baseRect.height - (paddingBottom + paddingTop)
        left: baseRect[side]
        right: baseRect[side] # trim
        top: baseRect.top + paddingTop
        width: 0 # trim
    else
      viewP.getBoundingClientRect()

  equals: (otherSelection) ->
    @focusItem is otherSelection.focusItem and
    @focusOffset is otherSelection.focusOffset and
    @anchorItem is otherSelection.anchorItem and
    @anchorOffset is otherSelection.anchorOffset and
    @selectionAffinity is otherSelection.selectionAffinity and
    shallowEquals(@items, otherSelection.items)

  selectionByExtending: (newFocusItem, newFocusOffset, newSelectionAffinity) ->
    new Selection(
      @editor,
      newFocusItem,
      newFocusOffset,
      @anchorItem,
      @anchorOffset,
      newSelectionAffinity or @selectionAffinity
    )

  selectionByModifying: (alter, direction, granularity) ->
    extending = alter is 'extend'
    next = @nextItemOffsetInDirection(direction, granularity, extending)

    if extending
      @selectionByExtending(next.offsetItem, next.offset, next.selectionAffinity);
    else
      new Selection(
        @editor,
        next.offsetItem,
        next.offset,
        next.offsetItem,
        next.offset,
        next.selectionAffinity
      )

  selectionByRevalidating: ->
    editor = @editor
    visibleItems = @items.filter (each) ->
      editor.isVisible each
    visibleSortedItems = visibleItems.sort (a, b) ->
      a.comparePosition(b) & Node.DOCUMENT_POSITION_PRECEDING

    if shallowEquals @items, visibleSortedItems
      return this

    focusItem = visibleSortedItems[0]
    anchorItem = visibleSortedItems[visibleSortedItems.length - 1]
    result = new Selection(
      @editor,
      focusItem,
      undefined,
      anchorItem,
      undefined,
      @selectionAffinity
    )

    result._calculateSelectionItems(visibleSortedItems)
    result

  nextItemOffsetInDirection: (direction, granularity, extending) ->
    if @isItemMode
      switch granularity
        when 'sentenceboundary', 'lineboundary', 'character', 'word', 'sentence', 'line'
          granularity = 'paragraphboundary'

    editor = @editor
    focusItem = @focusItem
    focusOffset = @focusOffset
    anchorOffset = @anchorOffset
    outlineEditorElement = @editor.outlineEditorElement
    upstream = Selection.isUpstreamDirection(direction)

    next =
      selectionAffinity: Constants.SelectionAffinityDownstream # All movements have downstream affinity except for line and lineboundary

    if focusItem
      unless extending
        focusItem = if upstream then @startItem else @endItem
      next.offsetItem = focusItem
    else
      next.offsetItem = if upstream then editor.lastVisibleItem() else editor.firstVisibleItem()

    switch granularity
      when 'sentenceboundary'
        next.offset = _nextSelectionIndexFrom(
          focusItem.bodyText,
          focusOffset,
          if upstream then 'backward' else 'forward',
          granularity
        )

      when 'lineboundary'
        currentRect = @clientRectForItemOffset focusItem, focusOffset
        if currentRect
          next = outlineEditorElement.pick(
            if upstream then Number.MIN_VALUE else Number.MAX_VALUE,
            currentRect.top + currentRect.height / 2.0
          ).itemCaretPosition

      when 'paragraphboundary'
        next.offset = if upstream then 0 else focusItem.bodyText.length

      when 'character'
        if upstream
          if not @isCollapsed && !extending
            if focusOffset < anchorOffset
              next.offset = focusOffset
            else
              next.offset = anchorOffset
          else
            if focusOffset > 0
              next.offset = focusOffset - 1
            else
              prevItem = editor.previousVisibleItem(focusItem)
              if prevItem
                next.offsetItem = prevItem
                next.offset = prevItem.bodyText.length
        else
          if !@isCollapsed && !extending
            if focusOffset > anchorOffset
              next.offset = focusOffset
            else
              next.offset = anchorOffset
          else
            if focusOffset < focusItem.bodyText.length
              next.offset = focusOffset + 1
            else
              nextItem = editor.nextVisibleItem(focusItem)
              if nextItem
                next.offsetItem = nextItem
                next.offset = 0

      when 'word', 'sentence'
        next.offset = _nextSelectionIndexFrom(
          focusItem.bodyText,
          focusOffset,
          if upstream then 'backward' else 'forward',
          granularity
        )

        if next.offset is focusOffset
          nextItem = if upstream then editor.previousVisibleItem(focusItem) else editor.nextVisibleItem(focusItem)
          if nextItem
            direction = if upstream then 'backward' else 'forward'
            editorSelection = new Selection(@editor, nextItem, if upstream then nextItem.bodyText.length else 0)
            editorSelection = editorSelection.selectionByModifying('move', direction, granularity)
            next =
              offsetItem: editorSelection.focusItem
              offset: editorSelection.focusOffset
              selectionAffinity: editorSelection.selectionAffinity

      when 'line'
        next = @nextItemOffsetByLineFromFocus(focusItem, focusOffset, direction)

      when 'paragraph'
        prevItem = if upstream then editor.previousVisibleItem(focusItem) else editor.nextVisibleItem(focusItem)
        if prevItem
          next.offsetItem = prevItem

      when 'branch'
        prevItem = if upstream then editor.previousVisibleBranch(focusItem) else editor.nextVisibleBranch(focusItem)
        if prevItem
          next.offsetItem = prevItem

      when 'list'
        if upstream
          next.offsetItem = editor.firstVisibleChild(focusItem.parent)
          unless next.offsetItem
            next = @nextItemOffsetUpstream(direction, 'branch', extending)
        else
          next.offsetItem = editor.lastVisibleChild(focusItem.parent)
          unless next.offsetItem
            next = @nextItemOffsetDownstream(direction, 'branch', extending)

      when 'parent'
        next.offsetItem = editor.visibleParent(focusItem)
        unless next.offsetItem
          next = @nextItemOffsetUpstream(direction, 'branch', extending)

      when 'firstchild'
        next.offsetItem = editor.firstVisibleChild(focusItem)
        unless next.offsetItem
          next = @nextItemOffsetDownstream(direction, 'branch', extending)

      when 'lastchild'
        next.offsetItem = editor.lastVisibleChild(focusItem)
        unless next.offsetItem
          next = @nextItemOffsetDownstream(direction, 'branch', extending)

      when 'documentboundary'
        next.offsetItem = if upstream then editor.firstVisibleItem() else editor.lastVisibleItem()

      else
        throw new Error 'Unexpected Granularity ' + granularity

    if not extending and not next.offsetItem
      next.offsetItem = focusItem

    if @isTextMode and next.offset is undefined
      next.offset = if upstream then 0 else next.offsetItem.bodyText.length

    next

  nextItemOffsetByLineFromFocus: (focusItem, focusOffset, direction) ->
    editor = @editor
    outlineEditorElement = editor.outlineEditorElement
    upstream = Selection.isUpstreamDirection(direction)
    focusViewP = outlineEditorElement.itemViewPForItem(focusItem)
    focusViewPRect = focusViewP.getBoundingClientRect()
    focusViewPStyle = window.getComputedStyle(focusViewP)
    viewLineHeight = parseInt(focusViewPStyle.lineHeight, 10)
    viewPaddingTop = parseInt(focusViewPStyle.paddingTop, 10)
    viewPaddingBottom = parseInt(focusViewPStyle.paddingBottom, 10)
    focusCaretRect = @clientRectForItemOffset(focusItem, focusOffset)
    x = editor.selectionVerticalAnchor()
    picked
    y

    if upstream
      y = focusCaretRect.bottom - (viewLineHeight * 1.5)
    else
      y = focusCaretRect.bottom + (viewLineHeight / 2.0)

    if y >= (focusViewPRect.top + viewPaddingTop) && y <= (focusViewPRect.bottom - viewPaddingBottom)
      picked = outlineEditorElement.pick(x, y).itemCaretPosition
    else
      nextItem

      if upstream
        nextItem = editor.previousVisibleItem(focusItem)
      else
        nextItem = editor.nextVisibleItem(focusItem)

      if nextItem
        editor.scrollToItemIfNeeded(nextItem) # pick breaks for offscreen items
        nextItemTextRect = outlineEditorElement.itemViewPForItem(nextItem).getBoundingClientRect()
        if upstream
          y = nextItemTextRect.bottom - 1
        else
          y = nextItemTextRect.top + 1
        picked = outlineEditorElement.pick(x, y).itemCaretPosition
      else
        if upstream
          picked =
            offsetItem: focusItem
            offset: 0
        else
          picked =
            offsetItem: focusItem
            offset: focusItem.bodyText.length
    picked

  _calculateSelectionItems: (overRideSelectionItems) ->
    items = overRideSelectionItems || []

    if @isValid and not overRideSelectionItems
      editor = @editor
      focusItem = @focusItem
      anchorItem = @anchorItem
      startItem = anchorItem
      endItem = focusItem

      if @isReversed
        startItem = focusItem
        endItem = anchorItem

      each = startItem
      while each
        items.push(each)
        if each is endItem
          break
        each = editor.nextVisibleItem(each)

    @items = items
    @itemsCover = Item.commonAncestors(items)
    @startItem = items[0]
    @endItem = items[items.length - 1]

    if @isReversed
      @startOffset = @focusOffset
      @endOffset = @anchorOffset
    else
      @startOffset = @anchorOffset
      @endOffset = @focusOffset

    if @isTextMode
      if @startOffset > @endOffset
        throw new Error 'Unexpected'

  toString: ->
    "anrchor: #{@anchorItem?.id}, #{@anchorOffset}, focus: #{@focusItem?.id}, #{@focusOffset}"

_isValidSelectionOffset = (editor, item, itemOffset) ->
  if item and editor.isVisible(item)
    if itemOffset is undefined
      true
    else
      itemOffset <= item.bodyText.length
  else
    false

_nextSelectionIndexFrom = (text, index, direction, granularity) ->
  assert(index >= 0 and index <= text.length, 'Invalid Index')

  if text.length is 0
    return 0

  iframe = document.getElementById('birchTextCalculationIFrame')
  unless iframe
    iframe = document.createElement("iframe")
    iframe.id = 'birchTextCalculationIFrame'
    document.body.appendChild(iframe)
    iframe.contentWindow.document.body.appendChild(iframe.contentWindow.document.createElement('P'))

  iframeWindow = iframe.contentWindow
  iframeDocument = iframeWindow.document
  selection = iframeDocument.getSelection()
  range = iframeDocument.createRange()
  iframeBody = iframeDocument.body
  p = iframeBody.firstChild

  p.textContent = text
  range.setStart(p.firstChild, index)
  selection.removeAllRanges()
  selection.addRange(range)
  selection.modify('move', direction, granularity)
  selection.focusOffset

module.exports = Selection