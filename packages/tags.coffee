OutlineEditorService = require '../lib/OutlineEditorService'

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if tags = item.attribute 'data-tags'
      for each in tags.split ','
        span = document.createElement 'A'
        span.className = 'btag'
        span.textContent = each.trim()
        addBadgeElement span
