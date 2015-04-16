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
      @cancel(e) unless @cancelling

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  ###
  Section: Messages to the user
  ###

  getPlaceholderText: ->
    @textEditor.getPlaceholderText()

  setPlaceholderText: (placeholderText) ->
    @textEditor.setPlaceholderText placeholderText

  setMessage: (message='') ->
    @message.innerHTML = ''
    if message.length is 0
      @message.style.display = 'none'
    else
      @message.textContent = message
      @message.style.display = null

  setHTMLMessage: (htmlMessage='') ->
    @message.innerHTML = ''
    if htmlMessage.length is 0
      @message.style.display = 'none'
    else
      @message.innerHTML = htmlMessage
      @message.style.display = null

  showDefaultMessage: ->
    @setHTMLMessage 'Press <kbd>Enter</kbd> to accept or <kbd>Escape</kbd> to cancel.'

  ###
  Section: Accessory Elements
  ###

  addAccessoryElement: (element) ->
    accessoryPanel = document.createElement 'atom-panel'
    accessoryPanel.appendChild element
    @insertBefore accessoryPanel, @textEditorElement.nextSibling

  removeAccesoryElement: (element) ->
    @removeChild element.parentElement

  ###
  Section: Text
  ###

  getText: ->
    @textEditor.getText()

  setText: (text) ->
    @textEditor.setText text or ''

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
  Section: Element Actions
  ###

  focusTextEditor: ->
    @textEditorElement.focus()

  cancel: (e) ->
    unless @cancelling
      if @delegate?.shouldCancel?
        unless @delegate.shouldCancel()
          e?.stopPropagation()
          return

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