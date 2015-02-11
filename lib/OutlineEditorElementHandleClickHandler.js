var EventDelegate = require('./EventDelegate'),
	ItemSerializer = require('./ItemSerializer');

function getOutlineEditorElement(e) {
	var element = e.target;
	while (element.tagName !== 'OUTLINE-EDITOR') {
		element = element.parentNode;
	}
	return element;
}

function onHandleMouseDown(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	outlineEditorElement._maintainOutlineEditorRange = editor.selectionRange();
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
		maintainOutlineEditorRange = outlineEditorElement._maintainOutlineEditorRange,
		editor = outlineEditorElement.editor;

	if (maintainOutlineEditorRange) {
		setTimeout(function() {
			if (maintainOutlineEditorRange.isTextMode) {
				editor.focus();
				editor._disableScrollToSelection = true;
				editor.moveSelectionRange(maintainOutlineEditorRange);
				editor._disableScrollToSelection = false;
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

EventDelegate.add('.bitemHandle', {
	mousedown: onHandleMouseDown,
	focusin: onHandleFocusIn,
	focusout: onHandleFocusOut,
	click: onHandleClick
});