OutlineEditorService = require '../lib/OutlineEditorService'

togglePriority = (editor, priority) ->
  outline = editor.outline
  undoManager = outline.undoManager
  selectedItems = editor.selection.items
  firstItem = selectedItems[0]

  if firstItem
    if firstItem.getAttribute('data-priority') is priority
      priority = undefined

    outline.beginUpdates()
    undoManager.beginUndoGrouping()
    for each in selectedItems
      each.setAttribute('data-priority', priority)
    undoManager.endUndoGrouping()
    outline.endUpdates()

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if value = item.getAttribute 'data-priority'
      span = document.createElement 'A'
      span.className = 'bpriority'
      span.setAttribute 'data-priority', value
      addBadgeElement span

atom.commands.add 'birch-outline-editor',
  'birch-outline-editor:toggle-priority-1': -> togglePriority @editor, '1'
  'birch-outline-editor:toggle-priority-2': -> togglePriority @editor, '2'
  'birch-outline-editor:toggle-priority-3': -> togglePriority @editor, '3'
  'birch-outline-editor:toggle-priority-4': -> togglePriority @editor, '4'
  'birch-outline-editor:toggle-priority-5': -> togglePriority @editor, '5'
  'birch-outline-editor:toggle-priority-6': -> togglePriority @editor, '6'
  'birch-outline-editor:toggle-priority-7': -> togglePriority @editor, '7'
  'birch-outline-editor:clear-priority': -> togglePriority @editor, undefined

atom.keymaps.add 'priorities-bindings',
  'birch-outline-editor.outlineMode':
    '1' : 'birch-outline-editor:toggle-priority-1'
    '2' : 'birch-outline-editor:toggle-priority-2'
    '3' : 'birch-outline-editor:toggle-priority-3'
    '4' : 'birch-outline-editor:toggle-priority-4'
    '5' : 'birch-outline-editor:toggle-priority-5'
    '6' : 'birch-outline-editor:toggle-priority-6'
    '7' : 'birch-outline-editor:toggle-priority-7'
    '0' : 'birch-outline-editor:clear-priority'