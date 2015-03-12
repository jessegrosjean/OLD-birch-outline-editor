# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

AttributedString = require './AttributedString'
Constants = require './Constants'
deepEqual = require 'deep-equal'
assert = require 'assert'
Util = require './Util'

attributedStringToDocumentFragment = (attributedString, ownerDocument) ->
  attributedString._ensureClean()
  nodeRanges = _calculateInitialNodeRanges attributedString, ownerDocument
  nodeRangeStack = [
    start: 0
    end: attributedString.length
    node: ownerDocument.createDocumentFragment()
  ]
  _buildFragmentFromNodeRanges nodeRanges, nodeRangeStack, ownerDocument

# For each attribute run create element nodes for each attribute and text node
# for the text content. Store node along with range over which is should be
# applied. Return sorted node ranages.
_calculateInitialNodeRanges = (attributedString, ownerDocument) ->
  string = attributedString.string()
  tagsToRanges = {}
  nodeRanges = []
  runIndex = 0

  for run in attributedString.attributeRuns()
    for tag, tagAttributes of run.attributes
      nodeRange = tagsToRanges[tag]
      if !nodeRange or nodeRange.end <= run.location
        assert(tag is tag.toUpperCase(), 'Tags Names Must be Uppercase')

        element = ownerDocument.createElement tag
        if tagAttributes
          for attrName, attrValue of tagAttributes
            element.setAttribute attrName, attrValue

        nodeRange =
          node: element
          start: run.location
          end: _seekTagRangeEnd tag, tagAttributes, runIndex, attributedString

        tagsToRanges[tag] = nodeRange
        nodeRanges.push nodeRange

    text = string.substr run.location, run.length
    if text != Constants.ObjectReplacementCharacter and text != Constants.LineSeparatorCharacter
      nodeRanges.push
        start: run.location
        end: run.location + run.length
        node: ownerDocument.createTextNode(text)

    runIndex++

  nodeRanges.sort _compareNodeRanges
  nodeRanges

_seekTagRangeEnd = (tagName, seekTagAttributes, runIndex, attributedString) ->
  attributeRuns = attributedString.attributeRuns()
  end = attributeRuns.length
  while true
    run = attributeRuns[runIndex++]
    runTagAttributes = run.attributes[tagName]
    equalAttributes = runTagAttributes is seekTagAttributes or deepEqual(runTagAttributes, seekTagAttributes)
    unless equalAttributes
      return run.location
    else if runIndex is end
      return run.location + run.length

_compareNodeRanges = (a, b) ->
  if a.start < b.start
    -1
  else if a.start > b.start
    1
  else if a.end != b.end
    b.end - a.end
  else
    aNodeType = a.node.nodeType
    bNodeType = b.node.nodeType
    if aNodeType != bNodeType
      if aNodeType is Node.TEXT_NODE
        1
      else if bNodeType is Node.TEXT_NODE
        -1
      else
        aTagName = a.node.tagName
        bTagName = b.node.tagName
        if aTagName < bTagName
          -1
        else if aTagName > bTagName
          1
        else
          0
    else
      0

_buildFragmentFromNodeRanges = (nodeRanges, nodeRangeStack, ownerDocument) ->
  i = 0
  while i < nodeRanges.length
    range = nodeRanges[i++]
    parentRange = nodeRangeStack.pop()
    while nodeRangeStack.length and parentRange.end <= range.start
      parentRange = nodeRangeStack.pop()

    if range.end > parentRange.end
      # In this case each has started inside current parent tag, but
      # extends past. Must split this node range into two. Process
      # start part of split here, and insert end part in correct
      # postion (after current parent) to be processed later.
      splitStart = range
      splitEnd =
        end: splitStart.end
        start: parentRange.end
        node: splitStart.node.cloneNode(true)
      splitStart.end = parentRange.end
      # Insert splitEnd after current parent in correct location.
      j = nodeRanges.indexOf parentRange
      while _compareNodeRanges(nodeRanges[j], splitEnd) < 0
        j++
      nodeRanges.splice(j, 0, splitEnd)

    parentRange.node.appendChild range.node
    nodeRangeStack.push parentRange
    nodeRangeStack.push range

  nodeRangeStack[0].node
`


function elementToAttributedString(element, innerHTML) {
  var attributedString = new AttributedString();

  if (innerHTML) {
    var each = element.firstChild;
    while (each) {
      _addDOMNodeToAttributedString(each, attributedString);
      each = each.nextSibling;
    }
  } else {
    _addDOMNodeToAttributedString(element, attributedString);
  }

  return attributedString;
}

var allowedTags = {
  'A': true,
  'ABBR': true,
  'B': true,
  'BDI': true,
  'BDO': true,
  'BR': true,
  'CITE': true,
  'CODE': true,
  'DATA': true,
  'DFN': true,
  'EM': true,
  'I': true,
  'KBD': true,
  'MARK': true,
  'Q': true,
  'RP': true,
  'RT': true,
  'RUBY': true,
  'S': true,
  'SAMP': true,
  'SMALL': true,
  'SPAN': true,
  'STRONG': true,
  'SUB': true,
  'SUP': true,
  'TIME': true,
  'U': true,
  'VAR': true,
  'WBR': true,

  'IMG': true
};

function _addDOMNodeToAttributedString(node, attributedString) {
  var nodeType = node.nodeType;

  if (nodeType === Node.TEXT_NODE) {
    attributedString.appendString(new AttributedString(node.nodeValue.replace(/(\r\n|\n|\r)/gm,'')));
  } else if (nodeType === Node.ELEMENT_NODE) {
    var tagStart = attributedString.length,
      each = node.firstChild;

    if (each) {
      while (each) {
        _addDOMNodeToAttributedString(each, attributedString);
        each = each.nextSibling;
      }

      if (allowedTags[node.tagName]) {
        attributedString.addAttributeInRange(node.tagName, _elementAttributes(node), tagStart, attributedString.length - tagStart);
      }
    } else if (allowedTags[node.tagName]) {
      if (node.tagName === 'BR') {
        var lineBreak = new AttributedString(Constants.LineSeparatorCharacter);
        lineBreak.addAttributeInRange('BR', _elementAttributes(node), 0, 1);
        attributedString.appendString(lineBreak);
      } else if (node.tagName === 'IMG') {
        var image = new AttributedString(Constants.ObjectReplacementCharacter);
        image.addAttributeInRange('IMG', _elementAttributes(node), 0, 1);
        attributedString.appendString(image);
      }
    }
  }
}

function _elementAttributes(element) {
  if (element.hasAttributes()) {
    var attrs = element.attributes,
      result = {};
    for (var i = attrs.length - 1; i >= 0; i--) {
        result[attrs[i].name] = attrs[i].value;
    }
    return result;
  }
  return null;
}

function nodeOffsetToBodyTextOffset(node, offset, bodyP) {
  if (node && bodyP && bodyP.contains(node)) {
    // If offset is > 0 and node is an element then map to child node
    // possition such that a backward walk from that node will cross over
    // all relivant text and void nodes.
    if (offset > 0 && node.nodeType === Node.ELEMENT_NODE) {
      var childAtOffset = node.firstChild;
      while (offset) {
        childAtOffset = childAtOffset.nextSibling;
        offset--;
      }

      if (childAtOffset) {
        node = childAtOffset;
      } else {
        node = Util.lastDescendantNodeOrSelf(node.lastChild);
      }
    }

    // Walk backward to bodyP summing text characters and void elements
    // inbetween.
    var each = node,
      nodeType,
      length;

    while (each !== bodyP) {
      length = 0;
      nodeType = each.nodeType;

      if (nodeType === Node.TEXT_NODE) {
        if (each !== node) {
          offset += each.nodeValue.length;
        }
      } else if (nodeType === Node.ELEMENT_NODE && each.textContent.length === 0 && !each.firstElementChild) {
        var tagName = each.tagName;
        if (tagName === 'BR' || tagName === 'IMG') {
          // Count void tags as 1
          offset++;
        }
      }

      each = Util.previousNode(each);
    }

    return offset;
  }
  return undefined;
}

function bodyTextOffsetToNodeOffset(bodyP, offset, downstreamAffinity) {
  if (bodyP) {
    var end = Util.nodeNextBranch(bodyP),
      each = bodyP,
      nodeType,
      length;

    while (each !== end) {
      length = 0;
      nodeType = each.nodeType;

      if (nodeType === Node.TEXT_NODE) {
        length = each.nodeValue.length;
      } else if (nodeType === Node.ELEMENT_NODE && !each.firstChild) {
        var tagName = each.tagName;

        if (tagName === 'BR' || tagName === 'IMG') {
          // Count void tags as 1
          length = 1;
          if (length === offset) {
            return {
              node: each.parentNode,
              offset: Util.childIndeOf(each) + 1
            };
          }
        }
      }

      if (length < offset) {
        offset -= length;
      } else {
        if (downstreamAffinity && length === offset) {
          var next = Util.nextNode(each);
          if (next) {
            if (next.nodeType === Node.ELEMENT_NODE && !next.firstChild) {
              each = next.parentNode;
              offset = Util.childIndeOf(next);
            } else {
              each = next;
              offset = 0;
            }
          }
        }

        return {
          node: each,
          offset: offset
        };
      }

      each = Util.nextNode(each);
    }
  }
  return undefined;
}

function bodyEncodedTextContent(node) {
  if (node) {
    var end = Util.nodeNextBranch(node),
      each = node,
      nodeType,
      text = [];

    while (each !== end) {
      nodeType = each.nodeType;

      if (nodeType === Node.TEXT_NODE) {
        text.push(each.nodeValue);
      } else if (nodeType === Node.ELEMENT_NODE && !each.firstChild) {
        var tagName = each.tagName;

        if (tagName === 'BR') {
          text.push(Constants.LineSeparatorCharacter);
        } else if (tagName === 'IMG') {
          text.push(Constants.ObjectReplacementCharacter);
        }
      }
      each = Util.nextNode(each);
    }
    return text.join('');
  }
  return '';
}

module.exports = {
  attributedStringToDocumentFragment: attributedStringToDocumentFragment,
  elementToAttributedString: elementToAttributedString,
  nodeOffsetToBodyTextOffset: nodeOffsetToBodyTextOffset,
  bodyTextOffsetToNodeOffset: bodyTextOffsetToNodeOffset,
  bodyEncodedTextContent: bodyEncodedTextContent
};`