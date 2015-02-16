// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

/**
 * Extension point process order.
 *
 * @typedef {(module:ft/core/extensions.PriorityNormal |
 *			module:ft/core/extensions.PriorityFirst |
 *			module:ft/core/extensions.PriorityLast |
 *			Number)} ExtensionPriority
 */

var PriorityNormal = 0,
	PriorityFirst = -1,
	PriorityLast = 1;

/**
 * Extensions add new behavior to FoldingText.
 *
 * This class manages those extensions. Use it to add your extension with to a
 * specific extension point. The extension logic is different for each
 * extension point, see each extension points example code to get started.
 *
 * Each extension point may have multiple extensions registered with it. When
 * you add an extension use the optional `priority` parameter to help
 * determine the order that your extension is called in.
 *
 * @private
 * @constructor
 * @alias module:ft/core/extensions.Extensions*/
function Extensions() {
	this._pointsToExtensions = {};
	this.PriorityNormal = PriorityNormal;
	this.PriorityFirst = PriorityFirst;
	this.PriorityLast = PriorityLast;
}

Extensions.prototype.add = function(extensionPoint, extension, priority) {
	var extensions = this._pointsToExtensions[extensionPoint];
	if (!extensions) {
		extensions = [];
		this._pointsToExtensions[extensionPoint] = extensions;
	}

	if (priority === undefined) {
		priority = PriorityNormal;
	}

	extensions.push({
		extension: extension,
		priority: priority
	});

	extensions.needsSort = true;
};

Extensions.prototype.remove = function(extensionPoint, filter) {
	var extensions = this._pointsToExtensions[extensionPoint];
	if (extensions) {
		var length = extensions.length,
			i;
		for (i = length - 1; i >= 0; i--) {
			if (filter(extensions[i].extension)) {
				extensions.splice(i, 1);
			}
		}
	}
};

Extensions.prototype.hasExtensions = function(extensionPoint) {
	var extensions = this._pointsToExtensions[extensionPoint];
	return extensions ? extensions.length > 0 : false;
};

Extensions.prototype.processExtensions = function(extensionPoint, block, returnFirst) {
	var extensions = this._pointsToExtensions[extensionPoint],
		length = extensions ? extensions.length : 0,
		i;

	if (extensions && extensions.needsSort) {
		extensions.sort(function (a, b) {
			return a.priority - b.priority;
		});
		extensions.needsSort = false;
	}

	for (i = 0; i < length; i++) {
		var eachResult = block(extensions[i].extension);
		if (eachResult !== undefined && returnFirst) {
			return eachResult;
		}
	}
};

/**
 * Default extension processing priority.
 */
Extensions.PriorityNormal = PriorityNormal;

/**
 * Extensions added with PriorityFirst priority are processed before other
 * extensions.
 */
Extensions.PriorityFirst = PriorityFirst;

/**
 * Extensions added with PriorityLast priority are processed after other
 * extensions.
 */
Extensions.PriorityLast = PriorityLast;


module.exports = new Extensions();