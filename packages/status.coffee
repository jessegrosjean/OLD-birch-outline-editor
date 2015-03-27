OutlineEditorService = require '../lib/OutlineEditorService'

toggleStatus = (editor, status) ->
  outline = editor.outline
  undoManager = outline.undoManager
  #doneDate = new Date().toISOString()
  selectedItems = editor.selection.items
  firstItem = selectedItems[0]

  if firstItem
    if firstItem.getAttribute('data-status') is status
      status = undefined

    outline.beginUpdates()
    undoManager.beginUndoGrouping()
    for each in selectedItems
      each.setAttribute('data-status', status)
    undoManager.endUndoGrouping()
    outline.endUpdates()

OutlineEditorService.eventRegistery.listen '.bstatus',
  click: (e) ->
    status = e.target.dataset.status
    outlineEditor = OutlineEditorService.OutlineEditor.findOutlineEditor e.target
    outlineEditor.setSearch "@data-status = #{status}"
    e.stopPropagation()
    e.preventDefault()

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if status = item.getAttribute 'data-status'
      a = document.createElement 'A'
      a.className = 'bstatus'
      a.setAttribute 'data-status', status
      addBadgeElement a

atom.commands.add 'birch-outline-editor',
  'birch-outline-editor:toggle-status-waiting': -> toggleStatus @editor, 'waiting'
  'birch-outline-editor:toggle-status-active': -> toggleStatus @editor, 'active'
  'birch-outline-editor:toggle-status-complete': -> toggleStatus @editor, 'complete'

atom.keymaps.add 'status-bindings',
  'birch-outline-editor.outlineMode':
    's w' : 'birch-outline-editor:toggle-status-waiting'
    's a' : 'birch-outline-editor:toggle-status-active'
    's c' : 'birch-outline-editor:toggle-status-complete'
    'space' : 'birch-outline-editor:toggle-status-complete'