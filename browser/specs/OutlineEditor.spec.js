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
			editor.getHoistedItem().should.equal(outline.root);
			editor.isVisible(editor.getHoistedItem()).should.be.false;
		});

		it('should make children of hoisted item visible', function() {
			editor.hoistItem(outlineSetup.two);
			editor.isVisible(editor.getHoistedItem()).should.be.false;
			editor.isVisible(outlineSetup.three).should.be.true;
			editor.isVisible(outlineSetup.four).should.be.true;
		});

		describe('Auto Create Child', function() {
			it('should autocreate child when needed', function() {
				should(outlineSetup.three.firstChild).not.be.ok;
				editor.hoistItem(outlineSetup.three);
				outlineSetup.three.firstChild.should.be.ok;
			});

			it('should select autocreated child', function() {
				editor.hoistItem(outlineSetup.three);
				editor.isSelected(outlineSetup.three.firstChild).should.be.true;
			});

			it('should delete autocreated child if empty', function() {
				editor.hoistItem(outlineSetup.three);
				editor.unhoist();
				should(outlineSetup.three.firstChild).not.be.ok;
			});

			it('should not delete autocreated child if not empty', function() {
				editor.hoistItem(outlineSetup.three);
				outlineSetup.three.firstChild.bodyText = 'save me!';
				editor.unhoist();
				outlineSetup.three.firstChild.should.be.ok;
			});
		});
	});

	describe('Expanding', function() {
		it('should make children of expanded visible', function() {
			editor.setExpanded(outlineSetup.one);
			editor.isExpanded(outlineSetup.one).should.be.true;
			editor.isVisible(outlineSetup.two).should.be.true;
			editor.isVisible(outlineSetup.five).should.be.true;

			editor.setCollapsed(outlineSetup.one);
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
		it('should select item', function() {
			editor.moveSelectionRange(outlineSetup.one);
			editor.selection.items.should.eql([outlineSetup.one]);
			editor.selection.isOutlineMode.should.be.true;
			editor.selection.focusItem.should.equal(outlineSetup.one);
			editor.selection.anchorItem.should.equal(outlineSetup.one);
			should(editor.selection.focusOffset === undefined);
			should(editor.selection.anchorOffset === undefined);
		});

		it('should select item text', function() {
			editor.moveSelectionRange(outlineSetup.one, 1);
			editor.selection.items.should.eql([outlineSetup.one]);
			editor.selection.isTextMode.should.be.true;
		});

		it('should extend text selection', function() {
			editor.moveSelectionRange(outlineSetup.one, 1);
			editor.extendSelectionRange(outlineSetup.one, 3);
			editor.selection.isTextMode.should.be.true;
			editor.selection.focusOffset.should.equal(3);
			editor.selection.anchorOffset.should.equal(1);
		});

		it('should null/undefined selection if invalid', function() {
			editor.moveSelectionRange(outlineSetup.one, 4);
			editor.selection.isValid.should.be.false;
			should(editor.selection.focusItem === null);
			should(editor.selection.focusOffset === undefined);
		});

		describe('Formatting', function() {
			it('should toggle formatting', function() {
				editor.moveSelectionRange(outlineSetup.one, 0, outlineSetup.one, 2);
				editor.toggleBold();
				outlineSetup.one.bodyHTML.should.equal('<b>on</b>e');
				editor.toggleBold();
				outlineSetup.one.bodyHTML.should.equal('one');
			});

			it('should toggle typing formatting tags if collapsed selection', function() {
				outlineSetup.one.bodyText = '';
				editor.moveSelectionRange(outlineSetup.one, 0);
				editor.toggleBold();
				editor.insertText('hello');
				outlineSetup.one.bodyHTML.should.equal('<b>hello</b>');
				editor.toggleBold();
				editor.insertText('world');
				outlineSetup.one.bodyHTML.should.equal('<b>hello</b>world');
			});
		});

		describe('Focus', function() {
			it('should not focus editor when setting selection unless it already has focus', function() {
				editor.moveSelectionRange(outlineSetup.one);
				document.activeElement.should.not.equal(editor.outlineEditorElement.focusElement);
				editor.moveSelectionRange(outlineSetup.one, 1);
				document.activeElement.textContent.should.not.equal(outlineSetup.one.bodyText);
			});

			it('should focus item mode focus element when selecting item', function() {
				editor.focus();
				editor.moveSelectionRange(outlineSetup.one);
				should(document.getSelection().focusNode === null);
				document.activeElement.should.equal(editor.outlineEditorElement.focusElement);
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
				editor.setExpanded(outlineSetup.one);
				editor.moveSelectionRange(outlineSetup.two, 1);
				editor.extendSelectionRange(outlineSetup.five, 3);
				should(document.getSelection().focusNode === null);
				document.activeElement.should.equal(editor.outlineEditorElement.focusElement);
			});

			it('should focus item mode focus element on invalid selection', function() {
				editor.focus();
				editor.moveSelectionRange(outlineSetup.one, 4);
				document.activeElement.should.equal(editor.outlineEditorElement.focusElement);
			});
		});
	});

	describe('Moving', function() {
		it ('should move items up', function () {
			editor.setExpanded(outlineSetup.one);
			editor.moveSelectionRange(outlineSetup.five);
			editor.moveItemsUp();
			outlineSetup.one.firstChild.should.equal(outlineSetup.five);
			outlineSetup.one.lastChild.should.equal(outlineSetup.two);
			editor.moveItemsUp(); // should do nothing
			outlineSetup.one.firstChild.should.equal(outlineSetup.five);
		});

		it ('should move items down', function () {
			editor.setExpanded(outlineSetup.one);
			editor.moveSelectionRange(outlineSetup.two);
			editor.moveItemsDown();
			outlineSetup.one.firstChild.should.equal(outlineSetup.five);
			outlineSetup.one.lastChild.should.equal(outlineSetup.two);
			editor.moveItemsDown(); // should do nothing
			outlineSetup.one.lastChild.should.equal(outlineSetup.two);
		});

		it ('should move items left', function () {
			editor.setExpanded(outlineSetup.one);
			editor.moveSelectionRange(outlineSetup.two);
			editor.moveItemsLeft();
			outlineSetup.one.firstChild.should.equal(outlineSetup.five);
			outlineSetup.one.nextSibling.should.equal(outlineSetup.two);
			editor.moveItemsLeft(); // should do nothing
			outlineSetup.one.nextSibling.should.equal(outlineSetup.two);
		});

		it ('should move items left with prev sibling children selected', function () {
			editor.setExpanded(outlineSetup.one);
			editor.setExpanded(outlineSetup.two);
			editor.moveSelectionRange(outlineSetup.four, undefined, outlineSetup.five);
			editor.moveItemsLeft();
			outlineSetup.two.nextSibling.should.equal(outlineSetup.four);
			outlineSetup.four.nextSibling.should.equal(outlineSetup.five);
		});

		it ('should move items right', function () {
			editor.setExpanded(outlineSetup.one);
			editor.setExpanded(outlineSetup.two);
			editor.moveSelectionRange(outlineSetup.four);
			editor.moveItemsRight();
			outlineSetup.three.firstChild.should.equal(outlineSetup.four);
			editor.moveItemsRight(); // should do nothing
			outlineSetup.three.firstChild.should.equal(outlineSetup.four);
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
			editor.setExpanded(outlineSetup.one);
			editor.moveSelectionRange(outlineSetup.two, 0);
			editor.delete('backward', 'character');
			outlineSetup.one.bodyText.should.equal('onetwo');
			editor.selection.focusItem.should.eql(outlineSetup.one);
			editor.selection.focusOffset.should.eql(3);
			outlineSetup.two.isInOutline.should.be.false;
			outlineSetup.three.isInOutline.should.be.true;
			outlineSetup.three.parent.should.eql(outlineSetup.one);
			outlineSetup.four.isInOutline.should.be.true;
			outlineSetup.four.parent.should.eql(outlineSetup.one);
		});

		it('should delete backward by word joining with previous node', function() {
			editor.setExpanded(outlineSetup.one);
			editor.moveSelectionRange(outlineSetup.two, 0);
			editor.delete('backward', 'word');
			outlineSetup.one.bodyText.should.equal('two');
			editor.selection.focusItem.should.eql(outlineSetup.one);
			editor.selection.focusOffset.should.eql(0);
			outlineSetup.two.isInOutline.should.be.false;
		});

		it('should delete backward by word from empty line joining with previous node', function() {
			editor.setExpanded(outlineSetup.one);
			outlineSetup.two.bodyText = '';
			editor.moveSelectionRange(outlineSetup.two, 0);
			editor.delete('backward', 'word');
			outlineSetup.one.bodyText.should.equal('');
			editor.selection.focusItem.should.eql(outlineSetup.one);
			editor.selection.focusOffset.should.eql(0);
			outlineSetup.two.isInOutline.should.be.false;
		});

		it('should delete forward by character joining with next node', function() {
			editor.setExpanded(outlineSetup.one);
			editor.moveSelectionRange(outlineSetup.one, 3);
			editor.delete('forward', 'character');
			outlineSetup.one.bodyText.should.equal('onetwo');
			editor.selection.focusItem.should.eql(outlineSetup.one);
			editor.selection.focusOffset.should.eql(3);
			outlineSetup.two.isInOutline.should.be.false;
		});


		it('should delete forward by word joining with previous node', function() {
			editor.setExpanded(outlineSetup.one);
			editor.moveSelectionRange(outlineSetup.one, 3);
			editor.delete('forward', 'word');
			outlineSetup.one.bodyText.should.equal('one');
			editor.selection.focusItem.should.eql(outlineSetup.one);
			editor.selection.focusOffset.should.eql(3);
			outlineSetup.two.isInOutline.should.be.false;
		});
	});
});
