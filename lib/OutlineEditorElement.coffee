# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

ChildrenAnimation = require './animations/ChildrenAnimation'
InsertAnimation = require './animations/InsertAnimation'
RemoveAnimation = require './animations/RemoveAnimation'
MoveAnimation = require './animations/MoveAnimation'
FocusElement = require './elements/FocusElement'
AttributedString = require './AttributedString'
ItemBodyEncoder = require './ItemBodyEncoder'
ItemSerializer = require './ItemSerializer'
EventRegistery = require './EventRegistery'
ItemRenderer = require './ItemRenderer'
{CompositeDisposable} = require 'atom'
Velocity = require 'velocity-animate'
Selection = require './Selection'
Constants = require './Constants'
diff = require 'fast-diff'
Util = require './Util'

class OutlineEditorElement extends HTMLElement

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

    animationLayerElement = document.createElement 'DIV'
    animationLayerElement.className = 'animationLayer'
    animationLayerElement.style.position = 'absolute'
    animationLayerElement.style.zIndex = '1'
    @appendChild animationLayerElement
    @animationLayerElement = animationLayerElement

    @styledTextCaretElement = document.createElement 'DIV'
    @styledTextCaretElement.className = 'styledTextCaret'
    @styledTextCaretElement.style.position = 'absolute'
    @styledTextCaretElement.style.zIndex = '1'
    @appendChild @styledTextCaretElement

    @focusElement = new FocusElement
    @appendChild(@focusElement)

    #textField = document.createElement 'INPUT'
    #textField.setAttribute 'type', 'text'
    #@appendChild textField

    topListElement = document.createElement('UL')
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

    @useStyledTextCaret = atom.config.get 'birch-outline-editor.useStyledTextCaret'
    @subscriptions.add atom.config.observe 'birch-outline-editor.useStyledTextCaret', (newValue) =>
      @useStyledTextCaret = newValue
      @updateSimulatedCursor()

    @disableAnimationOverride = atom.config.get 'birch-outline-editor.disableAnimation'
    @subscriptions.add atom.config.observe 'birch-outline-editor.disableAnimation', (newValue) =>
      @disableAnimationOverride = newValue

    this

  destroyed: ->
    if @parentNode
      @parentNode.removeChild(this)
    @subscriptions.dispose()
    @dragSubscription.dispose()
    @itemRenderer.destroyed()

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
    not @disableAnimationOverride and @_animationDisabled == 0

  disableAnimation: ->
    @_animationDisabled++

  enableAnimation: ->
    @_animationDisabled--

  animateMoveItems: (items, newParent, newNextSibling, startOffset) ->
    @itemRenderer.animateMoveItems items, newParent, newNextSibling, startOffset

  ###
  Section: Viewport
  ###

  viewportFirstItem: ->
    rect = @getBoundingClientRect()
    midX = rect.left + (rect.width / 2.0)
    @pick(midX, rect.top).itemCaretPosition?.offsetItem

  viewportLastItem: ->
    rect = @getBoundingClientRect()
    midX = rect.left + (rect.width / 2.0)
    @pick(midX, rect.bottom - 1).itemCaretPosition?.offsetItem

  viewportItems: ->
    startItem = @viewportFirstItem()
    endItem = @viewportLastItem()
    each = startItem
    items = []
    while each and each != endItem
      items.push(each)
      each = @editor.getNextVisibleItem(each)
    results

  viewportRect: ->
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
      bottomBoundary = @topListElement.scrollHeight - @viewportRect().height
      newScrollTop = Math.max 0, newScrollTop
      newScrollTop = Math.min bottomBoundary, newScrollTop

    Velocity this, 'stop', true

    if scrollLeft is newScrollLeft and scrollTop is newScrollTop
      return

    if @isAnimationEnabled()
      Velocity
        e: this
        p:
          tween: 1
        o:
          duration: Constants.ScrollAnimationContext.duration
          easing: Constants.ScrollAnimationContext.easing
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
    scrollHeight = topUL.scrollHeight
    viewportHeight = @viewportRect().height

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
    @scrollTo(0, @topListElement.getBoundingClientRect().height - @viewportRect().height)

  scrollPageUp: (e) ->
    @scrollBy(-@viewportRect().height)

  scrollPageDown: (e) ->
    @scrollBy(@viewportRect().height)

  scrollToOffsetRange: (startOffset, endOffset, align) ->
    viewportRect = @viewportRect()
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
    viewportRect = @viewportRect()
    rangeHeight = endOffset - startOffset
    scrollTop = viewportRect.top
    scrollBottom = viewportRect.bottom
    startsAboveTop = startOffset < scrollTop
    endsBelowBottom = endOffset > scrollBottom
    needsScroll = startsAboveTop || endsBelowBottom
    overlappingBothEnds = startsAboveTop && endsBelowBottom

    if needsScroll && !overlappingBothEnds
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

  scrollToItem: (item, align) ->
    viewP = @itemViewPForItem(item)
    if viewP
      viewportRect = @viewportRect()
      scrollTop = viewportRect.top
      itemClientRect = viewP.getBoundingClientRect()
      thisClientRect = @getBoundingClientRect()
      itemTop = scrollTop + (itemClientRect.top - thisClientRect.top)
      itemBottom = itemTop + itemClientRect.height
      @scrollToOffsetRange(itemTop, itemBottom, align)

  scrollToItemIfNeeded: (item, center) ->
    viewP = @itemViewPForItem(item)
    if viewP
      viewportRect = @viewportRect()
      scrollTop = viewportRect.top
      itemClientRect = viewP.getBoundingClientRect()
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
    @focusElement.select()
    @focusElement.focus()

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
    editor = @editor
    pick = @pick(e.clientX, e.clientY)
    caretPosition = pick.itemCaretPosition

    if caretPosition
      if e.shiftKey
        editor.extendSelectionRange(caretPosition.offsetItem, caretPosition.offset)
      else
        editor.moveSelectionRange(caretPosition.offsetItem, caretPosition.offset)

    e.stopPropagation()
    # Calling prevent default fixes picking inbetween items. But it breaks
    # autoscroll, double-click select word and triple-click select paragraph.
    # e.preventDefault()

    if e.button == 0
      @disableScrolling()
      editor._disableSyncDOMSelectionToEditor = true
      @_extendingSelectionInteraction = true
      @_extendingSelectionInteractionLastScrollTop = editor.outlineEditorElement.scrollTop
      @_extendSelectionDisposables = new CompositeDisposable(
        EventRegistery.listen(document, 'mouseup', @onDocumentMouseUp.bind(this)), # Listen to document otherwise will miss some mouse ups
        EventRegistery.listen('.beditor', 'mousemove', Util.debounce(@onMouseMove.bind(this))),
        EventRegistery.listen(this, 'scroll', Util.debounce(@onScroll.bind(this))) # Listen directly to self since scroll doesn't bubble
      )

  onContextMenu: (e) ->
    picked = @pick e.clientX, e.clientY

  onMouseMove: (e) ->
    pick = @pick(e.clientX, e.clientY)
    caretPosition = pick.itemCaretPosition

    if caretPosition
      #if e.target.classList.contains('bbodytext') and caretPosition.offsetItem != @editor.selection.anchorItem
      #  e.preventDefault() # don't understand this
      @editor.extendSelectionRange(caretPosition.offsetItem, caretPosition.offset)

  onScroll: (e) ->
    lastScrollTop = @_extendingSelectionInteractionLastScrollTop
    scrollTop = @scrollTop
    item

    if scrollTop < lastScrollTop
      item = @viewportFirstItem() # Scrolling Up
    else if scrollTop > lastScrollTop
      item = @viewportLastItem() # Scrolling Down

    if item
      @editor.extendSelectionRange(item, undefined)

    @_extendingSelectionInteractionLastScrollTop = scrollTop

  onDocumentMouseUp: (e) ->
    @endExtendSelectionInteraction()

  endExtendSelectionInteraction: (e) ->
    editor = @editor
    @enableScrolling()
    editor._disableSyncDOMSelectionToEditor = false
    selectionRange = editor.selection

    if selectionRange.isTextMode
      editor.moveSelectionRange(@editorRangeFromDOMSelection()) # Read in selection from double-click, etc.
    else
      editor.moveSelectionRange(selectionRange)

    @_extendSelectionDisposables.dispose()
    @_extendSelectionDisposables = new CompositeDisposable
    @_extendingSelectionInteraction = false

  updateSimulatedCursor: ->
    if @useStyledTextCaret
      selection = @editor.selection
      if selection.isTextMode and selection.isCollapsed
        width = 2
        rect = selection.focusClientRect
        @styledTextCaretElement.style.top = rect.top + 'px'
        @styledTextCaretElement.style.left = (rect.left - (width / 2)) + 'px'
        @styledTextCaretElement.style.height = rect.height + 'px'
        @styledTextCaretElement.style.width = width + 'px'

        @styledTextCaretElement.style.display = null
      else
        @styledTextCaretElement.style.display = 'none'
    else
      @styledTextCaretElement.style.display = 'none'

  ###
  Section: Drag and Drop
  ###

  onDragStart: (e) ->
    item = @itemForViewNode(e.target)
    li = @itemViewLIForItem(item)
    liRect = li.getBoundingClientRect()
    x = e.clientX - liRect.left
    y = e.clientY - liRect.top

    e.stopPropagation()
    e.dataTransfer.effectAllowed = 'all'
    e.dataTransfer.setDragImage(li, x, y)
    e.dataTransfer.setData('application/json', JSON.stringify({ itemID: item.id, editorID: @id }))
    ItemSerializer.writeItems([item], @editor, e.dataTransfer)

    @editor._hackDragItemMouseOffset =
      xOffset: x
      yOffset: y
    @editor.setDragState
      draggedItem: item

  onDrag: (e) ->
    e.stopPropagation()
    item = @itemForViewNode e.target
    draggedItem = @_draggedItemForEvent e
    if item != draggedItem
      e.preventDefault()

  onDragEnd: (e) ->
    @editor.setDragState {}
    e.stopPropagation()

  onDragEnter: (e) ->
    @onDragOver(e)

  onDragOver: (e) ->
    e.stopPropagation()
    e.preventDefault()

    draggedItem = @_draggedItemForEvent e
    dropTarget = @_dropTargetForEvent e

    unless e.ctrlKey or e.altKey
      e.dataTransfer.dropEffect = 'move'


    ###
    if e.ctrlKey
      e.dataTransfer.dropEffect = 'link'
    else if e.altKey
      e.dataTransfer.dropEffect = 'copy'
    else
      e.dataTransfer.dropEffect = 'move'

    if @_isInvalidDrop(dropTarget, draggedItem) and e.dataTransfer.dropEffect == 'move'
      e.dataTransfer.dropEffect = 'none'
      dropTarget.parent = null
      dropTarget.insertBefore = null
    ###

    @editor.debouncedSetDragState
      'draggedItem': draggedItem
      'dropEffect' : e.dataTransfer.dropEffect
      'dropParentItem' : dropTarget.parent
      'dropInsertBeforeItem' : dropTarget.insertBefore

  onDragLeave: (e) ->
    @editor.debouncedSetDragState
      'draggedItem': @_draggedItemForEvent e
      'dropEffect' : e.dataTransfer.dropEffect

  onDrop: (e) ->
    e.stopPropagation();

    # For some reason "dropEffect is always set to 'none' on e. So track
    # it in store state instead.
    dropEffect = @editor.dropEffect()
    draggedItem = @_draggedItemForEvent e
    dropParentItem = @editor.dropParentItem()
    dropInsertBeforeItem = @editor.dropInsertBeforeItem()

    #unless draggedItem
      #Pasteboard.setClipboardEvent(e);
      #draggedItem = Pasteboard.readNodes(editor.tree())[0];
      #Pasteboard.setClipboardEvent(null);

    if draggedItem and dropParentItem
      console.log 'dropEffect: ' + dropEffect
      console.log 'e.dataTransfer.dropEffect: ' + e.dataTransfer.dropEffect
      console.log 'effectAllowed: ' + e.dataTransfer.effectAllowed

      insertNode
      if dropEffect == 'move'
        insertNode = draggedItem
      else if dropEffect == 'copy'
        insertNode = draggedItem.cloneItem()
      else if dropEffect == 'link'
        console.log 'link'

      if insertNode and insertNode != dropInsertBeforeItem
        outline = dropParentItem.outline
        undoManager = outline.undoManager

        if insertNode.parent
          if insertNode.outline == outline
            compareTo = dropInsertBeforeItem ? dropInsertBeforeItem : dropParentItem.lastChild
            unless compareTo
              compareTo = dropParentItem

            if insertNode.comparePosition(compareTo) & Node.DOCUMENT_POSITION_FOLLOWING
              @scrollBy(-@itemViewLIForItem(insertNode).clientHeight)

        moveStartOffset

        if draggedItem == insertNode
          viewLI = @itemViewLIForItem(draggedItem)
          if viewLI
            editorElementRect = @getBoundingClientRect()
            viewLIRect = viewLI.getBoundingClientRect()
            editorLITop = viewLIRect.top - editorElementRect.top
            editorLILeft = viewLIRect.left - editorElementRect.left
            editorX = e.clientX - editorElementRect.left
            editorY = e.clientY - editorElementRect.top

            if @editor._hackDragItemMouseOffset
              editorX -= @editor._hackDragItemMouseOffset.xOffset
              editorY -= @editor._hackDragItemMouseOffset.yOffset

            moveStartOffset =
              xOffset: editorX - editorLILeft
              yOffset: editorY - editorLITop

        @editor.moveItems([insertNode], dropParentItem, dropInsertBeforeItem, moveStartOffset)
        undoManager.setActionName('Drag and Drop')

    @editor.debouncedSetDragState({})

  _draggedItemForEvent: (e) ->
    @editor.draggedItem()
    #try
    #  draggedIDs = JSON.parse(e.dataTransfer.getData('application/json'))
    #  editorID = draggedIDs.editorID
    #  itemID = draggedIDs.itemID
    #  if @id is editorID
    #    return @editor.outline.getItemForID itemID
    #catch

  _isInvalidDrop: (dropTarget, draggedItem) ->
    return !draggedItem or !dropTarget.parent or (dropTarget.parent == draggedItem or draggedItem.contains(dropTarget.parent));

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

    if itemPickAffinity == Constants.ItemAffinityAbove or itemPickAffinity == Constants.ItemAffinityTopHalf
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

  ###
  Section: Util
  ###

  itemForViewNode: (viewNode) ->
    @itemRenderer.itemForRenderedNode viewNode

  itemViewLIForItem: (item) ->
    @itemRenderer.renderedLIForItem item

  itemViewPForItem: (item) ->
    @_itemViewBodyP(@itemViewLIForItem(item))

  nodeOffsetToItemOffset: (node, offset) ->
    ItemBodyEncoder.nodeOffsetToBodyTextOffset(node, offset, @_itemViewBodyP(@itemViewLIForItem(@itemForViewNode(node))))

  itemOffsetToNodeOffset: (item, offset) ->
    ItemBodyEncoder.bodyTextOffsetToNodeOffset(@_itemViewBodyP(@itemViewLIForItem(item)), offset)

  _itemViewBodyP: (itemViewLI) ->
    ItemRenderer.renderedBodyTextSPANForRenderedLI itemViewLI

###
Util Functions
###

findOutlineEditorElement = (e) ->
  element = e.target
  while element and element.tagName != 'BIRCH-OUTLINE-EDITOR'
    element = element.parentNode
  element

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

EventRegistery.listen 'birch-outline-editor > ul',
  'mousedown': (e) ->
    editorElement = findOutlineEditorElement e
    editorElement.editor.focus()
    setTimeout ->
      editorElement.beginExtendSelectionInteraction e

EventRegistery.listen '.bbodytext',
  'focusin': (e) ->
    editorElement = findOutlineEditorElement e
    editor = editorElement.editor
    unless editorElement.isPerformingExtendSelectionInteraction()
      focusItem = editorElement.itemForViewNode e.target
      if editor.selection.focusItem != focusItem
        editor.moveSelectionRange focusItem

  'mousedown': (e) ->
    editorElement = findOutlineEditorElement e
    editorElement.editor.focus()
    editorElement.beginExtendSelectionInteraction e
    e.stopPropagation()

#
# Handle Text Input
#

EventRegistery.listen '.bitemcontent',
  compositionstart: (e) ->
  compositionupdate: (e) ->
  compositionend: (e) ->
  input: (e) ->
    editorElement = findOutlineEditorElement e
    editor = editorElement.editor
    typingFormattingTags = editor.typingFormattingTags()
    item = editorElement.itemForViewNode e.target
    itemViewLI = editorElement.itemViewLIForItem item
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
            if text != '^'
              item.replaceBodyTextInRange '', location, text.length


    # Range affinity should always be upstream after text input
    editorRange = editorElement.editorRangeFromDOMSelection()
    editorRange.selectionAffinity = Constants.SelectionAffinityUpstream
    editor.moveSelectionRange editorRange

    outline.endUpdates()

#
# Handle clicking on handle
#

EventRegistery.listen '.bhandle',
  mousedown: (e) ->
    editorElement = findOutlineEditorElement e
    editor = editorElement.editor
    editorElement._maintainSelection = editor.selection
    e.stopPropagation()

  focusin: (e) ->
    setTimeout ->
      e.target.blur()

  focusout: (e) ->
    editorElement = findOutlineEditorElement e
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
    editorElement = findOutlineEditorElement e
    item = editorElement.itemForViewNode e.target
    editor = editorElement.editor
    if item
      if e.shiftKey
        editor.hoistItem item
      else if item.firstChild
        editor.toggleFoldItems item
    e.stopPropagation()

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

atom.commands.add 'birch-outline-editor', stopEventPropagationAndGroupUndo(
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

EventRegistery.listen 'birch-outline-editor',
  'contextmenu': (e) -> @onContextMenu(e)

#
# Handle Commands
#

atom.commands.add 'birch-outline-editor', stopEventPropagationAndGroupUndo(
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
  'birch-outline-editor:promote-child-items': -> @editor.promoteChildItems()
  'birch-outline-editor:demote-trailing-sibling-items': -> @editor.demoteTrailingSiblingItems()
  'birch-outline-editor:group-items': -> @editor.groupItems()
  'deleteItemsBackward': -> @editor.deleteItemsBackward()
  'deleteItemsForward': -> @editor.deleteItemsForward()
  'birch-outline-editor:toggle-bold': -> @editor.toggleBold()
  'birch-outline-editor:toggle-italic': -> @editor.toggleItalic()
  'birch-outline-editor:toggle-underline': -> @editor.toggleUnderline()
  'birch-outline-editor:toggle-strikethrough': -> @editor.toggleStrikethrough()
  'birch-outline-editor:toggle-code': -> @editor.toggleCode()
  'birch-outline-editor:edit-link': -> @editor.editLink()
  'birch-outline-editor:clear-formatting': -> @editor.clearFormatting()
  'editor:upper-case': -> @editor.upperCase()
  'editor:lower-case': -> @editor.lowerCase()
)

atom.commands.add 'birch-outline-editor', stopEventPropagation(
  'core:cancel': -> @editor.selectLine()
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
  'editor:select-line': -> @editor.selectLine()
  'birch-outline-editor:hoist': -> @editor.hoistItem()
  'birch-outline-editor:unhoist': -> @editor.unhoist()
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
  'birch-outline-editor:toggle-fold-items': -> @editor.toggleFoldItems()
  'editor:copy-path': -> @editor.copyPathToClipboard()
)

module.exports = document.registerElement 'birch-outline-editor', prototype: OutlineEditorElement.prototype