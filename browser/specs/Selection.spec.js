'use strict';

var OutlineEditor = require('birch/OutlineEditor'),
	Selection = require('birch/Selection'),
	Outline = require('birch/Outline'),
	should = require('should');

describe('Selection', function() {
	var outlineSetup, outline, editor;

	beforeEach(function() {
		outlineSetup = require('./newOutlineSetup')();
		outline = outlineSetup.outline;
		editor = new OutlineEditor(outline);
		document.body.appendChild(editor.outlineEditorElement);
		editor.outlineEditorElement.disableAnimation(); // otherwise breaks geometry tests sometimes
		editor.setExpanded([
			outlineSetup.one,
			outlineSetup.five
		]);
	});

	afterEach(function() {
		editor.destroyed();
	});

	describe('Modify', function() {
		describe('Character', function() {
			it('should move/backward/character', function() {
				var r = editor.createSelection(outlineSetup.six, 1);
				r = r.selectionByModifying('move', 'backward', 'character');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(0);

				r = r.selectionByModifying('move', 'backward', 'character');
				r.focusItem.should.equal(outlineSetup.five);
				r.focusOffset.should.equal(4);
			});

			it('should move/forward/character', function() {
				var r = editor.createSelection(outlineSetup.one, 2);
				r = r.selectionByModifying('move', 'forward', 'character');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(3);

				r = r.selectionByModifying('move', 'forward', 'character');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(0);
			});
		});

		describe('Word', function() {
			it('should move/backward/word', function() {
				outlineSetup.six.bodyText = 'one two';
				var r = editor.createSelection(outlineSetup.six, 5);

				r = r.selectionByModifying('move', 'backward', 'word');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(4);

				r = r.selectionByModifying('move', 'backward', 'word');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(0);

				r = r.selectionByModifying('move', 'backward', 'word');
				r.focusItem.should.equal(outlineSetup.five);
				r.focusOffset.should.equal(0);
			});

			it('should move/forward/word', function() {
				outlineSetup.one.bodyText = 'one two';
				var r = editor.createSelection(outlineSetup.one, 1);

				r = r.selectionByModifying('move', 'forward', 'word');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(3);

				r = r.selectionByModifying('move', 'forward', 'word');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(7);

				r = r.selectionByModifying('move', 'forward', 'word');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(3);
			});

			it('should move/forward/word japanese', function() {
				outlineSetup.one.bodyText = 'ジェッセワsヘレ';
				var r = editor.createSelection(outlineSetup.one, 0);

				r = r.selectionByModifying('move', 'forward', 'word');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(5);

				r = r.selectionByModifying('move', 'forward', 'word');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(6);

				r = r.selectionByModifying('move', 'forward', 'word');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(8);

				r = r.selectionByModifying('move', 'forward', 'word');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(3);
			});
		});

		describe('Sentence', function() {
			it('should move/backward/sentance', function() {
				outlineSetup.six.bodyText = 'Hello world! Let\'s take a look at this.';
				var r = editor.createSelection(outlineSetup.six, 26);

				r = r.selectionByModifying('move', 'backward', 'sentence');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(13);

				r = r.selectionByModifying('move', 'backward', 'sentence');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(0);

				r = r.selectionByModifying('move', 'backward', 'sentence');
				r.focusItem.should.equal(outlineSetup.five);
				r.focusOffset.should.equal(0);
			});

			it('should move/forward/sentence', function() {
				outlineSetup.one.bodyText = 'Hello world! Let\'s take a look at this.';
				var r = editor.createSelection(outlineSetup.one, 8);

				r = r.selectionByModifying('move', 'forward', 'sentence');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(13);

				r = r.selectionByModifying('move', 'forward', 'sentence');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(39);

				r = r.selectionByModifying('move', 'forward', 'sentence');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(3);
			});
		});

		describe('Line Boundary', function() {
			it('should move/backward/lineboundary', function() {
				var r = editor.createSelection(outlineSetup.two, 1);
				r = r.selectionByModifying('move', 'backward', 'lineboundary');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(0);
			});

			it('should move/forward/lineboundary', function() {
				var r = editor.createSelection(outlineSetup.two, 1);
				r = r.selectionByModifying('move', 'forward', 'lineboundary');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(3);
			});
		});

		describe('Line', function() {
			it('should move/backward/line', function() {
				editor.moveSelectionRange(outlineSetup.six, 0);
				var r = editor.selection;
				r = r.selectionByModifying('move', 'backward', 'line');
				r.focusItem.should.equal(outlineSetup.five);
				r.focusOffset.should.equal(4);
			});

			it('should move/forward/line', function() {
				editor.moveSelectionRange(outlineSetup.five, 0);
				var r = editor.selection;
				r = r.selectionByModifying('move', 'forward', 'line');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(0);
			});
		});

		describe('Paragraph Boundary', function() {
			it('should move/backward/paragraphboundary', function() {
				var r = editor.createSelection(outlineSetup.six, 3);
				r = r.selectionByModifying('move', 'backward', 'paragraphboundary');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(0);

				r = r.selectionByModifying('move', 'backward', 'paragraphboundary');
				r.focusItem.should.equal(outlineSetup.six);
				r.focusOffset.should.equal(0);
			});

			it('should move/forward/paragraphboundary', function() {
				var r = editor.createSelection(outlineSetup.one, 0);
				r = r.selectionByModifying('move', 'forward', 'paragraphboundary');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(3);

				r = r.selectionByModifying('move', 'forward', 'paragraphboundary');
				r.focusItem.should.equal(outlineSetup.one);
				r.focusOffset.should.equal(3);
			});
		});

		describe('Paragraph', function() {
			it('should move/backward/paragraph', function() {
				var r = editor.createSelection(outlineSetup.six, 3);
				r = r.selectionByModifying('move', 'backward', 'paragraph');
				r.focusItem.should.equal(outlineSetup.five);
				r.focusOffset.should.equal(0);

				r = r.selectionByModifying('move', 'backward', 'paragraph');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(0);
			});

			it('should move/forward/paragraph', function() {
				var r = editor.createSelection(outlineSetup.one, 2);
				r = r.selectionByModifying('move', 'forward', 'paragraph');
				r.focusItem.should.equal(outlineSetup.two);
				r.focusOffset.should.equal(3);

				r = r.selectionByModifying('move', 'forward', 'paragraph');
				r.focusItem.should.equal(outlineSetup.five);
				r.focusOffset.should.equal(4);
			});
		});
	});

	describe('Geometry', function() {
		it('should get client rects from selection', function() {
			var itemRect = editor.createSelection(outlineSetup.one).focusClientRect,
				textRect1 = editor.createSelection(outlineSetup.one, 0).focusClientRect,
				textRect2 = editor.createSelection(outlineSetup.one, 3).focusClientRect;

			should(textRect1.left >= itemRect.left);
			should(textRect1.top >= itemRect.top);
			should(textRect1.bottom <= itemRect.bottom);
			textRect1.left.should.be.lessThan(textRect2.left);
		});

		it('should get client rects from empty selection', function() {
			outlineSetup.one.bodyText = '';

			var charRect = editor.createSelection(outlineSetup.one, 0).focusClientRect,
				itemRect = editor.createSelection(outlineSetup.one).focusClientRect;

			itemRect.left.should.equal(charRect.left);
			charRect.width.should.equal(0);
		});
	});
});
