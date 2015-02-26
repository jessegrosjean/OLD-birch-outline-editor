# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

OutlineEditorSelection = require './OutlineEditorSelection'
OutlineEditorElement = require './OutlineEditorElement'
Mutation = require './Mutation'
AttributedString = require './AttributedString'
{Emitter, CompositeDisposable} = require 'atom'
ItemBodyEncoder = require './ItemBodyEncoder'
ItemSerializer = require './ItemSerializer'
shallowEquals = require 'shallow-equals'
UndoManager = require './UndoManager'
Velocity = require 'velocity-animate'
shallowCopy = require 'shallow-copy'
typechecker = require 'typechecker'
Constants = require './Constants'
Outline = require './Outline'
shortid = require './shortid'
{Model} = require 'theorist'
assert = require 'assert'
Item = require './Item'
Util = require './Util'
path = require 'path'

# Public: Editor for {Outline}s.
#
# Maintains all editing state for the outline incuding: hoisted items,
# filtering items, expanded items, and item selection.
#
# A single {Outline} can belong to multiple editors. For example, if the same
# outline is open in two different panes, Atom creates a separate editor for
# each pane. If the outline is manipulated the changes are reflected in both
# editors, but each maintains its own selection, expanded items, etc.
#
# The easiest way to get hold of `OutlineEditor` objects is by registering a
# callback with `::observeOutlineEditors` through the {OutlineEditorService}.
module.exports =
class OutlineEditor extends Model
  atom.deserializers.add(this)

  @deserialize: (data) ->
    new OutlineEditor(Outline.deserialize(data.outline), data)

  constructor: (outline, params) ->
    id = shortid()

    @emitter = new Emitter()
    @outline = null
    @_overrideIsFocused = false
    @_selection = new OutlineEditorSelection(this)
    @_textModeExtendingFromSnapbackRange = null
    @_textModeTypingFormattingTags = {}
    @_selectionVerticalAnchor = undefined
    @_disableScrollToSelection = false
    @_disableSyncDOMSelectionToEditor = false
    @_itemFilterPathItems = []
    @_itemFilterPath = null

    @_hoistStack = []
    @_dragState =
      draggedItem: null
      dropEffect: null
      dropParentItem: null
      dropInsertBeforeItem: null
      dropInsertAfterItem: null

    @outline = outline or new Outline
    @subscribeToOutline()

    outlineEditorElement = new OutlineEditorElement().initialize(this)
    outlineEditorElement.id = id
    outlineEditorElement.classList.add('beditor')
    @outlineEditorElement = outlineEditorElement
    if params?.hostElement
      params.hostElement.appendChild(outlineEditorElement)

    @serializedState =
      hoistedItemIDs: params?.hoistedItemIDs
      expandedItemIDs: params?.expandedItemIDs

    @loadSerializedState()

  copy: ->
    new OutlineEditor(@outline)

  serialize: ->
    {} =
      deserializer: 'OutlineEditor'
      hoistedItemIDs: (each.id for each in @_hoistStack)
      expandedItemIDs: (each.id for each in @outline.items() when @isExpanded each)
      outline: @outline.serialize()

  loadSerializedState: ->
    hoistedItemIDs = @serializedState.hoistedItemIDs
    expandedItemIDs = @serializedState.expandedItemIDs
    unless expandedItemIDs
      expandedItemIDs = @outline.serializedState.expandedItemIDs or []
    @setExpanded (@outline.itemsForIDs expandedItemIDs)
    @setHoistedItemsStack @outline.itemsForIDs hoistedItemIDs

  subscribeToOutline: ->
    outline = @outline
    undoManager = outline.undoManager

    outline.retain()

    @subscribe outline.onDidChange @outlineDidChange.bind(this)

    @subscribe outline.onDidChangePath =>
      unless atom.project.getPaths()[0]?
        atom.project.setPaths([path.dirname(@getPath())])
      @emitter.emit 'did-change-title', @getTitle()

    @subscribe outline.onWillReload =>
      @outlineEditorElement.disableAnimation()

    @subscribe outline.onDidReload =>
      @loadSerializedState()
      @outlineEditorElement.enableAnimation()

    @subscribe outline.onDidDestroy => @destroy()

    @subscribe undoManager.onDidOpenUndoGroup () =>
      if not undoManager.isUndoing and not undoManager.isRedoing
        undoManager.setUndoGroupMetadata('undoSelection', @selection)

    @subscribe undoManager.onWillUndo (undoGroupMetadata) =>
      @_overrideIsFocused = @isFocused()
      undoManager.setUndoGroupMetadata('redoSelection', @selection)

    @subscribe undoManager.onDidUndo (undoGroupMetadata) =>
      selectionRange = undoGroupMetadata.undoSelection
      if selectionRange
        @moveSelectionRange(selectionRange)
      @_overrideIsFocused = false

    @subscribe undoManager.onWillRedo (undoGroupMetadata) =>
      @_overrideIsFocused = @isFocused()

    @subscribe undoManager.onDidRedo (undoGroupMetadata) =>
      selectionRange = undoGroupMetadata.redoSelection
      if selectionRange
        @moveSelectionRange(selectionRange)
      @_overrideIsFocused = false

  outlineDidChange: (e) ->
    if @itemFilterPath()
      hoistedItem = @hoistedItem()
      for eachMutation in e.mutations
        if eachMutation.type == Mutation.ChildrenChanged
          for eachItem in eachMutation.addedItems
            if hoistedItem.contains(eachItem)
              @_addItemFilterPathMatch(eachItem)

    selectionRange = @selection
    @_overrideIsFocused = @isFocused()
    @outlineEditorElement.outlineDidChange(e)
    @moveSelectionRange(selectionRange)
    @_overrideIsFocused = false

    for eachMutation in e.mutations
      if eachMutation.type == Mutation.ChildrenChanged
        targetItem = eachMutation.target
        if not targetItem.hasChildren
          @setCollapsed targetItem

  destroyed: ->
    @unsubscribe()
    @outline.release(@outlineEditorElement.id)
    @outlineEditorElement.destroyed()
    @outlineEditorElement = null
    @emitter.emit 'did-destroy'

  ###
  Section: Model
  ###

  # Public: The {Outline} that is being edited.
  outline: null

  ###
  Section: Event Subscription
  ###

  # Essential: Calls your `callback` when the editor's outline title has
  # changed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  # Essential: Calls your `callback` when the editor's outline path, and
  # therefore title, has changed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePath: (callback) ->
    @outline.onDidChangePath(callback)

  # Public: Invoke the given callback when the editor's outline changes.
  #
  # See {Outline} Examples for an example of subscribing to these events.
  #
  # - `callback` {Function} to be called when the outline changes.
  #   - `event` {Object} with following keys:
  #     - `mutations` {Array} of {Mutation}s.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    @outline.onDidChange(callback)

  # Extended: Calls your `callback` when the result of {::isModified} changes.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeModified: (callback) ->
    @outline.onDidChangeModified(callback)

  # Extended: Calls your `callback` when the editor's outline's underlying
  # file changes on disk at a moment when the result of {::isModified} is
  # true.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidConflict: (callback) ->
    @outline.onDidConflict(callback)

  # Public: Invoke the given callback after the editor's outline is saved to
  # disk.
  #
  # * `callback` {Function} to be called after the buffer is saved.
  #   * `event` {Object} with the following keys:
  #     * `path` The path to which the buffer was saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidSave: (callback) ->
    @outline.onDidSave(callback)

  # Public: Invoke the given callback when the editor is destroyed.
  #
  # * `callback` {Function} to be called when the editor is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Hoisting Items
  ###

  # Public: Returns the current hoisted {Item}.
  hoistedItem: ->
    @_hoistStack[@_hoistStack.length - 1]

  # Public: Push a new hoisted {Item}.
  #
  # - `item` {Item} to hoist.
  hoist: (item) ->
    item ?= @selection.focusItem
    if item and item != @hoistedItem()
      stack = @_hoistStack.slice()
      stack.push(item)
      @setHoistedItemsStack(stack)
      @moveSelectionRange(@firstVisibleChild(item))

  # Public: Pop the current hoisted {Item}.
  unhoist: ->
    stack = @_hoistStack.slice()
    lastHoisted = stack.pop()
    @setHoistedItemsStack(stack)
    @moveSelectionRange(lastHoisted)

  setHoistedItemsStack: (newHoistedItems) ->
    oldHoistedItem = @hoistedItem()
    outline = @outline
    next

    for each in newHoistedItems by -1
      unless each.isInOutline and each.outline == outline
        newHoistedItems.pop()
      else
        if next
          if not each.contains(next)
            newHoistedItems.splice(i, 1)
          else
            next = each
        else
          next = each

    if newHoistedItems.length == 0
      newHoistedItems = [outline.root]
    else if  newHoistedItems[0] != outline.root
      newHoistedItems = [outline.root]

    @_hoistStack = newHoistedItems

    newHoistedItem = @hoistedItem()
    if oldHoistedItem != newHoistedItem
      @outlineEditorElement.updateHoistedItem(oldHoistedItem, newHoistedItem)

    @_revalidateSelectionRange()

  ###
  Section: Expanding Items
  ###

  # Public: Returns true if the item is expanded.
  #
  # - `item` {Item} to test.
  isExpanded: (item) ->
    return item and @editorState(item).expanded

  # Public: Returns true if the item is collapsed.
  #
  # - `item` {Item} to test.
  isCollapsed: (item) ->
    return item and not @editorState(item).expanded

  # Public: Expand the given items in this editor.
  #
  # - `items` {Item} or {Array} of items.
  setExpanded: (items, expanded) ->
    @_setExpandedState items, true

  # Public: Collapse the given items in this editor.
  #
  # - `items` {Item} or {Array} of items.
  setCollapsed: (items) ->
    @_setExpandedState items, false

  _setExpandedState: (items, expanded) ->
    items ?= @selection.rangeItemsCover

    if not typechecker.isArray(items)
      items = [items]

    if expanded
      # for better animations
      for each in items
        if not @isVisible(each)
          @editorState(each).expanded = expanded

      for each in items
        if @isExpanded(each) != expanded
          @editorState(each).expanded = expanded
          @outlineEditorElement.updateItemExpanded(each)
    else
      # for better animations
      for each in Item.commonAncestors(items)
        if @isExpanded(each) != expanded
          @editorState(each).expanded = expanded
          @outlineEditorElement.updateItemExpanded(each)

      for each in items
        @editorState(each).expanded = expanded

    @_disableScrollToSelection = true
    @_revalidateSelectionRange()
    @_disableScrollToSelection = false

  foldItems: (items, fully) ->
    @_foldItems items, false, fully

  unfoldItems: (items, fully) ->
    @_foldItems items, true, fully

  toggleFoldItems: (items, fully) ->
    @_foldItems items, undefined, fully

  _foldItems: (items, expand, fully) ->
    items ?= @selection.rangeItemsCover
    unless typechecker.isArray(items)
      items = [items]

    unless items.length
      return

    unless expand
      first = items[0]
      unless first.hasChildren
        parent = first.parent
        if @isVisible(parent)
          @moveSelectionRange(parent)
          @_foldItems(parent, expand, fully)
          return

    foldItems = []

    if expand == undefined
      expand = not @isExpanded((each for each in items when each.hasChildren)[0])

    if fully
      for each in Item.commonAncestors(items) when each.hasChildren and @isExpanded(each) != expand
        foldItems.push each
        foldItems.push each for each in each.descendants when each.hasChildren and @isExpanded(each) != expand
    else
      foldItems = (each for each in items when each.hasChildren and @isExpanded(each) != expand)

    if foldItems.length
      @_setExpandedState foldItems, expand

  toggleFullyExpandItems: (items) ->
    @toggleFoldItems items, true

  ###
  Section: Item Filter Path
  ###

  itemFilterPath: ->
    @_itemFilterPath

  setItemFilterPath: (itemFilterPath) ->
    @_itemFilterPath = itemFilterPath

    for each in @_itemFilterPathItems
      eachState = @editorState(each)
      eachState.expanded = false
      eachState.matched = false
      eachState.matchedAncestor = false

    if itemFilterPath
      @_itemFilterPathItems = []
      for each in @outline.itemsForXPath(itemFilterPath)
        @_addItemFilterPathMatch(each)
    else
      @_itemFilterPathItems = null

    @outlineEditorElement.updateHoistedItem(null, @hoistedItem())
    @_revalidateSelectionRange()

  _addItemFilterPathMatch: (item) ->
    itemFilterPathItems = @_itemFilterPathItems
    itemState = @editorState(item)
    itemState.matched = true
    itemFilterPathItems.push(item)

    each = item.parent
    while each
      eachState = @editorState(each)
      if eachState.matchedAncestor
        return
      else
        eachState.expanded = true
        eachState.matchedAncestor = true
        itemFilterPathItems.push(each)
      each = each.parent

  ###
  Section: Item Visibility
  ###

  # Public: Returns first visible {Item} in editor.
  firstVisibleItem: ->
    @nextVisibleItem(@hoistedItem())

  # Public: Returns last visible {Item} in editor.
  lastVisibleItem: ->
    last = @hoistedItem().lastDescendantOrSelf
    if @isVisible(last)
      last
    else
      @previousVisibleItem(last)

  # Public: Determine if an {Item} is visible. An item is visible if it
  # descends from the current hoisted item, and it isn't filtered, and all
  # ancestors up to hoisted node are expanded.
  #
  # - `item` {Item} to test.
  #
  # Returns {Boolean} indicating if item is visible.
  isVisible: (item) ->
    parent = item?.parent
    hoistedItem = @hoistedItem()

    while parent != hoistedItem
      return false unless @isExpanded(parent)
      parent = parent.parent

    return true unless @_itemFilterPath
    itemState = @editorState(item)
    itemState.matched or itemState.matchedAncestor

  # Public: Make the given item visible in the outline, expanding ancestors,
  # removing filter, and unhoisting as needed.
  #
  # - `item` {Item} to make visible.
  makeVisible: (item) ->
    assert.ok(
      item.isInOutline and (item.outline is @outline),
      'Item must be in this outline'
    )

    return if @isVisible item

    hoistedItem = @hoistedItem()
    while not hoistedItem.contains item
      @unhoist()
      hoistedItem = @hoistedItem()

    parentsToExpand = []
    eachParent = item.parent
    while eachParent != hoistedItem
      if @isCollapsed eachParent
        parentsToExpand.push eachParent
      eachParent = eachParent.parent

    @setExpanded parentsToExpand

  visibleParent: (item) ->
    if @isVisible(item?.parent)
      item.parent

  # Public: Returns previous visible sibling {Item} relative to given item.
  #
  # - `item` {Item}
  previousVisibleSibling: (item) ->
    item = item?.previousSibling
    while item
      if @isVisible(item)
        return item
      item = item.previousSibling

  # Public: Returns next visible sibling {Item} relative to given item.
  #
  # - `item` {Item}
  nextVisibleSibling: (item) ->
    item = item?.nextSibling
    while item
      if @isVisible(item)
        return item
      item = item.nextSibling

  # Public: Returns next visible {Item} relative to given item.
  #
  # - `item` {Item}
  nextVisibleItem: (item) ->
    item = item?.nextItem
    while item
      if @isVisible(item)
        return item
      item = item.nextItem

  # Public: Returns previous visible {Item} relative to given item.
  #
  # - `item` {Item}
  previousVisibleItem: (item) ->
    item = item?.previousItem
    while item
      if @isVisible(item)
        return item
      item = item.previousItem

  # Public: Returns first visible child {Item} relative to given item.
  #
  # - `item` {Item}
  firstVisibleChild: (item) ->
    firstChild = item?.firstChild
    if @isVisible(firstChild)
      return firstChild
    @nextVisibleSibling(firstChild)

  # Public: Returns last visible child {Item} relative to given item.
  #
  # - `item` {Item}
  lastVisibleChild: (item) ->
    lastChild = item?.lastChild
    if @isVisible(lastChild)
      return lastChild
    @previousVisibleSibling(lastChild)

  lastVisibleDescendantOrSelf: (item) ->
    lastChild = item.lastVisibleChild(item)
    if lastChild
      @lastVisibleDescendantOrSelf(lastChild)
    else
      item

  # Public: Returns previous visible branch {Item} relative to given item.
  #
  # - `item` {Item}
  previousVisibleBranch: (item) ->
    previousBranch = item?.previousBranch
    if @isVisible(previousBranch)
      previousBranch
    else
      @previousVisibleBranch(previousBranch)

  # Public: Returns next visible branch {Item} relative to given item.
  #
  # - `item` {Item}
  nextVisibleBranch: (item) ->
    nextBranch = item?.nextBranch
    if @isVisible(nextBranch)
      nextBranch
    else
      @nextVisibleBranch(nextBranch)

  ###
  Section: Focus
  ###

  # Public: Returns {Boolean} indicating if this editor has focus.
  isFocused: ->
    if @_overrideIsFocused
      true
    else
      activeElement = @DOMGetActiveElement()
      outlineEditorElement = @outlineEditorElement
      activeElement and (outlineEditorElement == activeElement or outlineEditorElement.contains(activeElement))

  # Public: Focus this editor.
  focus: ->
    @outlineEditorElement.focus()

  ###
  Section: Selection
  ###

  # Public: Read-only current {OutlineEditorSelection}.
  selection: null
  Object.defineProperty @::, 'selection',
    get: -> @_selection

  # Public: Returns {Boolean} indicating if given item is selected.
  #
  # - `item` {Item}
  isSelected: (item) ->
    @editorState(item).selected

  # Public: Returns `true` if is selecting at item level.
  isItemMode: ->
    @_selection.isItemMode

  # Public: Returns `true` if is selecting at text level.
  isTextMode: ->
    @_selection.isTextMode

  selectionVerticalAnchor: ->
    if @_selectionVerticalAnchor == undefined
      focusRect = @selection.focusClientRect
      @_selectionVerticalAnchor = if focusRect then focusRect.left else 0
    @_selectionVerticalAnchor

  setSelectionVerticalAnchor: (selectionVerticalAnchor) ->
    @_selectionVerticalAnchor = selectionVerticalAnchor

  # Public: Move selection backward.
  moveBackward: ->
    @modifySelectionRange('move', 'backward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection backward and modify selection.
  moveBackwardAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection forward.
  moveForward: ->
    @modifySelectionRange('move', 'forward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection forward and modify selection.
  moveForwardAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection up.
  moveUp: ->
    @modifySelectionRange('move', 'up', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection up and modify selection.
  moveUpAndModifySelection: ->
    @modifySelectionRange('extend', 'up', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection down.
  moveDown: ->
    @modifySelectionRange('move', 'down', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection down and modify selection.
  moveDownAndModifySelection: ->
    @modifySelectionRange('extend', 'down', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection left.
  moveLeft: ->
    @modifySelectionRange('move', 'left', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection left and modify selection.
  moveLeftAndModifySelection: ->
    @modifySelectionRange('extend', 'left', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection to begining of line.
  moveToBeginningOfLine: ->
    @modifySelectionRange('move', 'backward', (if @isTextMode() then 'lineboundary' else 'paragraphboundary'))

  # Public: Move selection to begining of line and modify selection.
  moveToBeginningOfLineAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', (if @isTextMode() then 'lineboundary' else 'paragraphboundary'))

  # Public: Move selection to begining of paragraph.
  moveToBeginningOfParagraph: ->
    @modifySelectionRange('move', 'backward', 'paragraphboundary')

  # Public: Move selection to begining of paragraph and modify selection.
  moveToBeginningOfParagraphAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', 'paragraphboundary')

  # Public: Move selection to next start of paragraph.
  moveParagraphBackward: ->
    if @isTextMode()
      @modifySelectionRange('move', 'backward', 'character')
      @modifySelectionRange('move', 'backward', 'paragraphboundary')
    else
      @modifySelectionRange('move', 'backward', 'paragraph')

  # Public: Move selection to next start of paragraph and modify selection.
  moveParagraphBackwardAndModifySelection: ->
    if @isTextMode()
      @modifySelectionRange('extend', 'backward', 'character')
      @modifySelectionRange('extend', 'backward', 'paragraphboundary')
    else
      @modifySelectionRange('extend', 'backward', 'paragraph')

  # Public: Move selection word left.
  moveWordLeft: ->
    @modifySelectionRange('move', 'left', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection word left and modify selection.
  moveWordLeftAndModifySelection: ->
    @modifySelectionRange('extend', 'left', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection right.
  moveRight: ->
    @modifySelectionRange('move', 'right', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection right and modify selection.
  moveRightAndModifySelection: ->
    @modifySelectionRange('extend', 'right', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection word right.
  moveWordRight: ->
    @modifySelectionRange('move', 'right', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection word right and modify selection.
  moveWordRightAndModifySelection: ->
    @modifySelectionRange('extend', 'right', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection to end of line.
  moveToEndOfLine: ->
    @modifySelectionRange('move', 'forward', 'lineboundary')

  # Public: Move selection to end of line and modify selection.
  moveToEndOfLineAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', 'lineboundary')

  # Public: Move selection to end of paragraph.
  moveToEndOfParagraph: ->
    @modifySelectionRange('move', 'forward', 'paragraphboundary')

  # Public: Move selection to end of paragraph and modify selection.
  moveToEndOfParagraphAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', 'paragraphboundary')

  # Public: Move selection to next end of paragraph.
  moveParagraphForward: ->
    if @isTextMode()
      @modifySelectionRange('move', 'forward', 'character')
      @modifySelectionRange('move', 'forward', 'paragraphboundary')
    else
      @modifySelectionRange('move', 'forward', 'paragraph')

  # Public: Move selection to next end of paragraph and modify selection.
  moveParagraphForwardAndModifySelection: ->
    if @isTextMode()
      @modifySelectionRange('extend', 'forward', 'character')
      @modifySelectionRange('extend', 'forward', 'paragraphboundary')
    else
      @modifySelectionRange('extend', 'forward', 'paragraph')

  # Public: Move selection to begining of document.
  moveToBeginningOfDocument: ->
    @modifySelectionRange('move', 'backward', 'documentboundary')

  # Public: Move selection to begining of document and modify selection.
  moveToBeginningOfDocumentAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', 'documentboundary')

  # Public: Move selection to end of document.
  moveToEndOfDocument: ->
    @modifySelectionRange('move', 'forward', 'documentboundary')

  # Public: Move selection to end of document and modify selection.
  moveToEndOfDocumentAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', 'documentboundary')

  insertCaretAtBeginingOfLine: ->
    startItem = @selection.startItem
    if startItem
      @moveSelectionRange(startItem, 0)

  insertCaretAtEndOfLine: ->
    endItem = @selection.endItem
    if endItem
      @moveSelectionRange(endItem, endItem.bodyText.length)

  selectLine: ->
    @moveSelectionRange(
      @selection.focusItem,
      undefined,
      @selection.anchorItem,
      undefined
    )

  # Public: Select all.
  selectAll: ->
    if @isItemMode()
      @_disableScrollToSelection = true
      @moveSelectionRange(@firstVisibleItem(), undefined, @lastVisibleItem(), undefined)
      @_disableScrollToSelection = false
    else
      selectionRange = @selection
      item = selectionRange.anchorItem
      startOffset = selectionRange.startOffset
      endOffset = selectionRange.endOffset

      if item
        textLength = item.bodyText.length;
        if startOffset == 0 and endOffset == textLength
          @moveSelectionRange(item, undefined, item, undefined)
        else
          @moveSelectionRange(item, 0, item, textLength)

  # Public: Set a new selection range.
  #
  # - `focusItem` Selection focus {Item}
  # - `focusOffset` (optional) Selection focus offset index. Or `undefined`
  #    when selecting at item level.
  # - `anchorItem` (optional) Selection anchor {Item}
  # - `anchorOffset` (optional) Selection anchor offset index. Or `undefined`
  #    when selecting at item level.
  moveSelectionRange: (focusItem, focusOffset, anchorItem, anchorOffset, rangeAffinity) ->
    @_textModeExtendingFromSnapbackRange = null
    @_updateSelectionIfNeeded(@createOutlineEditorSelection(focusItem, focusOffset, anchorItem, anchorOffset, rangeAffinity))

  # Public: Extend the selection range to a new focus item/offset.
  #
  # - `focusItem` Selection focus {Item}
  # - `focusOffset` (optional) Selection focus offset index. Or `undefined`
  #    when selecting at item level.
  extendSelectionRange: (focusItem, focusOffset, rangeAffinity) ->
    checkForTextModeSnapback = false
    if @selection.isTextMode
      @_textModeExtendingFromSnapbackRange = @selection
    else
      checkForTextModeSnapback = true
    @_updateSelectionIfNeeded(@_selection.rangeByExtending(focusItem, focusOffset, rangeAffinity), checkForTextModeSnapback)

  modifySelectionRange: (alter, direction, granularity, maintainVertialAnchor) ->
    saved = @selectionVerticalAnchor()
    checkForTextModeSnapback = false

    if alter == 'extend'
      selectionRange = @selection
      if selectionRange.isTextMode
        @_textModeExtendingFromSnapbackRange = selectionRange
      else
        checkForTextModeSnapback = true
    else
      @_textModeExtendingFromSnapbackRange = null

    @_updateSelectionIfNeeded(@_selection.selectionByModifying(alter, direction, granularity), checkForTextModeSnapback)

    if maintainVertialAnchor
      @setSelectionVerticalAnchor(saved)

  createOutlineEditorSelection: (focusItem, focusOffset, anchorItem, anchorOffset, rangeAffinity) ->
    new OutlineEditorSelection(this, focusItem, focusOffset, anchorItem, anchorOffset, rangeAffinity)

  _revalidateSelectionRange: ->
    @_updateSelectionIfNeeded(@_selection.rangeByRevalidating())

  _updateSelectionIfNeeded: (newSelection, checkForTextModeSnapback) ->
    currentSelection = @selection
    outlineEditorElement = @outlineEditorElement
    isFocused = @isFocused()

    if checkForTextModeSnapback
      if not newSelection.isTextMode and newSelection.focusItem == newSelection.anchorItem and @_textModeExtendingFromSnapbackRange
        newSelection = @_textModeExtendingFromSnapbackRange
        @_textModeExtendingFromSnapbackRange = null

    if not currentSelection.equals(newSelection)
      wasSelectedMarker = 'marker'
      newRangeItems = newSelection.rangeItems
      currentRangeItems = currentSelection.rangeItems
      @_selection = newSelection

      for each in currentRangeItems
        @editorState(each).selected = wasSelectedMarker

      for each in newRangeItems
        state = @editorState(each)
        if state.selected == wasSelectedMarker
          state.selected = true
        else
          state.selected = true
          outlineEditorElement.updateItemClass(each)

      for each in currentRangeItems
        state = @editorState(each)
        if state.selected == wasSelectedMarker
          state.selected = false
          outlineEditorElement.updateItemClass(each)

      if currentSelection.isTextMode != newSelection.isTextMode
        # Bit of overrendering... but need to handle item class case
        # .selectedItemWithTextSelection. So if selection has changed
        # from/to text mode then rerender all the endpoints.
        if currentSelection.isValid
          outlineEditorElement.updateItemClass(currentSelection.focusItem)
          outlineEditorElement.updateItemClass(currentSelection.anchorItem)

        if newSelection.isValid
          outlineEditorElement.updateItemClass(newSelection.focusItem)
          outlineEditorElement.updateItemClass(newSelection.anchorItem)

      currentSelection = newSelection

      if newSelection.focusItem and not @_disableScrollToSelection
        @scrollToItemIfNeeded(newSelection.focusItem, true)

      @setSelectionVerticalAnchor(undefined)

    if currentSelection.isTextMode
      focusItem = currentSelection.focusItem
      formattingOffset = currentSelection.anchorOffset

      if not currentSelection.isCollapsed
        formattingOffset = currentSelection.startOffset + 1

      if formattingOffset > 0
        @setTypingFormattingTags(focusItem.elementsAtBodyTextIndex(formattingOffset - 1))
      else
        @setTypingFormattingTags(focusItem.elementsAtBodyTextIndex(formattingOffset))
    else
      @setTypingFormattingTags({})

    if isFocused and not @_disableSyncDOMSelectionToEditor
      renderedSelection = outlineEditorElement.editorRangeFromDOMSelection()
      selection = @DOMGetSelection()

      if currentSelection.isValid
        if not currentSelection.equals(renderedSelection)
          if currentSelection.isTextMode
            nodeFocusOffset = outlineEditorElement.itemOffsetToNodeOffset(currentSelection.focusItem, currentSelection.focusOffset)
            nodeAnchorOffset = outlineEditorElement.itemOffsetToNodeOffset(currentSelection.anchorItem, currentSelection.anchorOffset)
            viewP = outlineEditorElement.itemViewPForItem(currentSelection.focusItem)
            range = document.createRange()

            selection.removeAllRanges()
            range.setStart(nodeAnchorOffset.node, nodeAnchorOffset.offset)
            selection.addRange(range)

            viewP.focus()

            if currentSelection.isCollapsed
              rect = currentSelection.clientRectForItemOffset(currentSelection.focusItem, currentSelection.focusOffset)
              if rect.positionedAtEndOfWrappingLine
                selection.modify('move', 'backward', 'character')
                selection.modify('move', 'forward', 'lineboundary')
            else
              selection.extend(nodeFocusOffset.node, nodeFocusOffset.offset)
          else
            @focus()
      else
        @focus()

    classList = outlineEditorElement.classList
    if currentSelection.isTextMode
      if classList.contains('itemMode')
        classList.remove('itemMode')
      if not classList.contains('textMode')
        classList.add('textMode')
    else if (currentSelection.isItemMode)
      if classList.contains('textMode')
        classList.remove('textMode')
      if not classList.contains('itemMode')
        classList.add('itemMode')

  ###
  Section: Insert Items
  ###

  # Public: Insert text at current selection. If is in text selection mode the
  # current text selection will get replaced with this text. If in item
  # selection mode a new item will get inserted.
  #
  # - `text` Text {String} or {AttributedString} to insert
  insertText: (insertedText) ->
    selectionRange = @selection
    undoManager = @outline.undoManager

    if selectionRange.isTextMode
      if not (insertedText instanceof AttributedString)
        insertedText = new AttributedString(insertedText)
        insertedText.addAttributesInRange(@typingFormattingTags(), 0, -1)

      focusItem = selectionRange.focusItem
      startOffset = selectionRange.startOffset
      endOffset = selectionRange.endOffset

      focusItem.replaceBodyTextInRange(insertedText, startOffset, endOffset - startOffset)
      @moveSelectionRange(focusItem, startOffset + insertedText.length)
    else
      @moveSelectionRange(@insertItem(insertedText))

  insertNewline: ->
    selectionRange = @selection
    if selectionRange.isTextMode
      if not selectionRange.isCollapsed
        @delete()
        selectionRange = @selection

      focusItem = selectionRange.focusItem
      focusOffset = selectionRange.focusOffset

      if focusOffset == 0
        @insertItem('', true)
        @moveSelectionRange(focusItem, 0)
      else
        splitText = focusItem.attributedBodyTextSubstring(focusOffset, -1)
        undoManager = @outline.undoManager
        undoManager.beginUndoGrouping()
        focusItem.replaceBodyTextInRange('', focusOffset, -1)
        @insertItem(splitText)
        undoManager.endUndoGrouping()
    else
      @insertItem()

  # Public: Insert item at current selection.
  #
  # - `text` Text {String} or {AttributedString} for new item.
  #
  # Returns the new {Item}.
  insertItem: (text, above=false) ->
    text ?= ''
    selectedItems = @selection.rangeItems
    insertBefore
    parent

    if above
      selectedItem = selectedItems[0]
      if not selectedItem
        parent = @hoistedItem()
        insertBefore = parent.firstChild
      else
        parent = selectedItem.parent
        insertBefore = selectedItem
    else
      selectedItem = selectedItems[selectedItems.length - 1]
      if not selectedItem
        parent = @hoistedItem()
        insertBefore = parent.firstChild
      else if @isExpanded(selectedItem)
        parent = selectedItem
        insertBefore = selectedItem.firstChild
      else
        parent = selectedItem.parent
        insertBefore = selectedItem.nextSibling

    outline = parent.outline
    outlineEditorElement = @outlineEditorElement
    insertItem = outline.createItem(text)
    undoManager = outline.undoManager

    undoManager.beginUndoGrouping()
    parent.insertChildBefore(insertItem, insertBefore)
    undoManager.endUndoGrouping()

    undoManager.setActionName('Insert Item')
    @moveSelectionRange(insertItem, 0)

    insertItem

  insertItemAbove: (text) ->
    @insertItem(text, true)

  insertItemBelow: (text) ->
    @insertItem(text)

  indent: ->
    @moveItemsRight()

  outdent: ->
    @moveItemsLeft()

  insertTabIgnoringFieldEditor: ->
    @insertText('\t')

  typingFormattingTags: ->
    @_textModeTypingFormattingTags

  setTypingFormattingTags: (typingFormattingTags) ->
    if typingFormattingTags
      typingFormattingTags = shallowCopy(typingFormattingTags)
    @_textModeTypingFormattingTags = typingFormattingTags or {}

  toggleTypingFormattingTag: (tagName, tagValue) ->
    typingFormattingTags = @typingFormattingTags
    if typingFormattingTags[tagName] != undefined
      delete typingFormattingTags[tagName]
    else
      typingFormattingTags[tagName] = tagValue or null
    @typingFormattingTags = typingFormattingTags

  ###
  Section: Move Items
  ###

  moveItemsUp: ->
    @_moveItemsInDirection('up')

  moveItemsDown: ->
    @_moveItemsInDirection('down')

  moveItemsLeft: ->
    @_moveItemsInDirection('left')

  moveItemsRight: ->
    @_moveItemsInDirection('right')

  _moveItemsInDirection: (direction) ->
    selectedItems = @selection.rangeItemsCover
    if selectedItems.length > 0
      startItem = selectedItems[0]
      newNextSibling
      newParent

      if direction == 'up'
        newNextSibling  = @previousVisibleSibling(startItem)
        if newNextSibling
          newParent = startItem.parent
      else if direction == 'down'
        endItem = selectedItems[selectedItems.length - 1]
        newNextSibling = @nextVisibleSibling(endItem)
        if newNextSibling
          newParent = endItem.parent
          newNextSibling = @nextVisibleSibling(newNextSibling)
      else if direction == 'left'
        startItemParent = startItem.parent
        if startItemParent != @hoistedItem()
          newParent = startItemParent.parent
          newNextSibling = @nextVisibleSibling(startItemParent)
      else if direction == 'right'
        newParent = @previousVisibleSibling(startItem)

      if newParent
        @moveItems(selectedItems, newParent, newNextSibling)

  promoteChildItems: (e) ->
    selectedItems = @selection.rangeItemsCover
    if selectedItems.length > 0
      undoManager = @outline.undoManager
      undoManager.beginUndoGrouping()
      for each in selectedItems
        @moveItems(each.children, each.parent, each.nextSibling)
      undoManager.endUndoGrouping()
      undoManager.setActionName('Promote Children')

  demoteTrailingSiblingItems: (e) ->
    selectedItems = @selection.rangeItemsCover
    item = selectedItems[0]

    if item
      trailingSiblings = []
      each = item.nextSibling

      while each
        trailingSiblings.push(each)
        each = each.nextSibling

      if trailingSiblings.length > 0
        @moveItems(trailingSiblings, item, null)
        @outline.undoManager.setActionName('Demote Siblings')

  moveItems: (items, newParent, newNextSibling, startOffset) ->
    undoManager = newParent.outline.undoManager
    undoManager.beginUndoGrouping()
    @outlineEditorElement._animateMoveItems(items, newParent, newNextSibling, startOffset)
    undoManager.endUndoGrouping()
    undoManager.setActionName('Move Items')

  ###
  Section: Delete Items
  ###

  deleteBackward: ->
    @delete('backward', 'character')

  deleteBackwardByDecomposingPreviousCharacter: ->
    @delete('backward', 'character')

  deleteWordBackward: ->
    @delete('backward', 'word')

  deleteToBeginningOfLine: ->
    @delete('backward', 'lineboundary')

  deleteToEndOfParagraph: ->
    @delete('forward', 'paragraphboundary')

  deleteForward: ->
    @delete('forward', 'character')

  deleteWordForward: ->
    @delete('forward', 'word')

  deleteItemsBackward: ->
    @delete('backward', 'item')

  deleteItemsForward: ->
    @delete('forward', 'item')

  delete: (direction, granularity) ->
    outline = @outline
    selectionRange = @selection
    undoManager = outline.undoManager
    outlineEditorElement = @outlineEditorElement

    if selectionRange.isTextMode
      if selectionRange.isCollapsed
        @modifySelectionRange('extend', direction, granularity)
        selectionRange = @selection

      startItem = selectionRange.startItem
      startOffset = selectionRange.startOffset
      endItem = selectionRange.endItem
      endOffset = selectionRange.endOffset

      if not selectionRange.isCollapsed
        undoManager.beginUndoGrouping()
        outline.beginUpdates()

        if 0 == startOffset && startItem != endItem && startItem == endItem.previousSibling && startItem.bodyText.length == 0
          @moveSelectionRange(endItem, 0)
          endItem.replaceBodyTextInRange('', 0, endOffset)
          for each in selectionRange.rangeItems[...-1]
            each.removeFromParent()
        else
          @moveSelectionRange(startItem, startOffset)
          if startItem == endItem
            startItem.replaceBodyTextInRange('', startOffset, endOffset - startOffset)
          else
            startItem.replaceBodyTextInRange(endItem.attributedBodyTextSubstring(endOffset, -1), startOffset, -1)
            startItem.appendChildren(endItem.children)
            for each in selectionRange.rangeItems[1...]
              each.removeFromParent()

        outline.endUpdates()
        undoManager.endUndoGrouping()
        undoManager.setActionName('Delete')
    else if selectionRange.isItemMode
      selectedItems = selectionRange.rangeItemsCover
      if selectedItems.length > 0
        startItem = selectedItems[0]
        endItem = selectedItems[selectedItems.length - 1]
        parent = startItem.parent
        nextSibling = @nextVisibleSibling(endItem)
        previousSibling = @previousVisibleItem(startItem)
        nextSelection = null

        if OutlineEditorSelection.isUpstreamDirection(direction)
          nextSelection = previousSibling || nextSibling || parent
        else
          nextSelection = nextSibling || previousSibling || parent

        undoManager.beginUndoGrouping()
        outline.beginUpdates()

        if nextSelection
          @moveSelectionRange(nextSelection)

        outline.removeItemsFromParents(selectedItems)
        outline.endUpdates()
        undoManager.endUndoGrouping()
        undoManager.setActionName('Delete')

  ###
  Section: Pasteboard
  ###

  copySelection: (dataTransfer) ->
    selectionRange = @selection

    if not selectionRange.isCollapsed
      if selectionRange.isItemMode
        items = selectionRange.rangeItemsCover
        ItemSerializer.writeItems(items, this, dataTransfer)
      else if selectionRange.isTextMode
        focusItem = selectionRange.focusItem
        startOffset = selectionRange.startOffset
        endOffset = selectionRange.endOffset
        selectedText = focusItem.attributedBodyTextSubstring(startOffset, endOffset - startOffset)
        p = document.createElement('P')
        p.appendChild(ItemBodyEncoder.attributedStringToDocumentFragment(selectedText, document))
        dataTransfer.setData('text/plain', selectedText.string())
        dataTransfer.setData('text/html', p.innerHTML)

  cutSelection: (dataTransfer) ->
    selectionRange = @selection
    if selectionRange.isValid
      if not selectionRange.isCollapsed
        @copySelection(dataTransfer)
        @delete()

  pasteToSelection: (dataTransfer) ->
    selectionRange = @selection
    items = ItemSerializer.readItems(this, dataTransfer)

    if items.itemFragmentString
      @insertText(items.itemFragmentString)
    else if items.length
      parent = @hoistedItem()
      insertBefore = null

      if selectionRange.isValid
        endItem = selectionRange.endItem
        if @isExpanded(endItem)
          parent = endItem
          insertBefore = endItem.firstChild
        else
          parent = endItem.parent
          insertBefore = endItem.nextSibling

      parent.insertChildrenBefore(items, insertBefore)
      @moveSelectionRange(items[0], undefined, items[items.length - 1], undefined)

  ###
  Section: Formatting
  ###

  toggleBold: ->
    @_toggleFormattingTag('B')

  toggleItalic: ->
    @_toggleFormattingTag('I')

  toggleUnderline: ->
    @_toggleFormattingTag('U')

  toggleCode: ->
    @_toggleFormattingTag('CODE')

  toggleStrikethrough: ->
    @_toggleFormattingTag 'S'


  _toggleFormattingTag: (tagName, attributes={}) ->
    selectionRange = @selection
    startItem = selectionRange.startItem

    if selectionRange.isCollapsed
      @toggleTypingFormattingTag(tagName)
    else if startItem
      tagAttributes = startItem.elementAtBodyTextIndex(tagName, selectionRange.startOffset or 0)
      addingTag = tagAttributes is undefined

      @_transformSelectedText (eachItem, start, end) ->
        if (addingTag)
          eachItem.addElementInBodyTextRange(tagName, attributes, start, end - start)
        else
          eachItem.removeElementInBodyTextRange(tagName, start, end - start)

  upperCase: ->
    @_transformSelectedText (item, start, end) ->
      item.replaceBodyTextInRange(item.bodyText.substring(start, end).toUpperCase(), start, end - start)

  lowerCase: ->
    @_transformSelectedText (item, start, end) ->
      item.replaceBodyTextInRange(item.bodyText.substring(start, end).toLowerCase(), start, end - start)

  _transformSelectedText: (transform) ->
    selectionRange = @selection
    outline = @outline
    undoManager = outline.undoManager
    outline.beginUpdates()
    undoManager.beginUndoGrouping()

    if selectionRange.isTextMode
      transform(selectionRange.startItem, selectionRange.startOffset, selectionRange.endOffset)
    else
      for each in selectionRange.rangeItems
        transform(each, 0, each.bodyText.length)

    undoManager.endUndoGrouping()
    outline.endUpdates()

  toggleDone: (e) ->
    outline = @outline
    undoManager = outline.undoManager
    doneDate = new Date().toISOString()
    selectedItems = @selection.rangeItems
    firstItem = selectedItems[0]

    if firstItem
      if firstItem.hasAttribute('data-done')
        doneDate = undefined

      outline.beginUpdates()
      undoManager.beginUndoGrouping()
      for each in selectedItems
        each.setAttribute('data-done', doneDate)
      undoManager.endUndoGrouping()
      outline.endUpdates()

  ###
  Section: Drag and Drop
  ###

  draggedItem: ->
    @outline._draggedItemHack

  dropEffect: ->
    @_dragState.dropEffect

  dropParentItem: ->
    @_dragState.dropParentItem

  dropInsertBeforeItem: ->
    @_dragState.dropInsertBeforeItem

  dropInsertAfterItem: ->
    @_dragState.dropInsertAfterItem

  _refreshIfDifferent: (item1, item2) ->
    if item1 != item2
      outlineEditorElement = @outlineEditorElement
      outlineEditorElement.updateItemClass(item1)
      outlineEditorElement.updateItemClass(item2)

  setDragState: (state) ->
    if state.dropParentItem and not state.dropInsertBeforeItem
      state.dropInsertAfterItem = @lastVisibleChild(state.dropParentItem)

    oldState = @_dragState
    @outline._draggedItemHack = state.draggedItem
    @_dragState = state

    @_refreshIfDifferent(oldState.draggedItem, state.draggedItem)
    @_refreshIfDifferent(oldState.dropParentItem, state.dropParentItem)
    @_refreshIfDifferent(oldState.dropInsertBeforeItem, state.dropInsertBeforeItem)
    @_refreshIfDifferent(oldState.dropInsertAfterItem, state.dropInsertAfterItem)

  OutlineEditor::debouncedSetDragState = Util.debounce(OutlineEditor::setDragState)

  ###
  Section: Undo
  ###

  # Essential: Undo the last change.
  undo: ->
    @outline.undoManager.undo()

  # Essential: Redo the last change.
  redo: ->
    @outline.undoManager.redo()

  didOpenUndoGroup: (undoManager) ->
    if !undoManager.isUndoing && !undoManager.isRedoing
      undoManager.setUndoGroupMetadata('undoSelection', @selection)

  didReopenUndoGroup: (undoManager) ->

  willUndo: (undoManager, undoGroupMetadata) ->
    @_overrideIsFocused = @isFocused()
    undoManager.setUndoGroupMetadata('redoSelection', @selection)

  didUndo: (undoManager, undoGroupMetadata) ->
    selectionRange = undoGroupMetadata.undoSelection
    if selectionRange
      @moveSelectionRange(selectionRange)
    @_overrideIsFocused = false

  willRedo: (undoManager, undoGroupMetadata) ->
    @_overrideIsFocused = @isFocused()

  didRedo: (undoManager, undoGroupMetadata) ->
    selectionRange = undoGroupMetadata.redoSelection
    if selectionRange
      @moveSelectionRange(selectionRange)
    @_overrideIsFocused = false

  ###
  Section: Scrolling
  ###

  scrollToBeginningOfDocument: (e) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    outlineEditorElement.scrollToBeginningOfDocument()
    outlineEditorElement.popAnimationContext()

  scrollToEndOfDocument: (e) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    @outlineEditorElement.scrollToEndOfDocument()
    outlineEditorElement.popAnimationContext()

  scrollPageUp: (e) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    @outlineEditorElement.scrollPageUp()
    outlineEditorElement.popAnimationContext()

  pageUpAndModifySelection: (e) ->
    # Extend focus up 1 page

  pageUp: (e) ->
    # Move focus up 1 page

  scrollPageDown: (e) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    @outlineEditorElement.scrollPageDown()
    outlineEditorElement.popAnimationContext()

  pageDownAndModifySelection: (e) ->
    # Extend focus down 1 page

  pageDown: (e) ->
    # Move focus down 1 page

  scrollToOffsetRange: (startOffset, endOffset, align) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    @outlineEditorElement.scrollToOffsetRange(startOffset, endOffset, align)
    outlineEditorElement.popAnimationContext()

  scrollToOffsetRangeIfNeeded: (startOffset, endOffset, center) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    @outlineEditorElement.scrollToOffsetRangeIfNeeded(startOffset, endOffset, center)
    outlineEditorElement.popAnimationContext()

  scrollToItem: (item, align) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    @outlineEditorElement.scrollToItem(item, align)
    outlineEditorElement.popAnimationContext()

  scrollToItemIfNeeded: (item, center) ->
    outlineEditorElement = @outlineEditorElement
    outlineEditorElement.pushAnimationContext(Constants.DefaultScrollAnimactionContext)
    @outlineEditorElement.scrollToItemIfNeeded(item, center)
    outlineEditorElement.popAnimationContext()

  centerSelectionInVisibleArea: ->

  ###
  Section: File Details
  ###

  getTitle: ->
    if sessionPath = @getPath()
      path.basename(sessionPath)
    else
      'Untitled'

  getLongTitle: ->
    if sessionPath = @getPath()
      fileName = path.basename(sessionPath)
      directory = atom.project.relativize(path.dirname(sessionPath))
      directory = if directory.length > 0 then directory else path.basename(path.dirname(sessionPath))
      "#{fileName} - #{directory}"
    else
      'Untitled'

  getURI: ->
    @outline.getUri()

  getPath: ->
    @outline.getPath()

  isModified: ->
    @outline.isModified()

  isEmpty: ->
    @outline.isEmpty()

  save: ->
    @outline.save(this)

  saveAs: (filePath) ->
    @outline.saveAs(filePath, this)

  shouldPromptToSave: ->
    @isModified() and not @outline.hasMultipleEditors()

  ###
  Section: Util
  ###

  editorState: (item) ->
    item?.editorState(@outlineEditorElement.id)

  #OutlineEditor::DOMGetElementById(id) {
  #  let shadowRoot = this._shadowRoot;
  #  if (shadowRoot) {
  #    return shadowRoot.getElementById(id);
  #  }
  #  return document.getElementById(id);
  #};

  DOMGetSelection: (id) ->
    #let shadowRoot = this._shadowRoot;
    #if (shadowRoot) {
    #  return shadowRoot.getSelection(id);
    #}
    document.getSelection(id)

  DOMGetActiveElement: (id) ->
    #let shadowRoot = this._shadowRoot;
    #if (shadowRoot) {
    #  return shadowRoot.activeElement;
    #}
    document.activeElement

  DOMElementFromPoint: (clientX, clientY) ->
    root = @_shadowRoot or document
    root.elementFromPoint(clientX, clientY)

  DOMCaretPositionFromPoint: (clientX, clientY) ->
    # NOTE, this code fails under shadow DOM
    root = @_shadowRoot or document
    result

    if root.caretPositionFromPoint
      result = root.caretPositionFromPoint(clientX, clientY)
      result.range = document.createRange()
      result.range.setStart(result.offsetItem, result.offset)
    # WebKit
    else if root.caretRangeFromPoint
      range = root.caretRangeFromPoint(clientX, clientY)
      if range
        result =
          offsetItem: range.startContainer
          offset: range.startOffset
          range: range

    result