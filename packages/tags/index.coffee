TokenInputElement = require '../../lib/birch-ui/TokenInputElement'
ListInputElement = require '../../lib/birch-ui/ListInputElement'
OutlineEditorService = require '../../lib/OutlineEditorService'
{CompositeDisposable} = require 'atom'

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if tags = item.getAttribute 'data-tags', true
      for each in tags
        each = each.trim()
        a = document.createElement 'A'
        a.className = 'btag'
        a.setAttribute 'data-tag', each
        a.textContent = each
        addBadgeElement a

OutlineEditorService.eventRegistery.listen '.btag',
  click: (e) ->
    tag = e.target.textContent
    outlineEditor = OutlineEditorService.OutlineEditor.findOutlineEditor e.target
    outlineEditor.setSearch "##{tag}"
    e.stopPropagation()
    e.preventDefault()

editTags = (editor) ->
  savedSelection = editor.selection
  selectedItems = savedSelection.items
  item = savedSelection.focusItem
  return unless selectedItems.length > 0

  outlineTagsMap = {}
  for eachItem in editor.outline.evaluateItemPath('#')
    for eachTag in eachItem.getAttribute('data-tags', true) or []
      outlineTagsMap[eachTag] = true

  selectedTagsMap = {}
  for eachItem in selectedItems
    for eachTag in eachItem.getAttribute('data-tags', true) or []
      selectedTagsMap[eachTag] = true

  listSelectionMessage = 'Press <kbd>Space</kbd> to toggle selected tag.'

  addedTokens = {}
  deletedTokens = {}
  listInput = document.createElement 'birch-list-input'
  tokenInput = document.createElement 'birch-token-input'
  listInput.setAllowMarkActive true
  listInput.setTextInputElement tokenInput
  tokenInput.tokenizeText(Object.keys(selectedTagsMap).join(','))
  tokenInput.showDefaultMessage()

  listInput.setDelegate
    didChangeSelectionRange: (e) ->
      listInput.setSelectedItem null

    willInsertText: (e) ->
      text = e.text
      if (text is ' ' or text is ',') and listInput.getSelectedItem()
        e.cancel()
        tokenInput.toggleToken listInput.getSelectedItem()
        tokenInput.setText('')

    didInsertText: (e) ->
      listInput.setSelectedItem null

    didAddToken: (token) ->
      outlineTagsMap[token] = true
      addedTokens[token] = true
      delete deletedTokens[token]
      listInput.setItems Object.keys(outlineTagsMap).sort()

    didSelectToken: (token) ->
      if token
        listInput.setSelectedItem null

    didDeleteToken: (token) ->
      delete addedTokens[token]
      deletedTokens[token] = true
      listInput.setItems Object.keys(outlineTagsMap).sort()

    elementForListItem: (item) ->
      li = document.createElement 'li'
      if tokenInput.hasToken item
        li.classList.add 'active'
      span = document.createElement 'span'
      span.textContent = item
      li.appendChild span
      li

    mouseClickListItem: (e) ->
      tokenInput.toggleToken listInput.getSelectedItem()
      listInput.setSelectedItem null
      tokenInput.setText('')

    didSelectListItem: (item) ->
      if item
        tokenInput.setSelectedToken null
        tokenInput.setHTMLMessage listSelectionMessage
      else
        tokenInput.showDefaultMessage()

    shouldCancel: ->
      if listItem = listInput.getSelectedItem()
        listInput.setSelectedItem null
        tokenInput.setText('')
        false
      else
        true

    cancelled: ->
      listInputPanel.destroy()

    confirm: ->
      listItem = listInput.getSelectedItem()
      text = tokenInput.getText()

      if listItem
        listInput.setSelectedItem null
        tokenInput.setText('')
      else if text
        tokenInput.tokenizeText()
      else
        if selectedItems.length is 1
          selectedItems[0].setAttribute('data-tags', tokenInput.getTokens())
        else if selectedItems.length > 1
          editor.outline.beginUpdates()
          for each in selectedItems
            eachTags = each.getAttribute('data-tags', true) or []
            changed = false
            for eachDeleted of deletedTokens
              if eachDeleted in eachTags
                eachTags.splice(eachTags.indexOf(eachDeleted), 1)
                changed = true
            for eachAdded of addedTokens
              unless eachAdded in eachTags
                eachTags.push eachAdded
                changed = true
            if changed
              each.setAttribute('data-tags', eachTags)

          editor.outline.endUpdates()

        listInputPanel.destroy()
        @restoreFocus()

    restoreFocus: ->
      editor.focus()
      editor.moveSelectionRange savedSelection

  listInput.setItems Object.keys(outlineTagsMap).sort()
  listInputPanel = atom.workspace.addModalPanel
    item: listInput
    visible: true
  listInput.focusTextEditor()

clearTags = (editor) ->
  outline = editor.outline
  undoManager = outline.undoManager
  selectedItems = editor.selection.items

  if selectedItems.length
    outline.beginUpdates()
    undoManager.beginUndoGrouping()
    for each in selectedItems
      each.removeAttribute 'data-tags'
    outline.endUpdates()
    undoManager.endUndoGrouping()

atom.commands.add 'birch-outline-editor',
  'birch-outline-editor:edit-tags': -> editTags @editor
  'birch-outline-editor:clear-tags': -> clearTags @editor

atom.commands.add 'birch-outline-editor .btag',
  'birch-outline-editor:delete-tag': (e) ->
    tag = @textContent
    editor = OutlineEditorService.OutlineEditor.findOutlineEditor this
    item = editor.selection.focusItem
    tags = item.getAttribute 'data-tags', true
    if tag in tags
      tags.splice(tags.indexOf(tag), 1)
      item.setAttribute 'data-tags', tags
    e.stopPropagation()
    e.preventDefault()

atom.contextMenu.add
  'birch-outline-editor .btag': [
    {label: 'Delete Tag', command:'birch-outline-editor:delete-tag'}
  ]