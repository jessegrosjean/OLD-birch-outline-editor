OutlineEditorService = require '../OutlineEditorService'
{Disposable, CompositeDisposable} = require 'atom'

fuzzyFilter = null # defer until used

class ListInputElement extends HTMLElement

  items: []
  maxItems: Infinity
  allowNewItems: true
  allowMultipleItems: true
  allowEmptySelection: true
  scheduleTimeout: null
  inputThrottle: 50

  createdCallback: ->
    @classList.add 'select-list'

    @error = document.createElement 'div'
    @error.classList.add 'error-message'
    @appendChild @error

    @loadingArea = document.createElement 'div'
    @loadingArea.classList.add 'loading'
    @appendChild @loadingArea

    @loading = document.createElement 'span'
    @loading.classList.add 'loading-message'
    @loadingArea.appendChild @loading

    @loadingBadge = document.createElement 'span'
    @loadingBadge.classList.add 'badge'
    @loadingArea.appendChild @loadingBadge

    @list = document.createElement 'ol'
    @list.classList.add 'list-group'
    @appendChild @list

    @setTextInputElement document.createElement 'birch-text-input'

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  ###
  Section: Text Input
  ###

  getTextInputElement: ->
    @textInputElement

  setTextInputElement: (textInputElement) ->
    if @textInputElement
      @textInputElement.parentElement.removeChild @textInputElement
    @textInputElement = textInputElement
    if @textInputElement
      this.insertBefore @textInputElement, this.firstChild

  ###
  Section: Delegate
  ###

  getDelegate: ->
    @textInputElement.getDelegate()

  setDelegate: (delegate) ->
    originalDidChangeText = delegate.didChangeText?.bind(delegate)
    originalCanceled = delegate.canceled?.bind(delegate)

    delegate.didChangeText = (e) =>
      @schedulePopulateList()
      originalDidChangeText?(e)

    delegate.canceled = =>
      @list.innerHTML = ''
      originalCanceled?()

    @textInputElement.setDelegate(delegate)
    @populateList()
    @setLoading()

  ###
  Section: Text
  ###

  getFilterKey: ->

  getText: ->
    @textInputElement.getText()

  setText: (text) ->
    @textInputElement.setText text

  ###
  Section: Managing the list of items
  ###

  getSelectedItem: ->
    @getSelectedItemElement()?._item

  setSelectedItem: (item) ->
    @selectItemElement @getElementForItem item

  setItems: (@items=[]) ->
    @populateList()
    @setLoading()

  setMaxItems: (@maxItems) ->

  reloadItem: (item) ->
    if itemElement = @getElementForItem item
      newItemElement = @getDelegate().elementForListItem(item)
      newItemElement._item = item
      itemElement.parentElement.replaceChild(newItemElement, itemElement)

  populateList: ->
    return unless @items?

    selectedItem = @getSelectedItem()
    filterQuery = @getText()
    if filterQuery.length
      fuzzyFilter ?= require('fuzzaldrin').filter
      filteredItems = fuzzyFilter(@items, filterQuery, key: @getFilterKey())
    else
      filteredItems = @items

    @list.innerHTML = ''
    if filteredItems.length
      @setError(null)

      for i in [0...Math.min(filteredItems.length, @maxItems)]
        item = filteredItems[i]
        itemElement = @getDelegate().elementForListItem(item)
        itemElement._item = item
        @list.appendChild(itemElement)

      if selectedElement = @getElementForItem selectedItem
        @selectItemElement(selectedElement)
      else if not @allowEmptySelection
        @selectItemElement(@list.firstChild)
    else
      @setError(@getEmptyMessage(@items.length, filteredItems.length))

  ###
  Section: Allow Mark Active
  ###

  getAllowMarkActive: ->
    @allowMarkActive

  setAllowMarkActive: (allowMarkActive) ->
    unless @allowMarkActive is allowMarkActive
      @allowMarkActive = allowMarkActive
      if allowMarkActive
        @list.classList.add 'mark-active'
      else
        @list.classList.remove 'mark-active'

  ###
  Section: Messages to the user
  ###

  setError: (message='') ->
    if message.length is 0
      @error.textContent = ''
      @error.style.display = 'none'
    else
      @setLoading()
      @error.textContent = message
      @error.style.display = null

  setLoading: (message='') ->
    if message.length is 0
      @loading.textContent = ''
      @loading.style.display = 'none'
      @loadingBadge.textContent = ''
      @loadingBadge.style.display = 'none'
    else
      @setError()
      @loading.textContent = message
      @loadingArea.style.display = null

  getEmptyMessage: (itemCount, filteredItemCount) ->
    emptyMessage = @getDelegate().getEmptyMessage?(itemCount, filteredItemCount)
    emptyMessage ?= 'No matches found'
    emptyMessage

  ###
  Section: Element Actions
  ###

  focusTextEditor: ->
    @textInputElement.focusTextEditor()

  ###
  Section: Private
  ###

  selectFirstElement: (e) ->
    @selectItemElement(@list.firstChild)
    @list.scrollTop = 0
    e?.stopImmediatePropagation()

  selectLastElement: (e) ->
    @selectItemElement(@list.lastChild)
    @list.scrollTop = @list.scrollHeight
    e?.stopImmediatePropagation()

  selectPreviousItemElement: (e) ->
    current = @getSelectedItemElement()
    previous = current?.previousSibling
    if !previous and !current
      previous = @list.lastChild
    if previous
      @selectItemElement(previous)
    e?.stopImmediatePropagation()

  selectNextItemElement: (e) ->
    current = @getSelectedItemElement()
    next = current?.nextSibling
    if !next and !current
      next = @list.firstChild
    if next
      @selectItemElement(next)
    e?.stopImmediatePropagation()

  selectItemElement: (element) ->
    oldSelected = @getSelectedItemElement()
    unless element is oldSelected
      delegate = @getDelegate()
      delegate.willSelectListItem?(element?._item)
      @getSelectedItemElement()?.classList.remove 'selected'
      if element and not element.classList.contains 'selected'
        element.classList.add('selected')
        @scrollToItemElement(element)
      delegate.didSelectListItem?(element?._item)

  clearListSelection: ->
    @selectItemElement(null)

  scrollToItemElement: (element) ->
    scrollTop = @list.scrollTop
    listRect = @list.getBoundingClientRect()
    elementRect = element.getBoundingClientRect()
    if elementRect.bottom > listRect.bottom
      @list.scrollTop += (elementRect.bottom - listRect.bottom)
    else if elementRect.top < listRect.top
      @list.scrollTop += (elementRect.top - listRect.top)

  getSelectedItemElement: ->
    for each in @list.children
      if each.classList.contains 'selected'
        return each

  getElementForItem: (item) ->
    for each in @list.children
      if each._item is item
        return each

  schedulePopulateList: ->
    clearTimeout(@scheduleTimeout)
    populateCallback = =>
      @populateList() if document.contains(this)
    @scheduleTimeout = setTimeout(populateCallback,  @inputThrottle)

liForNode = (node) ->
  while node and node.tagName != 'LI'
    node = node.parentElement
  node

OutlineEditorService.eventRegistery.listen 'birch-list-input > .list-group',
  # This prevents the focusout event from firing on the filter editor element
  # when the list is scrolled by clicking the scrollbar and dragging.
  mousedown: (e) ->
    @parentElement.selectItemElement(liForNode(e.target))
    e.preventDefault()
    e.stopPropagation()

  click: (e) ->
    listInput = @parentElement
    li = liForNode(e.target)
    if li?.classList.contains('selected')
      if listInput.getDelegate().mouseClickListItem
        listInput.getDelegate().mouseClickListItem(e)
    e.preventDefault()
    e.stopPropagation()

atom.commands.add 'birch-list-input',
  'core:move-up': (e) -> @selectPreviousItemElement(e)
  'core:move-down': (e) -> @selectNextItemElement(e)
  'core:move-to-top': (e) -> @selectFirstElement(e)
  'core:move-to-bottom': (e) -> @selectLastElement(e)

atom.commands.add 'birch-list-input > birch-token-input > birch-text-input > atom-text-editor[mini]',
  'core:move-up': (e) -> @parentElement.parentElement.parentElement.selectPreviousItemElement(e)
  'core:move-down': (e) -> @parentElement.parentElement.parentElement.selectNextItemElement(e)
  'core:move-to-top': (e) -> @parentElement.parentElement.parentElement.selectFirstElement(e)
  'core:move-to-bottom': (e) -> @parentElement.parentElement.parentElement.selectLastElement(e)

module.exports = document.registerElement 'birch-list-input', prototype: ListInputElement.prototype