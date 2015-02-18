# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

OutlineEditor = require './OutlineEditor'
{CompositeDisposable} = require 'atom'
Outline = require './Outline'
path = require 'path'

# Do this early because serlialization happens before package activation
atom.views.addViewProvider OutlineEditor, (model) ->
  model.outlineEditorElement

module.exports = BirchOutliner =
  subscriptions: null

  config:
    disableAnimation:
      type: 'boolean'
      default: true

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'birch-outliner:new-outline': =>
      atom.workspace.open('outline-editor://new-outline')

    @subscriptions.add atom.workspace.addOpener (filePath) =>
      if filePath is 'outline-editor://new-outline'
        new OutlineEditor
      else
        extension = path.extname(filePath).toLowerCase()
        switch extension
          when '.ftml'
            o = new Outline({
              filePath: filePath,
              load: true
            })
            new OutlineEditor(o)

    # Essential: Get all outline editors in the workspace.
    #
    # Returns an {Array} of {OutlineEditor}s.
    atom.workspace.getOutlineEditors = ->
      @getPaneItems().filter (item) -> item instanceof OutlineEditor

    # Extended: Invoke the given callback when an outline editor is added to the
    # workspace.
    #
    # * `callback` {Function} to be called panes are added.
    #   * `event` {Object} with the following keys:
    #     * `outlineEditor` {OutlineEditor} that was added.
    #     * `pane` {Pane} containing the added outline editor.
    #     * `index` {Number} indicating the index of the added outline editor in its
    #        pane.
    #
    # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
    atom.workspace.onDidAddOutlineEditor = (callback) ->
      @onDidAddPaneItem ({item, pane, index}) ->
        callback({outlineEditor: item, pane, index}) if item instanceof OutlineEditor

    # Essential: Invoke the given callback with all current and future outline
    # editors in the workspace.
    #
    # * `callback` {Function} to be called with current and future outline editors.
    #   * `editor` An {OutlineEditor} that is present in {::getOutlineEditors} at the time
    #     of subscription or that is added at some later time.
    #
    # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
    atom.workspace.observeOutlineEditors = (callback) ->
      callback(outlineEditor) for outlineEditor in @getOutlineEditors()
      @onDidAddOutlineEditor ({outlineEditor}) -> callback(outlineEditor)

  deactivate: ->
    @subscriptions.dispose()