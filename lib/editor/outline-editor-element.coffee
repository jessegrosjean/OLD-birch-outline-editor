# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

OutlineEditorFocusElement = require './outline-editor-focus-element'
AttributedString = require '../core/attributed-string'
ItemBodyEncoder = require '../core/item-body-encoder'
ItemSerializer = require '../core/item-serializer'
EventRegistery = require './event-registery'
ItemRenderer = require './item-renderer'
{CompositeDisposable} = require 'atom'
GlobalMouse = require './global-mouse'
rafdebounce = require './raf-debounce'
Velocity = require 'velocity-animate'
Outline = require '../core/outline'
Selection = require './selection'
diff = require 'fast-diff'

module.exports =
class OutlineEditorElement extends HTMLElement

  @ScrollAnimationContext:
    easing: 'ease-out'
    duration: 400

  ###
  Section: Element Lifecycle
  ###

  createdCallback: ->

  attachedCallback: ->

  detachedCallback: ->
    @_extendSelectionDisposables.dispose()

  attributeChangedCallback: ->

  initialize: (editor) ->
    @tabIndex = -1
    @editor = editor
    @itemRenderer = new ItemRenderer editor, this
    @_animationDisabled = 0
    @_maintainSelection = null
    @_disableScrolling = 0

    @_extendingSelectionInteraction = false
    @_extendingSelectionInteractionLastScrollTop = undefined
    @_extendSelectionDisposables = new CompositeDisposable()

    @backgroundMessage = document.createElement('UL')
    @backgroundMessage.classList.add 'background-message'
    @backgroundMessage.classList.add 'centered'
    @backgroundMessage.style.display = 'none'
    @backgroundMessage.style.position = 'absolute'
    @backgroundMessage.appendChild document.createElement 'LI'
    @appendChild @backgroundMessage

    itemAnimationLayerElement = document.createElement 'DIV'
    itemAnimationLayerElement.className = 'item-animation-layer'
    itemAnimationLayerElement.style.position = 'absolute'
    itemAnimationLayerElement.style.zIndex = '1'
    @appendChild itemAnimationLayerElement
    @itemAnimationLayerElement = itemAnimationLayerElement

    @focusElement = new OutlineEditorFocusElement()
    @appendChild(@focusElement)

    topListElement = document.createElement('UL')
    topListElement.classList.add 'top-item-list'
    @appendChild(topListElement)
    @topListElement = topListElement

    # Register directly on this element because Atom app handles this event
    # meaning that the event delegation path won't get called
    @dragSubscription = EventRegistery.listen this,
      dragstart: @onDragStart
      drag: @onDrag
      dragend: @onDragEnd
      dragenter: @onDragEnter
      dragover: @onDragOver
      drop: @onDrop
      dragleave: @onDragLeave

    @subscriptions = new CompositeDisposable

    @disableAnimationOverride = atom.config.get 'ft-outline-editor.disableAnimation'
    @subscriptions.add atom.config.observe 'ft-outline-editor.disableAnimation', (newValue) =>
      @disableAnimationOverride = newValue

    if atom.styles
      process.nextTick =>
        @onStylesheetsChanged()
        onStylesheetsChanged = rafdebounce(@onStylesheetsChanged, 100)
        @subscriptions.add atom.styles.onDidAddStyleElement(onStylesheetsChanged)
        @subscriptions.add atom.styles.onDidRemoveStyleElement(onStylesheetsChanged)
        @subscriptions.add atom.styles.onDidUpdateStyleElement(onStylesheetsChanged)

    this

  destroy: ->
    unless @destroyed
      if @parentNode
        @parentNode.removeChild(this)
      @subscriptions.dispose()
      @dragSubscription.dispose()
      @itemRenderer.destroy()
      @destroyed = true

  ###
  Section: Updates
  ###

  prepareUpdateHoistedItem: (oldHoistedItem, newHoistedItem) ->
    @itemRenderer.prepareUpdateHoistedItem oldHoistedItem, newHoistedItem

  updateHoistedItem: (oldHoistedItem, newHoistedItem) ->
    @itemRenderer.updateHoistedItem oldHoistedItem, newHoistedItem

  updateItemClass: (item) ->
    @itemRenderer.updateItemClass item

  updateItemExpanded: (item) ->
    @itemRenderer.updateItemExpanded item

  outlineDidChange: (e) ->
    @itemRenderer.outlineDidChange e

  onStylesheetsChanged: =>
    return unless @parentElement

    # Force a redraw so the scrollbars are styled correctly based on the theme
    @style.display = 'none'
    @offsetWidth
    @style.display = 'block'

  ###
  Section: Background Message
  ###

  getBackgroundMessage: ->
    if @backgroundMessage.parentNode
      @backgroundMessage.firstChild.innerHTML
    else
      ''

  setBackgroundMessage: (message) ->
    message ?= ''
    @backgroundMessage.firstChild.innerHTML = message
    @backgroundMessage.style.display = if message then null else 'none'

  ###
  Section: Animation
  ###

  isAnimationEnabled: ->
    not @disableAnimationOverride and @_animationDisabled is 0

  disableAnimation: ->
    @_animationDisabled++

  enableAnimation: ->
    @_animationDisabled--

  animateMoveItems: (items, newParent, newNextSibling, startOffset) ->
    @itemRenderer.animateMoveItems items, newParent, newNextSibling, startOffset

  ###
  Section: Viewport
  ###

  getViewportFirstItem: ->
    rect = @getBoundingClientRect()
    midX = rect.left + (rect.width / 2.0)
    @pick(midX, rect.top).itemCaretPosition?.offsetItem

  getViewportLastItem: ->
    rect = @getBoundingClientRect()
    midX = rect.left + (rect.width / 2.0)
    @pick(midX, rect.bottom - 1).itemCaretPosition?.offsetItem

  getViewportItems: ->
    startItem = @getViewportFirstItem()
    endItem = @getViewportLastItem()
    each = startItem
    items = []
    while each and each isnt endItem
      items.push(each)
      each = @editor.getNextVisibleItem(each)
    results

  getViewportRect: ->
    top = @scrollTopWithOverscroll
    left = @scrollLeftWithOverscroll
    rect = @getBoundingClientRect()
    {} =
      top: top
      left: left
      bottom: top + rect.height
      right: left + rect.width
      width: rect.width
      height: rect.height

  getClientRectForItemRange: (startItem, startOffset, endItem, endOffset) ->
    endItem ?= startItem
    endOffset ?= startOffset

    startRect = @getClientRectForItemOffset startItem, startOffset
    if endItem is startItem and endOffset is startOffset
      startRect
    else
      endRect = @getClientRectForItemOffset endItem, endOffset
      result =
        top: Math.min startRect.top, endRect.top
        bottom: Math.max startRect.bottom, endRect.bottom
        left: Math.min startRect.left, endRect.left
        right: Math.max startRect.right, endRect.right
      result.height = result.bottom - result.top
      result.width = result.right - result.left
      result

  getClientRectForItemOffset: (item, offset) ->
    return undefined unless item
    viewP = @itemViewPForItem item
    return undefined unless viewP
    return undefined unless document.body.contains viewP

    if offset is undefined
      return viewP.getBoundingClientRect()

    bodyText = item.bodyText
    paddingBottom = 0
    paddingTop = 0
    computedStyle

    if offset isnt undefined
      positionedAtEndOfWrappingLine = false
      baseRect
      side

      if bodyText.length > 0
        domRange = document.createRange()
        startDOMNodeOffset
        endDOMNodeOffset

        if offset < bodyText.length
          startDOMNodeOffset = @itemOffsetToNodeOffset(item, offset)
          endDOMNodeOffset = @itemOffsetToNodeOffset(item, offset + 1)
          side = 'left'
        else
          startDOMNodeOffset = @itemOffsetToNodeOffset(item, offset - 1)
          endDOMNodeOffset = @itemOffsetToNodeOffset(item, offset)
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
        if clientRects.length > 1
          alternateRect = clientRects[1]
          sameLine = alternateRect.top < baseRect.bottom
          if sameLine
            unless baseRect.width
              baseRect = alternateRect
          else if @selectionAffinity is Selection.SelectionAffinityUpstream
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

  ###
  Section: Scrolling
  ###

  isScrollingEnabled: ->
    @_disableScrolling is 0

  disableScrolling: ->
    @_disableScrolling++

  enableScrolling: ->
    @_disableScrolling--

  Object.defineProperty @::, 'scrollTopWithOverscroll',
    get: -> @scrollTop + -parseFloat(@topListElement.style.top or '0')

  Object.defineProperty @::, 'scrollLeftWithOverscroll',
    get: -> -parseFloat(@topListElement.style.left or '0')

  scrollTo: (newScrollLeft, newScrollTop, allowOverscroll) ->
    # Scrolling is a bit odd... The issues are that out of bounds scrolling
    # isn't allowed (so for example scrollTop = -10), but we need to get that
    # negative scroll effect to make hoist animations look right. The other
    # issue is that scrollLeft is disabled by CSS (I think) because generally
    # we don't want horizonal scrolling in the editor. But we do need it for
    # hoist animations.
    #
    # To resolve these issues scrolling is implmented in two ways. When
    # possible normal .scrollTop is used to scroll the editor. But in cases
    # where that isn't flexible enought then topUL.style.left and
    # topUL.style.top are used. Generally those cases should only happen
    # during hoist animations.
    unless @isScrollingEnabled()
      return

    scrollLeft = @scrollLeftWithOverscroll
    scrollTop = @scrollTopWithOverscroll
    newScrollLeft = scrollLeft if newScrollLeft is undefined
    newScrollTop = scrollTop if newScrollTop is undefined

    unless allowOverscroll
      newScrollLeft = 0
      bottomBoundary = @topListElement.scrollHeight - @getViewportRect().height
      newScrollTop = Math.min bottomBoundary, newScrollTop
      newScrollTop = Math.max 0, newScrollTop

    Velocity this, 'stop', true

    if scrollLeft is newScrollLeft and scrollTop is newScrollTop
      return

    if @isAnimationEnabled()
      Velocity
        e: this
        p:
          tween: 1
        o:
          duration: OutlineEditorElement.ScrollAnimationContext.duration
          easing: OutlineEditorElement.ScrollAnimationContext.easing
          progress: (elements, percentComplete, timeRemaining, timeStart, tweenValue) =>
            nextScrollLeft = scrollLeft + ((newScrollLeft - scrollLeft) * tweenValue)
            nextScrollTop = scrollTop + ((newScrollTop - scrollTop) * tweenValue)
            @_scrollTo nextScrollLeft, nextScrollTop
          complete: (elements) =>
            @_scrollTo newScrollLeft, newScrollTop
    else
      @_scrollTo newScrollLeft, newScrollTop

  _scrollTo: (newScrollLeft, newScrollTop) ->
    topUL = @topListElement
    viewportHeight = @getViewportRect().height
    scrollHeight = Math.max topUL.scrollHeight, viewportHeight

    @scrollTop = newScrollTop

    if newScrollTop < 0
      topUL.style.top = -newScrollTop + 'px'
    else
      needMore = newScrollTop - (scrollHeight - viewportHeight)
      if needMore > 0
        topUL.style.top = -needMore + 'px'
      else
        topUL.style.top = '0px'

    topUL.style.left = -newScrollLeft + 'px'

  scrollBy: (delta) ->
    @scrollTo(0, @scrollTop + delta)

  scrollToBeginningOfDocument: (e) ->
    @scrollTo(0, 0)

  scrollToEndOfDocument: (e) ->
    @scrollTo(0, @topListElement.getBoundingClientRect().height - @getViewportRect().height)

  scrollPageUp: (e) ->
    @scrollBy(-@getViewportRect().height)

  scrollPageDown: (e) ->
    @scrollBy(@getViewportRect().height)

  scrollToOffsetRange: (startOffset, endOffset, align) ->
    viewportRect = @getViewportRect()
    align = align or 'center'
    switch align
      when 'top'
        @scrollTo(0, startOffset)
      when 'center'
        offsetCenter = startOffset + ((endOffset - startOffset) / 2.0)
        offsetViewportCenter = offsetCenter - (viewportRect.height / 2.0)
        @scrollTo(0, offsetViewportCenter)
      when 'bottom'
        @scrollTo(0, endOffset - viewportRect.height)

  scrollToOffsetRangeIfNeeded: (startOffset, endOffset, center) ->
    viewportRect = @getViewportRect()
    rangeHeight = endOffset - startOffset
    scrollTop = viewportRect.top
    scrollBottom = viewportRect.bottom
    startsAboveTop = startOffset < scrollTop
    endsBelowBottom = endOffset > scrollBottom
    needsScroll = startsAboveTop or endsBelowBottom
    overlappingBothEnds = startsAboveTop and endsBelowBottom

    if needsScroll and not overlappingBothEnds
      if center
        @scrollToOffsetRange(startOffset, endOffset, 'center')
      else
        if rangeHeight > viewportRect.height
          if startsAboveTop
            @scrollToOffsetRange(startOffset, endOffset, 'bottom')
          else if endsBelowBottom
            @scrollToOffsetRange(startOffset, endOffset, 'top')
        else
          if startsAboveTop
            @scrollToOffsetRange(startOffset, endOffset, 'top')
          else if endsBelowBottom
            @scrollToOffsetRange(startOffset, endOffset, 'bottom')

  scrollToItem: (item, offset, align) ->
    if itemClientRect = @getClientRectForItemOffset item, offset
      viewportRect = @getViewportRect()
      scrollTop = viewportRect.top
      thisClientRect = @getBoundingClientRect()
      itemTop = scrollTop + (itemClientRect.top - thisClientRect.top)
      itemBottom = itemTop + itemClientRect.height
      @scrollToOffsetRange(itemTop, itemBottom, align)

  scrollToItemIfNeeded: (item, offset, center) ->
    if itemClientRect = @getClientRectForItemOffset item, offset
      viewportRect = @getViewportRect()
      scrollTop = viewportRect.top
      thisClientRect = @getBoundingClientRect()
      itemTop = scrollTop + (itemClientRect.top - thisClientRect.top)
      itemBottom = itemTop + itemClientRect.height
      @scrollToOffsetRangeIfNeeded(itemTop, itemBottom, center)

  ###
  Section: Picking
  ###

  pick: (clientX, clientY) ->
    @itemRenderer.pick clientX, clientY

  ###
  Section: Selection
  ###

  focus: ->
    # Update DOM selection to match editor selection if in text mode.
    # Otherwise give @focusElement focus when in outline mode.
    unless @isPerformingExtendSelectionInteraction()
      @focusElement.select()
      @focusElement.focus()

      editor = @editor
      selection = editor.DOMGetSelection()
      renderedSelection = @editorRangeFromDOMSelection()
      currentSelection = editor.selection

      if currentSelection.isValid
        if not currentSelection.equals(renderedSelection)
          if currentSelection.isTextMode
            nodeFocusOffset = @itemOffsetToNodeOffset(currentSelection.focusItem, currentSelection.focusOffset)
            nodeAnchorOffset = @itemOffsetToNodeOffset(currentSelection.anchorItem, currentSelection.anchorOffset)
            viewP = @itemViewPForItem(currentSelection.focusItem)
            range = document.createRange()

            selection.removeAllRanges()
            range.setStart(nodeAnchorOffset.node, nodeAnchorOffset.offset)
            selection.addRange(range)

            viewP.focus()

            if currentSelection.isCollapsed
              rect = currentSelection.focusClientRect
              if rect.positionedAtEndOfWrappingLine
                selection.modify('move', 'backward', 'character')
                selection.modify('move', 'forward', 'lineboundary')
            else
              selection.extend(nodeFocusOffset.node, nodeFocusOffset.offset)

  editorRangeFromDOMSelection: ->
    selection = @editor.DOMGetSelection()

    if selection.focusNode
      focusItem = @itemForViewNode(selection.focusNode)
      if focusItem
        focusOffset = @nodeOffsetToItemOffset(selection.focusNode, selection.focusOffset)
        anchorOffset = @nodeOffsetToItemOffset(selection.anchorNode, selection.anchorOffset)
        return new Selection(
          @editor,
          focusItem,
          focusOffset,
          @itemForViewNode(selection.anchorNode),
          anchorOffset
        )

    new Selection(@editor)

  isPerformingExtendSelectionInteraction: ->
    @_extendingSelectionInteraction

  beginExtendSelectionInteraction: (e) ->
    # Only start the drag interaction if "current" mouse down button is 0.
    # Mouse down events can get queued at startup, so that if we test e.button
    # it will say mouse is down when it really isn't, that that cause problem
    # in the selection interaction logic, since we never get mouseup event to
    # end it.
    if GlobalMouse.isGlobalLeftMouseDown()
      editor = @editor
      pick = @pick(e.clientX, e.clientY)
      caretPosition = pick.itemCaretPosition

      if caretPosition
        if e.shiftKey
          editor.extendSelectionRange(caretPosition.offsetItem, caretPosition.offset)
        else
          editor.moveSelectionRange(caretPosition.offsetItem, caretPosition.offset)

      # Calling prevent default fixes picking inbetween items. But it breaks
      # autoscroll, double-click select word and triple-click select paragraph.
      # e.preventDefault()
      e.stopPropagation()

      @disableScrolling()
      editor._disableSyncDOMSelectionToEditor = true
      @_extendingSelectionInteraction = true
      @_extendingSelectionInteractionLastScrollTop = editor.outlineEditorElement.scrollTop
      @_extendSelectionDisposables = new CompositeDisposable(
        EventRegistery.listen(document, 'mouseup', @onDocumentMouseUp.bind(this)), # Listen to document otherwise will miss some mouse ups
        EventRegistery.listen('.beditor', 'mousemove', rafdebounce(@onMouseMove.bind(this))),
        EventRegistery.listen(this, 'scroll', rafdebounce(@onScroll.bind(this))) # Listen directly to self since scroll doesn't bubble
      )

  onContextMenu: (e) ->
    e.preventDefault()
    e.stopPropagation()

    pick = @pick(e.clientX, e.clientY)
    caretPosition = pick.itemCaretPosition
    selection = @editor.selection

    if selection.isTextMode
      unless selection.contains caretPosition.offsetItem, caretPosition.offset
        @editor.moveSelectionRange caretPosition.offsetItem, caretPosition.offset
        @editor.extendSelectionRangeToWordBoundaries()
    else
      @editor.moveSelectionRange caretPosition.offsetItem, undefined

    setTimeout (-> atom.contextMenu.showForEvent(e)), 100

  onMouseMove: (e) ->
    pick = @pick(e.clientX, e.clientY)
    caretPosition = pick.itemCaretPosition

    if caretPosition
      #if e.target.classList.contains('ft-body-text') and caretPosition.offsetItem isnt @editor.selection.anchorItem
      #  e.preventDefault() # don't understand this
      @editor.extendSelectionRange(caretPosition.offsetItem, caretPosition.offset)

  onScroll: (e) ->
    lastScrollTop = @_extendingSelectionInteractionLastScrollTop
    scrollTop = @scrollTop
    item

    if scrollTop < lastScrollTop
      item = @getViewportFirstItem() # Scrolling Up
    else if scrollTop > lastScrollTop
      item = @getViewportLastItem() # Scrolling Down

    if item
      @editor.extendSelectionRange(item, undefined)

    @_extendingSelectionInteractionLastScrollTop = scrollTop

  onDocumentMouseUp: (e) ->
    @endExtendSelectionInteraction()

  endExtendSelectionInteraction: (e) ->
    editor = @editor
    @enableScrolling()
    editor._disableSyncDOMSelectionToEditor = false

    @_extendSelectionDisposables.dispose()
    @_extendSelectionDisposables = new CompositeDisposable
    @_extendingSelectionInteraction = false

    selectionRange = editor.selection
    if selectionRange.isTextMode
      editor.moveSelectionRange(@editorRangeFromDOMSelection()) # Read in selection from double-click, etc.
    else
      editor.moveSelectionRange(selectionRange)

  ###
  Section: Drag and Drop
  ###

  onDragStart: (e) ->
    item = @itemForViewNode e.target
    li = @renderedLIForItem item
    liRect = li.getBoundingClientRect()
    x = e.clientX - liRect.left
    y = e.clientY - liRect.top

    e.stopPropagation()
    e.dataTransfer.effectAllowed = 'all'
    e.dataTransfer.setDragImage li, x, y
    e.dataTransfer.setData 'application/json', JSON.stringify
      outlineID: item.outline.id
      itemID: item.id
    ItemSerializer.writeItems [item], @editor, e.dataTransfer

    @editor._hackDragItemMouseOffset =
      xOffset: x
      yOffset: y
    @editor.setDragState
      draggedItem: item

  onDrag: (e) ->
    e.stopPropagation()
    item = @itemForViewNode e.target
    draggedItem = @editor.draggedItem()
    if item isnt draggedItem
      e.preventDefault()

  onDragEnd: (e) ->
    # Should remove item if was a move. Remove item
    @editor.setDragState {}
    e.stopPropagation()

  onDragEnter: (e) ->
    @onDragOver(e)

  onDragOver: (e) ->
    e.stopPropagation()
    e.preventDefault()

    draggedItem = @editor.draggedItem()
    dropTarget = @_dropTargetForEvent e
    dropEffect = e.dataTransfer.effectAllowed

    if dropEffect is 'all'
      dropEffect = 'move'

    unless @_isValidDrop dropTarget, draggedItem, dropEffect
      dropTarget.parent = null
      dropTarget.insertBefore = null
      dropEffect = 'none'

    e.dataTransfer.dropEffect = dropEffect

    @editor.debouncedSetDragState
      'draggedItem': draggedItem
      'dropEffect': dropEffect
      'dropParentItem': dropTarget.parent
      'dropInsertBeforeItem': dropTarget.insertBefore

  onDragLeave: (e) ->
    @editor.debouncedSetDragState
      'draggedItem': @editor.draggedItem()
      'dropEffect': e.dataTransfer.dropEffect

  onDrop: (e) ->
    e.stopPropagation()
    e.preventDefault()

    # For some reason "dropEffect is always set to 'none' on e. So track it in
    # store state instead. Not sure if I'm doing something wrong or what.
    dropEffect = @editor.dropEffect()
    droppedItem = @_itemToInsertForEvent e
    dropParentItem = @editor.dropParentItem()
    dropInsertBeforeItem = @editor.dropInsertBeforeItem()

    if droppedItem and dropParentItem
      insertItem
      if dropEffect is 'all' or dropEffect is 'move'
        insertItem = droppedItem
      else if dropEffect is 'copy'
        insertItem = droppedItem.cloneItem()
      else if dropEffect is 'link'
        console.log 'link'

      if insertItem and insertItem isnt dropInsertBeforeItem
        outline = dropParentItem.outline
        undoManager = outline.undoManager

        if insertItem.parent
          compareTo = if dropInsertBeforeItem then dropInsertBeforeItem else dropParentItem.lastChild
          unless compareTo
            compareTo = dropParentItem

          if insertItem.comparePosition(compareTo) & Node.DOCUMENT_POSITION_FOLLOWING
            @scrollBy(-@renderedLIForItem(insertItem).clientHeight)

        moveStartOffset

        if droppedItem is insertItem
          renderedLI = @renderedLIForItem(droppedItem)
          if renderedLI
            editorElementRect = @getBoundingClientRect()
            renderedLIRect = renderedLI.getBoundingClientRect()
            editorLITop = renderedLIRect.top - editorElementRect.top
            editorLILeft = renderedLIRect.left - editorElementRect.left
            editorX = e.clientX - editorElementRect.left
            editorY = e.clientY - editorElementRect.top

            if @editor._hackDragItemMouseOffset
              editorX -= @editor._hackDragItemMouseOffset.xOffset
              editorY -= @editor._hackDragItemMouseOffset.yOffset

            moveStartOffset =
              xOffset: editorX - editorLILeft
              yOffset: editorY - editorLITop

        @editor.moveItems([insertItem], dropParentItem, dropInsertBeforeItem, moveStartOffset)
        undoManager.setActionName('Drag and Drop')

    @editor.debouncedSetDragState({})

  _itemToInsertForEvent: (e) ->
    draggedItem = @editor.draggedItem()
    return draggedItem if draggedItem

    try
      # If item is from another outline must import it into this outline.
      draggedItemIDs = JSON.parse e.dataTransfer.getData('application/json')
      outline = Outline.getOutlineForID draggedItemIDs.outlineID
      draggedItem = outline.getItemForID draggedItemIDs.itemID
      draggedItem = @editor.outline.importItem draggedItem.cloneItem()
      return draggedItem if draggedItem
    catch error

    items = ItemSerializer.readItems @editor, e.dataTransfer
    if items.itemFragmentString
      @editor.outline.createItem items.itemFragmentString
    else
      items[0]

  _dropTargetForEvent: (e) ->
    picked = @pick(e.clientX, e.clientY)
    itemCaretPosition = picked.itemCaretPosition

    unless itemCaretPosition
      return {}

    pickedItem = itemCaretPosition.offsetItem
    itemPickAffinity = itemCaretPosition.itemAffinity
    newDropInserBeforeItem = null
    newDropInsertAfterItem = null
    newDropParent = null

    if itemPickAffinity is Selection.ItemAffinityAbove or itemPickAffinity is Selection.ItemAffinityTopHalf
      {} =
        parent: pickedItem.parent
        insertBefore: pickedItem
    else
      if pickedItem.firstChild and @editor.isExpanded(pickedItem)
        {} =
          parent: pickedItem
          insertBefore: @editor.getFirstVisibleChild(pickedItem)
      else
        {} =
          parent: pickedItem.parent
          insertBefore: @editor.getNextVisibleSibling(pickedItem)

  _isValidDrop: (dropTarget, draggedItem, dropEffect) ->
    unless draggedItem
      # 'application/json' only seems present on drop event, not in dragOver.
      # 'Also want to support dropping of plain text and other things... so
      # 'validate all drops that don't have an item. Accept/reject will be
      # 'determined in drop handler.
      true
    else
      if dropEffect is 'move'
        if draggedItem and dropTarget.parent
          dropTarget.parent isnt draggedItem and not draggedItem.contains dropTarget.parent
        else
          false
      else
        true

  ###
  Section: Util
  ###

  @findOutlineEditor: (element) ->
    @findOutlineEditorElement(element)?.editor

  @findOutlineEditorElement: (element) ->
    while element and element.tagName isnt 'FT-OUTLINE-EDITOR'
      element = element.parentNode
    element

  itemForViewNode: (viewNode) ->
    @itemRenderer.itemForRenderedNode viewNode

  renderedLIForItem: (item) ->
    @itemRenderer.renderedLIForItem item

  itemViewPForItem: (item) ->
    @_itemViewBodyP(@renderedLIForItem(item))

  nodeOffsetToItemOffset: (node, offset) ->
    ItemBodyEncoder.nodeOffsetToBodyTextOffset(node, offset, @_itemViewBodyP(@renderedLIForItem(@itemForViewNode(node))))

  itemOffsetToNodeOffset: (item, offset) ->
    ItemBodyEncoder.bodyTextOffsetToNodeOffset(@_itemViewBodyP(@renderedLIForItem(item)), offset)

  _itemViewBodyP: (itemViewLI) ->
    ItemRenderer.renderedBodyTextSPANForRenderedLI itemViewLI

###
Util Functions
###

stopEventPropagation = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        commandListener.call(this, event)
  newCommandListeners

stopEventPropagationAndGroupUndo = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        commandListener.call(this, event)
  newCommandListeners

###
Event and Command registration
###

#
# Handle Selection Interaction
#

EventRegistery.listen 'ft-outline-editor > ul.top-item-list',
  'mousedown': (e) ->
    editorElement = OutlineEditorElement.findOutlineEditorElement e.target
    editorElement.editor.focus()
    setTimeout ->
      editorElement.beginExtendSelectionInteraction e

EventRegistery.listen '.ft-body-text',
  'mousedown': (e) ->
    editorElement = OutlineEditorElement.findOutlineEditorElement e.target
    editorElement.editor.focus()
    editorElement.beginExtendSelectionInteraction e
    e.stopPropagation()

#
# Handle Text Input
#

EventRegistery.listen '.ft-item-content',
  compositionstart: (e) ->
  compositionupdate: (e) ->
  compositionend: (e) ->
  input: (e) ->
    editorElement = OutlineEditorElement.findOutlineEditorElement e.target
    editor = editorElement.editor
    typingFormattingTags = editor.getTypingFormattingTags()
    item = editorElement.itemForViewNode e.target
    itemViewLI = editorElement.renderedLIForItem item
    itemViewP = editorElement._itemViewBodyP itemViewLI
    newBodyText = ItemBodyEncoder.bodyEncodedTextContent itemViewP
    oldBodyText = item.bodyText
    outline = item.outline
    location = 0

    outline.beginUpdates()

    # Insert marker into old body text to ensure diffs get generated in
    # correct locations. For example if user has cursor at position "tw^o"
    # and types an "o" then the default diff will insert a new "o" after the
    # original. But that's not what is needed since the cursor is after the
    # "w" not the "o". In plain text it doesn't make much difference, but
    # when rich text attributes (bold, italic, etc) are in play it can mess
    # things up... so add the marker which will server as an anchor point
    # from which the diff is generated.
    marker = '\uE000'
    markerRegex = new RegExp marker, 'g'
    startOffset = editor.selection.startOffset
    markedOldBodyText = oldBodyText.slice(0, startOffset) + marker + oldBodyText.slice(startOffset)

    for each in diff markedOldBodyText, newBodyText
      type = each[0]
      text = each[1].replace(markerRegex, '')

      if text.length
        switch type
          when diff.INSERT
            text = new AttributedString text
            text.addAttributesInRange typingFormattingTags, 0, -1
            item.replaceBodyTextInRange text, location, 0
          when diff.EQUAL
            location += text.length
          when diff.DELETE
            if text isnt '^'
              item.replaceBodyTextInRange '', location, text.length


    # Range affinity should always be upstream after text input
    editorRange = editorElement.editorRangeFromDOMSelection()
    editorRange.selectionAffinity = Selection.SelectionAffinityUpstream
    editor.moveSelectionRange editorRange

    outline.endUpdates()

#
# Handle clicking on handle
#

EventRegistery.listen '.ft-handle',
  mousedown: (e) ->
    editorElement = OutlineEditorElement.findOutlineEditorElement e.target
    editor = editorElement.editor
    editorElement._maintainSelection = editor.selection
    e.stopPropagation()

  focusin: (e) ->
    setTimeout ->
      e.target.blur()

  focusout: (e) ->
    editorElement = OutlineEditorElement.findOutlineEditorElement e.target
    maintainSelection = editorElement._maintainSelection
    editor = editorElement.editor

    if maintainSelection
      setTimeout ->
        if maintainSelection.isTextMode
          editor.focus()
          @disableScrolling()
          editor.moveSelectionRange maintainSelection
          @enableScrolling()
        else
          editor.focus()

  click: (e) ->
    editorElement = OutlineEditorElement.findOutlineEditorElement e.target
    item = editorElement.itemForViewNode e.target
    editor = editorElement.editor
    if item
      if e.metaKey
        editor.hoistItem item
      else if item.firstChild
        if e.shiftKey
          editor.toggleFullyFoldItems item
        else
          editor.toggleFoldItems item

    e.stopPropagation()

#
# Handle clicking on file links
#

EventRegistery.listen '.ft-body-text a',
  click: (e) ->
    if href = e.target.href
      if href.indexOf('file://') is 0
        e.preventDefault()
        e.stopPropagation()
        atom.workspace.open unescape(href.substring(7)),
          searchAllPanes: true

#
# Handle Cut/Copy/Paste
#

EventRegistery.listen 'input[is="outline-editor-focus"]', stopEventPropagation(
  'cut': (e) -> @parentElement.editor.cutSelection(e.clipboardData)
  'copy': (e) -> @parentElement.editor.copySelection(e.clipboardData)
  'paste': (e) -> @parentElement.editor.pasteToSelection(e.clipboardData)
)

clipboardAsDatatransfer =
  getData: (type) -> atom.clipboard.read()
  setData: (type, data) -> atom.clipboard.write(data)

atom.commands.add 'ft-outline-editor', stopEventPropagationAndGroupUndo(
  'core:cut': (e) ->
    @editor.cutSelection clipboardAsDatatransfer
  'core:copy': (e) ->
    @editor.copySelection clipboardAsDatatransfer
  'core:paste': (e) ->
    @editor.pasteToSelection clipboardAsDatatransfer
)

#
# Handle Context Menu
#

EventRegistery.listen 'ft-outline-editor',
  'contextmenu': (e) -> @onContextMenu(e)

#
# Handle Commands
#

atom.commands.add 'ft-outline-editor', stopEventPropagationAndGroupUndo(
  'core:undo': -> @editor.undo()
  'core:redo': -> @editor.redo()
  'editor:newline': -> @editor.insertNewline()
  'editor:newline-above': -> @editor.insertItemAbove()
  'editor:newline-below': -> @editor.insertItemBelow()
  'editor:newline-ignore-field-editor': -> @editor.insertNewlineIgnoringFieldEditor()
  'editor:line-break': -> @editor.insertLineBreak()
  'editor:indent': -> @editor.indent()
  'editor:indent-selected-rows': -> @editor.indent()
  'editor:outdent-selected-rows': -> @editor.outdent()
  'editor:insert-tab-ignoring-field-editor': -> @editor.insertTabIgnoringFieldEditor()
  'core:backspace': -> @editor.deleteBackward()
  #'core:backspace-decomposing-previous-character': -> @editor.deleteBackwardByDecomposingPreviousCharacter()
  'editor:delete-to-beginning-of-word': -> @editor.deleteWordBackward()
  'editor:delete-to-beginning-of-line': -> @editor.deleteToBeginningOfLine()
  'deleteToEndOfParagraph': -> @editor.deleteToEndOfParagraph()
  'core:delete': -> @editor.deleteForward()
  'editor:delete-to-end-of-word': -> @editor.deleteWordForward()
  'editor:move-line-up': -> @editor.moveItemsUp()
  'editor:move-line-down': -> @editor.moveItemsDown()
  'outline-editor:promote-child-items': -> @editor.promoteChildItems()
  'outline-editor:demote-trailing-sibling-items': -> @editor.demoteTrailingSiblingItems()
  'outline-editor:group-items': -> @editor.groupItems()
  'deleteItemsBackward': -> @editor.deleteItemsBackward()
  'deleteItemsForward': -> @editor.deleteItemsForward()
  'outline-editor:toggle-abbreviation': -> @editor.toggleFormattingTag 'ABBR'
  'outline-editor:toggle-bold': -> @editor.toggleFormattingTag 'B'
  'outline-editor:toggle-citation': -> @editor.toggleFormattingTag 'CITE'
  'outline-editor:toggle-code': -> @editor.toggleFormattingTag 'CODE'
  'outline-editor:toggle-definition': -> @editor.toggleFormattingTag 'DFN'
  'outline-editor:toggle-emphasis': -> @editor.toggleFormattingTag 'EM'
  'outline-editor:toggle-italic': -> @editor.toggleFormattingTag 'I'
  'outline-editor:toggle-keyboard-input': -> @editor.toggleFormattingTag 'KBD'
  'outline-editor:toggle-inline-quote': -> @editor.toggleFormattingTag 'Q'
  'outline-editor:toggle-strikethrough': -> @editor.toggleFormattingTag 'S'
  'outline-editor:toggle-sample-output': -> @editor.toggleFormattingTag 'SAMP'
  'outline-editor:toggle-small': -> @editor.toggleFormattingTag 'SMALL'
  'outline-editor:toggle-strong': -> @editor.toggleFormattingTag 'STRONG'
  'outline-editor:toggle-subscript': -> @editor.toggleFormattingTag 'SUB'
  'outline-editor:toggle-superscript': -> @editor.toggleFormattingTag 'SUP'
  'outline-editor:toggle-underline': -> @editor.toggleFormattingTag 'U'
  'outline-editor:toggle-variable': -> @editor.toggleFormattingTag 'VAR'

  'outline-editor:clear-formatting': -> @editor.clearFormatting()
  'editor:upper-case': -> @editor.upperCase()
  'editor:lower-case': -> @editor.lowerCase()
)

atom.commands.add 'ft-outline-editor', stopEventPropagation(
  'core:cancel': ->
    if @editor.isTextMode()
      @editor.extendSelectionRangeToItemBoundaries()

  'core:move-backward': -> @editor.moveBackward()
  'core:select-backward': -> @editor.moveBackwardAndModifySelection()
  'core:move-up': -> @editor.moveUp()
  'core:select-up': -> @editor.moveUpAndModifySelection()
  'core:move-to-top': -> @editor.moveToBeginningOfDocument()
  'core:select-to-top': -> @editor.moveToBeginningOfDocumentAndModifySelection()
  'core:move-forward': -> @editor.moveForward()
  'core:select-forward': -> @editor.moveForwardAndModifySelection()
  'core:move-down': -> @editor.moveDown()
  'core:select-down': -> @editor.moveDownAndModifySelection()
  'core:move-to-bottom': -> @editor.moveToEndOfDocument()
  'core:select-to-bottom': -> @editor.moveToEndOfDocumentAndModifySelection()
  'core:move-left': -> @editor.moveLeft()
  'core:select-left': -> @editor.moveLeftAndModifySelection()
  'editor:move-to-beginning-of-word': -> @editor.moveWordLeft()
  'editor:select-to-beginning-of-word': -> @editor.moveWordLeftAndModifySelection()
  'editor:move-to-first-character-of-line': -> @editor.moveToBeginningOfLine()
  'editor:select-to-first-character-of-line': -> @editor.moveToBeginningOfLineAndModifySelection()
  'editor:move-to-beginning-of-line': -> @editor.moveToBeginningOfLine()
  'editor:select-to-beginning-of-line': -> @editor.moveToBeginningOfLineAndModifySelection()
  'editor:move-to-beginning-of-paragraph': -> @editor.moveToBeginningOfParagraph()
  'editor:select-to-beginning-of-paragraph': -> @editor.moveToBeginningOfParagraphAndModifySelection()
  'editor:move-paragraph-backward': -> @editor.moveParagraphBackward()
  'editor:select-paragraph-backward': -> @editor.moveParagraphBackwardAndModifySelection()
  'core:move-right': -> @editor.moveRight()
  'core:select-right': -> @editor.moveRightAndModifySelection()
  'editor:move-to-end-of-word': -> @editor.moveWordRight()
  'editor:select-to-end-of-word': -> @editor.moveWordRightAndModifySelection()
  'editor:move-to-end-of-screen-line': -> @editor.moveToEndOfLine()
  'editor:select-to-end-of-screen-line': -> @editor.moveToEndOfLineAndModifySelection()
  'editor:move-to-end-of-line': -> @editor.moveToEndOfLine()
  'editor:select-to-end-of-line': -> @editor.moveToEndOfLineAndModifySelection()
  'editor:move-to-end-of-paragraph': -> @editor.moveToEndOfParagraph()
  'editor:select-to-end-of-paragraph': -> @editor.moveToEndOfParagraphAndModifySelection()
  'editor:move-paragraph-forward': -> @editor.moveParagraphForward()
  'editor:select-paragraph-forward': -> @editor.moveParagraphForwardAndModifySelection()
  'core:select-all': -> @editor.selectAll()
  'editor:select-line': -> @editor.extendSelectionRangeToItemBoundaries()
  'outline-editor:hoist': -> @editor.hoistItem()
  'outline-editor:unhoist': -> @editor.unhoist()
  'editor:scroll-to-top': -> @editor.scrollToBeginningOfDocument()
  'editor:scroll-to-bottom': -> @editor.scrollToEndOfDocument()
  'editor:scroll-to-selection': -> @editor.centerSelectionInVisibleArea()
  'editor:scroll-to-cursor': -> @editor.centerSelectionInVisibleArea()
  'core:scroll-page-up': -> @editor.scrollPageUp()
  'core:select-page-up': -> @editor.pageUpAndModifySelection()
  'core:page-up': -> @editor.pageUp()
  'core:scroll-page-down': -> @editor.scrollPageDown()
  'core:select-page-down': -> @editor.pageDownAndModifySelection()
  'core:page-down': -> @editor.pageDown()
  'editor:fold-current-row': -> @editor.foldItems()
  'editor:unfold-current-row': -> @editor.unfoldItems()
  'outline-editor:toggle-fold-items': -> @editor.toggleFoldItems()
  'outline-editor:toggle-fully-fold-items': -> @editor.toggleFullyFoldItems()
  'editor:copy-path': -> @editor.copyPathToClipboard()
)

document.registerElement 'ft-outline-editor', prototype: OutlineEditorElement.prototype