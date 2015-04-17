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
    useStyledTextCaret:
      type: 'boolean'
      default: false
    disableAnimation:
      type: 'boolean'
      default: false

  birchOutlineEditorService: ->
    outlineEditorService

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'birch-outline-editor:new-outline': =>
      atom.workspace.open('birch-outline-editor://new-outline')

    @subscriptions.add atom.workspace.addOpener (filePath) =>
      if filePath is 'birch-outline-editor://new-outline'
        new OutlineEditor
      else
        extension = path.extname(filePath).toLowerCase()
        switch extension
          when '.bml'
            Outline.getOutlineForPath(filePath).then (outline) ->
              new OutlineEditor(outline)

    atom.workspace.getOutlineEditors = outlineEditorService.getOutlineEditors.bind(outlineEditorService)
    atom.workspace.onDidAddOutlineEditor = outlineEditorService.onDidAddOutlineEditor.bind(outlineEditorService)
    atom.workspace.observeOutlineEditors = outlineEditorService.observeOutlineEditors.bind(outlineEditorService)
    atom.workspace.observeActiveOutlineEditor = outlineEditorService.observeActiveOutlineEditor.bind(outlineEditorService)

    require '../packages/durations'
    require '../packages/mentions'
    require '../packages/priorities'
    require '../packages/status'
    require '../packages/tags'

    panelContainerPath = atom.config.resourcePath + '/src/panel-container'
    PanelContainer = require panelContainerPath
    atom.workspace.panelContainers.popover = new PanelContainer({location: 'popover'})
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.panelContainers.popover = atom.views.getView(atom.workspace.panelContainers.popover)
    workspaceElement.appendChild workspaceElement.panelContainers.popover

    atom.workspace.getPopoverPanels = ->
      atom.workspace.getPanels('popover')

    atom.workspace.addPopoverPanel = (options) ->
      panel = atom.workspace.addPanel('popover', options)
      options ?= {}
      panel.target = options.target
      panel.position = options.position or 'top center'
      panel.constrainToWindow = options.constrainToWindow
      panel.constrainToScrollParent = options.constrainToScrollParent
      @schedulePositionPopovers()
      panel

    atom.workspace.schedulePositionPopovers = ->
      unless @scheduledPositionPopovers
        @scheduledPositionPopovers = window.requestAnimationFrame =>
          @positionPopovers()

    atom.workspace.positionPopovers = ->
      @scheduledPositionPopovers = null

      for panel in @getPopoverPanels()
        if panel.isVisible()
          target = panel.target
          position = panel.position.split ' '
          targetPrimary = position[0]
          targetSecondary = position[1]
          constrainToWindow = panel.constrainToWindow
          constrainToScrollParent = panel.constrainToScrollParent

          panelElement = atom.views.getView(panel)
          panelRect = panelElement.getBoundingClientRect()

          targetRect ?= target.getBoundingClientRect?()
          targetRect ?= target?()
          targetRect ?= target

          switch targetPrimary
            when 'top'
              panelTop = targetRect.top - panelRect.height
            when 'bottom'
              panelTop = targetRect.bottom
            when 'left'
              panelLeft = targetRect.left - panelRect.width
            when 'right'
              panelLeft = targetRect.right

          switch targetSecondary
            when 'left'
              panelLeft = targetRect.left
            when 'center'
              panelLeft = targetRect.left + ((panelRect.width - targetRect.width) / 2.0)
            when 'right'
              panelLeft = targetRect.right - panelRect.width
            when 'top'
              panelTop = targetRect.top
            when 'middle'
              panelTop = targetRect.top + ((panelRect.height - targetRect.height) / 2.0)
            when 'bottom'
              panelTop = targetRect.bottom - panelRect.height

          unless panel.cachedTop is panelTop and panel.cachedLeft is panelLeft
            panelElement.style.top = panelTop + 'px'
            panelElement.style.left = panelLeft + 'px'
            position.cachedTop = panelTop
            position.cachedLeft = panelLeft


          ###
          # positioning
          position = panel.position
          target = position.target
          xAnchor = position.xAnchor
          yAnchor = position.yAnchor
          targetXAnchor = position.targetXAnchor
          targetYAnchor = position.targetYAnchor
          cachedPanelRect = position.cachedPanelRect
          cachedTargetRect = position.cachedTargetRect

          # positioning defaults
          xAnchor ?= 0.5
          yAnchor ?= 0.5
          target ?=
            top: 0
            height: window.innerHeight
            bottom: window.innerHeight
            left: 0
            width: window.innerWidth
            right: window.innerWidth
          targetXAnchor ?= 0.5
          targetYAnchor ?= 0.5

          # calculated positioning
          panelElement = atom.views.getView(panel)
          panelRect = panelElement.getBoundingClientRect()

          if targetRect = target?()
            @schedulePositionPopovers()
          else
            targetRect = target

          unless cachedPanelRect and
             cachedPanelRect.top is panelRect.top and
             cachedPanelRect.bottom is panelRect.bottom and
             cachedPanelRect.left is panelRect.left and
             cachedPanelRect.right is panelRect.right and
             cachedTargetRect and
             cachedTargetRect.top is targetRect.top and
             cachedTargetRect.bottom is targetRect.bottom and
             cachedTargetRect.left is targetRect.left and
             cachedTargetRect.right is targetRect.right

            yAnchor *= panelRect.height
            targetYAnchor *= targetRect.height
            top = (targetRect.top - yAnchor) + targetYAnchor

            xAnchor *= panelRect.width
            targetXAnchor *= targetRect.width
            left = (targetRect.left - xAnchor) + targetXAnchor

            # apply positioning
            panelElement.style.top = top + 'px'
            panelElement.style.left = left + 'px'
            position.cachedPanelRect = panelRect
            position.cachedTargetRect = targetRect
            console.log 'boo'
          ###

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
