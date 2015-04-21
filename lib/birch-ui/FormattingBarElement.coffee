# Copyright (c) 2015 Jesse Grosjean. All rights reserved.
OutlineEditorService = require '../OutlineEditorService'
{Disposable, CompositeDisposable} = require 'atom'

class FormattingBarElement extends HTMLElement
  constructor: ->
    super()

  createdCallback: ->
    @classList.add 'btn-toolbar'

    @formattingButtonGroup = document.createElement 'div'
    @formattingButtonGroup.classList.add 'btn-group'
    @appendChild @formattingButtonGroup

    @boldButton = document.createElement 'button'
    @boldButton.className = 'btn fa fa-bold fa-lg'
    @boldButton.setAttribute 'data-command', 'birch-outline-editor:toggle-bold'
    @formattingButtonGroup.appendChild @boldButton

    @italicButton = document.createElement 'button'
    @italicButton.className = 'btn fa fa-italic fa-lg'
    @italicButton.setAttribute 'data-command', 'birch-outline-editor:toggle-italic'
    @formattingButtonGroup.appendChild @italicButton

    @strikethoughButton = document.createElement 'button'
    @strikethoughButton.className = 'btn fa fa-strikethrough fa-lg'
    @strikethoughButton.setAttribute 'data-command', 'birch-outline-editor:toggle-strikethrough'
    @formattingButtonGroup.appendChild @strikethoughButton

    @linkButton = document.createElement 'button'
    @linkButton.className = 'btn fa fa-link fa-lg'
    @linkButton.setAttribute 'data-command', 'birch-outline-editor:edit-link'
    @formattingButtonGroup.appendChild @linkButton

    @statusButton = document.createElement 'button'
    @statusButton.className = 'btn fa fa-check fa-lg'
    @statusButton.setAttribute 'data-command', 'birch-outline-editor:toggle-status-complete'
    @formattingButtonGroup.appendChild @statusButton

    @tagsButton = document.createElement 'button'
    @tagsButton.className = 'btn fa fa-tags fa-lg'
    @tagsButton.setAttribute 'data-command', 'birch-outline-editor:edit-tags'
    @formattingButtonGroup.appendChild @tagsButton

  attachedCallback: ->
    ###
    @tooltipSubs = new CompositeDisposable
    @tooltipSubs.add atom.tooltips.add @boldButton,
      title: "Bold text",
      keyBindingCommand: 'birch-outline-editor:toggle-bold'
    @tooltipSubs.add atom.tooltips.add @italicButton,
      title: "Italic text",
      keyBindingCommand: 'birch-outline-editor:toggle-italic'
    @tooltipSubs.add atom.tooltips.add @underlineButton,
      title: "Underline text",
      keyBindingCommand: 'birch-outline-editor:toggle-underline'
    @tooltipSubs.add atom.tooltips.add @linkButton,
      title: "Edit Link",
      keyBindingCommand: 'birch-outline-editor:edit-link'
    ###

  detachedCallback: ->
    #@tooltipSubs.dispose()

OutlineEditorService.eventRegistery.listen 'birch-formatting-bar button',
  mousedown: (e) ->
    outlineEditorElement = OutlineEditorService.getActiveOutlineEditor()?.outlineEditorElement
    if outlineEditorElement and command = e.target.getAttribute?('data-command')
      if command is 'birch-outline-editor:edit-link'
        formattingBarPanel.hide()
      atom.commands.dispatch outlineEditorElement, command
      e.stopImmediatePropagation()
      e.stopPropagation()
      e.preventDefault()

formattingBar = document.createElement 'birch-formatting-bar'
formattingBarPanel = atom.workspace.addPopoverPanel
  item: formattingBar
  target: ->
    OutlineEditorService.getActiveOutlineEditor()?.selection?.selectionClientRect
  viewport: ->
    OutlineEditorService.getActiveOutlineEditor()?.outlineEditorElement.getBoundingClientRect()

OutlineEditorService.observeActiveOutlineEditorSelection (selection) ->
  if selection?.isTextMode and not selection.isCollapsed
    formattingBarPanel.show()
  else
    formattingBarPanel.hide()

module.exports = document.registerElement 'birch-formatting-bar', prototype: FormattingBarElement.prototype


###
  editFormatting: ->
    editor = this
    savedSelection = editor.selection
    item = savedSelection.startItem
    offset = savedSelection.startOffsetOffset
    return unless item


    subscription = @onDidChangeSelection ->
      subscription.dispose()
      formattingBarPanel.destroy()
###