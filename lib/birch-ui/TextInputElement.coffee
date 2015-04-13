OutlineEditorService = require '../OutlineEditorService'
{Disposable, CompositeDisposable} = require 'atom'

fuzzyFilter = null # defer until used

class TextInputElement extends HTMLElement

  textEditor: null
  cancelling: false
  delegate: null

  createdCallback: ->

    @textEditorElement = document.createElement 'atom-text-editor'
    @textEditorElement.setAttribute 'mini', true
    @textEditor = @textEditorElement.getModel()
    @appendChild @textEditorElement

    @message = document.createElement 'div'
    @appendChild @message

    @textEditor.onDidChangeSelectionRange (e) =>
      @delegate?.didChangeSelectionRange?(e)

    @textEditor.onDidChangeSelectionRange (e) =>
      @delegate?.didChangeSelectionRange?(e)

    @textEditor.onWillInsertText (e) =>
      @delegate?.willInsertText?(e)

    @textEditor.onDidInsertText (e) =>
      @delegate?.didInsertText?(e)

    @textEditor.onDidChange (e) =>
      @delegate?.didChangeText?(e)

    @textEditorElement.addEventListener 'blur', (e) =>
      #@cancel() unless @cancelling

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  ###
  Section: Text
  ###

  getText: ->
    @textEditor.getText()

  setText: (text) ->
    @textEditor.setText text

  isCursorAtStart: ->
    range = @textEditor.getSelectedBufferRange()
    range.isEmpty() and range.containsPoint([0, 0])

  ###
  Section: Delegate
  ###

  getDelegate: ->
    @delegate

  setDelegate: (@delegate) ->

  ###
  Section: Accessory Elements
  ###

  addAccessoryElement: (element) ->
    accessoryPanel = document.createElement 'atom-panel'
    accessoryPanel.appendChild element
    @insertBefore accessoryPanel, @textEditorElement

  removeAccesoryElement: (element) ->
    @removeChild element.parentElement

  ###
  Section: Messages to the user
  ###

  setMessage: (message='') ->
    if message.length is 0
      @message.textContent = ''
      @message.style.display = 'none'
    else
      @message.textContent = message
      @message.style.display = null

  ###
  Section: Element Actions
  ###

  focusTextEditor: ->
    @textEditorElement.focus()

  cancel: ->
    @cancelling = true
    textEditorElementFocused = @textEditorElement.hasFocus()
    @delegate?.cancelled?() unless @confirming
    @textEditor.setText('')
    @delegate?.restoreFocus?() if textEditorElementFocused
    @cancelling = false

  confirm: ->
    @confirming = true
    @delegate?.confirm?()
    @confirming = false

atom.commands.add 'birch-text-input > atom-text-editor[mini]',
  'core:confirm': (e) -> @parentElement.confirm(e)
  'core:cancel': (e) -> @parentElement.cancel(e)

module.exports = document.registerElement 'birch-text-input', prototype: TextInputElement.prototype