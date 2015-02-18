# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Function::property = (prop, desc) ->
  Object.defineProperty @prototype, prop, desc

ItemBodyUndoOperation = require './ItemBodyUndoOperation'
AttributedString = require './AttributedString'
ItemBodyEncoder = require './ItemBodyEncoder'
ItemEditorState = require './ItemEditorState'
Constants = require './Constants'
assert = require 'assert'
Util = require './Util'

# Essential: A paragraph of text in an {Outline}.
#
# Items cannot be instantiated directly, instead use {Outline::createItem}.
#
# Items may contain other child items to form a hiearchical outline structure.
# When you move an item all of it's children are moved with it.
#
# Items have a single paragraph of body text. You can access it as plain text,
# a HTML string, or an AttributedString. You can add formatting to make parts
# of the text bold, italic, etc.
#
# You can assign item level attributes to items. For example you might store a
# due date in the `data-due-date` attribute. Or store an item type in the
# `data-type` attribute.
#
# ## Examples
#
# Create Items:
#
# ```coffeescript
# item = outline.createItem('Hello World!')
# outline.root.appendChild(item)
# ```
#
# Add body text formatting:
#
# ```coffeescript
# item = @createItem('Hello World!')
# item.addElementInBodyTextRange('B', {}, 6, 5)
# item.addElementInBodyTextRange('I', {}, 0, 11)
# ```
#
# Read body text formatting:
#
# ```coffeescript
# effectiveRange = end: 0
# textLength = item.bodyText.length
# while effectiveRange.end < textLength
#   console.log item.elementsAtBodyTextIndex effectiveRange.end, effectiveRange
#```
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

  # Public: Deep clones this item.
  #
  # Returns a duplicate {Item}.
  cloneItem: ->
    @outline.cloneItem(this)

  ###
  Section: Attributes
  ###

  # Public: Read-only unique and persistent {String} ID.
  id: null
  @property 'id',
    get: -> @_liOrRootUL.id

  # Public: Read-only {Array} of this item's attribute names.
  attributeNames: null
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

  # Public: Test to see if this item has an attribute with the given name.
  #
  # - `name` The {String} attribute name.
  #
  # Returns a {Boolean}
  hasAttribute: (name) ->
    @_liOrRootUL.hasAttribute(name)

  # Public: Get the value of the specified attribute. If the attribute does
  # not exist will return `undefined`.
  #
  # - `name` The {String} attribute name.
  #
  # Returns attribute value or `undefined`.
  attribute: (name) ->
    @_liOrRootUL.getAttribute(name) or undefined

  # Public: Adds a new attribute or changes the value of an existing
  # attribute. `id` is reserved and an exception is thrown if your try to set
  # it.
  #
  # - `name` The {String} attribute name.
  # - `value` The new attribute value.
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

  # Public: Body text as plain text {String}.
  bodyText: null
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

  # Public: Body text as HTML {String}.
  bodyHTML: null
  @property 'bodyHTML',
    get: -> _bodyP(@_liOrRootUL).innerHTML
    set: (html) ->
      p = @_liOrRootUL.ownerDocument.createElement('P')
      p.innerHTML = html
      @attributedBodyText = ItemBodyEncoder.elementToAttributedString(p, true)

  # Public: Body text as {AttributedString}.
  attributedBodyText: null
  @property 'attributedBodyText',
    get: ->
      if @isRoot
        return new AttributedString
      @_bodyAttributedString ?= ItemBodyEncoder.elementToAttributedString(
        _bodyP(@_liOrRootUL),
        true
      )

    set: (attributedText) ->
      @replaceBodyTextInRange(attributedText, 0, @bodyText.length);

  # Public: Returns an {AttributedString} substring of this item's body text.
  #
  # - `location` Substring's strart location.
  # - `length` Length of substring to extract.
  attributedBodyTextSubstring: (location, length) ->
    @attributedBodyText.attributedSubstring(location, length)

  # Public: Looks to see if there's an element with the given `tagName` at the
  # given index. If there is then that element's attributes are returned and
  # by reference the range over which the element applies.
  #
  # - `tagName` Tag name of the element.
  # - `index` The character index.
  # - `effectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to effective range of element.
  # - `longestEffectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to longest effective range of element.
  #
  # Returns elements attribute values as an {Object} or {undefined}
  elementAtBodyTextIndex: (tagName, index, effectiveRange, longestEffectiveRange) ->
    assert(tagName == tagName.toUpperCase(), 'Tag Names Must be Uppercase')
    @attributedBodyText.attributeAtIndex(
      tagName,
      index,
      effectiveRange,
      longestEffectiveRange
    )

  # Public: Returns an {Object} with keys for each element at the given
  # character index, and by reference the range over which the elements apply.
  #
  # - `index` The character index.
  # - `effectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to effective range of element.
  # - `longestEffectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to longest effective range of element.
  elementsAtBodyTextIndex: (index, effectiveRange, longestEffectiveRange) ->
    @attributedBodyText.attributesAtIndex(
      index,
      effectiveRange,
      longestEffectiveRange
    )

  # Public: Adds an element with the given tagName and attributes to the
  # characters in the specified range.
  #
  # - `tagName` Tag name of the element.
  # - `attributes` Element attributes. Use `null` as a placeholder if element
  #    doesn't need attributes.
  # - `location` Start location character index.
  # - `length` Range length.
  addElementInBodyTextRange: (tagName, attributes, location, length) ->
    elements = {}
    elements[tagName] = attributes
    @addElementsInBodyTextRange(elements, location, length)

  addElementsInBodyTextRange: (elements, location, length) ->
    for eachTagName of elements
      assert(
        eachTagName == eachTagName.toUpperCase(),
        'Tag Names Must be Uppercase'
      )
    changedText = @attributedBodyTextSubstring(location, length)
    changedText.addAttributesInRange(elements, 0, length)
    @replaceBodyTextInRange(changedText, location, length)

  # Public: Removes the element with the tagName from the characters in the
  # specified range.
  #
  # - `tagName` Tag name of the element.
  # - `location` Start location character index.
  # - `length` Range length.
  removeElementInBodyTextRange: (tagName, location, length) ->
    assert(tagName == tagName.toUpperCase(), 'Tag Names Must be Uppercase')
    @removeElementsInBodyTextRange([tagName], location, length)

  removeElementsInBodyTextRange: (tagNames, location, length) ->
    for eachTagName in tagNames
      assert(
        eachTagName == eachTagName.toUpperCase(),
        'Tag Names Must be Uppercase'
      )
    changedText = @attributedBodyTextSubstring(location, length)
    changedText.removeAttributesInRange(tagNames, 0, length)
    @replaceBodyTextInRange(changedText, location, length)

  insertLineBreakInBodyTextAtLocation: (location) ->

  insertImageInBodyTextAtLocation: (location, image) ->

  # Public: Replace body text in the given range.
  #
  # - `insertedText` {String} or {AttributedString}
  # - `location` Start location character index.
  # - `length` Range length.
  replaceBodyTextInRange: (insertedText, location, length) ->
    attributedBodyText = @attributedBodyText
    isInOutline = @isInOutline
    outline = @outline
    insertedString

    if insertedText instanceof AttributedString
      insertedString = insertedText.string()
    else
      insertedString = insertedText

    assert.ok(
      insertedString.indexOf('\n') == -1,
      'Item body text cannot contain newlines'
    )

    if isInOutline
      undoManager = outline.undoManager
      replacedText

      if length
        replacedText = attributedBodyText.attributedSubstring(location, length)
      else
        replacedText = new AttributedString

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

        eachAlias._replaceBodyTextInRangeIgnoringAliases(
          insertedText,
          location,
          length
        )

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
    newBodyPContent = ItemBodyEncoder.attributedStringToDocumentFragment(
      attributedBodyText,
      ownerDocument
    )
    newBodyP = ownerDocument.createElement('P')
    newBodyP.appendChild(newBodyPContent)
    li.replaceChild(newBodyP, bodyP)

  ###
  Section: Outline Structure
  ###

  # Public: Read-only true if is root {Item}.
  isRoot: null
  @property 'isRoot',
    get: -> @id == Constants.RootID

  # Public: Read-only true if item is part of owning {Outline}
  isInOutline: null
  @property 'isInOutline',
    get: ->
      li = @_liOrRootUL
      li.ownerDocument.contains(li);

  # Public: Read-only parent {Item}.
  parent: null
  @property 'parent',
    get: -> _parentLIOrRootUL(@_liOrRootUL)?._item

  # Public: Read-only first child {Item}.
  firstChild: null
  @property 'firstChild',
    get: -> _childrenUL(@_liOrRootUL, false)?.firstElementChild?._item

  # Public: Read-only last child {Item}.
  lastChild: null
  @property 'lastChild',
    get: -> _childrenUL(@_liOrRootUL, false)?.lastElementChild?._item

  # Public: Read-only previous sibling {Item}.
  previousSibling: null
  @property 'previousSibling',
    get: -> @_liOrRootUL.previousElementSibling?._item

  # Public: Read-only next sibling {Item}.
  nextSibling: null
  @property 'nextSibling',
    get: -> @_liOrRootUL.nextElementSibling?._item

  # Public: Read-only previous branch {Item}.
  previousBranch: null
  @property 'previousBranch',
    get: -> @previousSibling or @previousItem

  # Public: Read-only next branch {Item}.
  nextBranch: null
  @property 'nextBranch',
    get: -> @lastDescendantOrSelf.nextItem

  # Public: Read-only ancestor items {Array}.
  ancestors: null
  @property 'ancestors',
    get: ->
      ancestors = []
      each = @parent
      while each
        ancestors.unshift(each)
        each = each.parent
      ancestors

  # Public: Read-only descendant items {Array}.
  descendants: null
  @property 'descendants',
    get: ->
      descendants = []
      end = @nextBranch
      each = @nextItem
      while each != end
        descendants.push(each)
        each = each.nextItem
      return descendants

  # Public: Read-only last descendant {Item}.
  lastDescendant: null
  @property 'lastDescendant',
    get: ->
      each = @lastChild
      while each?.lastChild
        each = each.lastChild
      each

  @property 'lastDescendantOrSelf',
    get: -> @lastDescendant or this

  # Public: Read-only previous {Item} in outline order.
  previousItem: null
  @property 'previousItem',
    get: ->
      previousSibling = @previousSibling
      if previousSibling
        previousSibling.lastDescendantOrSelf
      else
        parent = @parent
        if not parent or parent.isRoot
          null
        else
          parent

  @property 'previousItemOrRoot',
    get: -> @previousItem or @parent

  # Public: Read-only next {Item} in outline order.
  nextItem: null
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

  # Public: Read-only {Boolean}
  hasChildren: null
  @property 'hasChildren',
    get: ->
      ul = _childrenUL(@_liOrRootUL)
      if ul
        ul.hasChildNodes()
      else
        false

  # Public: Read-only child items {Array}.
  children: null
  @property 'children',
    get: ->
      children = []
      each = @firstChild
      while each
        children.push(each)
        each = each.nextSibling
      children

  # Public: Determins if this item contains the given item.
  #
  # - `item` The {Item} to check for containment.
  #
  # Returns {Boolean}.
  contains: (item) ->
    @_liOrRootUL.contains(item._liOrRootUL)

  # Public: Compares the position of this item against another item in the
  # outline. See
  # [Node.compareDocumentPosition()](https://developer.mozilla.org/en-
  # US/docs/Web/API/Node.compareDocumentPosition) for more information.
  #
  # - `item` The {Item} to compare against.
  #
  # Returns a {Number} bitmask.
  comparePosition: (item) ->
    @_liOrRootUL.compareDocumentPosition(item._liOrRootUL)

  @coverItems: (items) ->
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

  @itemsWithAncestors: (items) ->
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
  Section: Mutating Outline Structure
  ###

  # Public: Insert the new child item before the referenced sibling in this
  # item's list of children. If referenceSibling isn't defined the item is
  # inserted at the end.
  #
  # - `child` The inserted child {Item} .
  # - `referenceSibling` (optional) The referenced sibling {Item} .
  insertChildBefore: (child, referenceSibling) ->
    @insertChildrenBefore([child], referenceSibling)

  # Public: Insert the new children before the referenced sibling
  # in this item's list of children. If referenceSibling isn't defined the new
  # children are inserted at the end.
  #
  # - `children` {Array} of {Item}s to insert.
  # - `referenceSibling` (optional) The referenced sibling {Item}.
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
          eachReferenceSiblingAlias.parent._insertChildrenBeforeIgnoringAliases(
            _aliasChildren(children),
            eachReferenceSiblingAlias
          )
      else
        for eachAlias in @aliases
          eachInOutline = eachAlias.isInOutline
          eachOutline = eachAlias.outline
          if eachInOutline
            eachOutline.beginUpdates()
          eachAlias._insertChildrenBeforeIgnoringAliases(
            _aliasChildren(children),
            null
          )
          if eachInOutline
            eachOutline.endUpdates()

    if isInOutline
      outline.endUpdates()

  _insertChildrenBeforeIgnoringAliases: (children, referenceSibling) ->
    ownerDocument = @_liOrRootUL.ownerDocument
    documentFragment = ownerDocument.createDocumentFragment()
    referenceSiblingLI = referenceSibling?._liOrRootUL
    childrenUL = _childrenUL(@_liOrRootUL, true)

    for each in children
      assert.ok(
        each._liOrRootUL.ownerDocument == ownerDocument,
        'children must share same owner document'
      )
      documentFragment.appendChild(each._liOrRootUL)

    childrenUL.insertBefore(documentFragment, referenceSiblingLI)

  # Public: Append the new children to this item's list of children.
  #
  # - `children` The children {Array} to append.
  appendChildren: (children) ->
    @insertChildrenBefore(children)

  # Public: Append the new child to this item's list of children.
  #
  # - `child` The child {Item} to append.
  appendChild: (child) ->
    @insertChildrenBefore([child])

  # Public: Remove the children from this item's list of children.
  #
  # - `children` The {Array} of children {Items}s to remove.
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

        eachAlias._removeChildrenIgnoringAliases(eachAliasChildrenToRemove)

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

  # Public: Remove the given child from this item's list of children.
  #
  # - `child` The child {Item} to remove.
  removeChild: (child) ->
    @removeChildren([child])

  # Public: Remove this item from it's parent item if it has a parent.
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

  # Extended: Returns debug string for this branch.
  branchToString: (indent) ->
    indent ?= ''
    results = [@toString(indent)]
    for each in @children
      results.push(each.branchToString(indent + '    '))
    results.join('\n')

  # Extended: Returns debug HTML string for this branch.
  branchToHTML: ->
    @_liOrRootUL.outerHTML

  # Extended: Returns debug string for this item.
  toString: (indent) ->
    (indent or '') + '(' + @id + ') ' + @bodyHTML

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