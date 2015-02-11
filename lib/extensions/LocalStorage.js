var ItemSerializer = require('../ItemSerializer'),
	Extensions = require('../Extensions'),
	Delay = require('../Delay');

//function changed(editor) {
//	editor.autosaveDelay.clear();
//	editor.autosaveDelay.set(1000, function () {
//		saveIfNeeded(editor);
//	});
//}

function saveIfNeeded(editor) {
	//if (!editor.isClean()) {
		window.localStorage.setItem('birchRoot', ItemSerializer.itemsToHTML(editor.outline.root.children, editor));
	//	editor.markClean();
	//}
}

function hasLocalStorage() {
	try {
		return 'localStorage' in window && window.localStorage !== null;
	} catch (e) {
		return false;
	}
}

function startUsingLocalStorage(editor) {
	window.onbeforeunload = function () {
		saveIfNeeded(editor);
		return null;
	};

	var birchRootHTML = window.localStorage.getItem('birchRoot');
	if (birchRootHTML) {
		var items = ItemSerializer.itemsFromHTML(birchRootHTML, editor.outline, editor);
		if (items && items.length) {
			var outlineEditorElement = editor.outlineEditorElement,
				outline = editor.outline,
				undoManager = outline.undoManager;

			outlineEditorElement.disableAnimation();
			undoManager.disableUndoRegistration();
			outline.root.appendChildren(items);
			undoManager.enableUndoRegistration();
			outlineEditorElement.enableAnimation();
		}
	}

	//editor.autosaveDelay = new Delay();
	//editor.on('change', changed);
}

function stopUsingLocalStorage(editor) {
	//if (editor.autosaveDelay) {
	//	editor.autosaveDelay.clear();
	//}
	//editor.off('change', changed);
}

Extensions.add('com.foldingtext.editor.init', function (editor) {
	if (hasLocalStorage()) {
		window.setTimeout(function () {
			startUsingLocalStorage(editor);
		}, 0);
	} else {
		window.onbeforeunload = function () {
			return 'Local storage is not supported in your browser. You must copy and paste you text to some other place to save it.';
		};
	}
});

Extensions.add('com.foldingtext.editor.dispose', function (editor) {
});