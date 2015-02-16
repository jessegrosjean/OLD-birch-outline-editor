// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

var AttributedString = require('./AttributedString'),
	Constants = require('./Constants'),
	assert = require('assert'),
	Util = require('./Util');

function _compareNodeRanges(a, b) {
	if (a.start < b.start) {
		return -1;
	} else if (a.start > b.start) {
		return 1;
	} else if (a.end !== b.end) {
		return b.end - a.end;
	} else {
		var aNodeType = a.node.nodeType,
			bNodeType = b.node.nodeType;

		if (aNodeType !== bNodeType) {
			if (aNodeType === Node.TEXT_NODE) {
				return 1;
			} else if (bNodeType === Node.TEXT_NODE) {
				return -1;
			} else {
				var aTagName = a.node.tagName,
					bTagName = b.node.tagName;

				if (aTagName < bTagName) {
					return -1;
				} else if (aTagName > bTagName) {
					return 1;
				}
			}
		}
		return 0;
	}
}

function attributedStringToDocumentFragment(attributedString, ownerDocument) {
	var string = attributedString.string(),
		tagsToLastDeclaredNodeRanges = {},
		nodeRanges = [],
		runIndex = 0;

	/*var nonBreakingSpace = '\u00A0';
		prev = null,
		cur = null;

	for (var i = 0; i < string.length; i++) {
		cur = string[i];
		if (cur === ' ') {

		} else if (cur === nonBreakingSpace) {
		}

		if (prev === ' ' && cur === ' ') {
			cur = nonBreakingSpace;
			string = string.substr(0, i) + cur + string.substr(i + 1);
		} else if (prev !== ' ' && cur === nonBreakingSpace && i !== string.length - 1) {
			cur = ' ';
			string = string.substr(0, i) + cur + string.substr(i + 1);
		}
		prev === cur;
	}*/

	attributedString._ensureClean();
	attributedString.attributeRuns().forEach(function (eachRun) {
		var eachRunAttributes = eachRun.attributes;

		Object.keys(eachRunAttributes).forEach(function (eachTag) {
			var nodeRange = tagsToLastDeclaredNodeRanges[eachTag];
			if (!nodeRange || nodeRange.end < eachRun.location) {
				assert(eachTag === eachTag.toUpperCase(), 'Tags Names Must be Uppercase');
				var eachTagAttributes = eachRunAttributes[eachTag],
					element = ownerDocument.createElement(eachTag);

				if (eachTagAttributes) {
					Object.keys(eachTagAttributes).forEach(function (eachAttributeName) {
						element.setAttribute(eachAttributeName, eachTagAttributes[eachAttributeName]);
					});
				}

				nodeRange = {
					start: eachRun.location,
					end: _attributeRunEnd(eachTag, eachTagAttributes, runIndex, attributedString),
					node: element
				};
				tagsToLastDeclaredNodeRanges[eachTag] = nodeRange;
				nodeRanges.push(nodeRange);
			}
		});

		var eachRunText = string.substr(eachRun.location, eachRun.length);
		if (eachRunText !== Constants.ObjectReplacementCharacter && eachRunText !== Constants.LineSeparatorCharacter) {
			nodeRanges.push({
				start: eachRun.location,
				end: eachRun.location + eachRun.length,
				node: ownerDocument.createTextNode(eachRunText)
			});
		}

		runIndex++;
	});

	nodeRanges.sort(_compareNodeRanges);

	var nodeRangeParentStack = [{
		start: 0,
		end: string.length,
		node: ownerDocument.createDocumentFragment()
	}];

	for (var i = 0; i < nodeRanges.length; i++) {
		var eachNodeRange = nodeRanges[i],
			parentNodeRange = nodeRangeParentStack.pop();

		while (nodeRangeParentStack.length && parentNodeRange.end <= eachNodeRange.start) {
			parentNodeRange = nodeRangeParentStack.pop();
		}

		if (eachNodeRange.end > parentNodeRange.end) {
			// In this case each has started inside current parent tag, but
			// extends past. Must split this node range into two. Process
			// start part of split here, and insert end part in correct
			// postion (after current parent) to be processed later.
			var splitStart = eachNodeRange,
				splitEnd = {
				start: parentNodeRange.end,
				end: splitStart.end,
				node: splitStart.node.cloneNode(true)
			};
			splitStart.end = parentNodeRange.end;

			// Insert splitEnd after current parent in correct location.
			var j = nodeRanges.indexOf(parentNodeRange);
			while (_compareNodeRanges(nodeRanges[j], splitEnd) < 0) {
				j++;
			}
			nodeRanges.splice(j, 0, splitEnd);
		}

		parentNodeRange.node.appendChild(eachNodeRange.node);
		nodeRangeParentStack.push(parentNodeRange);
		nodeRangeParentStack.push(eachNodeRange);
	}

	return nodeRangeParentStack[0].node;
}

function _attributeRunEnd(attribute, value, runIndex, attributedString) {
	var attributeRuns = attributedString.attributeRuns(),
		end = attributeRuns.length - 1,
		eachRun;

	while (true) {
		eachRun = attributeRuns[runIndex];
		if (eachRun.attributes[attribute] !== value) {
			return eachRun.location;
		} else if (runIndex === end) {
			return eachRun.location + eachRun.length;
		}
		runIndex++;
	}
}

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
	'B': true,
	'I': true,
	'U': true,
	'S': true,
	'A': true,
	'BR': true,
	'IMG': true
};

var allowedAttributes = {
	'href': true,
	'src': true
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
				attributedString.addAttributeInRange(node.tagName, _elementAllowedAttributes(node), tagStart, attributedString.length - tagStart);
			}
		} else if (allowedTags[node.tagName]) {
			if (node.tagName === 'BR') {
				var lineBreak = new AttributedString(Constants.LineSeparatorCharacter);
				lineBreak.addAttributeInRange('BR', _elementAllowedAttributes(node), 0, 1);
				attributedString.appendString(lineBreak);
			} else if (node.tagName === 'IMG') {
				var image = new AttributedString(Constants.ObjectReplacementCharacter);
				image.addAttributeInRange('IMG', _elementAllowedAttributes(node), 0, 1);
				attributedString.appendString(image);
			}
		}
	}
}

function _elementAllowedAttributes(element) {
	if (element.hasAttributes()) {
		var attrs = element.attributes,
			result = {};
		for (var i = attrs.length - 1; i >= 0; i--) {
			var name = attrs[i].name;
			if (allowedAttributes[name]) {
				result[name] = attrs[i].value;
			}
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
};