// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

var Velocity = require('velocity-animate'),
	Constants = require('../Constants'),
	Util = require('../Util');

function LIRemoveAnimation(id, item, outlineEditorElement) {
	this._id = id;
	this._item = item;
	this.outlineEditorElement = outlineEditorElement;
	this._removingLI = null;
	this._targetHeight = 0;
}

LIRemoveAnimation.id = 'ItemLIRemove';

LIRemoveAnimation.prototype.fastForward = function() {
	if (this._removingLI) {
		this._removingLI.style.height = this._targetHeight + 'px';
	}
};

LIRemoveAnimation.prototype.complete = function() {
	this.outlineEditorElement._completedAnimation(this._id);
	if (this._removingLI) {
		Velocity(this._removingLI, 'stop', true);
		Util.removeFromDOM(this._removingLI);
	}
};

LIRemoveAnimation.prototype.remove = function(LI, context) {
	var id = this._id,
		outerThis = this,
		easing = context.easing,
		outlineEditorElement = this.outlineEditorElement,
		clientHeight = LI.clientHeight,
		duration = context.duration,
		startHeight = clientHeight,
		targetHeight = 0;

	if (this._removingLI) {
		Velocity(this._removingLI, 'stop', true);
		Util.removeFromDOM(this._removingLI);
	}

	this._removingLI = LI;
	this._targetHeight = targetHeight;
	Velocity(LI, 'stop', true);
	//Util.removeBranchIDs(LI);

	Velocity(LI, {
		tween: [targetHeight, startHeight],
		height: targetHeight
	}, {
		easing: easing,
		duration: duration,
		begin: function(elements) {
			LI.style.overflowY = 'hidden';
			LI.style.height = startHeight;
			LI.style.visibility = 'hidden';
			LI.style.pointerEvents = 'none';
		},
		progress: function(elements, percentComplete, timeRemaining, timeStart, tweenLIHeight) {
			if (tweenLIHeight < 0) {
				LI.style.height = '0px';
				LI.style.marginBottom = tweenLIHeight + 'px';
			} else {
				LI.style.marginBottom = null;
			}
		},
		complete: function(elements) {
			outerThis.complete();
		}
	});
};

module.exports = LIRemoveAnimation;