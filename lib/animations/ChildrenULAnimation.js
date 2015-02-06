var Velocity = require('velocity-animate'),
	Constants = require('../Constants'),
	assert = require('assert'),
	Util = require('../Util');

function ChildrenULAnimation(id, item, outlineEditorElement) {
	this._id = id;
	this.outlineEditorElement = outlineEditorElement;
	this._expandingUL = null;
	this._collapsingUL = null;
	this._item = item;
	this._targetHeight = 0;
}

ChildrenULAnimation.id = 'ChildrenUL';

ChildrenULAnimation.prototype.fastForward = function(context) {
	if (this._expandingUL) {
		this._expandingUL.style.height = this._targetHeight + 'px';
	} else if (this._collapsingUL) {
		this._collapsingUL.style.height = this._targetHeight + 'px';
	}
};

ChildrenULAnimation.prototype.expand = function(UL, context) {
	//assert.ok(!this._expandingUL, 'do not expand twice in row');

	var id = this._id,
		easing = context.easing,
		outlineEditorElement = this.outlineEditorElement,
		targetHeight = UL.clientHeight,
		startHeight = this._collapsingUL ? this._collapsingUL.clientHeight : 0,
		duration = context.duration;

	if (this._collapsingUL) {
		Velocity(this._collapsingUL, 'stop', true);
		Util.removeFromDOM(this._collapsingUL);
		this._collapsingUL = null;
	}

	this._expandingUL = UL;
	this._targetHeight = targetHeight;

	Velocity(UL, {
		height: targetHeight
	}, {
		easing: easing,
		duration: duration,
		begin: function(elements) {
			UL.style.height = startHeight + 'px';
			UL.style.overflowY = 'hidden';
		},
		complete: function(elements) {
			UL.style.height = null;
			UL.style.marginBottom = null;
			UL.style.overflowY = null;
			outlineEditorElement._completedAnimation(id);
		}
	});
};

ChildrenULAnimation.prototype.collapse = function(UL, context) {
	//assert.ok(!this._collapsingUL, 'do not collapse twice in row');

	var id = this._id,
		easing = context.easing,
		outlineEditorElement = this.outlineEditorElement,
		clientHeight = UL.clientHeight,
		duration = context.duration,
		startHeight = clientHeight,
		targetHeight = 0;

	if (this._expandingUL) {
		Velocity(this._expandingUL, 'stop', true);
		this._expandingUL = null;
	}

	this._collapsingUL = UL;
	this._targetHeight = targetHeight;
	//Util.removeBranchIDs(UL);

	Velocity(UL, {
		tween: [targetHeight, startHeight],
		height: targetHeight
	}, {
		easing: easing,
		duration: duration,
		begin: function(elements) {
			UL.style.overflowY = 'hidden';
			UL.style.pointerEvents = 'none';
			UL.style.height = startHeight + 'px';
		},
		progress: function(elements, percentComplete, timeRemaining, timeStart, tweenULHeight) {
			if (tweenULHeight < 0) {
				UL.style.height = '0px';
				UL.style.marginBottom = tweenULHeight + 'px';
			} else {
				UL.style.marginBottom = null;
			}
		},
		complete: function(elements) {
			Util.removeFromDOM(UL);
			outlineEditorElement._completedAnimation(id);
		}
	});
};

module.exports = ChildrenULAnimation;