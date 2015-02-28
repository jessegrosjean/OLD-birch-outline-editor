# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Emitter, Disposable, CompositeDisposable} = require 'atom'

# Make this more generic... add modes for editing node path search link. Link to another node, etc.
class InputElement extends HTMLElement

  createdCallback: ->
    @emitter = new Emitter

    block1 = document.createElement 'div'
    block1.classList.add 'block'
    @appendChild block1

    @label = document.createElement 'label'
    @label.classList.add 'setting-title'
    block1.appendChild @label

    @miniEditor = document.createElement 'atom-text-editor'
    @miniEditor.classList.add 'padding'
    @miniEditor.setAttribute 'mini', true
    block1.appendChild @miniEditor

    block2 = document.createElement 'div'
    block2.classList.add 'block'
    @appendChild block2

    @validationLabel = document.createElement 'label'
    @validationLabel.classList.add 'text-warning'
    block2.appendChild @validationLabel

    block3 = document.createElement 'div'
    block3.classList.add 'block'
    block3.classList.add 'buttonRow'
    @appendChild block3

    cancelButton = document.createElement 'button'
    cancelButton.textContent = 'Cancel'
    cancelButton.classList.add 'btn'
    cancelButton.classList.add 'inline-block'
    cancelButton.addEventListener 'click', =>
      setTimeout =>
        @emitter.emit 'did-cancel'
    block3.appendChild cancelButton

    okButton = document.createElement 'button'
    okButton.textContent = 'OK'
    okButton.classList.add 'btn'
    okButton.classList.add 'btn-primary'
    okButton.classList.add 'inline-block'
    okButton.addEventListener 'click', =>
      setTimeout =>
        @emitter.emit 'did-confirm'
    block3.appendChild okButton

    @miniEditor.getModel().onDidChange (e) =>
      editor = @miniEditor.getModel()
      newVal = editor.getText()
      if newVal != @getAttribute 'text'
        @setAttribute 'text', editor.getText()
      @_validate()

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->
    if attrName is 'label'
      @label.textContent = newVal
    if attrName is 'text'
      editor = @miniEditor.getModel()
      if newVal != editor.getText()
        editor.setText(newVal)

  focus: -> @miniEditor.focus()

  setValidator: (validator) ->
    @validator = validator
    @_validate()

  _validate: ->
    errorMessage = @validator?(@miniEditor.getModel().getText()) or 'PLACEHOLDER'
    if errorMessage is 'PLACEHOLDER'
      @validationLabel.style.visibility = 'hidden'
    else
      @validationLabel.style.visibility = null
    @validationLabel.textContent = errorMessage

  onConfirm: (callback) ->
    @emitter.on 'did-confirm', callback

  onCancel: (callback) ->
    @emitter.on 'did-cancel', callback

  confirm: ->
    @emitter.emit 'did-confirm'

  cancel: ->
    @emitter.emit 'did-cancel'

atom.commands.add 'birch-link-editor',
  'core:confirm': -> @confirm()
  'core:cancel': -> @cancel()

module.exports = document.registerElement 'birch-link-editor', prototype: InputElement.prototype