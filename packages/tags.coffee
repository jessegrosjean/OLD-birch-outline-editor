OutlineEditorService = require '../lib/OutlineEditorService'

OutlineEditorService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if tags = item.getAttribute 'data-tags', true
      for each in tags
        span = document.createElement 'A'
        span.className = 'btag'
        span.textContent = each.trim()
        addBadgeElement span

OutlineEditorService.eventRegistery.listen '.btag',
  click: (e) ->
    tag = e.target.textContent
    outlineEditor = OutlineEditorService.OutlineEditor.findOutlineEditor e.target
    outlineEditor.setSearch "##{tag}"
    e.stopPropagation()
    e.preventDefault()