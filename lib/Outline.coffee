# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Emitter, CompositeDisposable} = require 'atom'
ItemSerializer = require './ItemSerializer'
OutlineChange = require './OutlineChange'
UndoManager = require './UndoManager'
Constants = require './Constants'
{File} = require 'pathwatcher'
emissary = require 'emissary'
shortid = require './shortid'
assert = require 'assert'
Item = require './Item'
Q = require 'q'

# Essential: A mutable outline of {Item}'s.
#
# Use outlines to create new items, find existing items, and watch for changes
# in items. Outlines also coordinate loading and saving items.
#
# Internally outlines uses a HTMLDocument with a restricted (Folding Text
# Markup Language) set of HTML to store the underlying outline data. You
# should never modify the content of this HTMLDocument directly, but you can
# query it using {::evaluateXPath}. Read more about [Folding Text Markup
# Language]().
#
# ## Examples
#
# Group multiple changes into a single {OutlineChange}:
#
# ```coffeescript
# outline.beginUpdates()
# root = outline.root
# root.appendChild outline.createItem()
# root.appendChild outline.createItem()
# root.firstChild.bodyText = 'first'
# root.lastChild.bodyText = 'last'
# outline.endUpdates()
# ```
#
# Watch for outline changes:
#
# ```coffeescript
# disposable = outline.onDidChange (e) ->
#   for delta in e.deltas
#     switch delta.type
#       when 'attributes'
#         console.log delta.attributeName
#       when 'bodyText'
#         console.log delta.target.bodyText
#       when 'children'
#         console.log delta.addedItems
#         console.log delta.removedItems
# ```
#
# Use XPath to list all items with bold text:
#
# ```coffeescript
# for each in outline.itemsForXPath('//li/p//b')
#   console.log each
# ```
class Outline
  atom.deserializers.add(this)

  refcount: 0
  changeCount: 0
  undoSubscriptions: null
  updateCount: 0
  updateMutations: null
  updateMutationObserver: null
  cachedText: null
  stoppedChangingDelay: 300
  stoppedChangingTimeout: null
  file: null
  fileConflict: false
  fileSubscriptions: null
  serializedState: null

  ###
  Section: Construction
  ###

  # Public: Create a new outline.
  constructor: (params) ->
    Outline.idsToOutlines[@id = shortid()] = this

    @outlineStore = @createOutlineStoreIfNeeded(params?.outlineStore)

    @loadingLIUsedIDs = {}
    @root = @createItem(null, @outlineStore.getElementById(Constants.RootID))
    @loadingLIUsedIDs = null

    @undoManager = undoManager = new UndoManager()
    @emitter = new Emitter()

    @loaded = false
    @digestWhenLastPersisted = params?.digestWhenLastPersisted ? false
    @modifiedWhenLastPersisted = params?.modifiedWhenLastPersisted ? false
    @useSerializedText = @modifiedWhenLastPersisted isnt false
    @serializedState = {}

    @updateMutationObserver = new MutationObserver (mutations) =>
      @updateMutations = @updateMutations.concat(mutations)
    @updateMutationObserver.observe(
      @outlineStore.getElementById(Constants.RootID),
      {
        attributes: true,
        childList: true,
        characterData: true,
        subtree: true,
        attributeOldValue: true,
        characterDataOldValue: true
      }
    )

    @undoSubscriptions = new CompositeDisposable(
      undoManager.onDidCloseUndoGroup =>
        unless undoManager.isUndoing or undoManager.isRedoing
          @changeCount++
          @scheduleModifiedEvents()
      undoManager.onDidUndo =>
        @changeCount--
        @scheduleModifiedEvents()
      undoManager.onDidRedo =>
        @changeCount++
        @scheduleModifiedEvents()
    )

    @setPath(params.filePath) if params?.filePath
    @load() if params?.load

  createOutlineStoreIfNeeded: (outlineStore) ->
    if not outlineStore
      outlineStore = document.implementation.createHTMLDocument()
      rootUL = outlineStore.createElement('ul')
      rootUL.id = Constants.RootID
      outlineStore.documentElement.lastChild.appendChild(rootUL)
    return outlineStore

  serialize: ->
    {} =
      deserializer: 'Outline'
      text: @getText()
      filePath: @getPath()
      modifiedWhenLastPersisted: @isModified()
      digestWhenLastPersisted: @file?.getDigest()

  @deserialize: (data) ->
    filePath = data.filePath
    outline = Outline.pathsToOutlines[filePath]
    unless outline
      data.load = true
      outline = new Outline(data)
      if filePath
        Outline.pathsToOutlines[filePath] = outline
    outline

  ###
  Section: Finding Outlines
  ###

  # Public: Read-only unique, but not persistent, {String} ID.
  id: null

  @idsToOutlines: {}
  @pathsToOutlines: {}

  # Public: Returns existing {Outline} instance with the given outline id.
  #
  # - `id` {String} outline id.
  @outlineForID: (id) ->
    Outline.idsToOutlines[id]

  # Public: Returns existing {Outline} instance with the given file path.
  #
  # - `filePath` {String} outline file path.
  @outlineForFilePath: (filePath) ->
    Outline.pathsToOutlines[filePath]

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when the outline changes.
  #
  # See {Outline} Examples for an example of subscribing to {OutlineChange}s.
  #
  # - `callback` {Function} to be called when the outline changes.
  #   - `event` {OutlineChange} event.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidStopChanging: (callback) ->
    @emitter.on 'did-stop-changing', callback

  # Public: Invoke the given callback when the in-memory contents of the
  # outline become in conflict with the contents of the file on disk.
  #
  # - `callback` {Function} to be called when the outline enters conflict.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidConflict: (callback) ->
    @emitter.on 'did-conflict', callback

  # Public: Invoke the given callback when the value of {::isModified} changes.
  #
  # - `callback` {Function} to be called when {::isModified} changes.
  #   - `modified` {Boolean} indicating whether the outline is modified.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeModified: (callback) ->
    @emitter.on 'did-change-modified', callback

  # Public: Invoke the given callback when the value of {::getPath} changes.
  #
  # - `callback` {Function} to be called when the path changes.
  #   - `path` {String} representing the outline's current path on disk.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePath: (callback) ->
    @emitter.on 'did-change-path', callback

  # Public: Invoke the given callback before the outline is saved to disk.
  #
  # - `callback` {Function} to be called before the outline is saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillSave: (callback) ->
    @emitter.on 'will-save', callback

  # Public: Invoke the given callback after the outline is saved to disk.
  #
  # - `callback` {Function} to be called after the outline is saved.
  #   - `event` {Object} with the following keys:
  #     - `path` The path to which the outline was saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidSave: (callback) ->
    @emitter.on 'did-save', callback

  # Public: Invoke the given callback before the outline is reloaded from the
  # contents of its file on disk.
  #
  # - `callback` {Function} to be called before the outline is reloaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillReload: (callback) ->
    @emitter.on 'will-reload', callback

  # Public: Invoke the given callback after the outline is reloaded from the
  # contents of its file on disk.
  #
  # - `callback` {Function} to be called after the outline is reloaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidReload: (callback) ->
    @emitter.on 'did-reload', callback

  # Public: Invoke the given callback when the outline is destroyed.
  #
  # - `callback` {Function} to be called when the outline is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  getStoppedChangingDelay: -> @stoppedChangingDelay

  ###
  Section: Reading Items
  ###

  # Public: Returns an {Array} of all {Item}s in the outline (except the
  # root) in outline order.
  items: ->
    @root.descendants

  isEmpty: ->
    firstChild = @root.firstChild
    not firstChild or
        (not firstChild.nextItem and
        firstChild.bodyText.length == 0)

  # Public: Returns {Item} for given id.
  #
  # - `id` {String} id.
  itemForID: (id) ->
    @outlineStore.getElementById(id)?._item

  # Public: Returns {Array} of {Item}s for given {Array} of ids.
  #
  # - `ids` {Array} of ids.
  itemsForIDs: (ids) ->
    return [] unless ids

    items = []
    for each in ids
      each = @itemForID each
      if each
        items.push each
    items

  ###
  Section: Creating Items
  ###

  # Public: Create a new item. The new item is owned by this outline, but is
  # not yet inserted into it so it won't be visible until you insert it.
  #
  # - `text` (optional) {String} or {AttributedString}.
  createItem: (text, li, remapIDCallback) ->
    new Item(@, text, li or @createStoreLI(), remapIDCallback)

  cloneItem: (item) ->
    assert.ok(not item.isRoot, 'Can not clone root')
    assert.ok(item.outline == @, 'Item must be owned by this outline')
    @createItem(null, item._liOrRootUL.cloneNode(true))

  importItem: (item) ->
    assert.ok(!item.isRoot, 'Can not import root item')
    assert.ok(item.outline != @, 'Item must not be owned by this outline')
    @createItem(null, @outlineStore.importNode(item._liOrRootUL, true))

  aliasItem: (item) ->
    assert.ok(!item.isRoot, 'Can not alias root item')
    alias = @cloneItem(item)
    aliases = item._aliases
    end = item.nextBranch
    eachAlias = alias
    each = item

    while each != end
      @associateItemWithAlias(each, eachAlias)
      each = each.nextItem
      eachAlias = eachAlias.nextItem

    alias

  removeItemsFromParents: (items) ->
    siblings = []
    prev = null

    for each in items
      if not prev or prev.nextSibling == each
        siblings.push(each)
      else
        @removeSiblingsFromParent(siblings)
        siblings = [each]
      prev = each

    if siblings.length
      @removeSiblingsFromParent(siblings);

  removeSiblingsFromParent: (siblings) ->
    return unless siblings.length

    firstSibling = siblings[0]
    outline = firstSibling.outline
    parent = firstSibling.parent

    return unless parent

    nextSibling = siblings[siblings.length - 1].nextSibling
    isInOutline = firstSibling.isInOutline
    undoManager = outline.undoManager

    if isInOutline
      if undoManager.isUndoRegistrationEnabled()
        undoManager.registerUndoOperation ->
          parent.insertChildrenBefore(siblings, nextSibling)

      undoManager.disableUndoRegistration()
      outline.beginUpdates()

    for each in siblings
      parent.removeChild each

    if isInOutline
      undoManager.enableUndoRegistration()
      outline.endUpdates()

  ###
  Section: Querying Items
  ###

  # Public: XPath query internal HTML structure for matching {Items}.
  #
  # Items are considered to match if they, or if a node contained in their
  # body text matches the XPath.
  #
  # - `xpathExpression` {String} xpath expression
  # - `namespaceResolver` (optional) {String}
  #
  # Returns an {Array} of all {Item} matching the
  # [XPath](https://developer.mozilla.org/en-US/docs/Web/XPath) expression.
  itemsForXPath: (xpathExpression, namespaceResolver) ->
    xpathResult = @evaluateXPath(
      xpathExpression,
      null,
      XPathResult.ORDERED_NODE_ITERATOR_TYPE
    )
    each = xpathResult.iterateNext()
    lastItem = undefined
    items = []

    while each
      while each and not each._item
        each = each.parentNode
      if each
        eachItem = each._item
        if eachItem != lastItem
          items.push(eachItem)
          lastItem = eachItem
      each = xpathResult.iterateNext()

    return items

  # Public: XPath query internal HTML structure.
  #
  # - `xpathExpression` {String} xpath expression
  # - `namespaceResolver` (optional)
  # - `resultType` (optional)
  # - `result` (optional)
  #
  # This query evaluates on the underlying HTMLDocument. Please refere to the
  # standard [document.evaluate](https://developer.mozilla.org/en-
  # US/docs/Web/API/document.evaluate) documentation for details.
  #
  # Returns an [XPathResult](https://developer.mozilla.org/en-
  # US/docs/XPathResult) based on an [XPath](https://developer.mozilla.org/en-
  # US/docs/Web/XPath) expression and other given parameters.
  evaluateXPath: (xpathExpression, namespaceResolver, resultType, result) ->
    @outlineStore.evaluate(
      xpathExpression,
      @root._liOrRootUL,
      namespaceResolver,
      resultType,
      result
    )

  ###
  Section: Grouping Changes
  ###

  # Public: Returns {true} if outline is updating.
  isUpdating: -> @updateCount != 0

  # Public: Begin grouping changes into a single {OutlineChange} event. Must
  # later call {::endUpdates} to balance this call.
  beginUpdates: ->
    if ++@updateCount == 1 then @updateMutations = []

  # Public: End grouping changes. Must call to balance a previous
  # {::beginUpdates} call.
  endUpdates: ->
    if --@updateCount == 0
      updateMutations = @updateMutations
      @updateMutations = null

      updateMutations = updateMutations.concat(@updateMutationObserver.takeRecords())
      if updateMutations.length > 0
        @cachedText = null
        @conflict = false if @conflict and !@isModified()
        @emitter.emit('did-change', new OutlineChange(updateMutations))
        @scheduleModifiedEvents()

  ###
  Section: Undo
  ###

  # Essential: Undo the last change.
  undo: ->
    @undoManager.undo()

  # Essential: Redo the last change.
  redo: ->
    @undoManager.redo()

  ###
  Section: File Details
  ###

  # Public: Determine if the in-memory contents of the outline differ from its
  # contents on disk.
  #
  # If the outline is unsaved, always returns `true` unless the outline is
  # empty.
  #
  # Returns a {Boolean}.
  isModified: ->
    @changeCount != 0

  # Public: Determine if the in-memory contents of the outline conflict with the
  # on-disk contents of its associated file.
  #
  # Returns a {Boolean}.
  isInConflict: -> @conflict

  # Public: Get the path of the associated file.
  #
  # Returns a {String}.
  getPath: ->
    @file?.getPath()

  # Public: Set the path for the outlines's associated file.
  #
  # - `filePath` A {String} representing the new file path
  setPath: (filePath) ->
    return if filePath == @getPath()

    if filePath
      @file = new File(filePath)
      @file.setEncoding('utf8')
      @subscribeToFile()
    else
      @file = null

    @emitter.emit 'did-change-path', @getPath()

  getUri: ->
    @getPath()

  getBaseName: ->
    @file?.getBaseName()

  ###
  Section: File Content Operations
  ###

  # Public: Save the outline.
  save: (editor) ->
    @saveAs @getPath(), editor

  # Public: Save the outline at a specific path.
  #
  # - `filePath` The path to save at.
  saveAs: (filePath, editor) ->
    unless filePath then throw new Error("Can't save outline with no file path")

    @emitter.emit 'will-save', {path: filePath}
    @setPath(filePath)
    @file.write(@getText(editor))
    @cachedDiskContents = @getText(editor)
    @conflict = false
    @changeCount = 0
    @emitModifiedStatusChanged(false)
    @emitter.emit 'did-save', {path: filePath}

  # Public: Reload the outlines's contents from disk.
  #
  # Sets the outlines's content to the cached disk contents
  reload: ->
    @emitter.emit 'will-reload'

    try
      @beginUpdates()
      @root.removeChildren(@root.children)
      items = ItemSerializer.itemsFromHTML(@cachedDiskContents, this)
      @serializedState = items.metaState
      for each in items
        @root.appendChild(each)
      @endUpdates()
    catch error
      console.log error

    @changeCount = 0
    @emitModifiedStatusChanged(false)
    @emitter.emit 'did-reload'

  updateCachedDiskContentsSync: ->
    @cachedDiskContents = @file?.readSync() ? ""

  updateCachedDiskContents: (flushCache=false, callback) ->
    Q(@file?.read(flushCache) ? "").then (contents) =>
      @cachedDiskContents = contents
      callback?()

  ###
  Section: Private Utility Methods
  ###

  createStoreLI: ->
    outlineStore = @outlineStore
    li = outlineStore.createElement('LI')
    li.appendChild(outlineStore.createElement('P'))
    li

  nextOutlineUniqueItemID: (candidateID) ->
    loadingLIUsedIDs = @loadingLIUsedIDs
    while true
      id = candidateID or shortid()
      if loadingLIUsedIDs and not loadingLIUsedIDs[id]
        loadingLIUsedIDs[id] = true
        return id
      else if not @outlineStore.getElementById(id)
        return id
      else
        candidateID = null

  associateItemWithAlias: (item, newAlias) ->
    assert.ok(
      newAlias._aliases == null,
      'should only happen when item is first created'
    )
    itemAliases = item._aliases ?= []
    newAliases = newAlias._aliases = itemAliases.slice()

    for each in itemAliases
      newAliases.push each

    newAliases.push(item)
    itemAliases.push(newAlias)

  getText: (editor) ->
    if @cachedText?
      @cachedText
    else
      @cachedText = ItemSerializer.itemsToHTML(@root.children, editor)

  loadSync: ->
    @updateCachedDiskContentsSync()
    @finishLoading()

  load: ->
    @updateCachedDiskContents().then => @finishLoading()

  finishLoading: ->
    if @isAlive()
      @loaded = true
      if @useSerializedText and @digestWhenLastPersisted is @file?.getDigest()
        @emitModifiedStatusChanged(true)
      else
        @reload()
      @undoManager.removeAllActions()
    this

  destroy: ->
    unless @destroyed
      delete Outline.idsToOutlines[@id]
      delete Outline.pathsToOutlines[@getPath()]
      @updateMutationObserver.disconnect()
      @cancelStoppedChangingTimeout()
      @undoSubscriptions?.dispose()
      @fileSubscriptions?.dispose()
      @destroyed = true
      @emitter.emit 'did-destroy'

  isAlive: -> not @destroyed

  isDestroyed: -> @destroyed

  isRetained: -> @refcount > 0

  retain: ->
    @refcount++
    this

  release: (editorID) ->
    @refcount--
    for each in @items()
      each.clearEditorState editorID
    @destroy() unless @isRetained()
    this

  subscribeToFile: ->
    @fileSubscriptions?.dispose()
    @fileSubscriptions = new CompositeDisposable

    @fileSubscriptions.add @file.onDidChange =>
      @conflict = true if @isModified()
      previousContents = @cachedDiskContents

      # Synchrounously update the disk contents because the {File} has already
      # cached them. If the contents updated asynchrounously multiple
      # `conlict` events could trigger for the same disk contents.
      @updateCachedDiskContentsSync()
      return if previousContents == @cachedDiskContents

      if @conflict
        @emitter.emit 'did-conflict'
      else
        @reload()

    @fileSubscriptions.add @file.onDidDelete =>
      @destroy() unless isModified()

    @fileSubscriptions.add @file.onDidRename =>
      @emitter.emit 'did-change-path', @getPath()

    @fileSubscriptions.add @file.onWillThrowWatchError (errorObject) =>
      @emitter.emit 'will-throw-watch-error', errorObject

  hasMultipleEditors: -> @refcount > 1

  cancelStoppedChangingTimeout: ->
    clearTimeout(@stoppedChangingTimeout) if @stoppedChangingTimeout

  scheduleModifiedEvents: ->
    @cancelStoppedChangingTimeout()
    stoppedChangingCallback = =>
      @stoppedChangingTimeout = null
      modifiedStatus = @isModified()
      @emitter.emit 'did-stop-changing'
      @emitModifiedStatusChanged(modifiedStatus)
    @stoppedChangingTimeout = setTimeout(
      stoppedChangingCallback,
      @stoppedChangingDelay
    )

  emitModifiedStatusChanged: (modifiedStatus) ->
    return if modifiedStatus is @previousModifiedStatus
    @previousModifiedStatus = modifiedStatus
    @emitter.emit 'did-change-modified', modifiedStatus

module.exports = Outline