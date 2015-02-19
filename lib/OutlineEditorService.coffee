{Disposable, CompositeDisposable} = require 'atom'
OutlineLiveQuery = require './liveQueries/OutlineLiveQuery'
WorkspaceLiveQuery = require './liveQueries/WorkspaceLiveQuery'
OutlineEditor = require './OutlineEditor'
Outline = require './Outline'
Item = require './Item'

# Essential: This is the service object provided by the `outline-editor-
# service`.
#
# Atom allows packages to interact with each other through a [services
# API](https://atom.io/docs/latest/creating-a-package#interacting-with-other-
# packages-via-services). If you want to write a package that enhances the
# outline editor your package should subscribe to the `outline-editor-service`
# as show below. It will then have access a OutlineEditorService instance.
#
# ## Subscribe to the Outline Editor Service
#
# Subscribe in your packages `package.json`:
#
# ```json
# "consumedServices": {
#   "outine-editor-service": {
#     "versions": {
#       "^1.0.0": "consumeOutlineEditorService"
#     }
#   }
# }
# ```
#
# Implement the service's callback in your main module:
#
# ```coffeescript
# consumeOutlineEditorService: (outlineEditorService) ->
#   @outlineEditorService = outlineEditorService
#   new Disposable =>
#     @outlineEditorService = null
# ```
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

  # Public: {OutlineLiveQuery} Class
  @OutlineLiveQuery: OutlineLiveQuery

  # Public: {WorkspaceLiveQuery} Class
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

  ###

  # Public: Live XPath query all {Outlines}.
  #
  # Items are considered to match if they, or if a node contained in their
  # body text matches the XPath.
  #
  # - `xpathExpression` {String} xpath expression
  # - `namespaceResolver` (optional) {String}
  # - `callback` {Function}
  @scheduleLiveQuery: (xpathExpression, namespaceResolver, callback) ->
    if @liveQueries.length == 0
      @_beginObservingOutlinesForLiveQueries()

    liveQuery =
      xpathExpression: xpathExpression
      namespaceResolver: namespaceResolver
      callback: callback

    new Disposable =>
      @liveQueries.splice(@liveQueries.indexOf(liveQuery), 1)
      if @liveQueries.length == 0
        @_endObservingOutlinesForLiveQueries()

  @liveQueries: []
  @liveQueryOutlines: []
  @liveQueryOutlinesSubscription: null

  @_beginObservingOutlinesForLiveQueries: ->
    @liveQueryOutlinesSubscription = new CompositeDisposable
    @liveQueryOutlinesSubscription.add @observeOutlineEditors (editor) =>
      @_observeOutline editor.outline
    @scheduleRunLiveQuery()

  @_endObservingOutlinesForLiveQueries: ->
    @liveQueryOutlinesSubscription.dispose()
    @liveQueryOutlinesSubscription = null
    @liveQueryOutlines = []

  @_observeOutline: (outline) ->
    unless outline in @liveQueryOutlines
      changedSubscription = outline.onDidChange (e) =>
        @scheduleRunLiveQuery()

      changedPathSubscription = outline.onDidChangePath (path) =>
        @scheduleRunLiveQuery()

      destroyedSubscription = outline.onDidDestroy =>
        changedSubscription.dispose()
        destroyedSubscription.dispose()
        @liveQueryOutlines.splice(@liveQueryOutlines.indexOf(outline), 1)
        @scheduleRunLiveQuery()

      @liveQueryOutlinesSubscription.add changedSubscription
      @liveQueryOutlinesSubscription.add changedPathSubscription
      @liveQueryOutlinesSubscription.add destroyedSubscription
      @liveQueryOutlines.push outline
      @scheduleRunLiveQuery()

  @_runLiveQueries: ->
    for eachQuery in @liveQueries
      queryResults = []
      for eachOutline in @liveQueryOutlines
        queryResults.push
          outline: eachOutline
          matchingItems: eachOutline.itemsForXPath(
            eachQuery.xpathExpression,
            eachQuery.namespaceResolver
          )
      eachQuery.callback(queryResults)
  ###

module.exports = OutlineEditorService