"use 6to5";

var EventDelegate = require('./EventDelegate'),
	ItemSerializer = require('./ItemSerializer'),
	Util = require('./Util');

function getOutlineEditorElement(e) {
	var element = e.target;
	while (element && element.tagName !== 'OUTLINE-EDITOR') {
		element = element.parentNode;
	}
	return element;
}

function onBodyFocusIn(e) {
	let outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	if (!outlineEditorElement._extendingSelection) {
		let focusItem = outlineEditorElement.itemForViewNode(e.target);
		if (editor.selectionRange().focusItem !== focusItem) {
			editor.moveSelectionRange(focusItem);
		}
	}
}

function onBodyFocusOut(e) {
}

function onBodyMouseDown(e) {
	let outlineEditorElement = getOutlineEditorElement(e);
	outlineEditorElement.beginExtendSelectionInteraction(e);
	e.stopPropagation();
}

function onEditorMouseDown(e) {
	let outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	editor.focus();
	setTimeout(function () {
		outlineEditorElement.beginExtendSelectionInteraction(e);
	});
}

EventDelegate.add('outline-editor', {
	mousedown: onEditorMouseDown,
});

EventDelegate.add('.bbody', {
	focusin: onBodyFocusIn,
	focusout: onBodyFocusOut,
	mousedown: onBodyMouseDown
});