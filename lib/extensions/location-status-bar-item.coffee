# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

foldingTextService = require '../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'

exports.consumeStatusBarService = (statusBar) ->
  hoistElement = document.createElement 'a'
  hoistElement.className = 'ft-location-status-bar-item icon-location inline-block'
  hoistElement.addEventListener 'click', (e) ->
    editor = foldingTextService.getActiveOutlineEditor()
    savedSelection = editor.selection
    return unless editor

    listInput = document.createElement 'ft-list-input'
    listInput.setText editor.getSearch().query

    listInput.setDelegate
      elementForListItem: (item) ->
        li = document.createElement 'li'
        span = document.createElement 'span'
        span.textContent = item.bodyText
        li.appendChild span
        li

      mouseClickListItem: (e) ->

      didSelectListItem: (item) ->

      restoreFocus: ->
        editor.focus()
        editor.moveSelectionRange savedSelection

      cancelled: ->
        listInputPanel.destroy()

      confirm: ->
        listInputPanel.destroy()
        @restoreFocus()

    listInput.setItems editor.outline.evaluateItemPath '//*/parent::*'
    listInputPanel = atom.workspace.addPopoverPanel
      className: 'ft-text-input-panel'
      item: listInput
      target: e.target

    listInput.focusTextEditor()

  locationStatusBarItem = statusBar.addLeftTile(item: hoistElement, priority: 0)

  activeOutlineEditorSubscriptions = null
  activeOutlineEditorSubscription = foldingTextService.observeActiveOutlineEditor (outlineEditor) ->
    activeOutlineEditorSubscriptions?.dispose()
    if outlineEditor
      update = ->
        hoistedItem = outlineEditor.getHoistedItem()
        hoistElement.classList.toggle 'active', not hoistedItem.isRoot

      hoistElement.style.display = null
      activeOutlineEditorSubscriptions = new CompositeDisposable()
      activeOutlineEditorSubscriptions.add outlineEditor.onDidChangeSearch -> update()
      activeOutlineEditorSubscriptions.add outlineEditor.onDidChangeHoistedItem -> update()
      update()
    else
      hoistElement.style.display = 'none'

  new Disposable ->
    activeOutlineEditorSubscription.dispose()
    activeOutlineEditorSubscriptions?.dispose()
    locationStatusBarItem.destroy()