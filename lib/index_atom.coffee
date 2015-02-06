OutlineEditor = require './OutlineEditor'
{CompositeDisposable} = require 'atom'
Outline = require './Outline'
path = require 'path'

module.exports = BirchOutliner =
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.workspace.addOpener (filePath) =>
      extension = path.extname(filePath).toLowerCase()
      switch extension
        when '.outline'
          o = new Outline()
          o.root.appendChild(o.createItem('hello world 1'));
          o.root.appendChild(o.createItem('hello world 2'));
          o.root.appendChild(o.createItem('hello world 3'));
          new OutlineEditor(o)

    @subscriptions.add atom.views.addViewProvider OutlineEditor, (model) ->
      model.outlineEditorElement

  deactivate: ->
    @subscriptions.dispose()
