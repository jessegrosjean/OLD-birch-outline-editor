# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

LocationStatusBarItem = require './extensions/location-status-bar-item'
SearchStatusBarItem = require './extensions/search-status-bar-item'
outlineEditorService = require './outline-editor-service'
OutlineEditor = require './editor/outline-editor'
{CompositeDisposable} = require 'atom'
Outline = require './core/outline'
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

    @subscriptions.add atom.commands.add 'atom-workspace', 'birch-outline-editor:new-outline': ->
      atom.workspace.open('birch-outline-editor://new-outline')

    @subscriptions.add atom.workspace.addOpener (filePath) ->
      if filePath is 'birch-outline-editor://new-outline'
        new OutlineEditor
      else
        extension = path.extname(filePath).toLowerCase()
        switch extension
          when '.bml'
            Outline.getOutlineForPath(filePath).then (outline) ->
              new OutlineEditor(outline)

    ###
    require '../packages/durations'
    require '../packages/mentions'
    require '../packages/priorities'
    require '../packages/status'
    require '../packages/tags'
    require './atom-ui/popovers'
    require './atom-ui/EditLink'
    require './atom-ui/TextFormattingPopover'
    ###

    #@initializeGlobalOutlineEditorStyleSheet()
    #@observeTextEditorFontConfig()

  consumeStatusBarService: (statusBar) ->
    disposable = new CompositeDisposable()
    disposable.add LocationStatusBarItem.consumeStatusBarService(statusBar)
    disposable.add SearchStatusBarItem.consumeStatusBarService(statusBar)
    disposable

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