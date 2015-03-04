// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

"use babel";

var EventRegistery = require('../EventRegistery'),
	ItemSerializer = require('../ItemSerializer'),
	Util = require('../Util');

function getOutlineEditorElement(e) {
	var element = e.target;
	while (element && element.tagName !== 'BIRCH-OUTLINE-EDITOR') {
		element = element.parentNode;
	}
	return element;
}

function onBodyFocusIn(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	if (!outlineEditorElement._extendingSelection) {
		var focusItem = outlineEditorElement.itemForViewNode(e.target);
		if (editor.selection.focusItem !== focusItem) {
			editor.moveSelectionRange(focusItem);
		}
	}
}

function onBodyFocusOut(e) {
}

function onBodyMouseDown(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	editor.focus();
	outlineEditorElement.beginExtendSelectionInteraction(e);
	e.stopPropagation();
}

function onEditorMouseDown(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	editor.focus();
	setTimeout(function () {
		outlineEditorElement.beginExtendSelectionInteraction(e);
	});
}

EventRegistery.listen('birch-outline-editor > ul', {
	mousedown: onEditorMouseDown,
});

EventRegistery.listen('.bbody', {
	focusin: onBodyFocusIn,
	focusout: onBodyFocusOut,
	mousedown: onBodyMouseDown
});