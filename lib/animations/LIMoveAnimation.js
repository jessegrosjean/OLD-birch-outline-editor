// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

var Velocity = require('velocity-animate'),
	Util = require('../Util');

function LIMoveAnimation(id, item, outlineEditorElement) {
	this._id = id;
	this._item = item;
	this.outlineEditorElement = outlineEditorElement;
	this._movingLIClone = null;
}

LIMoveAnimation.id = 'ItemLIMove';

LIMoveAnimation.prototype.fastForward = function() {
};

LIMoveAnimation.prototype.beginMove = function(LI, position) {
	var movingLIClone = this._movingLIClone;
	if (!movingLIClone) {
		movingLIClone = LI.cloneNode(true);
		movingLIClone.style.marginTop = 0;
		movingLIClone.style.position = 'absolute';
		movingLIClone.style.top = position.top + 'px';
		movingLIClone.style.left = position.left + 'px';
		movingLIClone.style.width = position.width + 'px';
		movingLIClone.dataset.pLeft = position.pLeft;
		movingLIClone.style.pointerEvents = 'none';

		// Add simulated selection if in text edit mode.
		var outlineEditorElement = this.outlineEditorElement,
			selectionRange = outlineEditorElement.editor.selection;

		if (selectionRange.isTextMode && selectionRange.focusItem === this._item) {
			var itemRect = LI.getBoundingClientRect(),
				selectionRects = [];

			// focusClientRect is more acurate in a number of collapsed cases,
			// so use it when possible. Otherwise just use
			// document.getSelection() rects.
			if (selectionRange.isCollapsed) {
				selectionRects.push(selectionRange.focusClientRect);
			} else {
				var domSelection = outlineEditorElement.editor.DOMGetSelection();
				if (domSelection.rangeCount > 0) {
					var domRange = domSelection.getRangeAt(0),
						rangeRects = domRange.getClientRects(),
						length = rangeRects.length;

					for (var i = 0; i < length; i++) {
						selectionRects.push(rangeRects[i]);
					}
				}
			}

			for (var i = 0; i < selectionRects.length; i++) {
				var rect = selectionRects[i],
					selectDIV = document.createElement('div');
					selectDIV.style.position = 'absolute';
					selectDIV.style.top = (rect.top - itemRect.top) + 'px';
					selectDIV.style.left = (rect.left - itemRect.left) + 'px';
					selectDIV.style.width = rect.width + 'px';
					selectDIV.style.height = rect.height + 'px';
					selectDIV.style.zIndex = '-1';

				if (rect.width <= 1) {
					selectDIV.className = 'bsimulatedSelectionCursor';
					selectDIV.style.width = '1px';
				} else {
					selectDIV.className = 'bsimulatedSelection';
				}

				movingLIClone.appendChild(selectDIV);
			}
		}

		this.outlineEditorElement.animationLayerElement.appendChild(movingLIClone);
		this._movingLIClone = movingLIClone;
		//Util.removeBranchIDs(movingLIClone);
	}
};

LIMoveAnimation.prototype.performMove = function(LI, position, context) {
	var id = this._id,
		outlineEditorElement = this.outlineEditorElement,
		movingLIClone = this._movingLIClone,
		pLeftDiff = parseInt(movingLIClone.dataset.pLeft, 10) - position.pLeft;

	Velocity(movingLIClone, 'stop', true);
	Velocity(movingLIClone, {
		top: position.top,
		left: position.left - pLeftDiff,
		width: position.width + pLeftDiff
	}, {
		easing: context.easing,
		duration: context.duration,
		begin: function(elements) {
			//LI.style.visibility = 'hidden'; // Breaks focus
			LI.style.opacity = '0';
		},
		complete: function(elements) {
			LI.style.opacity = null;
			Util.removeFromDOM(movingLIClone);
			outlineEditorElement._completedAnimation(id);
		}
	});
};

module.exports = LIMoveAnimation;