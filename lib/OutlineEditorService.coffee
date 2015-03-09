{Disposable, CompositeDisposable} = require 'atom'
OutlineLiveQuery = require './liveQueries/OutlineLiveQuery'
WorkspaceLiveQuery = require './liveQueries/WorkspaceLiveQuery'
OutlineEditor = require './OutlineEditor'
Outline = require './Outline'
Item = require './Item'

# Public: This is the Atom [services
# API](https://atom.io/docs/latest/creating-a-package#interacting-with-other-
# packages-via-services) object vended for `birch-outline-editor-service`.
# Please see the [Customizing Birch](README#customizing-birch) to get started
# in creating a package that uses this service.
class OutlineEditorService

  ###
  Section: Classes
  ###

  # Public: {Item} Class
  @Item: Item

  # Public: {Outline} Class
  @Outline: Outline

  # Public: {OutlineEditor} Class
  @OutlineEditor: OutlineEditor

  # Private: {OutlineLiveQuery} Class
  @OutlineLiveQuery: OutlineLiveQuery

  # Private: {WorkspaceLiveQuery} Class
  @WorkspaceLiveQuery: WorkspaceLiveQuery

  ###
  Section: Workspace Outline Editors
  ###

  # Public: Get all outline editors in the workspace.
  #
  # Returns an {Array} of {OutlineEditor}s.
  @getOutlineEditors: ->
    atom.workspace.getPaneItems().filter (item) -> item instanceof OutlineEditor

  # Public: Get the active item if it is an {OutlineEditor}.
  #
  # Returns an {OutlineEditor} or `undefined` if the current active item is
  # not an {OutlineEditor}.
  @getActiveOutlineEditor: ->
    activeItem = atom.workspace.getActivePaneItem()
    activeItem if activeItem instanceof OutlineEditor

  # Public: Get all outline editors for a given outine the workspace.
  #
  # - `outline` The {Outline} to search for.
  #
  # Returns an {Array} of {OutlineEditor}s.
  @getOutlineEditorsForOutline: (outline) ->
    atom.workspace.getPaneItems().filter (item) ->
      item instanceof OutlineEditor and item.outline is outline

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when an outline editor is added to the
  # workspace.
  #
  # * `callback` {Function} to be called panes are added.
  #   * `event` {Object} with the following keys:
  #     * `outlineEditor` {OutlineEditor} that was added.
  #     * `pane` {Pane} containing the added outline editor.
  #     * `index` {Number} indicating the index of the added outline editor
  #       in its pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  @onDidAddOutlineEditor: (callback) ->
    atom.workspace.onDidAddPaneItem ({item, pane, index}) ->
      if item instanceof OutlineEditor
        callback({outlineEditor: item, pane, index})

  # Public: Invoke the given callback with all current and future outline
  # editors in the workspace.
  #
  # * `callback` {Function} to be called with current and future outline
  #    editors.
  #   * `editor` An {OutlineEditor} that is present in {::getOutlineEditors}
  #      at the time of subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  @observeOutlineEditors: (callback) ->
    callback(outlineEditor) for outlineEditor in @getOutlineEditors()
    @onDidAddOutlineEditor ({outlineEditor}) -> callback(outlineEditor)

  # Public: Invoke the given callback when the active {OutlineEditor} changes.
  #
  # * `callback` {Function} to be called when the active {OutlineEditor} changes.
  #   * `outlineEditor` The active OutlineEditor.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  @onDidChangeActiveOutlineEditor: (callback) ->
    atom.workspace.onDidChangeActivePaneItem (item) ->
      if item instanceof OutlineEditor
        callback item
      else
        callback null

  # Public: Invoke the given callback with the current {OutlineEditor} and
  # with all future active outline editors in the workspace.
  #
  # * `callback` {Function} to be called when the {OutlineEditor} changes.
  #   * `outlineEditor` The current active {OultineEditor}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  @observeActiveOutlineEditor: (callback) ->
    atom.workspace.observeActivePaneItem (item) ->
      if item instanceof OutlineEditor
        callback item
      else
        callback null

  # Public: Invoke the given callback when the active {OutlineEditor}
  # {Selection} changes.
  #
  # * `callback` {Function} to be called when the active {OutlineEditor} {Selection} changes.
  #   * `selection` The active {OutlineEditor} {Selection}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  @onDidChangeActiveOutlineEditorSelection: (callback) ->
    selectionSubscription = null
    activeEditorSubscription = @onDidChangeActiveOutlineEditor (outlineEditor) ->
      selectionSubscription?.dispose()
      selectionSubscription = outlineEditor?.onDidChangeSelection callback
      callback outlineEditor?.selection or null

    new Disposable ->
      selectionSubscription?.dispose()
      activeEditorSubscription.dispose()

  # Public: Invoke the given callback with the active {OutlineEditor} {Selection} and
  # with all future active outline editor selections in the workspace.
  #
  # * `callback` {Function} to be called when the {OutlineEditor} {Selection} changes.
  #   * `selection` The current active {OultineEditor} {Selection}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  @observeActiveOutlineEditorSelection: (callback) ->
    callback @getActiveOutlineEditor()?.selection
    @onDidChangeActiveOutlineEditorSelection callback

module.exports = OutlineEditorService