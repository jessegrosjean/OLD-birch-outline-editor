# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

assert = require 'assert'

# Public: A record of a single change in a target {Item}.
#
# A new mutation is created to record each attribute set, body text change,
# and child item's update. Use {Outline::onDidChange} to receive this mutation
# record so you can track what has changed as an outline is edited.
module.exports =
class Mutation

  ###
  Section: Constants
  ###

  # Public: ATTRIBUTE_CHANGED Mutation type constant.
  @ATTRIBUTE_CHANGED: 'attribute'

  # Public: BODT_TEXT_CHANGED Mutation type constant.
  @BODT_TEXT_CHANGED: 'bodyText'

  # Public: CHILDREN_CHANGED Mutation type constant.
  @CHILDREN_CHANGED: 'children'

  ###
  Section: Attributes
  ###

  # Public: Read-only {Item} target of the change delta.
  target: null

  # Public: Read-only type of change. {Mutation.ATTRIBUTE_CHANGED},
  # {Mutation.BODT_TEXT_CHANGED}, or {Mutation.CHILDREN_CHANGED}.
  type: null

  # Public: Read-only {Array} of child {Item}s added to the target.
  addedItems: null

  # Public: Read-only {Array} of child {Item}s removed from the target.
  removedItems: null

  # Public: Read-only previous sibling {Item} of the added or removed Items,
  # or null.
  previousSibling: null

  # Public: Read-only next sibling {Item} of the added or removed Items, or
  # null.
  nextSibling: null

  # Public: Read-only name of changed attribute in the target {Item}, or null.
  attributeName: null

  # Public: Read-only previous value of changed attribute in the target
  # {Item}, or null.
  attributeOldValue: null

  @createFromDOMMutations: (mutationRecords) ->
    results = []
    for mutationRecord in mutationRecords
      if mutation = Mutation.createFromDOMMutation(mutationRecord)
        results.push mutation
    results

  @createFromDOMMutation: (mutationRecord) ->
    type = mutationRecord.type
    target = mutationRecord.target
    targetTag = target.tagName
    mutation = new Mutation mutationRecord
    mutation.target = _item(target)

    unless mutation.target
      # Must be a body child node that is later removed, so at this point
      # it's no longer connected to a parent. Ignore here by returning null,
      # body change will be generated later when it's removed.
      return null

    # Map raw XML model changes to Items. Also validate those changes, only
    # expect a few types of changes, XML model should never get arbitrarily
    # changed.

    if targetTag is 'LI'
      if type is 'attributes'
        mutation.type = Mutation.ATTRIBUTE_CHANGED
        mutation.attributeName = mutationRecord.attributeName
        mutation.attributeOldValue = mutationRecord.attributeOldValue
      else if type is 'childList'
        if mutationRecord.removedNodes.length is 1 && mutationRecord.addedNodes.length is 1 && mutationRecord.addedNodes[0].tagName is 'P'
          # updating bodyP through replacement
          mutation.type = Mutation.BODT_TEXT_CHANGED
        else
          return null # adding 'UL' ... ignore, li children will be added separate
      else
        throw new Error 'Unexpected Mutation: ' + mutationRecord

    else if targetTag is 'UL'
      if type != 'childList'
        throw new Error 'Unexpected Mutation: ' + mutationRecord

      for each in mutationRecord.removedNodes
        mutation.removedItems.push _item(each)

      for each in mutationRecord.addedNodes
        mutation.addedItems.push _item(each)

      mutation.previousSibling = _item(mutationRecord.previousSibling)
      mutation.nextSibling = _item(mutationRecord.nextSibling)
      mutation.type = Mutation.CHILDREN_CHANGED
    else
      throw new Error 'Unexpected Mutation: ' + mutationRecord

    mutation

  constructor: (mutationRecord) ->
    @_mutation = mutationRecord
    @addedItems = []
    @removedItems = []

_item = (domNode) ->
  while domNode
    if domNode._item
      return domNode._item
    domNode = domNode.parentNode