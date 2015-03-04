# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

OutlineEditorQueryFieldElement  = require './OutlineEditorQueryFieldElement'
OutlineEditorFocusElement = require './OutlineEditorFocusElement'
ChildrenULAnimation = require './animations/ChildrenULAnimation'
LIInsertAnimation = require './animations/LIInsertAnimation'
LIRemoveAnimation = require './animations/LIRemoveAnimation'
Selection = require './Selection'
LIMoveAnimation = require './animations/LIMoveAnimation'
ItemBodyEncoder = require './ItemBodyEncoder'
Mutation = require './Mutation'
ItemSerializer = require './ItemSerializer'
EventRegistery = require './EventRegistery'
{CompositeDisposable} = require 'atom'
Velocity = require 'velocity-animate'
Constants = require './Constants'
Util = require './Util'

require './OutlineEditorElementSelectionMouseHandler'
require './OutlineEditorElementHandleClickHandler'
require './OutlineEditorElementBodyInputHandler'

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
    @_animationDisabled = 0
    @_animationContexts = [Constants.DefaultItemAnimactionContext]
    @_maintainSelection = null
    @_animations = {}
    @_idsToElements = {}
    @_extendingSelection = false
    @_extendingSelectionLastScrollTop = undefined
    @_extendSelectionDisposables = new CompositeDisposable()

    @backgroundMessage = document.createElement('UL')
    @backgroundMessage.classList.add 'background-message'
    @backgroundMessage.classList.add 'centered'
    @backgroundMessage.style.display = 'none'
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

    outlineEditorFocusElement = new OutlineEditorFocusElement
    @appendChild(outlineEditorFocusElement)
    @outlineEditorFocusElement = outlineEditorFocusElement

    outlineEditorQueryFieldElement = new OutlineEditorQueryFieldElement
    #@appendChild(outlineEditorQueryFieldElement)

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
    @_idsToElements = null

  ###
  Section: Rendering
  ###

  createLIForItem: (item, level) ->
    li = document.createElement('LI')

    for eachName in item.attributeNames
      value = item.attribute(eachName)
      if value
        li.setAttribute(eachName, value)

    if level == undefined
      level = @_levelToHoistedItem(item)

    li.id = item.id
    li.className = @createItemClassString(item)
    li.setAttribute('data-level', level)
    li.appendChild(@createDIVForItemRow(item))

    @_idsToElements[item.id] = li

    childrenUL = @createULForItemChildren(item, level + 1)
    if childrenUL
      li.appendChild(childrenUL)

    li

  createItemClassString: (item) ->
    editor = @editor
    itemClass = ['bitem']

    if item.hasChildren
      itemClass.push('bhasChildren')

    if editor.isExpanded(item)
      itemClass.push('bexpandedItem')

    if editor.isSelected(item)
      itemClass.push('bselectedItem')
      if editor.selection.isTextMode
        itemClass.push('bselectedItemWithTextSelection')

    if editor.hoistedItem() == item
      itemClass.push('bhoistedItem')

    if editor.dropParentItem() == item
      itemClass.push('bdropParentItem')

    if editor.dropInsertBeforeItem() == item
      itemClass.push('bdropInsertBeforeItem')

    if editor.dropInsertAfterItem() == item
      itemClass.push('bdropInsertAfterItem')

    itemClass.join(' ')

  createDIVForItemRow: (item) ->
    div = document.createElement('DIV')
    div.className = 'bcontent'
    div.appendChild(@createDIVForItemGutter(item))
    div.appendChild(@createPForItemBody(item))
    div

  createDIVForItemGutter: (item) ->
    div = document.createElement('DIV')
    div.className = 'bgutter'
    div.appendChild(@createBUTTONForItemHandle(item))
    div

  createBUTTONForItemHandle: (item) ->
    button = document.createElement('button')
    button.className = 'bitemHandle'
    button.draggable = true
    button.tabIndex = -1
    button

  createPForItemBody: (item) ->
    p = document.createElement('p')
    p.className = 'bbody'
    p.contentEditable = true
    p.innerHTML = @createItemHighlightedBodyHTML(item)
    p

  createItemHighlightedBodyHTML: (item) ->
    #text = item.bodyText
    #index = text.indexOf('a')
    #if (index !== -1) {
    #  attributedString = item.attributedBodyText.copy();
    #  attributedString.addAttributeInRange('B', null, index, 1);
    #  p = document.createElement('p');
    #  p.appendChild(ItemBodyEncoder.attributedStringToDocumentFragment(attributedString, document));
    #  return p.innerHTML;
    #} else {
    #  return item.bodyHTML;
    #}
    item.bodyHTML

  createULForItemChildren: (item, level) ->
    editor = @editor
    if editor.isExpanded(item) || editor.hoistedItem() == item
      each = item.firstChild
      if each
        ul = document.createElement('UL')
        ul.className = 'bchildren'
        while each
          if editor.isVisible(each)
            ul.appendChild(@createLIForItem(each, level))
          each = each.nextSibling
        return ul

  _levelToHoistedItem: (item) ->
    hoistedItem = @editor.hoistedItem()
    level = 0
    while item != hoistedItem
      item = item.parent
      level++
    level

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

  animationContext: ->
    @_animationContexts[@_animationContexts.length - 1]

  pushAnimationContext: (context) ->
    @_animationContexts.push(context)

  popAnimationContext: ->
    @_animationContexts.pop()

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
      each = @editor.nextVisibleItem(each)
    results

  viewportRect: ->
    scrollTop = @scrollTop
    rect = @getBoundingClientRect()
    {} =
      top: scrollTop
      left: 0
      bottom: scrollTop + rect.height
      right: 0 + rect.width
      width: rect.width
      height: rect.height

  scrollTo: (offset) ->
    topListElement = @topListElement

    Velocity(topListElement, 'stop', true)

    if @scrollTop == offset
      return

    if @isAnimationEnabled()
      context = @animationContext()
      Velocity topListElement, 'scroll',
        duration: context.duration
        easing: context.easing
        container: this
        offset: offset
    else
      @scrollTop = offset

  scrollBy: (delta) ->
    @scrollTo(@scrollTop + delta)

  scrollToBeginningOfDocument: (e) ->
    @scrollTo(0)

  scrollToEndOfDocument: (e) ->
    @scrollTo(@topListElement.getBoundingClientRect().height - @viewportRect().height)

  scrollPageUp: (e) ->
    @scrollBy(-@viewportRect().height)

  scrollPageDown: (e) ->
    @scrollBy(@viewportRect().height)

  scrollToOffsetRange: (startOffset, endOffset, align) ->
    viewportRect = @viewportRect()
    align = align or 'center'
    switch align
      when 'top'
        @scrollTo(startOffset)
      when 'center'
        @scrollTo(startOffset + ((endOffset - startOffset) / 2.0) - (viewportRect.height / 2.0))
      when 'bottom'
        @scrollTo(endOffset - viewportRect.height)

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
  Section: Updates
  ###

  updateHoistedItem: (oldHoistedItem, newHoistedItem) ->
    editor = @editor

    #if @isAnimationEnabled && oldHoistedItem && newHoistedItem
      # 1. Find "RelativeToItem" that's visible in both views
      # 2. Get rect of item in first view.
      # 3. Disable animation
      # 4. Render next view
      # 5. Enable animation
      # 6. Get rect of item in second view.
      # 7. Animate topListElement relative based on differece between those two rects.
      #relativeToItem
      #oldVisible = editor.isVisible(oldHoistedItem),
      #  newVisible = editor.isVisible(newHoistedItem);

      #if (newVisible) {
        # fade out all roots that do not contain new hoisted item.
        # disable animate
        # means we are zooming in.
      #}

    @topListElement.innerHTML = ''
    @_idsToElements = {}
    if newHoistedItem
      @topListElement.appendChild(@createLIForItem(newHoistedItem));

  updateItemClass: (item) ->
    @itemViewLIForItem(item)?.className = @createItemClassString(item)

  updateItemAttribute: (item, attributeName) ->
    itemViewLI = @itemViewLIForItem(item)
    if itemViewLI
      if item.hasAttribute(attributeName)
        itemViewLI.setAttribute(attributeName, item.attribute(attributeName))
      else
        itemViewLI.removeAttribute(attributeName)

  updateItemBody: (item) ->
    itemViewLI = @itemViewLIForItem(item)
    if itemViewLI
      itemViewP = @_itemViewBodyP(itemViewLI)
      viewPHTML = itemViewP.innerHTML
      bodyHighlightedHTML = @createItemHighlightedBodyHTML(item)

      if viewPHTML != bodyHighlightedHTML
        itemViewP.innerHTML = bodyHighlightedHTML

  updateItemChildren: (item, removedChildren, addedChildren, nextSibling) ->
    itemViewLI = @itemViewLIForItem(item)
    if itemViewLI
      itemViewUL = @_itemViewChildrenUL(itemViewLI)
      animate = @isAnimationEnabled()
      editor = @editor

      @updateItemClass(item)

      for eachChild in removedChildren
        eachChildLI = @itemViewLIForItem(eachChild)
        if eachChildLI
          @_disconnectBranchIDs(eachChildLI)
          if animate
            @_animateRemoveLI(eachChild, eachChildLI)
          else
            itemViewUL.removeChild(eachChildLI)

      if addedChildren.length
        nextSiblingLI = @itemViewLIForItem(nextSibling)
        documentFragment = document.createDocumentFragment()
        addedChildrenLIs = []

        for eachChild in addedChildren
          if editor.isVisible(eachChild)
            eachChildItemLI = @createLIForItem(eachChild)
            addedChildrenLIs.push(eachChildItemLI)
            documentFragment.appendChild(eachChildItemLI)

        if !itemViewUL
          itemViewUL = @_itemViewChildrenUL(itemViewLI, true)

        itemViewUL.insertBefore(documentFragment, nextSiblingLI)

        if animate
          for eachChildLI in addedChildrenLIs
            @_animateInsertLI(
              editor.outline.itemForID(eachChildLI.id),
              eachChildLI
            )

  updateRefreshItemChildren: (item) ->
    itemViewLI = @itemViewLIForItem(item)
    if itemViewLI
      itemViewUL = @_itemViewChildrenUL(itemViewLI)

      if itemViewUL
        itemViewUL.parentNode.removeChild(itemViewUL)
        @_disconnectBranchIDs(itemViewUL)

      itemViewUL = @createULForItemChildren(
        item,
        @_levelToHoistedItem(item) + 1
      )
      if itemViewUL
        itemViewLI.appendChild(itemViewUL)

  updateItemExpanded: (item) ->
    @updateItemClass(item)

    itemViewLI = @itemViewLIForItem(item)
    if itemViewLI
      animate = @isAnimationEnabled()
      itemViewUL = @_itemViewChildrenUL(itemViewLI)

      if itemViewUL
        if animate
          @_animateCollapseUL(item, itemViewUL)
        else
          itemViewUL.parentNode.removeChild(itemViewUL)
        @_disconnectBranchIDs(itemViewUL)

      newViewUL = @createULForItemChildren(item, @_levelToHoistedItem(item) + 1)
      if newViewUL
        itemViewLI.appendChild(newViewUL)
        if animate
          @_animateExpandUL(item, newViewUL)

  outlineDidChange: (e) ->
    for each in e.mutations
      switch each.type
        when Mutation.AttributeChanged
          @updateItemAttribute(each.target, each.attributeName)
        when Mutation.BodyTextChanged
          @updateItemBody(each.target)
        when Mutation.ChildrenChanged
          @updateItemChildren(
            each.target,
            each.removedItems,
            each.addedItems,
            each.nextSibling
          )
        else
          throw new Error 'Unexpected Change Type'

  ###
  Section: Animations
  ###

  _completedAnimation: (id) ->
    delete @_animations[id]

  _animationForItem: (item, clazz) ->
    animationID = item.id + clazz.id
    animation = @_animations[animationID]

    if not animation
      animation = new clazz(animationID, item, this)
      @_animations[animationID] = animation

    animation

  _animateExpandUL: (item, viewUL) ->
    @_animationForItem(item, ChildrenULAnimation).expand(viewUL, @animationContext())

  _animateCollapseUL: (item, viewUL) ->
    @_animationForItem(item, ChildrenULAnimation).collapse(viewUL, @animationContext())

  _animateInsertLI: (item, viewLI) ->
    @_animationForItem(item, LIInsertAnimation).insert(viewLI, @animationContext())

  _animateRemoveLI: (item, viewLI) ->
    @_animationForItem(item, LIRemoveAnimation).remove(viewLI, @animationContext())

  _viewLIPosition: (viewLI) ->
    viewPRect = @_itemViewBodyP(viewLI).getBoundingClientRect()
    animationRect = @animationLayerElement.getBoundingClientRect()
    viewLIRect = viewLI.getBoundingClientRect()

    {
      top: viewLIRect.top - animationRect.top,
      bottom: viewPRect.bottom - animationRect.bottom,
      left: viewLIRect.left - animationRect.left,
      pLeft: viewPRect.left,
      width: viewLIRect.width
    }

  _animateMoveItems: (items, newParent, newNextSibling, startOffset) ->
    if items.length == 0
      return

    editor = @editor
    outline = editor.outline
    animate = @isAnimationEnabled()
    savedSelectionRange = editor.selection
    hoistedItem = editor.hoistedItem()
    context = @animationContext()
    animations = @_animations

    for own key, animation of animations
      animation.complete() if animation.complete

    if animate
      for each in items
        viewLI = @itemViewLIForItem(each);
        if viewLI
          startPosition = @_viewLIPosition(viewLI)
          if startOffset
            startPosition.left += startOffset.xOffset
            startPosition.top += startOffset.yOffset
            startPosition.bottom += startOffset.yOffset
          @_animationForItem(each, LIMoveAnimation).beginMove(viewLI, startPosition)

    firstItem = items[0]
    firstItemParent = firstItem.parent
    firstItemParentParent = firstItemParent?.parent
    lastItem = items[items.length - 1]
    shouldDisableRemoveInsertAndExpandAnimations = false
    newParentNeedsExpand = newParent != hoistedItem && !editor.isExpanded(newParent) && editor.isVisible(newParent)

    # Special case indent and unindent indentations when vertical position of
    # fist item won't change. In those cases disable all animations except
    # for the slide
    if newParent == editor.previousVisibleSibling(firstItem) && !newNextSibling && (!newParentNeedsExpand || !newParent.firstChild)
      shouldDisableRemoveInsertAndExpandAnimations = true
    else if newParent == firstItemParentParent && firstItemParent == lastItem.parent && editor.lastVisibleChild(lastItem.parent) == lastItem
      shouldDisableRemoveInsertAndExpandAnimations = true

    if shouldDisableRemoveInsertAndExpandAnimations
      @disableAnimation()

    outline.beginUpdates()
    outline.removeItemsFromParents(items)
    newParent.insertChildrenBefore(items, newNextSibling)
    outline.endUpdates()

    if newParentNeedsExpand
      editor.setExpanded(newParent)

    if shouldDisableRemoveInsertAndExpandAnimations
      @enableAnimation()

    editor.moveSelectionRange(savedSelectionRange)

    # Fast temporarily forward all animations to final position. Animation
    # system will automatically continue normal animations on next tick.
    for own key, animation of animations
      animation.fastForward(context)

    scrollToTop = Number.MAX_VALUE
    scrollToBottom = Number.MIN_VALUE

    if animate
      for each in items
        animation = animations[each.id + LIMoveAnimation.id]
        viewLI = @itemViewLIForItem(each)

        if animation
          position = @_viewLIPosition(viewLI, true)
          scrollToTop = Math.min(position.top, scrollToTop)
          scrollToBottom = Math.max(position.bottom, scrollToBottom)
          animation.performMove(viewLI, position, context)

    if scrollToTop != Number.MAX_VALUE
      @scrollToOffsetRangeIfNeeded(scrollToTop, scrollToBottom, true)

  ###
  Section: Picking
  ###

  pick: (clientX, clientY) ->
    topListElement = @topListElement

    if topListElement
      rect = topListElement.getBoundingClientRect()
      x = rect.left + (rect.width / 2.0)
      y = clientY
      row = @_pickRow(x, y)

      if not row
        lineHeight = parseInt(window.getComputedStyle(topListElement).lineHeight, 10)
        prevRow = @_pickNextRow(x, y, rect, -lineHeight)
        nextRow = @_pickNextRow(x, y, rect, lineHeight)

        if prevRow and nextRow
          prevRect = prevRow.getBoundingClientRect()
          nextRect = nextRow.getBoundingClientRect()
          prevDist = y - prevRect.bottom
          nextDist = nextRect.top - y

          if prevDist < nextDist
            row = prevRow
          else
            row = nextRow
        else if prevRow && !nextRow
          row = prevRow
        else if !prevRow && nextRow
          row = nextRow

      if row
        return @_pickItemBody(clientX, clientY, @_itemViewBodyP(row.parentNode))

    {}

  _pickRow: (x, y) ->
    each = @editor.DOMElementFromPoint(x, y)
    while each
      if each.tagName == 'DIV' && each.classList.contains('bcontent')
        return each
      each = each.parentNode

  _pickNextRow: (x, y, bounds, pickDelta) ->
    looking = ->
      if pickDelta < 0
        y > bounds.top
      else
        y < bounds.bottom

    while looking()
      row = @_pickRow(x, y)
      if row
        return row
      y += pickDelta

  _pickItemBody: (clientX, clientY, itemBody) ->
    item = @itemForViewNode(itemBody)
    bodyRect = itemBody.getBoundingClientRect()
    bodyRectMid = bodyRect.top + (bodyRect.height / 2.0)
    itemAffinity

    if clientY < bodyRect.top
      itemAffinity = Constants.ItemAffinityAbove
      clientX = Number.MIN_VALUE
    else if clientY < bodyRectMid
      itemAffinity = Constants.ItemAffinityTopHalf
    else if clientY > bodyRect.bottom
      itemAffinity = Constants.ItemAffinityBelow
      clientX = Number.MAX_VALUE
    else
      itemAffinity = Constants.ItemAffinityBottomHalf

    # Constrain pick point inside the text rect so that we'll get a good
    # 3 pick result.

    style = window.getComputedStyle(itemBody)
    paddingTop = parseInt(style.paddingTop, 10)
    paddingBottom = parseInt(style.paddingBottom, 10)
    lineHeight = parseInt(style.lineHeight, 10)
    halfLineHeight = lineHeight / 2.0
    bodyTop = Math.ceil(bodyRect.top)
    bodyBottom = Math.ceil(bodyRect.bottom)
    pickableBodyTop = bodyTop + halfLineHeight + paddingTop
    pickableBodyBottom = bodyBottom - (halfLineHeight + paddingBottom)

    if clientY <= pickableBodyTop
      clientY = pickableBodyTop
    else if clientY >= pickableBodyBottom
      clientY = pickableBodyBottom

    # Magic nubmer is "1" for x values, any more and we miss l's at the
    # end of the line.

    if clientX <= bodyRect.left
      clientX = Math.ceil(bodyRect.left) + 1
    else if clientX >= bodyRect.right
      clientX = Math.floor(bodyRect.right) - 1

    nodeCaretPosition = @_nodeCaretPositionFromPoint(clientX, clientY)
    itemCaretPosition = {
      offsetItem: item,
      offset: if nodeCaretPosition then @nodeOffsetToItemOffset(nodeCaretPosition.offsetItem, nodeCaretPosition.offset) else 0,
      selectionAffinity: if nodeCaretPosition then nodeCaretPosition.selectionAffinity else Constants.SelectionAffinityUpstream,
      itemAffinity: itemAffinity
    }

    return {
      nodeCaretPosition: nodeCaretPosition,
      itemCaretPosition: itemCaretPosition
    }

  ###
  Section: Selection
  ###

  focus: ->
    @outlineEditorFocusElement.select()
    @outlineEditorFocusElement.focus()

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

    # Calling prevent default fixes picking inbetween items. But it
    # breaks autoscroll. e.preventDefault();

    if e.button == 0
      editor._disableScrollToSelection = true
      editor._disableSyncDOMSelectionToEditor = true
      @_extendingSelection = true
      @_extendingSelectionLastScrollTop = editor.outlineEditorElement.scrollTop
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
      if e.target.tagName == 'P' and caretPosition.offsetItem != @editor.selection.anchorItem
        e.preventDefault()
      @editor.extendSelectionRange(caretPosition.offsetItem, caretPosition.offset)

  onScroll: (e) ->
    lastScrollTop = @_extendingSelectionLastScrollTop
    scrollTop = @scrollTop
    item

    if scrollTop < lastScrollTop
      item = @viewportFirstItem() # Scrolling Up
    else if scrollTop > lastScrollTop
      item = @viewportLastItem() # Scrolling Down

    if item
      @editor.extendSelectionRange(item, undefined)

    @_extendingSelectionLastScrollTop = scrollTop

  onDocumentMouseUp: (e) ->
    @endExtendSelectionInteraction()

  endExtendSelectionInteraction: (e) ->
    editor = @editor
    editor._disableScrollToSelection = false
    editor._disableSyncDOMSelectionToEditor = false
    selectionRange = editor.selection

    if selectionRange.isTextMode
      editor.moveSelectionRange(@editorRangeFromDOMSelection()) # Read in selection from double-click, etc.
    else
      editor.moveSelectionRange(selectionRange)

    @_extendSelectionDisposables.dispose()
    @_extendSelectionDisposables = new CompositeDisposable
    @_extendingSelection = false

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
    #    return @editor.outline.itemForID itemID
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
          insertBefore: @editor.firstVisibleChild(pickedItem)
      else
        {} =
          parent: pickedItem.parent
          insertBefore: @editor.nextVisibleSibling(pickedItem)

  ###
  Section: Util
  ###

  itemForViewNode: (viewNode) ->
    while viewNode
      item = @editor.outline.itemForID(viewNode?.id)
      return item if item
      viewNode = viewNode.parentNode

  itemViewLIForItem: (item) ->
    if item
      # Maintain our own idsToElements mapping instead of using
      # getElementById so that we can maintain two views of the same
      # document in the same DOM. The other approach would be to require
      # use of Shadow DOM in that case, but that brings lots of bagage and
      # some performance issues with it.
      return @_idsToElements[item.id]

  itemViewPForItem: (item) ->
    @_itemViewBodyP(@itemViewLIForItem(item))

  itemViewChildrenULForItem: (item) ->
    @_itemViewChildrenUL(@itemViewLIForItem(item))

  nodeOffsetToItemOffset: (node, offset) ->
    ItemBodyEncoder.nodeOffsetToBodyTextOffset(node, offset, @_itemViewBodyP(@itemViewLIForItem(@itemForViewNode(node))))

  itemOffsetToNodeOffset: (item, offset) ->
    ItemBodyEncoder.bodyTextOffsetToNodeOffset(@_itemViewBodyP(@itemViewLIForItem(item)), offset)

  _disconnectBranchIDs: (element) ->
    end = Util.nodeNextBranch(element)
    idsToElements = @_idsToElements
    each = element
    while each != end
      if each.id
        delete idsToElements[each.id]
        each.removeAttribute('id')
      each = Util.nextNode(each)

  _nodeCaretPositionFromPoint: (clientX, clientY) ->
    pick = @editor.DOMCaretPositionFromPoint(clientX, clientY)
    range = pick?.range
    clientRects = range?.getClientRects()
    length = clientRects?.length

    if length > 1
      upstreamRect = clientRects[0]
      downstreamRect = clientRects[1]
      upstreamDist = Math.abs(upstreamRect.left - clientX)
      downstreamDist = Math.abs(downstreamRect.left - clientX)
      if downstreamDist < upstreamDist
        pick.selectionAffinity = Constants.SelectionAffinityDownstream
      else
        pick.selectionAffinity = Constants.SelectionAffinityUpstream
    else
      pick?.selectionAffinity = Constants.SelectionAffinityUpstream

    pick

  _itemViewBodyP: (itemViewLI) ->
    @_itemViewRowDIV(itemViewLI)?.firstChild.nextElementSibling

  _itemViewRowDIV: (itemViewLI) ->
    itemViewLI?.firstChild

  _itemViewChildrenUL: (itemViewLI, createIfNeeded) ->
    if itemViewLI
      lastElement = itemViewLI.lastElementChild
      if lastElement.classList.contains('bchildren')
        return lastElement

      if createIfNeeded
        ul = document.createElement('UL')
        ul.className = 'bchildren'
        itemViewLI.appendChild(ul)
        return ul

    return null

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

EventRegistery.listen 'input[is="outline-editor-focus"]', stopEventPropagation(
  'cut': (e) -> @parentElement.editor.cutSelection(e.clipboardData)
  'copy': (e) -> @parentElement.editor.copySelection(e.clipboardData)
  'paste': (e) -> @parentElement.editor.pasteToSelection(e.clipboardData)
)

EventRegistery.listen 'birch-outline-editor',
  'contextmenu': (e) -> @onContextMenu(e)

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
  'birch-outline-editor:toggle-done': -> @editor.toggleDone()
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
  'birch-outline-editor:hoist': -> @editor.hoist()
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

)

module.exports = document.registerElement 'birch-outline-editor', prototype: OutlineEditorElement.prototype