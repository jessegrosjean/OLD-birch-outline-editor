// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

var Velocity = require('velocity-animate');

Velocity.Easings.birchEasing = function(p, opts, tweenDelta) {
	var tension = 1.5,
        friction = Math.log((Math.abs(tweenDelta) + 1) * 10);
    return 1 - (Math.cos(p * tension * Math.PI) * Math.exp(-p * friction));
};

module.exports = {
    RootID: 'Birch.Root',
	ItemAffinityAbove: 'ItemAffinityAbove',
	ItemAffinityTopHalf: 'ItemAffinityTopHalf',
	ItemAffinityBottomHalf: 'ItemAffinityBottomHalf',
	ItemAffinityBelow: 'ItemAffinityBelow',

	SelectionAffinityUpstream: 'SelectionAffinityUpstream',
	SelectionAffinityDownstream: 'SelectionAffinityDownstream',

	ObjectReplacementCharacter: '\ufffc',
	LineSeparatorCharacter: '\u2028',
	ParagraphSeparatorCharacter: '\u2029',

	DefaultItemAnimactionContext: {
		duration: 400,
		easing: 'birchEasing'
	},

	DefaultScrollAnimactionContext: {
		duration: 400,
		easing: 'ease-out'
	},
};