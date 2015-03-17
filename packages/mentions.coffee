OutlineEditorService = require '../lib/OutlineEditorService'

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if mentions = item.attribute 'data-mentions'
      for each in mentions.split ','
        span = document.createElement 'A'
        span.className = 'bmention'
        span.textContent = each.trim()
        addBadgeElement span