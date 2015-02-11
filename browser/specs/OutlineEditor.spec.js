'use strict';

var OutlineEditor = require('birch/OutlineEditor'),
	Outline = require('birch/Outline'),
	should = require('should');

describe('OutlineEditor', function() {
	var outlineSetup, outline, editor;

	beforeEach(function() {
		outlineSetup = require('./newOutlineSetup')();
		outline = outlineSetup.outline;
		editor = new OutlineEditor(outline);
		document.body.appendChild(editor.outlineEditorElement);
	});

	afterEach(function() {
		editor.destroyed();
	});

	describe('Hoisting', function() {
		it('should hoist root by default', function() {
			editor.hoistedItem().should.equal(outline.root);
			editor.isVisible(editor.hoistedItem()).should.be.false;
		});

		it('should make children of hoisted item visible', function() {
			editor.hoist(outlineSetup.two);
			editor.isVisible(editor.hoistedItem()).should.be.false;
			editor.isVisible(outlineSetup.three).should.be.true;
			editor.isSelected(outlineSetup.three).should.be.true;
			editor.isVisible(outlineSetup.four).should.be.true;
		});
	});

	describe('Expanding', function() {
		it('should make children of expanded visible', function() {
			editor.setExpanded(outlineSetup.one, true);
			editor.isExpanded(outlineSetup.one).should.be.true;
			editor.isVisible(outlineSetup.two).should.be.true;
			editor.isVisible(outlineSetup.five).should.be.true;

			editor.setExpanded(outlineSetup.one, false);
			editor.isExpanded(outlineSetup.one).should.be.false;
			editor.isVisible(outlineSetup.two).should.be.false;
			editor.isVisible(outlineSetup.five).should.be.false;
		});

		it('should toggle expanded state', function() {
			editor.toggleFoldItems(outlineSetup.one);
			editor.isExpanded(outlineSetup.one).should.be.true;

			editor.toggleFoldItems(outlineSetup.one);
			editor.isExpanded(outlineSetup.one).should.be.false;
		});
	});

	describe('Visibility', function() {
		it('should know if item is visible', function() {
			editor.isVisible(outlineSetup.one).should.be.ok;
			editor.isVisible(outlineSetup.two).should.not.be.ok;
			editor.isVisible(outlineSetup.three).should.not.be.ok;
			editor.isVisible(outlineSetup.five).should.not.be.ok;
		});
	});

	describe('Matching', function() {
		it('should set match path', function() {
			editor.setItemFilterPath('//li/p[text()=\'two\']');
			editor.isVisible(outlineSetup.one).should.be.ok;
			editor.isVisible(outlineSetup.two).should.be.ok;
			editor.isVisible(outlineSetup.three).should.not.be.ok;
			editor.isVisible(outlineSetup.five).should.not.be.ok;
			editor.setItemFilterPath(null);
			editor.isVisible(outlineSetup.one).should.be.ok;
			editor.isVisible(outlineSetup.two).should.not.be.ok;
			editor.isVisible(outlineSetup.three).should.not.be.ok;
			editor.isVisible(outlineSetup.five).should.not.be.ok;
		});
	});

	describe('Selection', function() {
		it('should be empty by default', function() {
			editor.selectionRange().rangeItems.should.eql([]);
		});

		it('should select item', function() {
			editor.moveSelectionRange(outlineSetup.one);
			editor.selectionRange().rangeItems.should.eql([outlineSetup.one]);
			editor.selectionRange().isItemMode.should.be.true;
			editor.selectionRange().focusItem.should.equal(outlineSetup.one);
			editor.selectionRange().anchorItem.should.equal(outlineSetup.one);
			should(editor.selectionRange().focusOffset === undefined);
			should(editor.selectionRange().anchorOffset === undefined);
		});

		it('should select item text', function() {
			editor.moveSelectionRange(outlineSetup.one, 1);
			editor.selectionRange().rangeItems.should.eql([outlineSetup.one]);
			editor.selectionRange().isTextMode.should.be.true;
		});

		it('should extend text selection', function() {
			editor.moveSelectionRange(outlineSetup.one, 1);
			editor.extendSelectionRange(outlineSetup.one, 3);
			editor.selectionRange().isTextMode.should.be.true;
			editor.selectionRange().focusOffset.should.equal(3);
			editor.selectionRange().anchorOffset.should.equal(1);
		});

		it('should null/undefined selection if invalid', function() {
			editor.moveSelectionRange(outlineSetup.one, 4);
			editor.selectionRange().isValid.should.be.false;
			should(editor.selectionRange().focusItem === null);
			should(editor.selectionRange().focusOffset === undefined);
		});

		describe('Focus', function() {
			it('should not focus editor when setting selection unless it already has focus', function() {
				editor.moveSelectionRange(outlineSetup.one);
				document.activeElement.should.not.equal(editor.outlineEditorElement.outlineEditorFocusElement);
				editor.moveSelectionRange(outlineSetup.one, 1);
				document.activeElement.textContent.should.not.equal(outlineSetup.one.bodyText);
			});

			it('should focus item mode focus element when selecting item', function() {
				editor.focus();
				editor.moveSelectionRange(outlineSetup.one);
				should(document.getSelection().focusNode === null);
				document.activeElement.should.equal(editor.outlineEditorElement.outlineEditorFocusElement);
			});

			it('should focus item text when selecting item text', function() {
				editor.focus();
				editor.moveSelectionRange(outlineSetup.one, 1);
				document.getSelection().focusNode.should.equal(editor.outlineEditorElement.itemViewPForItem(outlineSetup.one).firstChild);
				document.getSelection().focusOffset.should.equal(1);
				document.activeElement.textContent.should.equal(outlineSetup.one.bodyText);
			});

			it('should focus item text when extending text selection', function() {
				editor.focus();
				editor.moveSelectionRange(outlineSetup.one, 1);
				editor.extendSelectionRange(outlineSetup.one, 3);
				document.getSelection().focusNode.should.equal(editor.outlineEditorElement.itemViewPForItem(outlineSetup.one).firstChild);
				document.getSelection().focusOffset.should.equal(3);
				document.getSelection().anchorOffset.should.equal(1);
			});

			it('should focus item mode focus element when extending to item selection', function() {
				editor.focus();
				editor.setExpanded(outlineSetup.one, true);
				editor.moveSelectionRange(outlineSetup.two, 1);
				editor.extendSelectionRange(outlineSetup.five, 3);
				should(document.getSelection().focusNode === null);
				document.activeElement.should.equal(editor.outlineEditorElement.outlineEditorFocusElement);
			});

			it('should focus item mode focus element on invalid selection', function() {
				editor.focus();
				editor.moveSelectionRange(outlineSetup.one, 4);
				document.activeElement.should.equal(editor.outlineEditorElement.outlineEditorFocusElement);
			});
		});
	});

	describe('Deleting', function() {
		it('should delete selection', function() {
			editor.moveSelectionRange(outlineSetup.one, 1, outlineSetup.one, 3);
			editor.delete();
			outlineSetup.one.bodyText.should.equal('o');
		});

		it('should delete backward by character', function() {
			editor.moveSelectionRange(outlineSetup.one, 1);
			editor.delete('backward', 'character');
			outlineSetup.one.bodyText.should.equal('ne');
		});

		it('should delete forward by character', function() {
			editor.moveSelectionRange(outlineSetup.one, 1);
			editor.delete('forward', 'character');
			outlineSetup.one.bodyText.should.equal('oe');
		});

		it('should delete backward by word', function() {
			outlineSetup.one.bodyText = 'one two three';
			editor.moveSelectionRange(outlineSetup.one, 7);
			editor.delete('backward', 'word');
			outlineSetup.one.bodyText.should.equal('one  three');
		});

		it('should delete forward by word', function() {
			outlineSetup.one.bodyText = 'one two three';
			editor.moveSelectionRange(outlineSetup.one, 7);
			editor.delete('forward', 'word');
			outlineSetup.one.bodyText.should.equal('one two');
		});

		it('should delete backward by line boundary', function() {
			outlineSetup.one.bodyText = 'one two three';
			editor.moveSelectionRange(outlineSetup.one, 12);
			editor.delete('backward', 'lineboundary');
			outlineSetup.one.bodyText.should.equal('e');
		});

		it('should delete backward by character joining with previous node', function() {
			editor.setExpanded(outlineSetup.one, true);
			editor.moveSelectionRange(outlineSetup.two, 0);
			editor.delete('backward', 'character');
			outlineSetup.one.bodyText.should.equal('onetwo');
			editor.selectionRange().focusItem.should.eql(outlineSetup.one);
			editor.selectionRange().focusOffset.should.eql(3);
			outlineSetup.two.isInOutline.should.be.false;
			outlineSetup.three.isInOutline.should.be.true;
			outlineSetup.three.parent.should.eql(outlineSetup.one);
			outlineSetup.four.isInOutline.should.be.true;
			outlineSetup.four.parent.should.eql(outlineSetup.one);
		});

		it('should delete backward by word joining with previous node', function() {
			editor.setExpanded(outlineSetup.one, true);
			editor.moveSelectionRange(outlineSetup.two, 0);
			editor.delete('backward', 'word');
			outlineSetup.one.bodyText.should.equal('two');
			editor.selectionRange().focusItem.should.eql(outlineSetup.one);
			editor.selectionRange().focusOffset.should.eql(0);
			outlineSetup.two.isInOutline.should.be.false;
		});

		it('should delete backward by word from empty line joining with previous node', function() {
			editor.setExpanded(outlineSetup.one, true);
			outlineSetup.two.bodyText = '';
			editor.moveSelectionRange(outlineSetup.two, 0);
			editor.delete('backward', 'word');
			outlineSetup.one.bodyText.should.equal('');
			editor.selectionRange().focusItem.should.eql(outlineSetup.one);
			editor.selectionRange().focusOffset.should.eql(0);
			outlineSetup.two.isInOutline.should.be.false;
		});

		it('should delete forward by character joining with next node', function() {
			editor.setExpanded(outlineSetup.one, true);
			editor.moveSelectionRange(outlineSetup.one, 3);
			editor.delete('forward', 'character');
			outlineSetup.one.bodyText.should.equal('onetwo');
			editor.selectionRange().focusItem.should.eql(outlineSetup.one);
			editor.selectionRange().focusOffset.should.eql(3);
			outlineSetup.two.isInOutline.should.be.false;
		});


		it('should delete forward by word joining with previous node', function() {
			editor.setExpanded(outlineSetup.one, true);
			editor.moveSelectionRange(outlineSetup.one, 3);
			editor.delete('forward', 'word');
			outlineSetup.one.bodyText.should.equal('one');
			editor.selectionRange().focusItem.should.eql(outlineSetup.one);
			editor.selectionRange().focusOffset.should.eql(3);
			outlineSetup.two.isInOutline.should.be.false;
		});
	});
});
