# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

assert = require 'assert'

# Public: Outline Change Delta.
#
# Represents a single change in a target {Item}. There are three types of
# changes that can occure: an attribute changed, the body text changed, or the
# item's children changed.
#
# See {Outline} Examples for an example of subscribing to {OutlineChange}s.
class OutlineChangeDelta

  # Public: Read-only type of change. `attributes`, 'bodyText', or 'children'.
  type: null

  # Public: Read-only target {Item} of change.
  target: null

  # Public: Read-only {Item} children added to target.
  addedItems: null

  # Public: Read-only {Item} children removed from target.
  removedItems: null

  # Public: Read-only previous sibling of the added or removed Items, or null.
  previousSibling: null

  # Public: Read-only next sibling of the added or removed Items, or null.
  nextSibling: null

  # Public: Read-only name of changed attribute, or null.
  attributeName: null

  # Public: Read-only previous value of changed attribute, or null.
  attributeOldValue: null

  constructor: (mutation) ->
    @_mutation = mutation
    @addedItems = []
    @removedItems = []

`
function error() {
  throw 'Unexpected Mutation: ' + mutation;
};

OutlineChangeDelta.createFromDOMMutation = function(mutation) {
  var type = mutation.type,
    target = mutation.target,
    targetTag = target.tagName,
    delta = new OutlineChangeDelta(mutation);

  delta.target = _item(target);

  if (!delta.target) {
    // Must be a body child node that is later removed, so at this point
    // it's no longer connected to a parent. Ignore here by returning null,
    // body change will be generated later when it's removed.
    return null;
  }

  // Map raw XML model changes to Items. Also validate those changes, only
  // expect a few types of changes, XML model should never get arbitrarily
  // changed.

  if (targetTag === 'LI') {
    if (type === 'attributes') {
      delta.type = OutlineChangeDelta.AttributeChanged;
      delta.attributeName = mutation.attributeName;
      delta.attributeOldValue = mutation.attributeOldValue;
    } else if (type === 'childList') {
      if (mutation.removedNodes.length === 1 && mutation.addedNodes.length === 1 && mutation.addedNodes[0].tagName === 'P') {
        // updating bodyP through replacement
        delta.type = OutlineChangeDelta.BodyTextChanged;
      } else {
        return null; // adding 'UL' ... ignore, li children will be added separate
      }
    } else {
      error();
    }
  } else if (targetTag === 'UL') {
    if (type !== 'childList') {
      error();
    }

    var removedNodes = mutation.removedNodes,
      removedLength = removedNodes.length;
    if (removedLength) {
      for (var i = 0; i < removedLength; i++) {
        delta.removedItems.push(_item(removedNodes[i]));
      }
    }

    var addedNodes = mutation.addedNodes,
      addedLength = addedNodes.length;
    if (addedLength) {
      for (var i = 0; i < addedLength; i++) {
        delta.addedItems.push(_item(addedNodes[i]));
      }
    }

    delta.previousSibling = _item(mutation.previousSibling);
    delta.nextSibling = _item(mutation.nextSibling);
    delta.type = OutlineChangeDelta.ChildrenChanged;
  } else {
    throw 'Unexpected';
  }

  return delta;
};

function _item(xmlNode) {
  while (xmlNode) {
    if (xmlNode._item) {
      return xmlNode._item;
    }
    xmlNode = xmlNode.parentNode;
  }
  return null;
};

OutlineChangeDelta.AttributeChanged = 'attribute';
OutlineChangeDelta.BodyTextChanged = 'bodyText';
OutlineChangeDelta.ChildrenChanged = 'children';

module.exports = OutlineChangeDelta;
`