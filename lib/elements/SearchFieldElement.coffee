{Disposable, CompositeDisposable} = require 'atom'
ItemPath = require '../ItemPath'

Grammar = null
if atom.inBrowserMode
  Grammar = {}
else
  # construct path on separate line for endokken
  grammarPath = atom.config.resourcePath + '/node_modules/first-mate/lib/grammar'
  Grammar = require grammarPath

class ItemPathGrammar extends Grammar
  constructor: (registry) ->
    super registry,
      name: 'ItemPath'
      scopeName: "source.itempath"

  tokenizeLine: (line, ruleStack, firstLine=false) ->
    tokens = []
    location = 0
    parsed = ItemPath.parse(line)

    if parsed.error
      offset = parsed.error.offset
      location = line.length
      tokens.push @createToken(line.substring(0, offset), ['source.itempath', 'invalid.illegal'])
      tokens.push @createToken(line.substring(offset, line.length), ['source.itempath', 'invalid.illegal.error'])
    else
      for each in parsed.keywords
        if each.offset > location
          tokens.push @createToken(line.substring(location, each.offset), ['source.itempath', 'none'])
        tokens.push @createToken(each.text, ['source.itempath', each.label or 'none'])
        location = each.offset + each.text.length

    if location < line.length
      tokens.push @createToken(line.substring(location, line.length), ['source.itempath', 'none'])

    {} =
      tokens: tokens
      ruleStack: []

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
    @textFieldEditor?.setGrammar new ItemPathGrammar(atom.grammars)
    @appendChild @textFieldElement

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

atom.commands.add 'outline-editor-search',
  'core:cancel': ->
    @editor.setSearch ''
    @editor.outlineEditorElement.focus()

module.exports = document.registerElement(
  'outline-editor-search',
  prototype: SearchFieldElement.prototype
)

