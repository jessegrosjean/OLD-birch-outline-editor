{Disposable, CompositeDisposable} = require 'atom'

class SearchFieldElement extends HTMLElement
  query: null

  initialize: ->
    this
    @classList.add 'block'

  createdCallback: ->
    @textFieldElement = document.createElement 'atom-text-editor'
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
      @editor?.setSearch newVal

  destroyed: ->
    @editor = null
    @filterPathSubscription?.dispose()

  focus: ->
    @textFieldElement.focus()

  getEditor: ->
    @editor

  setEditor: (editor) ->
    @filterPathSubscription?.dispose()
    @editor = editor
    @filterPathSubscription = @editor?.onDidChangeSearch (path, type) =>
      @setAttribute 'data-query', path

atom.commands.add 'outline-editor-search',
  'core:cancel': ->
    @setAttribute 'data-query', ''
    @editor.outlineEditorElement.focus()

module.exports = document.registerElement(
  'outline-editor-search',
  prototype: SearchFieldElement.prototype
)

