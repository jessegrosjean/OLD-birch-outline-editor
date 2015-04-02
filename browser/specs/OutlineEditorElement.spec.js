'use strict';

var OutlineEditor = require('birch/OutlineEditor'),
	Outline = require('birch/Outline'),
	OutlineEditorElement = require('birch/OutlineEditorElement'),
	should = require('should');

describe('OutlineEditorElement', function() {
	var outlineSetup, outline, editor, outlineEditorElement;

	beforeEach(function() {
		outlineSetup = require('./newOutlineSetup')();
		outline = outlineSetup.outline;
		editor = new OutlineEditor(outline);
		outlineEditorElement = editor.outlineEditorElement;
		document.body.appendChild(outlineEditorElement);
		outlineEditorElement.disableAnimation(); // otherwise breaks geometry tests sometimes
		editor.setExpanded([
			outlineSetup.one,
			outlineSetup.two,
			outlineSetup.five
		]);
	});

	afterEach(function() {
		editor.destroyed();
	});

	describe('Render', function() {
		describe('Model', function() {
			it('should render outline', function() {
				outlineEditorElement.textContent.should.equal('onetwothreefourfivesix');
			});

			it('should update when text changes', function() {
				outlineSetup.three.bodyText = 'NEW';
				outlineEditorElement.textContent.should.equal('onetwoNEWfourfivesix');
			});

			it('should update when child is added', function() {
				outlineSetup.two.appendChild(outline.createItem('Howdy!'));
				outlineEditorElement.textContent.should.equal('onetwothreefourHowdy!fivesix');
			});

			it('should update when child is removed', function() {
				outlineEditorElement.disableAnimation();
				outlineSetup.two.removeFromParent();
				outlineEditorElement.enableAnimation();
				outlineEditorElement.textContent.should.equal('onefivesix');
			});

			it('should update when attribute is changed', function() {
				var viewLI = document.getElementById(outlineSetup.three.id);
				should(viewLI.getAttribute('my') === null);
				outlineSetup.three.setAttribute('my', 'test');
				viewLI.getAttribute('my').should.equal('test');
			});

			it('should update when body text is changed', function() {
				var viewLI = document.getElementById(outlineSetup.one.id);
				outlineSetup.one.bodyText = 'one two three';
				outlineSetup.one.addElementInBodyTextRange('B', null, 4, 3);
				outlineEditorElement._itemViewBodyP(viewLI).innerHTML.should.equal('one <b>two</b> three');
			});

			it('should not crash when offscreen item is changed', function() {
				editor.setCollapsed(outlineSetup.one);
				outlineSetup.four.bodyText = 'one two three';
			});

			it('should not crash when child is added to offscreen item', function() {
				editor.setCollapsed(outlineSetup.one);
				outlineSetup.four.appendChild(outline.createItem('Boo!'));
			});

			it('should update correctly when child is inserted into filtered view', function() {
				editor.hoistItem(outlineSetup.one);
				editor.setSearch('five');

				var item = editor.insertItem('Boo!');
				item.nextSibling.should.equal(outlineSetup.five);
				var renderedItemLI = outlineEditorElement.itemViewLIForItem(item);
				renderedItemLI.nextSibling.should.equal(outlineEditorElement.itemViewLIForItem(item.nextSibling));
			});

			it('should update correctly when child is inserted before filtered sibling', function() {
				editor.hoistItem(outlineSetup.one);
				editor.setSearch('five');

				var item = editor.outline.createItem('Boo!');
				outlineSetup.one.insertChildBefore(item, outlineSetup.one.firstChild);
				var renderedItemLI = outlineEditorElement.itemViewLIForItem(item);
				var nextRenderedItemLI = outlineEditorElement.itemViewLIForItem(editor.getNextVisibleSibling(item));
				renderedItemLI.nextSibling.should.equal(nextRenderedItemLI);
			});
		});

		describe('Editor State', function() {
			it('should render selection state', function() {
				var li = outlineEditorElement.itemViewLIForItem(outlineSetup.one);
				editor.moveSelectionRange(outlineSetup.one);
				li.classList.contains('bitemselected').should.be.true;
				editor.moveSelectionRange(outlineSetup.two);
				li.classList.contains('bitemselected').should.be.false;
			});

			it('should render expanded state', function() {
				var li = outlineEditorElement.itemViewLIForItem(outlineSetup.one);
				li.classList.contains('bexpanded').should.be.true;
				editor.setCollapsed(outlineSetup.one);
				li.classList.contains('bexpanded').should.be.false;
			});
		});
	});

	describe('Picking', function() {
		it('should above/before', function() {
			var rect = outlineEditorElement.getBoundingClientRect(),
				itemCaretPosition = outlineEditorElement.pick(rect.left, rect.top).itemCaretPosition;
			itemCaretPosition.offsetItem.should.eql(outlineSetup.one);
			itemCaretPosition.offset.should.eql(0);
		});

		it('should above/after', function() {
			var rect = outlineEditorElement.getBoundingClientRect(),
				itemCaretPosition = outlineEditorElement.pick(rect.right, rect.top).itemCaretPosition;
			itemCaretPosition.offsetItem.should.eql(outlineSetup.one);
			itemCaretPosition.offset.should.eql(0);
		});

		it('should below/before', function() {
			var rect = outlineEditorElement.getBoundingClientRect(),
				itemCaretPosition = outlineEditorElement.pick(rect.left, rect.bottom).itemCaretPosition;
			itemCaretPosition.offsetItem.should.eql(outlineSetup.six);
			itemCaretPosition.offset.should.eql(3);
		});

		it('should below/after', function() {
			var rect = outlineEditorElement.getBoundingClientRect(),
				itemCaretPosition = outlineEditorElement.pick(rect.right, rect.bottom).itemCaretPosition;
			itemCaretPosition.offsetItem.should.eql(outlineSetup.six);
			itemCaretPosition.offset.should.eql(3);
		});

		it('should pick with no items without stackoverflow', function() {
			outlineSetup.one.removeFromParent()
			var pick = outlineEditorElement.pick(0, 0);
		});

	});

	describe('Offset Encoding', function() {
		it('should translate from outline to DOM offsets', function() {
			var viewLI = document.getElementById(outlineSetup.one.id),
				p = outlineEditorElement._itemViewBodyP(viewLI);

			outlineEditorElement.itemOffsetToNodeOffset(outlineSetup.one, 0).should.eql({
				node: p,
				offset: 0
			});

			outlineEditorElement.itemOffsetToNodeOffset(outlineSetup.one, 2).should.eql({
				node: p.firstChild,
				offset: 2
			});

			outlineSetup.one.bodyHTML = 'one <b>two</b> three';

			p = outlineEditorElement._itemViewBodyP(viewLI);
			outlineEditorElement.itemOffsetToNodeOffset(outlineSetup.one, 4).should.eql({
				node: p.firstChild,
				offset: 4
			});

			outlineEditorElement.itemOffsetToNodeOffset(outlineSetup.one, 5).offset.should.equal(1);
			outlineEditorElement.itemOffsetToNodeOffset(outlineSetup.one, 7).offset.should.equal(3);
			outlineEditorElement.itemOffsetToNodeOffset(outlineSetup.one, 8).offset.should.equal(1);
		});

		it('should translate from DOM to outline', function() {
			var viewLI = document.getElementById(outlineSetup.one.id),
				p = outlineEditorElement._itemViewBodyP(viewLI);

			outlineEditorElement.nodeOffsetToItemOffset(p, 0).should.equal(0);
			outlineEditorElement.nodeOffsetToItemOffset(p.firstChild, 0).should.equal(0);

			outlineSetup.one.bodyHTML = 'one <b>two</b> three';
				p = outlineEditorElement._itemViewBodyP(viewLI);

			outlineEditorElement.nodeOffsetToItemOffset(p, 0).should.equal(0);
			outlineEditorElement.nodeOffsetToItemOffset(p, 1).should.equal(4);
			outlineEditorElement.nodeOffsetToItemOffset(p, 2).should.equal(7);

			var b = p.firstChild.nextSibling;
			outlineEditorElement.nodeOffsetToItemOffset(b, 0).should.equal(4);
			outlineEditorElement.nodeOffsetToItemOffset(b.firstChild, 2).should.equal(6);

			outlineEditorElement.nodeOffsetToItemOffset(p.lastChild, 0).should.equal(7);
			outlineEditorElement.nodeOffsetToItemOffset(p.lastChild, 3).should.equal(10);
		});
	});
});
