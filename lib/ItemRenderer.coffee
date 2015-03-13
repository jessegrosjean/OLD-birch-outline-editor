ChildrenULAnimation = require './animations/ChildrenULAnimation'
LIInsertAnimation = require './animations/LIInsertAnimation'
LIRemoveAnimation = require './animations/LIRemoveAnimation'
LIMoveAnimation = require './animations/LIMoveAnimation'
ItemBodyEncoder = require './ItemBodyEncoder'
Constants = require './Constants'
Mutation = require './Mutation'
Util = require './Util'

module.exports =
class ItemRenderer

  editor: null
  editorElement: null
  idsToLIs: null
  renderers: null
  animations: null

  constructor: (@editor, @editorElement) ->
    @idsToLIs = {}
    @animations = {}
    @renderers = []
    @renderers.push
      renderBadges: (item, renderer)->
        if item.attribute('data-done')
          span = document.createElement 'A'
          span.className = 'btag'
          span.textContent = 'done'
          renderer span

  destroyed: ->
    @editor = null
    @editorElement = null
    @idsToLIs = null

  ###
  Section: Rendering
  ###

  renderItemLI: (item) ->
    li = document.createElement 'LI'

    for name in item.attributeNames
      if value = item.attribute name
        li.setAttribute name, value

    li.id = item.id
    li.className = @renderItemLIClasses item
    li.appendChild @renderBranchControlsDIV item
    li.appendChild @renderBranchDIV item
    @idsToLIs[item.id] = li
    li

  renderItemLIClasses: (item) ->
    classes = ['bitem']

    unless item.hasBodyText
      classes.push 'bempy'

    if item.hasChildren
      classes.push 'bhasChildren'

    if @editor.isExpanded item
      classes.push 'bexpanded'

    if @editor.isSelected item
      if @editor.selection.isTextMode
        classes.push 'btextselected'
      else
        classes.push 'bitemselected'

    if @editor.hoistedItem() is item
      classes.push 'bhoistedItem'

    if @editor.dropParentItem() is item
      classes.push 'bdropParentItem'

    if @editor.dropInsertBeforeItem() is item
      classes.push 'bdropbefore'

    if @editor.dropInsertAfterItem() is item
      classes.push 'bdropafter'

    classes.join ' '

  renderBranchControlsDIV: (item) ->
    bframe = document.createElement 'DIV'
    bframe.className = 'bbranchcontrols'
    bframe.appendChild @renderBranchHandleA item
    bframe.appendChild @renderBranchBorderDIV item
    bframe

  renderBranchHandleA: (item) ->
    bhandle = document.createElement 'A'
    bhandle.className = 'bhandle'
    bhandle.draggable = true
    #bhandle.tabIndex = -1
    bhandle

  renderBranchBorderDIV: (item) ->
    bborder = document.createElement 'DIV'
    bborder.className = 'bborder'
    bborder

  renderBranchDIV: (item) ->
    bbranch = document.createElement 'DIV'
    bbranch.className = 'bbranch'
    bbranch.appendChild @renderItemContentDIV item
    if bchildrenUL = @renderChildrenUL item
      bbranch.appendChild bchildrenUL
    bbranch

  renderItemContentDIV: (item) ->
    bitemcontent = document.createElement 'DIV'
    bitemcontent.className = 'bitemcontent'
    bitemcontent.appendChild @renderBodyTextP item
    if bbadges = @renderBadgesDIV item
      bitemcontent.appendChild bbadges
    bitemcontent

  renderBodyTextP: (item) ->
    bbodytext = document.createElement 'P'
    bbodytext.className = 'bbodytext'
    bbodytext.contentEditable = true
    bbodytext.innerHTML = @renderBodyTextInnerHTML item
    bbodytext

  renderBodyTextInnerHTML: (item) ->
    if @renderers
      highlighted = null

      for each in @renderers
        if each.highlightBodyText
          each.highlightBodyText item, (tagName, attributes, location, length) ->
            unless highlighted
              highlighted = item.attributedBodyText.copy()
            highlighted.addAttributeInRange tagName, attributes, location, length

      if highlighted
        ItemBodyEncoder.attributedStringToDocumentFragment highlighted, document
      else
        item.bodyHTML
    else
      item.bodyHTML

  renderBadgesDIV: (item) ->
    if @renderers
      bbadges = null
      for each in @renderers
        if each.renderBadges
          each.renderBadges item, (badge) ->
            unless bbadges
              bbadges = document.createElement 'DIV'
              bbadges.className = 'bbadges'
            bbadges.appendChild badge
      bbadges

  renderChildrenUL: (item) ->
    if @editor.isExpanded(item) or @editor.hoistedItem() is item
      each = item.firstChild
      if each
        bchildren = document.createElement 'UL'
        bchildren.className = 'bchildren'
        while each
          if @editor.isVisible each
            bchildren.appendChild @renderItemLI each
          each = each.nextSibling
        bchildren

  ###
  Section: Item Lookup
  ###

  itemForRenderedNode: (renderedNode) ->
    outline = @editor.outline
    while renderedNode
      if id = renderedNode.id
        if item = outline.itemForID id
          return item
      renderedNode = renderedNode.parentNode

  ###
  Section: Rendered Node Lookup
  ###

  renderedLIForItem: (item) ->
    # Maintain our own idsToElements mapping instead of using getElementById
    # so that we can maintain two views of the same document in the same DOM.
    # The other approach would be to require use of Shadow DOM in that case,
    # but that brings lots of bagage and some performance issues with it.
    @idsToLIs[item?.id]

  renderedBranchDIVForRenderedLI: (LI) ->
    LI?.firstChild.nextSibling

  renderedItemContentDIVForRenderedLI: (LI) ->
    @renderedBranchDIVForRenderedLI(LI)?.firstChild

  renderedBodyTextPForRenderedLI: (LI) ->
    @renderedItemContentDIVForRenderedLI(LI)?.firstChild

  renderedBodyBadgesDIVForRenderedLI: (LI) ->
    @renderedItemContentDIVForRenderedLI(LI)?.lastChild

  renderedChildrenULForRenderedLI: (LI, createIfNeeded) ->
    bbranch = @renderedBranchDIVForRenderedLI LI
    if bbranch
      last = bbranch.lastChild
      if last.classList.contains 'bchildren'
        last
      else if createIfNeeded
        ul = document.createElement('UL')
        ul.className = 'bchildren'
        bbranch.appendChild ul
        ul

  ###
  Section: Updates
  ###

  updateHoistedItem: (oldHoistedItem, newHoistedItem) ->
    #if @editorElement.isAnimationEnabled && oldHoistedItem && newHoistedItem
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
    @editorElement.topListElement.innerHTML = ''
    @idsToLIs = {}
    if newHoistedItem
      @editorElement.topListElement.appendChild @renderItemLI(newHoistedItem)

  updateItemClass: (item) ->
    @renderedLIForItem(item)?.className = @renderItemLIClasses item

  updateItemAttribute: (item, attributeName) ->
    renderedLI = @renderedLIForItem item
    if renderedLI
      if item.hasAttribute attributeName
        renderedLI.setAttribute attributeName, item.attribute(attributeName)
      else
        renderedLI.removeAttribute attributeName

  updateItemBodyContent: (item) ->
    renderedLI = @renderedLIForItem item
    renderedP = @renderedBodyTextPForRenderedLI renderedLI
    if renderedP
      html = @renderBodyTextInnerHTML item
      if renderedP.innerHTML != html
        renderedP.innerHTML = html

  updateItemChildren: (item, removedChildren, addedChildren, nextSibling) ->
    renderedLI = @renderedLIForItem item
    if renderedLI
      renderedChildrenUL = @renderedChildrenULForRenderedLI renderedLI
      animate = @editorElement.isAnimationEnabled()
      editor = @editor

      @updateItemClass item

      for eachChild in removedChildren
        eachChildRenderedLI = @renderedLIForItem eachChild
        if eachChildRenderedLI
          @disconnectBranchIDs eachChildRenderedLI
          if animate
            @animateRemoveRenderedItemLI eachChild, eachChildRenderedLI
          else
            renderedChildrenUL.removeChild eachChildRenderedLI

      if addedChildren.length
        nextSiblingRenderedLI = @renderedLIForItem nextSibling
        documentFragment = document.createDocumentFragment()
        addedChildrenLIs = []

        for eachChild in addedChildren
          if editor.isVisible eachChild
            eachChildRenderedLI = @renderItemLI eachChild
            addedChildrenLIs.push eachChildRenderedLI
            documentFragment.appendChild eachChildRenderedLI

        if !renderedChildrenUL
          renderedChildrenUL = @renderedChildrenULForRenderedLI(renderedLI, true)

        renderedChildrenUL.insertBefore documentFragment, nextSiblingRenderedLI

        if animate
          outline = editor.outline
          for eachChildRenderedLI in addedChildrenLIs
            eachChildItem = outline.itemForID eachChildRenderedLI.id
            @animateInsertRenderedItemLI eachChildItem, eachChildRenderedLI

  updateRefreshItemChildren: (item) ->
    renderedLI = @renderedLIForItem item
    if renderedLI
      renderedChildrenUL = @renderedChildrenULForRenderedLI renderedLI

      if renderedChildrenUL
        renderedChildrenUL.parentNode.removeChild renderedChildrenUL
        @disconnectBranchIDs renderedChildrenUL

      renderedChildrenUL = @renderChildrenUL item
      if renderedChildrenUL
        renderedLI.appendChild renderedChildrenUL

  updateItemExpanded: (item) ->
    @updateItemClass item

    renderedLI = @renderedLIForItem item
    if renderedLI
      animate = @editorElement.isAnimationEnabled()
      renderedChildrenUL = @renderedChildrenULForRenderedLI renderedLI

      if renderedChildrenUL
        if animate
          @animateCollapseRenderedChildrenUL item, renderedChildrenUL
        else
          renderedChildrenUL.parentNode.removeChild renderedChildrenUL
        @disconnectBranchIDs renderedChildrenUL

      renderedChildrenUL = @renderChildrenUL item
      if renderedChildrenUL
        renderedBranchDIV = @renderedBranchDIVForRenderedLI renderedLI
        renderedBranchDIV.appendChild renderedChildrenUL
        if animate
          @animateExpandRenderedChildrenUL item, renderedChildrenUL

  outlineDidChange: (e) ->
    for each in e.mutations
      switch each.type
        when Mutation.AttributeChanged
          @updateItemAttribute each.target, each.attributeName
        when Mutation.BodyTextChanged
          @updateItemBodyContent each.target
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

  completedAnimation: (id) ->
    delete @animations[id]

  animationForItem: (item, clazz) ->
    animationID = item.id + clazz.id
    animation = @animations[animationID]
    if not animation
      animation = new clazz animationID, item, this
      @animations[animationID] = animation
    animation

  animateExpandRenderedChildrenUL: (item, renderedLI) ->
    @animationForItem(item, ChildrenULAnimation).expand renderedLI, @editorElement.animationContext()

  animateCollapseRenderedChildrenUL: (item, renderedLI) ->
    @animationForItem(item, ChildrenULAnimation).collapse renderedLI, @editorElement.animationContext()

  animateInsertRenderedItemLI: (item, renderedLI) ->
    @animationForItem(item, LIInsertAnimation).insert renderedLI, @editorElement.animationContext()

  animateRemoveRenderedItemLI: (item, renderedLI) ->
    @animationForItem(item, LIRemoveAnimation).remove renderedLI, @editorElement.animationContext()

  renderedItemLIPosition: (renderedLI) ->
    renderedPRect = @renderedBodyTextPForRenderedLI(renderedLI).getBoundingClientRect()
    animationRect = @editorElement.animationLayerElement.getBoundingClientRect()
    renderedLIRect = renderedLI.getBoundingClientRect()
    {} =
      top: renderedLIRect.top - animationRect.top
      bottom: renderedPRect.bottom - animationRect.bottom
      left: renderedLIRect.left - animationRect.left
      pLeft: renderedPRect.left
      width: renderedLIRect.width

  animateMoveItems: (items, newParent, newNextSibling, startOffset) ->
    if items.length == 0
      return

    editor = @editor
    outline = editor.outline
    animate = @editorElement.isAnimationEnabled()
    savedSelectionRange = editor.selection
    hoistedItem = editor.hoistedItem()
    context = @editorElement.animationContext()
    animations = @animations

    # Complete all existing animations
    for own key, animation of animations
      animation.complete() if animation.complete

    if animate
      for each in items
        renderedLI = @renderedLIForItem each
        if renderedLI
          startPosition = @renderedItemLIPosition renderedLI
          if startOffset
            startPosition.left += startOffset.xOffset
            startPosition.top += startOffset.yOffset
            startPosition.bottom += startOffset.yOffset
          @animationForItem(each, LIMoveAnimation).beginMove renderedLI, startPosition

    firstItem = items[0]
    lastItem = items[items.length - 1]
    firstItemParent = firstItem.parent
    firstItemParentParent = firstItemParent?.parent
    newParentNeedsExpand =
      newParent != hoistedItem and
      !editor.isExpanded(newParent) and
      editor.isVisible(newParent)

    # Special case indent and unindent indentations when vertical position of
    # fist item won't change. In those cases disable all animations except
    # for the slide
    disableAnimation =
      (newParent is editor.previousVisibleSibling(firstItem) and
       !newNextSibling and
        (!newParentNeedsExpand or
         !newParent.firstChild)) or
      (newParent is firstItemParentParent and
       firstItemParent is lastItem.parent and
       editor.lastVisibleChild(lastItem.parent) is lastItem)

    if disableAnimation
      @editorElement.disableAnimation()

    outline.beginUpdates()
    outline.removeItemsFromParents items
    newParent.insertChildrenBefore items, newNextSibling
    outline.endUpdates()

    if newParentNeedsExpand
      editor.setExpanded newParent

    if disableAnimation
      @editorElement.enableAnimation()

    editor.moveSelectionRange savedSelectionRange

    # Fast temporarily forward all animations to final position. Animation
    # system will automatically continue normal animations on next tick.
    for own key, animation of animations
      animation.fastForward context

    scrollToTop = Number.MAX_VALUE
    scrollToBottom = Number.MIN_VALUE

    if animate
      for each in items
        animation = animations[each.id + LIMoveAnimation.id]
        renderedLI = @renderedLIForItem each

        if animation
          position = @renderedItemLIPosition renderedLI, true
          scrollToTop = Math.min position.top, scrollToTop
          scrollToBottom = Math.max position.bottom, scrollToBottom
          animation.performMove renderedLI, position, context

    if scrollToTop != Number.MAX_VALUE
      @editorElement.scrollToOffsetRangeIfNeeded scrollToTop, scrollToBottom, true

  ###
  Section: Picking
  ###

  pick: (clientX, clientY, LI) ->
    LI ?= @editorElement.topListElement.firstChild
    UL = @renderedChildrenULForRenderedLI LI

    if UL
      itemContentDIV = @renderedItemContentDIVForRenderedLI LI
      itemContentRect = itemContentDIV.getBoundingClientRect()
      if clientY > itemContentRect.top and clientY < itemContentRect.bottom
        @pickBodyTextP clientX, clientY, @renderedBodyTextPForRenderedLI LI
      else
        children = UL.children
        high = children.length - 1
        low = 0

        while low <= high
          i = Math.floor((low + high) / 2)
          childLI = children.item i
          childLIRect = childLI.getBoundingClientRect()
          if clientY < childLIRect.top
            high = i - 1
          else if clientY > childLIRect.bottom
            low = i + 1
          else
            return @pick clientX, clientY, childLI

        @pick clientX, clientY, childLI
    else
      @pickBodyTextP clientX, clientY, @renderedBodyTextPForRenderedLI LI

  pickBodyTextP: (clientX, clientY, renderedBodyTextP) ->
    item = @itemForRenderedNode renderedBodyTextP
    bodyTextRect = renderedBodyTextP.getBoundingClientRect()
    bodyTextRectMid = bodyTextRect.top + (bodyTextRect.height / 2.0)
    itemAffinity

    if clientY < bodyTextRect.top
      itemAffinity = Constants.ItemAffinityAbove
      clientX = Number.MIN_VALUE
    else if clientY < bodyTextRectMid
      itemAffinity = Constants.ItemAffinityTopHalf
    else if clientY > bodyTextRect.bottom
      itemAffinity = Constants.ItemAffinityBelow
      clientX = Number.MAX_VALUE
    else
      itemAffinity = Constants.ItemAffinityBottomHalf

    # Constrain pick point inside the text rect so that we'll get a good
    # 3 pick result.

    style = window.getComputedStyle(renderedBodyTextP)
    paddingTop = parseInt(style.paddingTop, 10)
    paddingBottom = parseInt(style.paddingBottom, 10)
    lineHeight = parseInt(style.lineHeight, 10)
    halfLineHeight = lineHeight / 2.0
    bodyTop = Math.ceil(bodyTextRect.top)
    bodyBottom = Math.ceil(bodyTextRect.bottom)
    pickableBodyTop = bodyTop + halfLineHeight + paddingTop
    pickableBodyBottom = bodyBottom - (halfLineHeight + paddingBottom)

    if clientY <= pickableBodyTop
      clientY = pickableBodyTop
    else if clientY >= pickableBodyBottom
      clientY = pickableBodyBottom

    # Magic nubmer is "1" for x values, any more and we miss l's at the
    # end of the line.

    if clientX <= bodyTextRect.left
      clientX = Math.ceil(bodyTextRect.left) + 1
    else if clientX >= bodyTextRect.right
      clientX = Math.floor(bodyTextRect.right) - 1

    nodeCaretPosition = @caretPositionFromPoint(clientX, clientY)
    itemCaretPosition =
      offsetItem: item
      offset: if nodeCaretPosition then @nodeOffsetToItemOffset(nodeCaretPosition.offsetItem, nodeCaretPosition.offset) else 0
      selectionAffinity: if nodeCaretPosition then nodeCaretPosition.selectionAffinity else Constants.SelectionAffinityUpstream
      itemAffinity: itemAffinity

    return {} =
      nodeCaretPosition: nodeCaretPosition
      itemCaretPosition: itemCaretPosition

  caretPositionFromPoint: (clientX, clientY) ->
    pick = @editor.DOMCaretPositionFromPoint clientX, clientY
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

  ###
  Section: Offset Mapping
  ###

  nodeOffsetToItemOffset: (node, offset) ->
    item = @itemForRenderedNode node
    renderedLI = @renderedLIForItem item
    renderedBodyTextP = @renderedBodyTextPForRenderedLI renderedLI
    ItemBodyEncoder.nodeOffsetToBodyTextOffset node, offset, renderedBodyTextP

  itemOffsetToNodeOffset: (item, offset) ->
    renderedLI = @renderedLIForItem item
    renderedBodyTextP = @renderedBodyTextPForRenderedLI renderedLI
    ItemBodyEncoder.bodyTextOffsetToNodeOffset renderedBodyTextP, offset

  ###
  Section: Util
  ###

  disconnectBranchIDs: (element) ->
    end = Util.nodeNextBranch(element)
    idsToLIs = @idsToLIs
    each = element
    while each != end
      if each.id
        delete idsToLIs[each.id]
        each.removeAttribute('id')
      each = Util.nextNode(each)