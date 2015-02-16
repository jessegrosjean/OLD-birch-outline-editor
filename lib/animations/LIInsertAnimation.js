// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

var Velocity = require('velocity-animate'),
	Util = require('../Util');

function LIInsertAnimation(id, item, outlineEditorElement) {
	this._id = id;
	this._item = item;
	this.outlineEditorElement = outlineEditorElement;
	this._insertLI = null;
	this._targetHeight = 0;
};

LIInsertAnimation.id = 'ItemLIInsert';

LIInsertAnimation.prototype.fastForward = function() {
	if (this._insertLI) {
		this._insertLI.style.height = this._targetHeight + 'px';
	}
};

LIInsertAnimation.prototype.complete = function() {
	this.outlineEditorElement._completedAnimation(this._id);
	if (this._insertLI) {
		Velocity(this._insertLI, 'stop', true);
		this._insertLI.style.height = null;
		this._insertLI.style.overflowY = null;
	}
};

LIInsertAnimation.prototype.insert = function(LI, context) {
	var outerThis = this,
		easing = context.easing,
		targetHeight = LI.clientHeight,
		duration = context.duration,
		startHeight = 0;

	this._insertLI = LI;
	this._targetHeight = targetHeight;

	Velocity(LI, {
		height: targetHeight
	}, {
		easing: easing,
		duration: duration,
		begin: function(elements) {
			LI.style.height = startHeight + 'px';
			LI.style.overflowY = 'hidden';
		},
		complete: function(elements) {
			outerThis.complete();
		}
	});
};

module.exports = LIInsertAnimation;