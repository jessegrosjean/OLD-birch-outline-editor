var EventDelegate = require('./EventDelegate'),
	ItemSerializer = require('./ItemSerializer');

function getOutlineEditorElement(e) {
	var element = e.target;
	while (element.tagName !== 'OUTLINE-EDITOR') {
		element = element.parentNode;
	}
	return element;
}

function onHandleDragStart(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		item = outlineEditorElement.itemForViewNode(e.target),
		li = outlineEditorElement.itemViewLIForItem(item),
		editor = outlineEditorElement.editor,
		liRect = li.getBoundingClientRect(),
		x = e.clientX - liRect.left,
		y = e.clientY - liRect.top;

	e.stopPropagation();
	e.dataTransfer.effectAllowed = 'all';
	e.dataTransfer.setDragImage(li, x, y);
	ItemSerializer.writeItems([item], editor, e.dataTransfer);

	editor._hackDragItemMouseOffset = {
		xOffset: x,
		yOffset: y
	};

	editor.setDragState({
		draggedItem: item
	});
}

function onHandleDrag(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		item = outlineEditorElement.itemForViewNode(e.target),
		editor = outlineEditorElement.editor;

	e.stopPropagation();

	if (item !== editor.draggedItem()) {
		e.preventDefault();
	}
}

function onHandleDragEnd(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	e.stopPropagation();
	editor.setDragState({});
}

EventDelegate.add('.bitemHandle', {
	dragstart: onHandleDragStart,
	drag: onHandleDrag,
	dragend: onHandleDragEnd,
});