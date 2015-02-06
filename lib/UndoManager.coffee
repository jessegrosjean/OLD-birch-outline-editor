{Emitter} = require 'atom'
assert = require 'assert'

class UndoManager

  constructor: ->
    @groupingLevel = 0
    @disabledLevel = 0
    @isRedoing = false
    @isUndoing = false
    @undoStack = []
    @redoStack = []
    @currentGroup = null
    @emitter = new Emitter()
    @removeAllActions()

  ###
  Section: Event Subscription
  ###

  onWillUndo: (callback) ->
    @emitter.on 'will-undo', callback

  onDidUndo: (callback) ->
    @emitter.on 'did-undo', callback

  onWillRedo: (callback) ->
    @emitter.on 'will-redo', callback

  onDidRedo: (callback) ->
    @emitter.on 'did-redo', callback

  onDidOpenUndoGroup: (callback) ->
    @emitter.on 'did-open-undo-group', callback

  onDidReopenUndoGroup: (callback) ->
    @emitter.on 'did-reopen-undo-group', callback

  onWillCloseUndoGroup: (callback) ->
    @emitter.on 'will-close-undo-group', callback

  onDidCloseUndoGroup: (callback) ->
    @emitter.on 'did-close-undo-group', callback

  ###
  Section: Undo Grouping
  ###

  beginUndoGrouping: (metadata) ->
    @groupingLevel++
    if @groupingLevel == 1
      @currentGroup = []
      @currentGroup.metadata = metadata or {}
      @emitter.emit 'did-open-undo-group'

  reopenLastUndoGrouping: ->
    if @undoStack.length
      @groupingLevel++
      if @groupingLevel == 1
        @currentGroup = @undoStack.pop()
        @emitter.emit 'did-reopen-undo-group'

  endUndoGrouping: ->
    if @groupingLevel > 0
      @groupingLevel--
      if @groupingLevel == 0
        if @currentGroup.length > 0
          if @isUndoing
            @redoStack.push(@currentGroup)
          else
            @undoStack.push(@currentGroup)

        if !@isUndoing && !@isRedoing
          @redoStack = []

        @currentGroup = null
        @emitter.emit 'did-close-undo-group'

  ###
  Section: Undo Registration
  ###

  isUndoRegistrationEnabled: -> @disabledLevel == 0

  disableUndoRegistration: -> @disabledLevel++

  enableUndoRegistration: -> @disabledLevel--

  registerUndoOperation: (operation) ->
    return unless @isUndoRegistrationEnabled()

    if not @isUndoing and not @isRedoing
      currentGroup = @currentGroup

      if not currentGroup
        @reopenLastUndoGrouping()
        currentGroup = @currentGroup
        if currentGroup
          coalesceOperation = currentGroup[currentGroup.length - 1]
          currentGroup = null
        @endUndoGrouping()
      else
        coalesceOperation = currentGroup[currentGroup.length - 1]

      if coalesceOperation && coalesceOperation.coalesce && coalesceOperation.coalesce(operation)
        return

    @beginUndoGrouping()
    @currentGroup.unshift(operation)
    @endUndoGrouping()

  setActionName: (actionName) ->
    @setUndoGroupMetadata 'actionName', actionName.toLocaleString()

  setUndoGroupMetadata: (key, value) ->
    undoStack = @undoStack
    lastOrCurrentGoup = @currentGroup || undoStack[undoStack.length - 1]
    lastOrCurrentGoup?.metadata[key] = value

  ###
  Section: Undo / Redo
  ###

  canUndo: ->
    !@isUndoing && !@isRedoing && @undoStack.length > 0

  canRedo: ->
    !@isUndoing && !@isRedoing && @redoStack.length > 0

  undo: (context) ->
    assert.ok(@groupingLevel == 0, 'Unclosed grouping')
    assert.ok(@disabledLevel == 0, 'Unclosed disable')

    return unless @canUndo()

    @endUndoGrouping()

    @emitter.emit 'will-undo'
    @isUndoing = true
    @beginUndoGrouping(@undoGroupMetadata())

    @undoStack.pop().forEach (each) ->
      if each.performOperation
        each.performOperation(context)
      else
        each(context)

    @endUndoGrouping()
    @isUndoing = false
    @emitter.emit 'did-undo', @redoGroupMetadata()

  redo: (context) ->
    assert.ok(@groupingLevel == 0, 'Unclosed grouping')
    assert.ok(@disabledLevel == 0, 'Unclosed disable')

    return unless @canRedo()

    @emitter.emit 'will-redo'
    @isRedoing = true
    @beginUndoGrouping(@redoGroupMetadata())

    @redoStack.pop().forEach (each) ->
      if each.performOperation
        each.performOperation(context)
      else
        each(context)

    @endUndoGrouping()
    @isRedoing = false
    @emitter.emit 'did-redo', @undoGroupMetadata()

  undoGroupMetadata: ->
    @undoStack[@undoStack.length - 1]?.metadata

  redoGroupMetadata: ->
    @redoStack[@redoStack.length - 1]?.metadata

  removeAllActions: ->
    assert.ok(@groupingLevel == 0, 'Unclosed grouping')
    assert.ok(@disabledLevel == 0, 'Unclosed disable')
    @undoStack = []
    @redoStack = []

module.exports = UndoManager;