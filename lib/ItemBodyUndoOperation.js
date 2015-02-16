// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

var Util = require('./Util');

function ItemBodyUndoOperation(item, insertText, location, length) {
	this._item = item;
	this._insertText = insertText;
	this._location = location;
	this._length = length;
};

ItemBodyUndoOperation.prototype.performOperation = function() {
	this._item.replaceBodyTextInRange(this._insertText, this._location, this._length);
};

ItemBodyUndoOperation.prototype.coalesce = function(operation) {
	if (operation instanceof ItemBodyUndoOperation) {
		if (this._item === operation._item) {
			// Undo operations represent the inverse of the original replace
			// action. Translating here back to "Original" action terms so I
			// can better reason about when I want coalescing to happen.
			var thisReplaceLocation = this._location,
				thisOriginalReplaceLength = this._insertText.length,
				thisOriginalInsertLength = this._length,
				thisOriginalEnd = thisReplaceLocation + thisOriginalInsertLength,
				newReplaceLocation = operation._location,
				newOriginalReplaceLength = operation._insertText.length,
				newOriginalInsertLength = operation._length;

			// Coelesce insert at end
			if (thisOriginalEnd === newReplaceLocation &&
				newOriginalInsertLength === 1 &&
				newOriginalReplaceLength === 0) {

				// back to undo terms
				this._length++;
				return true;
			}

			// Coelesce delete from end
			if (thisOriginalEnd === newReplaceLocation + newOriginalReplaceLength &&
				newOriginalInsertLength === 0 &&
				newOriginalReplaceLength === 1) {

				// back to undo terms
				if (newReplaceLocation < thisReplaceLocation) {
					this._location--;
					this._insertText.insertStringAtLocation(operation._insertText, 0);
				} else {
					this._length--;
				}
				return true;
			}
		}
	}
	return false;
};

module.exports = ItemBodyUndoOperation;