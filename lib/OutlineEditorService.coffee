{Disposable, CompositeDisposable} = require 'atom'
OutlineLiveQuery = require './liveQueries/OutlineLiveQuery'
WorkspaceLiveQuery = require './liveQueries/WorkspaceLiveQuery'
OutlineEditor = require './OutlineEditor'
Outline = require './Outline'
Item = require './Item'

# Essential: This is the Atom [services
# API](https://atom.io/docs/latest/creating-a-package#interacting-with-other-
# packages-via-services) object vended for `outline-editor-service`. Please
# see the [Package Tutorial](Package%20Tutorial) to learn how to build a
# package that uses this service.
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

  # Essential: Get all outline editors in the workspace.
  #
  # Returns an {Array} of {OutlineEditor}s.
  @getOutlineEditors: ->
    atom.workspace.getPaneItems().filter (item) -> item instanceof OutlineEditor

  # Essential: Get all outline editors for a given outine the workspace.
  #
  # - `outline` The {Outline} to search for.
  #
  # Returns an {Array} of {OutlineEditor}s.
  @getOutlineEditorsForOutline: (outline) ->
    atom.workspace.getPaneItems().filter (item) ->
      item instanceof OutlineEditor and item.outline is outline

  # Extended: Invoke the given callback when an outline editor is added to the
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

  # Essential: Invoke the given callback with all current and future outline
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

module.exports = OutlineEditorService