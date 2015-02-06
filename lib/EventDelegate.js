"use 6to5";

import {Emitter, Disposable, CompositeDisposable} from 'atom';
import matchesSelector from 'matches-selector';
import typechecker from 'typechecker';
import {specificity} from 'clear-cut';

function EventDelegate(rootElement) {
	this._rootElement = rootElement;
	this._bubbleListenerMap = {};
	this._useCaptureListenerMap = {};
	this._boundDispatchEvent = this.dispatch.bind(this);
	this._boundListenerUnsubscribes = [];
}

EventDelegate.prototype.dispose = function() {
	this._boundListenerUnsubscribes.forEach(function (each) {
		each();
	});
	this._boundListenerUnsubscribes = [];
};

EventDelegate.prototype.add = function(selector, type, handler, useCapture) {
	if (typechecker.isObject(type)) {
		let disposable = new CompositeDisposable(),
			typesToHandlers = type,
			outerThis = this;
		Object.keys(typesToHandlers).forEach(function (eachType) {
			disposable.add(outerThis.add(selector, eachType, typesToHandlers[eachType]));
		});
		return disposable;
	}

	var disposable = null;

	if (!typechecker.isString(selector)) {
		var target = selector;
		target.addEventListener(type, handler, useCapture);
		disposable = new Disposable(function () {
			target.removeEventListener(type, handler, useCapture);
		});
	} else {
		let listenerMap = useCapture ? this._useCaptureListenerMap : this._bubbleListenerMap,
			boundDispatch = this._boundDispatchEvent,
			rootElement = this._rootElement,
			listeners = listenerMap[type],
			listener = {
				selector: selector,
				handler: handler
			};

		if (!listeners) {
			listeners = [];
			listenerMap[type] = listeners;
			rootElement.addEventListener(type, boundDispatch, useCapture);
		}

		listeners.push(listener);
		listeners._needSort = true;

		disposable = new Disposable(function() {
			let index = listeners.indexOf(listener);
			if (index !== -1) {
				listeners.splice(index, 1);
				if (listeners.length === 0) {
					rootElement.removeEventListener(type, boundDispatch, useCapture);
					delete listenerMap[type];
				}
			}
		});
	}

	this._boundListenerUnsubscribes.push(disposable);

	return disposable;
};

EventDelegate.prototype._listeners = function(type, useCapture) {
	var listeners;
	if (useCapture) {
		listeners = this._useCaptureListenerMap[type];
	} else {
		listeners = this._bubbleListenerMap[type];
	}

	if (listeners) {
		if (listeners._needSort) {
			listeners.sort(function(a, b) {
				var aSelector = a.selector,
					bSelector = b.selector,
					aSpecificity = specificity(aSelector),
					bSpecificity = specificity(bSelector);
				return bSpecificity - aSpecificity;
			});
			listeners._needSort = false;
		}
	}

	return listeners;
};

function _messWith(e, target) {
	if (!e._messedWith) {
		var stopPropagation = e.stopPropagation,
			stopImmediatePropagation = e.stopImmediatePropagation;

		e.stopPropagation = function() {
			stopPropagation.call(e);
			this._isPropagationStopped = true;
		};

		e.stopImmediatePropagation = function() {
			stopImmediatePropagation.call(e);
			this._isPropagationStopped = true;
			this._isImmediatePropagationStopped = true;
		};

		e._messedWith = true;
	}

	e.delegateDispatchTarget = target;

	return e;
}

EventDelegate.prototype.dispatch = function(e) {
	if (e._isPropagationStopped) {
		return;
	}

	var type = e.type,
		phase = e.eventPhase,
		captureListeners = this._listeners(type, true),
		bubbleListeners = this._listeners(type, false),
		listeners;

	switch (phase) {
		case Event.CAPTURING_PHASE:
			listeners = captureListeners;
			break;

		case Event.AT_TARGET: {
			if (captureListeners || bubbleListeners) {
				listeners = [];
				if (captureListeners) {
					listeners = listeners.concat(captureListeners);
				}
				if (bubbleListeners) {
					listeners = listeners.concat(bubbleListeners);
				}
			}
			break;
		}

		case Event.BUBBLING_PHASE:
			listeners = bubbleListeners;
			break;
	}

	if (!listeners || listeners.length === 0) {
		return;
	}

	var rootElement = this._rootElement,
		target = e.target;

	if (target.nodeType === Node.TEXT_NODE) {
		target = target.parentElement;
	}

	while (target && listeners.length) {
		var eachListener;

		for (var i = 0; i < listeners.length; i++) {
			eachListener = listeners[i];

			if (matchesSelector(target, eachListener.selector)) {
				eachListener.handler.call(target, _messWith(e, target));
			}

			if (e._isImmediatePropagationStopped) {
				break;
			}
		}

		if (target === rootElement || e._isPropagationStopped) {
			break;
		}

		target = target.parentElement;
	}
};

module.exports = new EventDelegate(window);