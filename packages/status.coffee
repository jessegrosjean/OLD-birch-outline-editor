OutlineEditorService = require '../lib/OutlineEditorService'

toggleStatus = (editor, status) ->
  outline = editor.outline
  undoManager = outline.undoManager
  #doneDate = new Date().toISOString()
  selectedItems = editor.selection.items
  firstItem = selectedItems[0]

  if firstItem
    if firstItem.attribute('data-status') is status
      status = undefined

    outline.beginUpdates()
    undoManager.beginUndoGrouping()
    for each in selectedItems
      each.setAttribute('data-status', status)
    undoManager.endUndoGrouping()
    outline.endUpdates()

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if status = item.attribute 'data-status'
      span = document.createElement 'A'
      span.className = 'bstatus'
      span.setAttribute 'data-status', status
      addBadgeElement span

atom.commands.add 'birch-outline-editor',
  'birch-outline-editor:toggle-status-doing': -> toggleStatus @editor, 'doing'
  'birch-outline-editor:toggle-status-done': -> toggleStatus @editor, 'done'
  'birch-outline-editor:toggle-status-waiting': -> toggleStatus @editor, 'waiting'

atom.keymaps.add 'status-bindings',
  'birch-outline-editor':
    'cmd-d' : 'birch-outline-editor:toggle-status-done'

  'birch-outline-editor.outlineMode':
    'd' : 'birch-outline-editor:toggle-status-done'