# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

_GlobalMouseDown = 0
_GlobalMouseButton = 0

isGlobalMouseDown = ->
  _GlobalMouseDown > 0

isGlobalLeftMouseDown = ->
  isGlobalMouseDown() and _GlobalMouseButton is 0

isGlobalWheelMouseDown = ->
  isGlobalMouseDown() and _GlobalMouseButton is 1

isGlobalRightMouseDown = ->
  isGlobalMouseDown() and _GlobalMouseButton is 2

handleGlobalMouseDown = (e) ->
  ++_GlobalMouseDown
  _GlobalMouseButton = e.button

handleGlobalMouseUp = (e) ->
  --_GlobalMouseDown

document.addEventListener 'mousedown', handleGlobalMouseDown, true
document.addEventListener 'mouseup', handleGlobalMouseUp, true

`
var Constants = require('./Constants'),
	raf = require('raf');

if (typeof Array.prototype.lastObject !== 'function') {
	Array.prototype.lastObject = function () {
		return this[this.length - 1];
	};
}

if (typeof Array.prototype.sortedIndex !== 'function') {
	Array.prototype.sortedIndex = function (value, sortfunction) {
		var low = 0, high = this.length;
		while (low < high) {
			/*jshint bitwise: false */
			var mid = (low + high) >> 1;
			/*jshint bitwise: true */
			var less = false;

			if (sortfunction !== undefined) {
				if (sortfunction(this[mid], value) < 0) {
					less = true;
				}
			} else {
				if (this[mid] < value) {
					less = true;
				}
			}

			if (less) {
				low = mid + 1;
			} else {
				high = mid;
			}
		}
		return low;
	};
}


if (typeof Array.prototype.shallowEquals !== 'function') {
	Array.prototype.shallowEquals = function (array) {
		if (this === array) { return true; }
		if (this.length !== array.length) { return false; }
		for (var i = 0; i < this.length; ++i) {
			if (this[i] !== array[i]) {
				return false;
			}
		}
		return true;
	};
}

if (typeof Array.prototype.sortedContains !== 'function') {
	Array.prototype.sortedContains = function (value, sortfunction) {
		return this[this.sortedIndex(value, sortfunction)] === value;
	};
}

if (typeof Array.prototype.sortedAdd !== 'function') {
	Array.prototype.sortedAdd = function (value, noDuplicates, sortfunction) {
		var index = this.sortedIndex(value, sortfunction);
		if (noDuplicates && this[index] === value) {
			return;
		}
		this.splice(index, 0, value);
	};
}

if (typeof Array.prototype.sortedRemove !== 'function') {
	Array.prototype.sortedRemove = function (value, sortfunction) {
		var index = this.sortedIndex(value, sortfunction);
		if (this[index] === value) {
			this.splice(index, 1);
		}
	};
}

function removeObject(member, array) {
	var index = array.indexOf(member);
	if (index > -1) {
		array.splice(index, 1);
	}
	return array;
}

function previousNode(node) {
	var parent,
		previousSibling = node.previousSibling;
	if (previousSibling) {
		return lastDescendantNodeOrSelf(previousSibling);
	} else {
		parent = node.parentNode;
		if (!parent) {
			return null;
		} else {
			return parent;
		}
	}
}

function nextNode(node) {
	var firstChild = node.firstChild;
	if (firstChild) {
		return firstChild;
	}
	var nextSibling = node.nextSibling;
	if (nextSibling) {
		return nextSibling;
	}
	var parent = node.parentNode;
	while (parent) {
		nextSibling = parent.nextSibling;
		if (nextSibling) {
			return nextSibling;
		}
		parent = parent.parentNode;
	}
	return null;
}

function nodeNextBranch(node) {
	if (node.nextSibling) return node.nextSibling;

	var p = node.parentNode;
	while (p) {
		if (p.nextSibling) {
			return p.nextSibling;
		}
		p = p.parentNode;
	}
	return null;
}

function lastDescendantNodeOrSelf(node) {
	var each = node,
		lastChild = each.lastChild;
	while (lastChild) {
		each = lastChild;
		lastChild = each.lastChild;
	}
	return each;
}

/*function ancestorEncodedLength(ancestor) {
	if (ancestor) {
		var end = nodeNextBranch(ancestor),
			each = ancestor,
			nodeType,
			length = 0;

		while (each !== end) {
			nodeType = each.nodeType;

			if (nodeType === Node.TEXT_NODE) {
				length += each.nodeValue.length;
			} else if (nodeType === Node.ELEMENT_NODE && !each.firstChild) {
				// Count leaf elements with no text as 1
				length += 1;
			}
			each = nextNode(each);
		}
		return length;
	}
	return undefined;
}

function ancestorEncodedTextContent(ancestor) {
	if (ancestor) {
		var end = nodeNextBranch(ancestor),
			each = ancestor,
			nodeType,
			text = [];

		while (each !== end) {
			nodeType = each.nodeType;

			if (nodeType === Node.TEXT_NODE) {
				text.push(each.nodeValue);
			} else if (nodeType === Node.ELEMENT_NODE && !each.firstChild) {
				if (each.tagName === 'br') {
					text.push(Constants.LineSeparatorCharacter);
				} else {
					text.push(Constants.ObjectReplacementCharacter);
				}
			}
			each = nextNode(each);
		}
		return text.join('');
	}
	return '';
}

function nodeOffsetToAncestorEncodedOffset(node, offset, ancestor) {
	if (node && ancestor && ancestor.contains(node)) {
		if (offset > 0 && node.nodeType === Node.ELEMENT_NODE) {
			node = node.firstChild;
			while (offset) {
				node = node.nextSibling;
				offset--;
			}
		}

		var each = node,
			nodeType,
			length;

		while (each !== ancestor) {
			length = 0;
			nodeType = each.nodeType;

			if (nodeType === Node.TEXT_NODE) {
				if (each !== node) {
					offset += each.nodeValue.length;
				}
			} else if (nodeType === Node.ELEMENT_NODE && each.textContent.length === 0 && !each.firstElementChild) {
				// Count leaf elements with no text as 1
				offset++;
			}

			each = previousNode(each);
		}

		return offset;
	}
	return undefined;
}

function _childIndeOf(node) {
	var index = 0;
	while((node = node.previousSibling) !== null) {
		index++;
	}
	return index;
}

function ancestorEncodedOffsetToNodeOffset(ancestor, offset, downstreamAffinity) {
	if (ancestor) {
		var end = nodeNextBranch(ancestor),
			each = ancestor,
			nodeType,
			length;

		while (each !== end) {
			length = 0;
			nodeType = each.nodeType;

			if (nodeType === Node.TEXT_NODE) {
				length = each.nodeValue.length;
			} else if (nodeType === Node.ELEMENT_NODE && !each.firstChild) {
				// Count leaf elements with no text as 1
				length = 1;
				if (length === offset) {
					return {
						node: each.parentNode,
						offset: _childIndeOf(each) + 1
					}
				}
			}

			if (length < offset) {
				offset -= length;
			} else {
				if (downstreamAffinity && length === offset) {
					var next = nextNode(each);
					if (next) {
						if (next.nodeType === Node.ELEMENT_NODE && !next.firstChild) {
							each = next.parentNode;
							offset = _childIndeOf(next);
						} else {
							each = next;
							offset = 0;
						}
					}
				}

				return {
					node: each,
					offset: offset
				}
			}

			each = nextNode(each);
		}
	}
	return undefined;
}*/

function childIndeOf(node) {
	var index = 0;
	while((node = node.previousSibling) !== null) {
		index++;
	}
	return index;
}

/*function debounce(fn, now) {
	var args = null;
	var ctx = null;

	return debounced;

	function debounced() {
		if (args !== null) return;
		args = Array.prototype.slice.call(arguments);
		ctx = this;
		if (now) fn.apply(ctx, args);
		raf(next);
	}

	function next() {
		if (!now) fn.apply(ctx, args);
		args = null;
		ctx = null;
	}
}*/

// http://davidwalsh.name/javascript-debounce-function
//
// Returns a function, that, as long as it continues to be invoked, will not
// be triggered. The function will be called after it stops being called for N
// milliseconds. If immediate is passed, trigger the function on the leading
// edge, instead of the trailing.
function debounce(func, wait, immediate) {
	var timeout;
	return function() {
		var context = this,
			args = arguments,
			later = function() {
				timeout = null;
				if (!immediate) {
					func.apply(context, args);
				}
			};

		var callNow = immediate && !timeout;

		if (wait === undefined) {
			raf.cancel(timeout);
			timeout = raf(later);
		} else {
			clearTimeout(timeout);
			timeout = setTimeout(later, wait);
		}

		if (callNow) {
			func.apply(context, args);
		}
	};
}

function removeFromDOM(element) {
	var p = element.parentNode;
	if (p) {
		p.removeChild(element);
	}
}

function removeBranchIDs(element) {
	var end = nodeNextBranch(element),
		each = element;

	while (each !== end) {
		if (each.id) {
			each.removeAttribute('id');
		}
		each = nextNode(each);
	}
}

function getClipboarData(e) {
	var clipboardData = e.clipboardData;
	if (!clipboardData && typeof atom !== 'undefined') {
		var clipboard = atom.clipboard;
		return {
			getData: function(type) {
				return clipboard.read();
			},
			setData: function(type, text) {
				clipboard.write(text);
			}
		};
	}
	return clipboardData;
}

module.exports = {
	isGlobalMouseDown: isGlobalMouseDown,
	isGlobalLeftMouseDown: isGlobalLeftMouseDown,
	isGlobalWheelMouseDown: isGlobalWheelMouseDown,
	isGlobalRightMouseDown: isGlobalRightMouseDown,
	getClipboarData: getClipboarData,
	removeBranchIDs: removeBranchIDs,
	removeFromDOM: removeFromDOM,
	removeObject: removeObject,
	childIndeOf: childIndeOf,
	previousNode: previousNode,
	nextNode: nextNode,
	nodeNextBranch: nodeNextBranch,
	lastDescendantNodeOrSelf: lastDescendantNodeOrSelf,
	debounce: debounce
	//ancestorEncodedLength: ancestorEncodedLength,
	//ancestorEncodedTextContent: ancestorEncodedTextContent,
	//nodeOffsetToAncestorEncodedOffset: nodeOffsetToAncestorEncodedOffset,
	//ancestorEncodedOffsetToNodeOffset: ancestorEncodedOffsetToNodeOffset
};
`