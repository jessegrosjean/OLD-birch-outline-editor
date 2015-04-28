{Disposable, CompositeDisposable} = require 'atom'
EventRegistery = require '../EventRegistery'
ItemPath = require '../ItemPath'

class SearchFieldElement extends HTMLElement
  query: null

  initialize: ->
    this

  createdCallback: ->
    @classList.add 'block'

    @backButton = document.createElement 'button'
    @backButton.tabIndex = -1
    @backButton.classList.add 'unhoist'
    @backButton.classList.add 'fa'
    @backButton.classList.add 'fa-level-up'
    @backButton.classList.add 'fa-lg'
    @appendChild @backButton

    @findButton = document.createElement 'button'
    @findButton.tabIndex = -1
    @findButton.classList.add 'find'
    @findButton.classList.add 'fa'
    @findButton.classList.add 'fa-search'
    @findButton.classList.add 'fa-lg'
    @appendChild @findButton

    @textFieldElement = document.createElement 'atom-text-editor'
    @textFieldElement.setAttribute 'mini', true
    @textFieldElement.setAttribute 'placeholder-text', 'Search...'

    @textFieldEditor = @textFieldElement.getModel?()
    @textFieldEditor?.setGrammar new ItemPathGrammar(atom.grammars)
    @appendChild @textFieldElement

    @clearButton = document.createElement 'button'
    @clearButton.tabIndex = -1
    @clearButton.classList.add 'cancel'
    @clearButton.classList.add 'fa'
    @clearButton.classList.add 'fa-times'
    @clearButton.classList.add 'fa-lg'
    @appendChild @clearButton

  attachedCallback: ->

  detachedCallback: ->

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

    if editor
      textFieldEditor = @textFieldEditor
      @updateSearchInfo editor.getSearch()

      @filterPathSubscription = new CompositeDisposable(
        @editor.onDidChangeSearch (searchInfo) =>
          @updateSearchInfo searchInfo

        @editor.onDidChangeHoistedItem (item) =>
          if item.isRoot == @classList.contains('hoisted')
            @classList.toggle('hoisted')

        textFieldEditor?.onDidChange =>
          if @textFieldEditor.getText()
            @clearButton.style.display = null
          else
            @clearButton.style.display = 'none'

        textFieldEditor?.onDidStopChanging ->
          newQuery = textFieldEditor.getText()
          oldQuery = editor.getSearch().query
          unless newQuery is oldQuery
            editor.setSearch newQuery
      )

  updateSearchInfo: (searchInfo) ->
    query = searchInfo.query or ''
    if @textFieldEditor
      unless @textFieldEditor.getText() is query
        @textFieldEditor?.setText query

EventRegistery.listen 'outline-editor-search button.unhoist',
  mousedown: (e) ->
    e.preventDefault()
    e.stopPropagation()

  click: (e) ->
    @parentElement.editor.unhoist()

EventRegistery.listen 'outline-editor-search button.find',
  mousedown: (e) ->
    @parentElement.focus()
    e.preventDefault()
    e.stopPropagation()

  click: (e) ->
    # refresh search

EventRegistery.listen 'outline-editor-search button.cancel',
  mousedown: (e) ->
    @parentElement.focus()
    e.preventDefault()
    e.stopPropagation()

  click: (e) ->
    @parentElement.editor.setSearch ''

atom.commands.add 'outline-editor-search',
  'core:cancel': ->
    @editor.setSearch ''
    @editor.outlineEditorElement.focus()

module.exports = document.registerElement 'outline-editor-search', prototype: SearchFieldElement.prototype