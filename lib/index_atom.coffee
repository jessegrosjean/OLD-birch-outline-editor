OutlineEditor = require './OutlineEditor'
{CompositeDisposable} = require 'atom'
Outline = require './Outline'
path = require 'path'

# Do this early because serlialization happens before package activation
atom.views.addViewProvider OutlineEditor, (model) ->
  model.outlineEditorElement

module.exports = BirchOutliner =
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.workspace.addOpener (filePath) =>
      extension = path.extname(filePath).toLowerCase()
      switch extension
        when '.outline'
          o = new Outline({
            filePath: filePath,
            load: true
          })
          new OutlineEditor(o)

  deactivate: ->
    @subscriptions.dispose()