{Disposable, CompositeDisposable} = require 'atom'

class QueryFieldElement extends HTMLElement
  initialize: ->
    this

  createdCallback: ->
    @textContent = 'Hello world!'

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

module.exports = document.registerElement 'outline-editor-toolbar',
  prototype: QueryFieldElement.prototype