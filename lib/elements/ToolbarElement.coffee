{Disposable, CompositeDisposable} = require 'atom'

class ToolbarElement extends HTMLElement
  initialize: ->
    this

  createdCallback: ->

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  getEditor: ->
    @editor

  setEditor: (editor) ->
    @activePaneObserver?.dispose()
    @editor = editor
    if editor
      @activePaneObserver = atom.workspace.observeActivePaneItem? (item) =>
        @updateToolbar()
    else
      @updateToolbar()

  updateToolbar: ->
    unless @editor
      @parentElement?.removeChild this
    else
      pane = atom.workspace.paneForItem? @editor
      if pane?.getActiveItem() is @editor
        paneElement = atom.views.getView pane
        paneElement.insertBefore this, paneElement.lastChild
      else
        @parentElement?.removeChild this

  destroyed: ->
    @setEditor null

atom.commands.add 'outline-editor-toolbar',
  'find-and-replace:show': (e) ->
    e.preventDefault()
    e.stopPropagation()
  'find-and-replace:show-replace': (e) ->
    e.preventDefault()
    e.stopPropagation()

module.exports = document.registerElement 'outline-editor-toolbar', prototype: ToolbarElement.prototype