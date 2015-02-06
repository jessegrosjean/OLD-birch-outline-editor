"use 6to5";

import EventDelegate from './EventDelegate';
import Constants from './Constants';
import Util from './Util';

function getOutlineEditorElement(e) {
	var element = e.target;
	while (element.tagName !== 'OUTLINE-EDITOR') {
		element = element.parentNode;
	}
	return element;
}

function onEditorDragEnter(e) {
	onEditorDragOver(e);
}

function _dropTargetForEvent(e) {
	let outlineEditorElement = getOutlineEditorElement(e),
		picked = outlineEditorElement.pick(e.clientX, e.clientY),
		itemCaretPosition = picked.itemCaretPosition,
		editor = outlineEditorElement.editor;

	if (!itemCaretPosition) {
		return {};
	}

	let pickedItem = itemCaretPosition.offsetItem,
		itemPickAffinity = itemCaretPosition.itemAffinity,
		newDropInserBeforeItem = null,
		newDropInsertAfterItem = null,
		newDropParent = null;

	if (itemPickAffinity === Constants.ItemAffinityAbove || itemPickAffinity === Constants.ItemAffinityTopHalf) {
		return {
			parent: pickedItem.parent,
			insertBefore: pickedItem
		};
	} else {
		if (pickedItem.firstChild && editor.isExpanded(pickedItem)) {
			return {
				parent: pickedItem,
				insertBefore: editor.firstVisibleChild(pickedItem)
			};
		} else {
			return {
				parent: pickedItem.parent,
				insertBefore: editor.nextVisibleSibling(pickedItem)
			};
		}
	}
}

function _isInvalidDrop(dropTarget, draggedItem) {
	return !draggedItem || !dropTarget.parent || (dropTarget.parent === draggedItem || draggedItem.contains(dropTarget.parent));
}

function onEditorDragOver(e) {
	e.stopPropagation();
	e.preventDefault();

	let outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor,
		draggedItem = editor.draggedItem(),
		dropTarget = _dropTargetForEvent(e);

	if (e.ctrlKey) {
		e.dataTransfer.dropEffect = 'link';
	} else if (e.altKey) {
		e.dataTransfer.dropEffect = 'copy';
	} else {
		e.dataTransfer.dropEffect = 'move';
	}

	if (_isInvalidDrop(dropTarget, draggedItem) && e.dataTransfer.dropEffect === 'move') {
		e.dataTransfer.dropEffect = 'none';
		dropTarget.parent = null;
		dropTarget.insertBefore = null;
	}

	editor.debouncedSetDragState({
		'draggedItem' : draggedItem,
		'dropEffect' : e.dataTransfer.dropEffect,
		'dropParentItem' : dropTarget.parent,
		'dropInsertBeforeItem' : dropTarget.insertBefore
	});
}

function onEditorDrop(e) {
	e.stopPropagation();

	// For some reason "dropEffect is always set to 'none' on e. So track
	// it in store state instead.
	let outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor,
		dropEffect = editor.dropEffect(),
		draggedItem = editor.draggedItem(),
		dropParentItem = editor.dropParentItem(),
		dropInsertBeforeItem = editor.dropInsertBeforeItem();

	if (!draggedItem) {
		//Pasteboard.setClipboardEvent(e);
		//draggedItem = Pasteboard.readNodes(editor.tree())[0];
		//Pasteboard.setClipboardEvent(null);
	}

	if (draggedItem && dropParentItem) {
		let insertNode;

		if (dropEffect === 'move') {
			insertNode = draggedItem;
		} else if (dropEffect === 'copy') {
			insertNode = draggedItem.copyItem();
		} else if (dropEffect === 'link') {
		}

		if (insertNode && insertNode !== dropInsertBeforeItem) {
			let outline = dropParentItem.outline,
				undoManager = outline.undoManager;

			if (insertNode.parent) {
				if (insertNode.outline === outline) {
					let compareTo = dropInsertBeforeItem ? dropInsertBeforeItem : dropParentItem.lastChild;
					if (!compareTo) {
						compareTo = dropParentItem;
					}

					if (insertNode.comparePosition(compareTo) & Node.DOCUMENT_POSITION_FOLLOWING) {
						outlineEditorElement.scrollBy(-outlineEditorElement.itemViewLIForItem(insertNode).clientHeight);
					}
				}
			}

			let moveStartOffset;
			if (draggedItem === insertNode) {
				let editorElementRect = outlineEditorElement.getBoundingClientRect(),
					viewLI = outlineEditorElement.itemViewLIForItem(draggedItem),
					viewLIRect = viewLI.getBoundingClientRect(),
					editorLITop = viewLIRect.top - editorElementRect.top,
					editorLILeft = viewLIRect.left - editorElementRect.left,
					editorX = e.clientX - editorElementRect.left,
					editorY = e.clientY - editorElementRect.top;

				if (editor._hackDragItemMouseOffset) {
					editorX -= editor._hackDragItemMouseOffset.xOffset;
					editorY -= editor._hackDragItemMouseOffset.yOffset;
				}

				moveStartOffset = {
					xOffset: editorX - editorLILeft,
					yOffset: editorY - editorLITop
				};
			}
			editor.moveItems([insertNode], dropParentItem, dropInsertBeforeItem, moveStartOffset);
			undoManager.setActionName('Drag and Drop');
		}
	}

	editor.debouncedSetDragState({});
}

function onEditorDragLeave(e) {
	let outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor;

	editor.debouncedSetDragState({
		'draggedItem' : editor.draggedItem()
	});
}

EventDelegate.add('outline-editor', {
	dragenter: onEditorDragEnter,
	dragover: onEditorDragOver,
	drop: onEditorDrop,
	dragleave: onEditorDragLeave
});