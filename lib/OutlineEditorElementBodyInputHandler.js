"use babel";

// Copyright (c) 2015 Jesse Grosjean. All rights reserved.

import AttributedString from './AttributedString';
import ItemBodyEncoder from './ItemBodyEncoder';
import EventRegistery from './EventRegistery';
import Constants from './Constants';
import diff  from 'fast-diff';
import Util from './Util';

function getOutlineEditorElement(e) {
	var element = e.target;
	while (element.tagName !== 'BIRCH-OUTLINE-EDITOR') {
		element = element.parentNode;
	}
	return element;
}

function onBodyCompositionStart(e) {
}

function onBodyCompositionUpdate(e) {
}

function onBodyCompositionEnd(e) {
}

function onBodyInput(e) {
	var outlineEditorElement = getOutlineEditorElement(e),
		editor = outlineEditorElement.editor,
		item = outlineEditorElement.itemForViewNode(e.target),
		itemViewLI = outlineEditorElement.itemViewLIForItem(item),
		itemViewP = outlineEditorElement._itemViewBodyP(itemViewLI),
		typingFormattingTags = editor.typingFormattingTags(),
		newBodyText = ItemBodyEncoder.bodyEncodedTextContent(itemViewP),
		oldBodyText = item.bodyText,
		outline = item.outline,
		location = 0;

	outline.beginUpdates();

	// Insert marker into old body text to ensure diffs get generated in
	// correct locations. For example if user has cursor at position "tw^o"
	// and types an "o" then the default diff will insert a new "o" after the
	// original. But that's not what is needed since the cursor is after the
	// "w" not the "o". In plain text it doesn't make much difference, but
	// when rich text attributes (bold, italic, etc) are in play it can mess
	// things up... so add the marker which will server as an anchor point
	// from which the diff is generated.
	var marker = '\uE000',
		markerRegex = new RegExp(marker, 'g'),
		startOffset = editor.selection.startOffset,
		markedOldBodyText = oldBodyText.slice(0, startOffset) + marker + oldBodyText.slice(startOffset);

	diff(markedOldBodyText, newBodyText).forEach(function (each) {
		var type = each[0],
			text = each[1].replace(markerRegex, '');

		if (text.length) {
			switch (type) {
			case diff.INSERT:
				text = new AttributedString(text);
				text.addAttributesInRange(typingFormattingTags, 0, -1);
				item.replaceBodyTextInRange(text, location, 0);
				break;

			case diff.EQUAL:
				location += text.length;
				break;

			case diff.DELETE:
				if (text !== '^') {
					item.replaceBodyTextInRange('', location, text.length);
				}
				break;
			}
		}
	});

	// Range affinity should always be upstream after text input
	var editorRange = outlineEditorElement.editorRangeFromDOMSelection();
	editorRange.selectionAffinity = Constants.SelectionAffinityUpstream;
	editor.moveSelectionRange(editorRange);

	outline.endUpdates();
}

EventRegistery.listen('.bbody', {
	compositionstart: onBodyCompositionStart,
	compositionupdate: onBodyCompositionUpdate,
	compositionend: onBodyCompositionEnd,
	input: onBodyInput
});