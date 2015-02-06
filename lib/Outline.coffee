{Emitter, CompositeDisposable} = require 'atom'
ItemSerializer = require './ItemSerializer'
OutlineChange = require './OutlineChange'
UndoManager = require './UndoManager'
Constants = require './Constants'
emissary = require 'emissary'
shortid = require './shortid'
assert = require 'assert'
Item = require './Item'

class Outline

  refcount: 0
  updateCount: 0
  updateMutations: null
  updateMutationObserver: null
  cachedText: null
  encoding: null
  stoppedChangingDelay: 300
  stoppedChangingTimeout: null
  file: null
  fileConflict: false
  fileSubscriptions: null

  constructor: (params) ->
    @outlineStore = @createOutlineStoreIfNeeded(params?.outlineStore)

    @loadingLIUsedIDs = {}
    @root = @createItem(null, @outlineStore.getElementById(Constants.RootID))
    @loadingLIUsedIDs = null;

    @undoManager = new UndoManager()
    @emitter = new Emitter()
    @setEncoding(params?.encoding)
    @loaded = false

    @updateMutationObserver = new MutationObserver (mutations) =>
      @updateMutations = @updateMutations.concat(mutations)
    @updateMutationObserver.observe(@outlineStore.getElementById(Constants.RootID), {
      attributes: true,
      childList: true,
      characterData: true,
      subtree: true,
      attributeOldValue: true,
      characterDataOldValue: true
    })

    @setPath(params.filePath) if params?.filePath
    @load() if params?.load

  createOutlineStoreIfNeeded: (outlineStore) ->
    if not outlineStore
      outlineStore = document.implementation.createHTMLDocument()
      rootUL = outlineStore.createElement('ul')
      rootUL.id = Constants.RootID
      outlineStore.documentElement.lastChild.appendChild(rootUL)
    return outlineStore

  ###
  Section: Event Subscription
  ###

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidStopChanging: (callback) ->
    @emitter.on 'did-stop-changing', callback

  onDidConflict: (callback) ->
    @emitter.on 'did-conflict', callback

  onDidChangeModified: (callback) ->
    @emitter.on 'did-change-modified', callback

  onDidChangePath: (callback) ->
    @emitter.on 'did-change-path', callback

  onDidChangeEncoding: (callback) ->
    @emitter.on 'did-change-encoding', callback

  onWillSave: (callback) ->
    @emitter.on 'will-save', callback

  onDidSave: (callback) ->
    @emitter.on 'did-save', callback

  onWillReload: (callback) ->
    @emitter.on 'will-reload', callback

  onDidReload: (callback) ->
    @emitter.on 'did-reload', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  getStoppedChangingDelay: -> @stoppedChangingDelay

  ###
  Section: File Details
  ###

  isModified: ->
    return false unless @loaded
    if @file
      if @file.exists()
        @getText() != @cachedDiskContents
      else
        @wasModifiedBeforeRemove ? not @isEmpty()
    else
      not @isEmpty()

  isInConflict: -> @conflict

  getPath: ->
    @file?.getPath()

  setPath: (filePath) ->
    return if filePath == @getPath()

    if filePath
      @file = new File(filePath)
      @file.setEncoding(@getEncoding())
      @subscribeToFile()
    else
      @file = null

    @emitter.emit 'did-change-path', @getPath()

  setEncoding: (encoding='utf8') ->
    return if encoding is @getEncoding()

    @encoding = encoding
    if @file?
      @file.setEncoding(encoding)
      @emitter.emit 'did-change-encoding', encoding

      unless @isModified()
        @updateCachedDiskContents true, =>
          @reload()
          @clearUndoStack()
    else
      @emitter.emit 'did-change-encoding', encoding

    return

  getEncoding: -> @encoding ? @file?.getEncoding()

  getUri: ->
    @getPath()

  getBaseName: ->
    @file?.getBaseName()

  ###
  Section: Reading Items
  ###

  isEmpty: ->
    firstChild = @root.firstChild
    not firstChild or (not firstChild.nextItem and firstChild.bodyTextLength == 0)

  itemForID: (id) ->
    @outlineStore.getElementById(id)?._item

  items: ->
    @root.descendants

  itemsForXPath: (xpathExpression, namespaceResolver) ->
    xpathResult = @evaluateXPath(xpathExpression, null, XPathResult.ORDERED_NODE_ITERATOR_TYPE)
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

  evaluateXPath: (xpathExpression, namespaceResolver, resultType, result) ->
    @outlineStore.evaluate(xpathExpression, @root._liOrRootUL, namespaceResolver, resultType, result)

  ###
  Section: Creating and Mutating Items
  ###

  createItem: (text, li, remapIDCallback) ->
    new Item(@, text, li or @createStoreLI(), remapIDCallback)

  copyItem: (item) ->
    assert.ok(not item.isRoot, 'Can not copy root')
    assert.ok(item.outline == @, 'Item must be owned by this outline')
    @createItem(null, item._liOrRootUL.cloneNode(true))

  importItem: (item) ->
    assert.ok(!item.isRoot, 'Can not import root item')
    assert.ok(item.outline != @, 'Item must not be owned by this outline')
    @createItem(null, @outlineStore.importNode(item._liOrRootUL, true))

  aliasItem: (item) ->
    assert.ok(!item.isRoot, 'Can not alias root item');
    alias = @copyItem(item)
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
        @removeSiblingsFromParent(siblings);
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
  Section: Updates
  ###

  isUpdating: -> @updateCount != 0

  beginUpdates: ->
    if ++@updateCount == 1 then @updateMutations = []

  endUpdates: ->
    if --@updateCount == 0
      updateMutations = @updateMutations;
      @updateMutations = null;
      updateMutations = updateMutations.concat(@updateMutationObserver.takeRecords());
      if updateMutations.length > 0
        @cachedText = null
        @conflict = false if @conflict and !@isModified()
        @emitter.emit('did-change', new OutlineChange(updateMutations));
        @scheduleModifiedEvents()

  ###
  Section: Buffer Operations
  ###

  save: ->
    @saveAs(@getPath())

  saveAs: (filePath) ->
    unless filePath then throw new Error("Can't save buffer with no file path")

    @emitter.emit 'will-save', {path: filePath}
    @emit 'will-be-saved', this
    @setPath(filePath)
    @file.write(@getText())
    @cachedDiskContents = @getText()
    @conflict = false
    @emitModifiedStatusChanged(false)
    @emitter.emit 'did-save', {path: filePath}
    @emit 'saved', this

  reload: ->
    @emitter.emit 'will-reload'
    @emit 'will-reload'
    @setTextViaDiff(@cachedDiskContents)
    @emitModifiedStatusChanged(false)
    @emitter.emit 'did-reload'
    @emit 'reloaded'

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
    assert.ok(newAlias._aliases == null, 'should only happen when item is first created')
    itemAliases = item._aliases ?= []
    newAliases = newAlias._aliases = itemAliases.slice()

    for each in itemAliases
      newAliases.push each

    newAliases.push(item)
    itemAliases.push(newAlias)

  getText: ->
    if @cachedText?
      @cachedText
    else
      @cachedText = ItemSerializer.itemsToHTML(@root.children)

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
      @clearUndoStack()
    this

  destroy: ->
    unless @destroyed
      @cancelStoppedChangingTimeout()
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

      # Synchrounously update the disk contents because the {File} has already cached them. If the
      # contents updated asynchrounously multiple `conlict` events could trigger for the same disk
      # contents.
      @updateCachedDiskContentsSync()
      return if previousContents == @cachedDiskContents

      if @conflict
        @emitter.emit 'did-conflict'
        @emit "contents-conflicted"
      else
        @reload()

    @fileSubscriptions.add @file.onDidDelete =>
      modified = @getText() != @cachedDiskContents
      @wasModifiedBeforeRemove = modified
      if modified
        @updateCachedDiskContents()
      else
        @destroy()

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
    @stoppedChangingTimeout = setTimeout(stoppedChangingCallback, @stoppedChangingDelay)

  emitModifiedStatusChanged: (modifiedStatus) ->
    return if modifiedStatus is @previousModifiedStatus
    @previousModifiedStatus = modifiedStatus
    @emitter.emit 'did-change-modified', modifiedStatus

module.exports = Outline