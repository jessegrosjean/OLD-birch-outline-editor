ItemBodyUndoOperation = require './ItemBodyUndoOperation'
AttributedString = require './AttributedString'
ItemBodyEncoder = require './ItemBodyEncoder'
ItemEditorState = require './ItemEditorState'
Constants = require './Constants'
assert = require 'assert'
Util = require './Util'

Function::property = (prop, desc) ->
  Object.defineProperty @prototype, prop, desc

module.exports =
class Item

  constructor: (outline, text, liOrRootUL, remappedIDCallback) ->
    originalID = liOrRootUL.id
    assignedID = outline.nextOutlineUniqueItemID(originalID)
    ul = _childrenUL(liOrRootUL, false)

    if originalID != assignedID
      liOrRootUL.id = assignedID
      if remappedIDCallback and originalID
        remappedIDCallback(originalID, assignedID)

    @outline = outline
    @_liOrRootUL = liOrRootUL
    @_aliases = null
    @_editorState = {}
    @_bodyAttributedString = null
    liOrRootUL._item = this

    if ul
      childLI = ul.firstElementChild
      while childLI
        outline.createItem(null, childLI, remappedIDCallback)
        childLI = childLI.nextSibling

    if text
      if text instanceof AttributedString
        @attributedBodyText = text
      else
        _bodyP(liOrRootUL).textContent = text

  @property 'id',
    get: -> @_liOrRootUL.id

  @property 'parent',
    get: -> _parentLIOrRootUL(@_liOrRootUL)?._item

  @property 'firstChild',
    get: -> _childrenUL(@_liOrRootUL, false)?.firstElementChild?._item

  @property 'lastChild',
    get: -> _childrenUL(@_liOrRootUL, false)?.lastElementChild?._item

  @property 'previousSibling',
    get: -> @_liOrRootUL.previousElementSibling?._item

  @property 'nextSibling',
    get: -> @_liOrRootUL.nextElementSibling?._item

  @property 'isInOutline',
    get: ->
      li = @_liOrRootUL
      li.ownerDocument.contains(li);

  @property 'isRoot',
    get: -> @id == Constants.RootID

  @property 'previousBranch',
    get: -> @previousSibling or @previousItem

  @property 'nextBranch',
    get: -> @lastDescendantOrSelf.nextItem

  @property 'ancestors',
    get: ->
      ancestors = []
      each = @parent
      while each
        ancestors.unshift(each)
        each = each.parent
      ancestors

  @property 'descendants',
    get: ->
      descendants = []
      end = @nextBranch
      each = @nextItem
      while each != end
        descendants.push(each)
        each = each.nextItem
      return descendants

  @property 'lastDescendant',
    get: ->
      each = @lastChild
      while each?.lastChild
        each = each.lastChild
      each

  @property 'lastDescendantOrSelf',
    get: -> @lastDescendant or this

  @property 'previousItem',
    get: ->
      previousSibling = @previousSibling
      if previousSibling
        previousSibling.lastDescendantOrSelf
      else
        parent = @parent;
        if not parent or parent.isRoot
          null
        else
          parent

  @property 'previousItemOrRoot',
    get: -> @previousItem or @parent

  @property 'nextItem',
    get: ->
      firstChild = @firstChild
      if firstChild
        return firstChild

      nextSibling = @nextSibling
      if nextSibling
        return nextSibling

      parent = @parent
      while parent
        nextSibling = parent.nextSibling
        if nextSibling
          return nextSibling
        parent = parent.parent

      null

  @property 'hasChildren',
    get: ->
      ul = _childrenUL(@_liOrRootUL)
      if ul
        ul.hasChildNodes()
      else
        false

  @property 'children',
    get: ->
      children = []
      each = @firstChild
      while each
        children.push(each)
        each = each.nextSibling
      children

  @property 'branchHTML',
    get: -> @_liOrRootUL.outerHTML

  copyItem: ->
    @outline.copyItem(this)

  contains: (item) ->
    @_liOrRootUL.contains(item._liOrRootUL)

  comparePosition: (item) ->
    @_liOrRootUL.compareDocumentPosition(item._liOrRootUL)

  ###
  Section: Attributes
  ###

  @property 'attributeNames',
    get: ->
      namedItemMap = @_liOrRootUL.attributes
      length = namedItemMap.length
      attributeNames = []

      for i in [0..length - 1] by 1
        name = namedItemMap[i].name
        if name != 'id'
          attributeNames.push(name)

      attributeNames

  hasAttribute: (name) ->
    assert.ok(name != 'id', 'id is reserved attribute name')
    @_liOrRootUL.hasAttribute(name)

  attribute: (name) ->
    assert.ok(name != 'id', 'id is reserved attribute name')
    @_liOrRootUL.getAttribute(name) or undefined

  setAttribute: (name, value) ->
    outline = @outline
    isInOutline = @isInOutline

    if isInOutline
      oldValue = @attribute(name)
      outline.undoManager.registerUndoOperation =>
        @setAttribute(name, oldValue)
      outline.beginUpdates()

    @_setAttributeIgnoringAliases(name, value)

    if @isAliased
      for eachAlias in @aliases
        eachInOutline = eachAlias.isInOutline
        eachOutline = eachAlias.outline
        if eachInOutline then eachOutline.beginUpdates()
        eachAlias._setAttributeIgnoringAliases(name, value)
        if eachInOutline then eachOutline.endUpdates()

    if isInOutline
      outline.endUpdates()

  _setAttributeIgnoringAliases: (name, value) ->
    assert.ok(name != 'id', 'id is reserved attribute name')
    if value == undefined
      @_liOrRootUL.removeAttribute(name)
    else
      @_liOrRootUL.setAttribute(name, value)

  ###
  Section: Body Text
  ###

  @property 'bodyText',
    get: ->
      # Avoid creating attributed string if not already created. Syntax
      # highlighting will call this method for each displayed node, so try
      # to make it fast.
      if @_bodyAttributedString
        @_bodyAttributedString.string()
      else
        ItemBodyEncoder.bodyEncodedTextContent(_bodyP(@_liOrRootUL))
    set: (text) ->
      @replaceBodyTextInRange(text, 0, @bodyText.length)

  @property 'bodyHTML',
    get: -> _bodyP(@_liOrRootUL).innerHTML
    set: (html) ->
      p = @_liOrRootUL.ownerDocument.createElement('P')
      p.innerHTML = html
      @attributedBodyText = ItemBodyEncoder.elementToAttributedString(p, true)

  @property 'bodyTextLength',
    get: -> @bodyText.length

  @property 'attributedBodyText',
    get: ->
      if @isRoot
        return new AttributedString
      @_bodyAttributedString ?= ItemBodyEncoder.elementToAttributedString(_bodyP(@_liOrRootUL), true)

    set: (attributedText) ->
      @replaceBodyTextInRange(attributedText, 0, @bodyTextLength);

  attributedBodyTextSubstring: (location, length) ->
    @attributedBodyText.attributedSubstring(location, length)

  elementAtBodyTextIndex: (tagName, index, effectiveRange, longestEffectiveRange) ->
    assert(tagName == tagName.toUpperCase(), 'Tag Names Must be Uppercase')
    @attributedBodyText.attributeAtIndex(tagName, index, effectiveRange, longestEffectiveRange)

  elementsAtBodyTextIndex: (index, effectiveRange, longestEffectiveRange) ->
    @attributedBodyText.attributesAtIndex index, effectiveRange, longestEffectiveRange

  addElementInBodyTextRange: (tagName, attributes, location, length) ->
    elements = {}
    elements[tagName] = attributes
    @addElementsInBodyTextRange(elements, location, length)

  addElementsInBodyTextRange: (elements, location, length) ->
    for eachTagName of elements
      assert(eachTagName == eachTagName.toUpperCase(), 'Tag Names Must be Uppercase');
    changedText = @attributedBodyTextSubstring(location, length)
    changedText.addAttributesInRange(elements, 0, length)
    @replaceBodyTextInRange(changedText, location, length)

  removeElementInBodyTextRange: (tagName, location, length) ->
    assert(tagName == tagName.toUpperCase(), 'Tag Names Must be Uppercase')
    @removeElementsInBodyTextRange([tagName], location, length)

  removeElementsInBodyTextRange: (tagNames, location, length) ->
    for eachTagName in tagNames
      assert(eachTagName == eachTagName.toUpperCase(), 'Tag Names Must be Uppercase')

    changedText = @attributedBodyTextSubstring(location, length)
    changedText.removeAttributesInRange(tagNames, 0, length)
    @replaceBodyTextInRange(changedText, location, length)

  insertLineBreakInBodyTextAtLocation: (location) ->

  insertImageInBodyTextAtLocation: (location, image) ->

  replaceBodyTextInRange: (insertedText, location, length) ->
    attributedBodyText = @attributedBodyText
    isInOutline = @isInOutline
    outline = @outline
    insertedString

    if insertedText instanceof AttributedString
      insertedString = insertedText.string()
    else
      insertedString = insertedText

    assert.ok(insertedString.indexOf('\n') == -1, 'Item body text cannot contain newlines')

    if isInOutline
      replacedText = if length then attributedBodyText.attributedSubstring(location, length) else new AttributedString
      undoManager = outline.undoManager

      undoManager.registerUndoOperation(new ItemBodyUndoOperation(
        this,
        replacedText,
        location,
        insertedString.length
      ))

      outline.beginUpdates()

    @_replaceBodyTextInRangeIgnoringAliases(insertedText, location, length)

    if @isAliased
      for eachAlias in @aliases
        eachInOutline = eachAlias.isInOutline
        eachOutline = eachAlias.outline

        if eachInOutline
          eachOutline.beginUpdates()

        eachAlias._replaceBodyTextInRangeIgnoringAliases(insertedText, location, length)

        if eachInOutline
          eachOutline.endUpdates()

    if isInOutline
      outline.endUpdates()

  _replaceBodyTextInRangeIgnoringAliases: (insertedText, location, length) ->
    if @isRoot
      return

    li = @_liOrRootUL
    bodyP = _bodyP(li)
    attributedBodyText = @attributedBodyText
    ownerDocument = li.ownerDocument
    attributedBodyText.replaceCharactersInRange(insertedText, location, length)
    newBodyPContent = ItemBodyEncoder.attributedStringToDocumentFragment(attributedBodyText, ownerDocument)
    newBodyP = ownerDocument.createElement('P')
    newBodyP.appendChild(newBodyPContent)
    li.replaceChild(newBodyP, bodyP)

  ###
  Section: Children
  ###

  insertChildBefore: (child, referenceSibling) ->
    @insertChildrenBefore([child], referenceSibling)

  insertChildrenBefore: (children, referenceSibling) ->
    _aliasChildren = (children) ->
      aliases = []
      for each in children
        aliases.push each.aliasItem()
      aliases

    isInOutline = @isInOutline
    outline = @outline

    outline.removeItemsFromParents(children)

    if isInOutline
      outline.undoManager.registerUndoOperation =>
        @removeChildren(children)
      outline.beginUpdates()

    @_insertChildrenBeforeIgnoringAliases(children, referenceSibling)

    if @isAliased
      if referenceSibling
        for eachReferenceSiblingAlias in referenceSibling.aliases
          eachReferenceSiblingAlias.parent._insertChildrenBeforeIgnoringAliases(_aliasChildren(children), eachReferenceSiblingAlias)
      else
        for eachAlias in @aliases
          eachInOutline = eachAlias.isInOutline
          eachOutline = eachAlias.outline
          if eachInOutline
            eachOutline.beginUpdates()
          eachAlias._insertChildrenBeforeIgnoringAliases(_aliasChildren(children), null)
          if eachInOutline
            eachOutline.endUpdates()

    if isInOutline
      outline.endUpdates()

  _insertChildrenBeforeIgnoringAliases: (children, referenceSibling) ->
    documentFragment = @_liOrRootUL.ownerDocument.createDocumentFragment()
    referenceSiblingLI = referenceSibling?._liOrRootUL
    for each in children
      documentFragment.appendChild(each._liOrRootUL)
    _childrenUL(@_liOrRootUL, true).insertBefore(documentFragment, referenceSiblingLI)

  appendChildren: (children) ->
    @insertChildrenBefore(children)

  appendChild: (child) ->
    @insertChildrenBefore([child])

  removeChildren: (children) ->
    if not children.length
      return

    isInOutline = @isInOutline
    outline = @outline

    if isInOutline
      lastChild = children[children.length - 1]
      nextSibling = lastChild.nextSibling
      outline.undoManager.registerUndoOperation =>
        @insertChildrenBefore(children, nextSibling)
      outline.beginUpdates()

    @_removeChildrenIgnoringAliases(children)

    if @isAliased
      for eachAlias in @aliases
        eachInOutline = eachAlias.isInOutline
        eachOutline = eachAlias.outline

        if eachInOutline
          eachOutline.beginUpdates()

        eachAliasChildrenToRemove = []
        for eachChild in children
          for eachChildAlias in eachChild.aliases
            if eachChildAlias.parent == eachAlias
              eachAliasChildrenToRemove.push(eachChildAlias)

        eachAlias._removeChildrenIgnoringAliases(eachAliasChildrenToRemove);

        if eachInOutline
          eachOutline.endUpdates()

    if isInOutline
      outline.endUpdates()

  _removeChildrenIgnoringAliases: (children) ->
    siblingChildren = []
    outerThis = this
    lastSibling

    for each in children
      if lastSibling and lastSibling.nextSibling != each
        @_removeSiblingChildrenIgnoringAliases(siblingChildren)
        siblingChildren = [each]
      else
        siblingChildren.push(each)
      lastSibling = each

    @_removeSiblingChildrenIgnoringAliases(siblingChildren)

  _removeSiblingChildrenIgnoringAliases: (siblingChildren) ->
    if @isInOutline
      first = siblingChildren[0]
      last = siblingChildren[siblingChildren.length - 1]
      range = @_liOrRootUL.ownerDocument.createRange()
      range.setStartBefore(first._liOrRootUL)
      range.setEndAfter(last._liOrRootUL)
      range.deleteContents()
      range.detach()
    else
      # Range method is better (in Chrome at least) because it generates a
      # single mutation. But range method fails in Safari when items are
      # not in a document. So in case when not in outline remove manually.
      for each in siblingChildren
        each._liOrRootUL.parentNode.removeChild(each._liOrRootUL)

  removeChild: (child) ->
    @removeChildren([child])

  removeFromParent: ->
    @parent?.removeChild(this)

  ###
  Section: Aliases
  ###

  @property 'isAliased',
    get: -> @_aliases != null

  @property 'aliases',
    get: -> @_aliases

  aliasItem: ->
    @outline.aliasItem(this)

  ###
  Section: Editor State
  ###

  editorState: (editorID) ->
    @_editorState[editorID] ?= new ItemEditorState

  clearEditorState: (editorID) ->
    delete @_editorState[editorID]

  ###
  Section: Debug
  ###

  toString: (indent) ->
    (indent or '') + '(' + @id + ') ' + @bodyHTML

  branchToString: (indent) ->
    indent ?= ''
    results = [@toString(indent)]
    for each in @children
      results.push(each.branchToString(indent + '    '))
    results.join('\n')

  ###
  Section: Static Methods
  ###

  @coverItems = (items) ->
    coverItems = []
    itemIDs = {}

    for each in items
      itemIDs[each.id] = true

    for each in items
      p = each.parent
      while p and not itemIDs[p.id]
        p = p.parent
      unless p
        coverItems.push each

    coverItems

  @itemsWithAncestors = (items) ->
    ancestorsAndItems = []
    addedIDs = {}

    for each in items
      index = ancestorsAndItems.length
      while each
        if addedIDs[each.id]
          continue
        else
          ancestorsAndItems.splice(index, 0, each)
          addedIDs[each.id] = true
        each = each.parent

    ancestorsAndItems

###
Section: Util Functions
###

_parentLIOrRootUL = (liOrRootUL) ->
  parentNode = liOrRootUL.parentNode
  while parentNode
    if parentNode._item
      return parentNode
    parentNode = parentNode.parentNode

_bodyP = (liOrRootUL) ->
  if liOrRootUL.tagName == 'UL'
    # In case of root element just return an empty disconnected P for api
    # compatibilty.
    assert.ok(liOrRootUL.id == Constants.RootID)
    liOrRootUL.ownerDocument.createElement('p')
  else
    liOrRootUL.firstElementChild

_childrenUL = (liOrRootUL, createIfNeeded) ->
  if liOrRootUL.tagName == 'UL'
    assert.ok(liOrRootUL.id == Constants.RootID)
    liOrRootUL
  else
    ul = liOrRootUL.lastElementChild
    if ul?.tagName == 'UL'
      ul
    else if createIfNeeded
      ul = liOrRootUL.ownerDocument.createElement('UL')
      liOrRootUL.appendChild(ul)
      ul