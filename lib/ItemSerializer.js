var ItemBodyEncoder = require('./ItemBodyEncoder'),
	Constants = require('./Constants'),
	Util = require('./Util');

function itemsToTXT(items, editor) {
	var text = [];

	function itemToTXT(item, indent) {
		var itemText = [],
			child = item.firstChild;

		itemText.push(indent + item.bodyText);
		indent += '\t';

		while (child) {
			itemText.push(itemToTXT(child, indent));
			child = child.nextSibling;
		}

		return itemText.join('\n');
	}

	items.forEach(function (each) {
		text.push(itemToTXT(each, ''));
	});

	return text.join('\n');
}

function itemsFromTXT(text, editor) {
	var lines = text.split('\n'),
		outline = editor.outline,
		items = [];

	if (lines.length === 1) {
		items.itemFragmentString = lines[0].trim();
	} else {
		lines.forEach(function (eachLine) {
			items.push(outline.createItem(eachLine.trim()));
		});
	}

	return items;
}

function cleanHTMLDOM(element) {
	var each = element,
		eachType;

	while (each) {
		eachType = each.nodeType;
		if (eachType === Node.ELEMENT_NODE && each.tagName === 'P') {
			each = Util.nodeNextBranch(each);
		} else {
			if (eachType === Node.TEXT_NODE) {
				var textNode = each;
				each = Util.nextNode(each);
				textNode.parentNode.removeChild(textNode);
			} else {
				each = Util.nextNode(each);
			}
		}
	}
}

function tidyHTMLDOM(element, indent) {
	if (element.tagName === 'P') {
		return;
	}

	var eachChild = element.firstElementChild;
	if (eachChild) {
		var childIndent = indent + '  ';
		while (eachChild) {
			var tagName = eachChild.tagName;
			if (tagName === 'UL' && !eachChild.firstElementChild) {
				var ref = eachChild;
				eachChild = eachChild.nextElementSibling;
				element.removeChild(ref);
			} else {
				tidyHTMLDOM(eachChild, childIndent);
				element.insertBefore(element.ownerDocument.createTextNode(childIndent), eachChild);
				eachChild = eachChild.nextElementSibling;
			}
		}
		element.appendChild(element.ownerDocument.createTextNode(indent));
	}
}

function itemsToHTML(items, editor) {
	var htmlDocument = document.implementation.createHTMLDocument(),
		rootUL = htmlDocument.createElement('ul'),
		style = document.createElement('style'),
		serializer = new XMLSerializer(),
		head = htmlDocument.head,
		expandedIDs = [];

	if (editor) {
		items.forEach(function (each) {
			var end = each.nextBranch;
			while (each !== end) {
				if (editor.isExpanded(each)) {
					expandedIDs.push(each.id);
				}
				each = each.nextItem;
			}
		});
	}

	if (expandedIDs.length) {
		var expandedMeta = htmlDocument.createElement('meta');
		expandedMeta.name = 'expandedItems';
		expandedMeta.content = expandedIDs.join(' ');
		head.appendChild(expandedMeta);
	}

	var encodingMeta = htmlDocument.createElement('meta');
	encodingMeta.setAttribute('charset', 'UTF-8');
	head.appendChild(encodingMeta);

	style.type = 'text/css';
	style.appendChild(htmlDocument.createTextNode('p { white-space: pre-wrap; }'));
	head.appendChild(style);

	rootUL.id = Constants.RootID;
	htmlDocument.documentElement.lastChild.appendChild(rootUL);

	items.forEach(function (each) {
		rootUL.appendChild(each._liOrRootUL.cloneNode(true));
	});

	tidyHTMLDOM(htmlDocument.documentElement, '\n');

 	return serializer.serializeToString(htmlDocument);
}

function itemsFromHTML(htmlString, outline, editor) {
	var parser = new DOMParser(),
		htmlDocument = parser.parseFromString(htmlString, 'text/html'),
		rootUL = htmlDocument.getElementById(Constants.RootID),
		expandedItemIDs = {},
		items = [];

	if (rootUL) {
		cleanHTMLDOM(htmlDocument.body);

		var metaElements = htmlDocument.head.getElementsByTagName('meta'),
			expandedItemIDs = {};

		for (var i = 0; i < metaElements.length; i++) {
			var each = metaElements[i];
			if (each.name === 'expandedItems') {
				each.content.split(' ').forEach(function (eachID) {
					expandedItemIDs[eachID] = true;
				});
			}
		}

		var eachLI = rootUL.firstElementChild;
		while (eachLI) {
			var item = outline.createItem(null, outline.outlineStore.importNode(eachLI, true), function(oldID, newID) {
				if (expandedItemIDs[oldID]) {
					delete expandedItemIDs[oldID];
					expandedItemIDs[newID] = true;
				}
			});

			if (item) {
				items.push(item);
			}

			eachLI = eachLI.nextElementSibling;
		}
	} else {
		var body = htmlDocument.body,
			firstChild = body.firstElementChild;

		if (firstChild && firstChild.tagName === 'UL') {
			// special handling
		} else {
			items.itemFragmentString = ItemBodyEncoder.elementToAttributedString(body);
		}
	}

	if (editor) {
		items.forEach(function (each) {
			var end = each.nextBranch;
			while (each !== end) {
				if (expandedItemIDs[each.id]) {
					editor.editorState(each).expanded = true;
				}
				each = each.nextItem;
			}
		});
	}

	return items;
}

function itemsToOPML(items, editor) {
	var opmlDoc = document.implementation.createDocument(null, 'opml', null),
		headElement = opmlDoc.createElement('head'),
		bodyElement = opmlDoc.createElement('body'),
		documentElement = opmlDoc.documentElement;

	documentElement.setAttribute('version', '2.0');
	documentElement.appendChild(headElement);

	function itemToOPML(item) {
		var outlineElement = opmlDoc.createElementNS(null, 'outline');

		item.attributeNames.forEach(function (eachName) {
			outlineElement.setAttribute(eachKey, item.attribute(eachName));
		});

		outlineElement.setAttribute('id', item.id);
		outlineElement.setAttribute('text', item.bodyHTML);

		if (item.hasChildren) {
			var current = item.firstChild;
			while (current) {
				var childOutline = itemToOPML(current);
				outlineElement.appendChild(childOutline);
				current = current.nextSibling;
			}
		}

		return outlineElement;
	}

	items.forEach(function (each) {
		bodyElement.appendChild(itemToOPML(each));
	});

	documentElement.appendChild(bodyElement);

	return new XMLSerializer().serializeToString(documentElement);
}

function OPMLToItems(opml, editor) {
	function outlineElementToNode(outlineElement) {
		var attributes = outlineElement.attributes,
			eachOutline = outlineElement.firstElementChild,
			node = tree.createNode('', outlineElement.getAttribute('id'));

		for (var i = 0; i < attributes.length; i++) {
			var attr = attributes[i];
			if (attr.specified) {
				var name = attr.name,
					value = attr.value;

				if (name === 'text') {
					node.setAttributedTextContentFromHTML(value);
				} else if (name === 'id') {
					// ignore
				} else {
					node.setAttribute(name, value);
				}
			}
		}

		while (eachOutline) {
			node.appendChild(outlineElementToNode(eachOutline));
			eachOutline = eachOutline.nextElementSibling;
		}

		return node;
	}

	try {
		var opmlDoc = (new DOMParser()).parseFromString(opml, 'text/xml'),
			tree = this,
			state;

		if (!opmlDoc) {
			return null;
		}

		var documentElement = opmlDoc.documentElement;
		if (!documentElement) {
			return null;
		}

		var headElement = documentElement.getElementsByTagName('head')[0];
		if (headElement) {
			state = headElement.getAttribute('jsonstate');
		}

		var bodyElement = documentElement.getElementsByTagName('body')[0];
		if (!bodyElement) {
			return null;
		}

		var eachOutline = bodyElement.firstElementChild,
			nodes = [];

		while (eachOutline) {
			nodes.push(outlineElementToNode(eachOutline));
			eachOutline = eachOutline.nextElementSibling;
		}

		return {
			nodes: nodes,
			state: state
		};
	} catch(e) {
		console.log(e);
	}

	return null;
}

function writeItems(items, editor, dataTransfer) {
	dataTransfer.setData('text/plain', itemsToHTML(items, editor));
	dataTransfer.setData('text/html', itemsToHTML(items, editor));
	//dataTransfer.setData('text/xml+opml', itemsToOPML(items, editor));
}

function readItems(editor, dataTransfer) {
	var htmlString = dataTransfer.getData('text/html'),
		items = null;

	if (htmlString) {
		items = itemsFromHTML(htmlString, editor);
	}

	if (!items) {
		var txtString = dataTransfer.getData('text/plain');
		if (txtString) {
			items = itemsFromHTML(txtString, editor);
		}
	}

	return items || [];
	// plain text
	// html
	// instance
}

module.exports = {
	itemsToHTML: itemsToHTML,
	itemsFromHTML: itemsFromHTML,
	writeItems: writeItems,
	readItems: readItems
};