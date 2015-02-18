# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

outlineEditorService = require './OutlineEditorService'
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

  outlineEditorService: ->
    outlineEditorService

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

    atom.workspace.getOutlineEditors = outlineEditorService.getOutlineEditors.bind(outlineEditorService)
    atom.workspace.onDidAddOutlineEditor = outlineEditorService.onDidAddOutlineEditor.bind(outlineEditorService)
    atom.workspace.observeOutlineEditors = outlineEditorService.observeOutlineEditors.bind(outlineEditorService)

  deactivate: ->
    @subscriptions.dispose()
