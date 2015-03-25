{Disposable, CompositeDisposable} = require 'atom'

class SearchFieldElement extends HTMLElement
  query: null

  initialize: ->
    this

  createdCallback: ->
    @textFieldElement = document.createElement 'atom-text-editor'
    @textFieldElement.classList.add 'padding'
    @textFieldElement.setAttribute 'mini', true
    @textFieldElement.setAttribute 'placeholder-text', 'Search...'
    @textFieldEditor = @textFieldElement.getModel?()
    @textFieldEditor?.onDidStopChanging =>
      @setAttribute 'data-query', @textFieldEditor.getText()
    @appendChild @textFieldElement

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->
    if attrName is 'data-query'
      unless @textFieldEditor?.getText() is newVal
        @textFieldEditor?.setText newVal
      @editor?.setSearch "//*[text()[contains(.,'#{newVal}')]]"

  destroyed: ->
    @filterPathSubscription?.dispose()

  getEditor: ->
    @editor

  setEditor: (editor) ->
    @filterPathSubscription?.dispose()
    @editor = editor
    @filterPathSubscription = @editor?.onDidChangeFilterPath (filterPath) =>
      filterPath = filterPath.match(/\.,'(.*)'/)?[1]
      @setAttribute 'data-query', filterPath

module.exports = document.registerElement(
  'outline-editor-search',
  prototype: SearchFieldElement.prototype
)