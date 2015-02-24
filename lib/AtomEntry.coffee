# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

outlineEditorService = require './OutlineEditorService'
OutlineEditor = require './OutlineEditor'
{CompositeDisposable} = require 'atom'
Outline = require './Outline'
path = require 'path'

# Do this early because serlialization happens before package activation
atom.views.addViewProvider OutlineEditor, (model) ->
  model.outlineEditorElement

module.exports = BirchOutlineEditor =
  globalOutlineEditorStyleSheet: null
  subscriptions: null

  config:
    disableAnimation:
      type: 'boolean'
      default: false

  birchOutlineEditorService: ->
    outlineEditorService

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'birch-outline-editor:new-outline': =>
      atom.workspace.open('outline-editor://new-outline')

    @subscriptions.add atom.workspace.addOpener (filePath) =>
      if filePath is 'outline-editor://new-outline'
        new OutlineEditor
      else
        extension = path.extname(filePath).toLowerCase()
        switch extension
          when '.oeml'
            o = new Outline({
              filePath: filePath,
              load: true
            })
            new OutlineEditor(o)

    atom.workspace.getOutlineEditors = outlineEditorService.getOutlineEditors.bind(outlineEditorService)
    atom.workspace.onDidAddOutlineEditor = outlineEditorService.onDidAddOutlineEditor.bind(outlineEditorService)
    atom.workspace.observeOutlineEditors = outlineEditorService.observeOutlineEditors.bind(outlineEditorService)

    #@initializeGlobalOutlineEditorStyleSheet()
    #@observeTextEditorFontConfig()

  ###
  initializeGlobalOutlineEditorStyleSheet: ->
    atom.styles.addStyleSheet('outline-editor {}', sourcePath: 'global-outline-editor-styles')
    @globalOutlineEditorStyleSheet = document.head.querySelector('style[source-path="global-outline-editor-styles"]').sheet

  observeTextEditorFontConfig: ->
    @subscriptions.add atom.config.observe 'editor.fontSize', @setOutlineEditorFontSize.bind(this)
    @subscriptions.add atom.config.observe 'editor.fontFamily', @setOutlineEditorFontFamily.bind(this)
    @subscriptions.add atom.config.observe 'editor.lineHeight', @setOutlineEditorLineHeight.bind(this)

  setOutlineEditorFontSize: (fontSize) ->
    @updateGlobalOutlineEditorStyle('font-size', fontSize + 'px')

  setOutlineEditorFontFamily: (fontFamily) ->
    @updateGlobalOutlineEditorStyle('font-family', fontFamily)

  setOutlineEditorLineHeight: (lineHeight) ->
    @updateGlobalOutlineEditorStyle('line-height', lineHeight)

  updateGlobalOutlineEditorStyle: (property, value) ->
    debugger
    editorRule = @globalOutlineEditorStyleSheet.cssRules[0]
    editorRule.style[property] = value
  ###

  deactivate: ->
    @subscriptions.dispose()
