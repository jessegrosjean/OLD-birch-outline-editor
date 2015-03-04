{Disposable, CompositeDisposable} = require 'atom'

class QueryFieldElement extends HTMLElement
  query: null

  initialize: ->
    this

  createdCallback: ->
    @textFieldElement = document.createElement 'atom-text-editor'
    @textFieldElement.classList.add 'padding'
    @textFieldElement.setAttribute 'mini', true
    @textFieldElement.setAttribute 'placeholder-text', 'Search...'
    @textFieldEditor = @textFieldElement.getModel?()
    @appendChild @textFieldElement

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->
    if attrName is 'data-query'
      unless @textFieldEditor.getText() is newVal
        @textFieldEditor.setText newVal

module.exports = document.registerElement(
  'outline-editor-query-field',
  prototype: QueryFieldElement.prototype
)