OutlineEditorService = require '../lib/OutlineEditorService'

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if mentions = item.getAttribute 'data-mentions', true
      for each in mentions
        span = document.createElement 'A'
        span.className = 'bmention'
        span.textContent = each.trim()
        addBadgeElement span