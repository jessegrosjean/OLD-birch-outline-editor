OutlineEditorService = require '../lib/OutlineEditorService'

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if tags = item.getAttribute 'data-tags', true
      for each in tags
        span = document.createElement 'A'
        span.className = 'btag'
        span.textContent = each.trim()
        addBadgeElement span
