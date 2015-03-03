// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

var EventRegistery = require('./EventRegistery'),
	ItemSerializer = require('./ItemSerializer');

function getOutlineEditorElement(e) {
	var element = e.target;
	while (element.tagName !== 'BIRCH-OUTLINE-EDITOR') {
		element = element.parentNode;
	}
	return element;
}

function onHandleMouseDown(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	outlineEditorElement._maintainSelection = editor.selection;
	e.stopPropagation();
}

function onHandleFocusIn(e) {
	var target = e.target;
	setTimeout(function() {
		target.blur();
	});
}

function onHandleFocusOut(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		maintainSelection = outlineEditorElement._maintainSelection,
		editor = outlineEditorElement.editor;

	if (maintainSelection) {
		setTimeout(function() {
			if (maintainSelection.isTextMode) {
				editor.focus();
				editor._disableScrollToSelection = true;
				editor.moveSelectionRange(maintainSelection);
				editor._disableScrollToSelection = false;
			} else {
				editor.focus();
			}
		});
	}
}

function onHandleClick(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		item = outlineEditorElement.itemForViewNode(e.target),
		editor = outlineEditorElement.editor;

	if (item) {
		if (e.shiftKey) {
			editor.hoist(item);
		} else if (item.firstChild) {
			editor.toggleFoldItems(item);
		}
	}

	e.stopPropagation();
}

EventRegistery.listen('.bitemHandle', {
	mousedown: onHandleMouseDown,
	focusin: onHandleFocusIn,
	focusout: onHandleFocusOut,
	click: onHandleClick
});