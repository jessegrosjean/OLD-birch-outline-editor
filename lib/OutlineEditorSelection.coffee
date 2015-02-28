# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

shallowEquals = require 'shallow-equals'
Constants = require './Constants'
assert = require 'assert'
Item = require './Item'

class OutlineEditorSelection
  constructor: (editor, focusItem, focusOffset, anchorItem, anchorOffset, rangeAffinity) ->
    if focusItem instanceof OutlineEditorSelection
      range = focusItem
      editor = range.editor
      focusItem = range.focusItem
      focusOffset = range.focusOffset
      anchorItem = range.anchorItem
      anchorOffset = range.anchorOffset
      rangeAffinity = range.rangeAffinity

    @editor = editor
    @focusItem = focusItem or null
    @focusOffset = focusOffset
    @rangeAffinity = rangeAffinity or null
    @anchorItem = anchorItem or null
    @anchorOffset = anchorOffset

    unless anchorItem
      @anchorItem = @focusItem
      @anchorOffset = @focusOffset

    unless @isValid
      @focusItem = null
      @focusOffset = undefined
      @anchorItem = null
      @anchorOffset = undefined

    @_calculateRangeItems()

  clientRectForItemOffset: (item, offset) ->
    outlineEditorElement = @editor.outlineEditorElement

    return undefined unless item
    viewP = outlineEditorElement.itemViewPForItem item
    return undefined unless viewP
    return undefined unless document.body.contains viewP

    bodyText = item.bodyText
    paddingBottom = 0
    paddingTop = 0
    computedStyle

    if offset != undefined
      positionedAtEndOfWrappingLine = false
      baseRect
      side

      if bodyText.length > 0
        domRange = document.createRange()
        startDOMNodeOffset
        endDOMNodeOffset

        if offset < bodyText.length
          startDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset)
          endDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset + 1)
          side = 'left'
        else
          startDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset - 1)
          endDOMNodeOffset = outlineEditorElement.itemOffsetToNodeOffset(item, offset)
          side = 'right'

        domRange.setStart(startDOMNodeOffset.node, startDOMNodeOffset.offset)
        domRange.setEnd(endDOMNodeOffset.node, endDOMNodeOffset.offset)

        # This is hacky, not sure what's going one, but seems to work.
        # The goal is to get a single zero width rect for cursor
        # position. This is complicated by fact that when a line wraps
        # two rects are returned, one for each possible location. That
        # ambiguity is solved by tracking rangeAffinity.
        #
        # The messy part is that there are other times that two client
        # rects get returned. Such as when the range start starts at the
        # end of a <b>. Seems we can just ignore those cases and return
        # the first rect. To detect those cases the check is
        # clientRects[0].top !== clientRects[1].top, because if that's
        # true then we can be at a line wrap.
        clientRects = domRange.getClientRects()
        baseRect = clientRects[0]
        #if clientRects.length > 1 and clientRects[0].top != clientRects[1].top
        if clientRects.length > 1
          alternateRect = clientRects[1]
          sameLine = baseRect.top is alternateRect.top
          if sameLine
            unless baseRect.width
              baseRect = alternateRect
          else if @rangeAffinity == Constants.SelectionAffinityUpstream
            positionedAtEndOfWrappingLine = true
          else
            baseRect = alternateRect
      else
        computedStyle = window.getComputedStyle(viewP)
        paddingTop = parseInt(computedStyle.paddingTop, 10)
        paddingBottom = parseInt(computedStyle.paddingBottom, 10)
        baseRect = viewP.getBoundingClientRect()
        side = 'left'

      return {} =
        positionedAtEndOfWrappingLine: positionedAtEndOfWrappingLine
        bottom: baseRect.bottom - paddingBottom
        height: baseRect.height - (paddingBottom + paddingTop)
        left: baseRect[side]
        right: baseRect[side] # trim
        top: baseRect.top + paddingTop
        width: 0 # trim
    else
      viewP.getBoundingClientRect()

`function _isValidSelectionOffset(editor, item, itemOffset) {
  if (item && editor.isVisible(item)) {
    if (itemOffset === undefined) {
      return true;
    } else {
      return itemOffset <= item.bodyText.length;
    }
  }
  return false;
}

Object.defineProperty(OutlineEditorSelection.prototype, 'isValid', {
  get: function () {
    return (
      _isValidSelectionOffset(this.editor, this.focusItem, this.focusOffset) &&
      _isValidSelectionOffset(this.editor, this.anchorItem, this.anchorOffset)
    );
  }
});

Object.defineProperty(OutlineEditorSelection.prototype, 'isCollapsed', {
  get: function () {
    return this.isTextMode && this.focusOffset === this.anchorOffset;
  }
});

Object.defineProperty(OutlineEditorSelection.prototype, 'isUpstreamAffinity', {
  get: function () {
    return this.rangeAffinity === Constants.SelectionAffinityUpstream;
  }
});

Object.defineProperty(OutlineEditorSelection.prototype, 'isItemMode', {
  get: function () {
    return this.isValid && (
      !!this.anchorItem &&
      !!this.focusItem &&
        (this.anchorItem !== this.focusItem ||
        this.anchorOffset === undefined && this.focusOffset === undefined)
    );
  }
});

Object.defineProperty(OutlineEditorSelection.prototype, 'isTextMode', {
  get: function () {
    return this.isValid && (
      !!this.anchorItem &&
      this.anchorItem === this.focusItem &&
      this.anchorOffset !== undefined &&
      this.focusOffset !== undefined
    );
  }
});

Object.defineProperty(OutlineEditorSelection.prototype, 'isReversed', {
  get: function () {
    var focusItem = this.focusItem,
      anchorItem = this.anchorItem;

    if (focusItem === anchorItem) {
      return (
        this.focusOffset !== undefined &&
        this.anchorOffset !== undefined &&
        this.focusOffset < this.anchorOffset
      );
    }

    return (
      focusItem &&
      anchorItem &&
      !!(focusItem.comparePosition(anchorItem) & Node.DOCUMENT_POSITION_FOLLOWING)
    );
  }
});

Object.defineProperty(OutlineEditorSelection.prototype, 'focusClientRect', {
  get: function () {
    return this.clientRectForItemOffset(this.focusItem, this.focusOffset);
  }
});

Object.defineProperty(OutlineEditorSelection.prototype, 'anchorClientRect', {
  get: function () {
    return this.clientRectForItemOffset(this.anchorItem, this.anchorOffset);
  }
});



OutlineEditorSelection.prototype.equals = function(otherSelection) {
  return (
    this.focusItem === otherSelection.focusItem &&
    this.focusOffset === otherSelection.focusOffset &&
    this.anchorItem === otherSelection.anchorItem &&
    this.anchorOffset === otherSelection.anchorOffset &&
    this.rangeAffinity === otherSelection.rangeAffinity &&
    shallowEquals(this.rangeItems, otherSelection.rangeItems)
  );
};

OutlineEditorSelection.prototype.rangeByExtending = function(newFocusItem, newFocusOffset, newSelectionAffinity) {
  return new OutlineEditorSelection(
    this.editor,
    newFocusItem,
    newFocusOffset,
    this.anchorItem,
    this.anchorOffset,
    newSelectionAffinity || this.rangeAffinity
  );
};

OutlineEditorSelection.prototype.selectionByModifying = function(alter, direction, granularity) {
  var extending = alter === 'extend',
    next = this.nextItemOffsetInDirection(direction, granularity, extending);

  if (extending) {
    return this.rangeByExtending(next.offsetItem, next.offset, next.rangeAffinity);
  } else {
    return new OutlineEditorSelection(
      this.editor,
      next.offsetItem,
      next.offset,
      next.offsetItem,
      next.offset,
      next.rangeAffinity
    );
  }
};

OutlineEditorSelection.prototype.rangeByRevalidating = function() {
  var editor = this.editor,
    sortedVisibleItems = this.rangeItems.filter(function (each) {
      return editor.isVisible(each);
    }).sort(function (a, b) {
      //debugger;
      return (a.comparePosition(b) & Node.DOCUMENT_POSITION_PRECEDING);
    });

  if (shallowEquals(this.rangeItems, sortedVisibleItems)) {
    return this;
  }

  var result = new OutlineEditorSelection(
    this.editor,
    sortedVisibleItems[0],
    undefined,
    sortedVisibleItems[sortedVisibleItems.length - 1],
    undefined,
    this.rangeAffinity
  );

  result._calculateRangeItems(sortedVisibleItems);

  return result;
};

OutlineEditorSelection.prototype.rangeByDeleting = function(direction, granularity) {
  if (this.isTextMode) {

  } else {

  }
};

OutlineEditorSelection.prototype.nextItemOffsetInDirection = function(direction, granularity, extending) {
  if (this.isItemMode) {
    switch (granularity) {
      case 'sentenceboundary':
      case 'lineboundary':
      case 'character':
      case 'word':
      case 'sentence':
      case 'line':
        granularity = 'paragraphboundary';
    }
  }

  var editor = this.editor,
    focusItem = this.focusItem,
    focusOffset = this.focusOffset,
    anchorOffset = this.anchorOffset,
    outlineEditorElement = this.editor.outlineEditorElement,
    upstream = OutlineEditorSelection.isUpstreamDirection(direction),
    next = {
      rangeAffinity: Constants.SelectionAffinityDownstream // All movements have downstream affinity except for line and lineboundary
    };

  if (!focusItem) {
    next.offsetItem = upstream ? editor.lastVisibleItem() : editor.firstVisibleItem();
  } else {
    if (!extending) {
      focusItem = upstream ? this.startItem : this.endItem;
    }

    next.offsetItem = focusItem;

    switch (granularity) {
    case 'sentenceboundary':
      next.offset = nextSelectionIndexFrom(
        focusItem.bodyText,
        focusOffset,
        upstream ? 'backward' : 'forward',
        granularity
      );
      break;

    case 'lineboundary':
      var currentRect = this.clientRectForItemOffset(focusItem, focusOffset);
      if (currentRect) {
        next = outlineEditorElement.pick(
          upstream ? Number.MIN_VALUE : Number.MAX_VALUE,
          currentRect.top + currentRect.height / 2.0
        ).itemCaretPosition;
      }
      break;

    case 'paragraphboundary':
      next.offset = upstream ? 0 : focusItem.bodyText.length;
      break;

    case 'character':
      if (upstream) {
        if (!this.isCollapsed && !extending) {
          if (focusOffset < anchorOffset) {
            next.offset = focusOffset;
          } else {
            next.offset = anchorOffset;
          }
        } else {
          if (focusOffset > 0) {
            next.offset = focusOffset - 1;
          } else {
            var prevItem = editor.previousVisibleItem(focusItem);
            if (prevItem) {
              next.offsetItem = prevItem;
              next.offset = prevItem.bodyText.length;
            }
          }
        }
      } else {
        if (!this.isCollapsed && !extending) {
          if (focusOffset > anchorOffset) {
            next.offset = focusOffset;
          } else {
            next.offset = anchorOffset;
          }
        } else {
          if (focusOffset < focusItem.bodyText.length) {
            next.offset = focusOffset + 1;
          } else {
            var nextItem = editor.nextVisibleItem(focusItem);
            if (nextItem) {
              next.offsetItem = nextItem;
              next.offset = 0;
            }
          }
        }
      }
      break;

    case 'word':
    case 'sentence':
      next.offset = nextSelectionIndexFrom(
        focusItem.bodyText,
        focusOffset,
        upstream ? 'backward' : 'forward',
        granularity
      );

      if (next.offset === focusOffset) {
        var nextItem = upstream ? editor.previousVisibleItem(focusItem) : editor.nextVisibleItem(focusItem);
        if (nextItem) {
          var editorRange = new OutlineEditorSelection(this.editor, nextItem, upstream ? nextItem.bodyText.length : 0);
          editorRange = editorRange.selectionByModifying('move', upstream ? 'backward' : 'forward', granularity);
          next = {
            offsetItem: editorRange.focusItem,
            offset: editorRange.focusOffset,
            rangeAffinity: editorRange.rangeAffinity
          };
        }
      }
      break;

    case 'line':
      next = this.nextItemOffsetByLineFromFocus(focusItem, focusOffset, direction);
      break;

    case 'paragraph':
      var prevItem = upstream ? editor.previousVisibleItem(focusItem) : editor.nextVisibleItem(focusItem);
      if (prevItem) {
        next.offsetItem = prevItem;
      }
      break;

    case 'branch':
      var prevItem = upstream ? editor.previousVisibleBranch(focusItem) : editor.nextVisibleBranch(focusItem);
      if (prevItem) {
        next.offsetItem = prevItem;
      }
      break;

    case 'list':
      if (upstream) {
        next.offsetItem = editor.firstVisibleChild(focusItem.parent);
        if (!next.offsetItem) {
          next = this.nextItemOffsetUpstream(direction, 'branch', extending);
        }
      } else {
        next.offsetItem = editor.lastVisibleChild(focusItem.parent);
        if (!next.offsetItem) {
          next = this.nextItemOffsetDownstream(direction, 'branch', extending);
        }
      }
      break;

    case 'parent':
      next.offsetItem = editor.visibleParent(focusItem);
      if (!next.offsetItem) {
        next = this.nextItemOffsetUpstream(direction, 'branch', extending);
      }
      break;

    case 'firstchild':
      next.offsetItem = editor.firstVisibleChild(focusItem);
      if (!next.offsetItem) {
        next = this.nextItemOffsetDownstream(direction, 'branch', extending);
      }
      break;

    case 'lastchild':
      next.offsetItem = editor.lastVisibleChild(focusItem);
      if (!next.offsetItem) {
        next = this.nextItemOffsetDownstream(direction, 'branch', extending);
      }
      break;

    case 'documentboundary':
      next.offsetItem = upstream ? editor.firstVisibleItem() : editor.lastVisibleItem();
      break;

    default:
      throw 'Unexpected Granularity ' + granularity;
    }

    if (!next.offsetItem && !extending) {
      next.offsetItem = focusItem;
    }
  }

  if (this.isTextMode && next.offset === undefined) {
    next.offset = upstream ? 0 : next.offsetItem.bodyText.length;
  }

  return next;
};

OutlineEditorSelection.prototype.nextItemOffsetByLineFromFocus = function(focusItem, focusOffset, direction) {
  var editor = this.editor,
    outlineEditorElement = editor.outlineEditorElement,
    upstream = OutlineEditorSelection.isUpstreamDirection(direction),
    focusViewP = outlineEditorElement.itemViewPForItem(focusItem),
    focusViewPRect = focusViewP.getBoundingClientRect(),
    focusViewPStyle = window.getComputedStyle(focusViewP),
    viewLineHeight = parseInt(focusViewPStyle.lineHeight, 10),
    viewPaddingTop = parseInt(focusViewPStyle.paddingTop, 10),
    viewPaddingBottom = parseInt(focusViewPStyle.paddingBottom, 10),
    focusCaretRect = this.clientRectForItemOffset(focusItem, focusOffset),
    x = editor.selectionVerticalAnchor(),
    y;

  if (upstream) {
    y = focusCaretRect.bottom - (viewLineHeight * 1.5);
  } else {
    y = focusCaretRect.bottom + (viewLineHeight / 2.0);
  }

  var picked;

  if (y >= (focusViewPRect.top + viewPaddingTop) && y <= (focusViewPRect.bottom - viewPaddingBottom)) {
    picked = outlineEditorElement.pick(x, y).itemCaretPosition;
  } else {
    var nextItem;

    if (upstream) {
      nextItem = editor.previousVisibleItem(focusItem);
    } else {
      nextItem = editor.nextVisibleItem(focusItem);
    }

    if (nextItem) {
      editor.scrollToItemIfNeeded(nextItem); // pick breaks for offscreen items

      var nextItemTextRect = outlineEditorElement.itemViewPForItem(nextItem).getBoundingClientRect();

      if (upstream) {
        y = nextItemTextRect.bottom - 1;
      } else {
        y = nextItemTextRect.top + 1;
      }

      picked = outlineEditorElement.pick(x, y).itemCaretPosition;
    } else {
      if (upstream) {
        picked = {
          offsetItem: focusItem,
          offset: 0
        };
      } else {
        picked = {
          offsetItem: focusItem,
          offset: focusItem.bodyText.length
        };
      }
    }

  }

  return picked;
};

OutlineEditorSelection.prototype._calculateRangeItems = function(overRideRangeItems) {
  var rangeItems = overRideRangeItems || [];

  if (this.isValid && !overRideRangeItems) {
    var editor = this.editor,
      focusItem = this.focusItem,
      anchorItem = this.anchorItem,
      startItem = anchorItem,
      endItem = focusItem;

    if (this.isReversed) {
      startItem = focusItem;
      endItem = anchorItem;
    }

    var each = startItem;
    while (each) {
      rangeItems.push(each);
      if (each === endItem) {
        break;
      }
      each = editor.nextVisibleItem(each);
    }
  }

  this.rangeItems = rangeItems;
  this.rangeItemsCover = Item.commonAncestors(rangeItems);
  this.startItem = rangeItems[0];
  this.endItem = rangeItems[rangeItems.length - 1];

  if (this.isReversed) {
    this.startOffset = this.focusOffset;
    this.endOffset = this.anchorOffset;
  } else {
    this.startOffset = this.anchorOffset;
    this.endOffset = this.focusOffset;
  }

  if (this.isTextMode) {
    if (this.startOffset > this.endOffset) {
      throw "Unexpected";
    }
  }
};

//
// Debug
//

OutlineEditorSelection.prototype.toString = function(indent) {
  var focusItem = this.focusItem,
    anchorItem = this.anchorItem;

  return (
    'anchor: ' + (anchorItem ? anchorItem.id : 'none') + ',' +
    this.anchorOffset + ' ' +
    'focus: ' + (focusItem ? focusItem.id : 'none') + ',' +
    this.focusOffset + ' '
  );
};

//
// Util
//

OutlineEditorSelection.isUpstreamDirection = function isUpstreamDirection(direction) {
  return direction === 'backward' || direction === 'left' || direction === 'up';
};

OutlineEditorSelection.isDownstreamDirection = function isDownstreamDirection(direction) {
  return direction === 'forward' || direction === 'right' || direction === 'down';
};

function nextSelectionIndexFrom(text, index, direction, granularity) {
  assert(index >= 0 && index <= text.length, 'Invalid Index');

  if (text.length === 0) {
    return 0;
  }

  var iframe = document.getElementById('textIteratorIFrame');
  if (!iframe) {
    iframe = document.createElement("iframe");
    iframe.id = 'textIteratorIFrame';
    document.body.appendChild(iframe);
    iframe.contentWindow.document.body.appendChild(iframe.contentWindow.document.createElement('P'));
  }

  var iframeWindow = iframe.contentWindow,
    iframeDocument = iframeWindow.document,
    selection = iframeDocument.getSelection(),
    range = iframeDocument.createRange(),
    iframeBody = iframeDocument.body,
    p = iframeBody.firstChild,
    result;

  p.textContent = text;
  range.setStart(p.firstChild, index);
  selection.removeAllRanges();
  selection.addRange(range);
  selection.modify('move', direction, granularity);

  result = selection.focusOffset;

  return result;
}

module.exports = OutlineEditorSelection;`