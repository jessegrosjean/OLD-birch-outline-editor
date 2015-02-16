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

    @subscriptions.add atom.workspace.addOpener (filePath) =>
      extension = path.extname(filePath).toLowerCase()
      switch extension
        when '.ftml'
          o = new Outline({
            filePath: filePath,
            load: true
          })
          new OutlineEditor(o)

  deactivate: ->
    @subscriptions.dispose()