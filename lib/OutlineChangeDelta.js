var assert = require('assert');

function error() {
	throw 'Unexpected Mutation: ' + mutation;
};

OutlineChangeDelta.createFromDOMMutation = function(mutation) {
	var type = mutation.type,
		target = mutation.target,
		targetTag = target.tagName,
		delta = new OutlineChangeDelta(mutation);

	delta._target = _item(target);

	if (!delta._target) {
		// Must be a body child node that is later removed, so at this point
		// it's no longer connected to a parent. Ignore here by returning null,
		// body change will be generated later when it's removed.
		return null;
	}

	// Map raw XML model changes to Items. Also validate those changes, only
	// expect a few types of changes, XML model should never get arbitrarily
	// changed.

	if (targetTag === 'LI') {
		if (type === 'attributes') {
			delta._type = OutlineChangeDelta.AttributeChanged;
			delta._attributeName = mutation.attributeName;
			delta._attributeOldValue = mutation.attributeOldValue;
		} else if (type === 'childList') {
			if (mutation.removedNodes.length === 1 && mutation.addedNodes.length === 1 && mutation.addedNodes[0].tagName === 'P') {
				// updating bodyP through replacement
				delta._type = OutlineChangeDelta.ContentChanged;
			} else {
				return null; // adding 'UL' ... ignore, li children will be added separate
			}
		} else {
			error();
		}
	} else if (targetTag === 'UL') {
		if (type !== 'childList') {
			error();
		}

		var removedNodes = mutation.removedNodes,
			removedLength = removedNodes.length;
		if (removedLength) {
			for (var i = 0; i < removedLength; i++) {
				delta._removedItems.push(_item(removedNodes[i]));
			}
		}

		var addedNodes = mutation.addedNodes,
			addedLength = addedNodes.length;
		if (addedLength) {
			for (var i = 0; i < addedLength; i++) {
				delta._addedItems.push(_item(addedNodes[i]));
			}
		}

		delta._previousSibling = _item(mutation.previousSibling);
		delta._nextSibling = _item(mutation.nextSibling);
		delta._type = OutlineChangeDelta.ChildrenChanged;
	} else {
		throw 'Unexpected';
	}

	return delta;
};

function OutlineChangeDelta(mutation) {
	this._mutation = mutation;
	this._type = null;
	this._target = null;
	this._addedItems = [];
	this._removedItems = [];
	this._previousSibling = null;
	this._nextSibling = null;
	this._attributeName = null;
	this._attributeOldValue = null;
};

Object.defineProperty(OutlineChangeDelta.prototype, 'type', {
	get: function () {
		return this._type;
	}
});

Object.defineProperty(OutlineChangeDelta.prototype, 'target', {
	get: function () {
		return this._target;
	}
});

Object.defineProperty(OutlineChangeDelta.prototype, 'addedItems', {
	get: function () {
		return this._addedItems;
	}
});

Object.defineProperty(OutlineChangeDelta.prototype, 'removedItems', {
	get: function () {
		return this._removedItems;
	}
});

Object.defineProperty(OutlineChangeDelta.prototype, 'previousSibling', {
	get: function () {
		return this._previousSibling;
	}
});

Object.defineProperty(OutlineChangeDelta.prototype, 'nextSibling', {
	get: function () {
		return this._nextSibling;
	}
});

Object.defineProperty(OutlineChangeDelta.prototype, 'attributeName', {
	get: function () {
		return this._attributeName;
	}
});

Object.defineProperty(OutlineChangeDelta.prototype, 'attributeOldValue', {
	get: function () {
		return this._attributeOldValue;
	}
});

function _item(xmlNode) {
	while (xmlNode) {
		if (xmlNode._item) {
			return xmlNode._item;
		}
		xmlNode = xmlNode.parentNode;
	}
	return null;
};

OutlineChangeDelta.AttributeChanged = 1;
OutlineChangeDelta.ContentChanged = 2;
OutlineChangeDelta.ChildrenChanged = 3;

module.exports = OutlineChangeDelta;