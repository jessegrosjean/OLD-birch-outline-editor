{Disposable, CompositeDisposable} = require 'atom'

class ToolbarElement extends HTMLElement
  initialize: ->
    this

  createdCallback: ->
    @textContent = 'Hello world!'

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

module.exports = document.registerElement 'outline-editor-toolbar',
  prototype: ToolbarElement.prototype