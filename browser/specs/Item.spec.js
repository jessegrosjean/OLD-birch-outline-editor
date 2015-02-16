'use strict';

var Constants = require('birch/Constants'),
	Outline = require('birch/Outline'),
	Item = require('birch/Item'),
	Util = require('birch/Util'),
	should = require('should');

describe('Item', function() {
	var outlineSetup, outline;

	beforeEach(function() {
		outlineSetup = require('./newOutlineSetup')();
		outline = outlineSetup.outline;
	});

	it('should get parent', function() {
		outlineSetup.two.parent.should.equal(outlineSetup.one);
		outlineSetup.one.parent.should.equal(outlineSetup.root);
	});

	it('should append item', function() {
		var item = outline.createItem('hello');
		outline.root.appendChild(item);
		item.parent.should.equal(outline.root);
		item.isInOutline.should.be.true;
	});

	it('should delete item', function() {
		outlineSetup.two.removeFromParent();
		should(outlineSetup.two.parent === null);
	});

	it('should make item connections', function() {
		outlineSetup.one.firstChild.should.equal(outlineSetup.two);
		outlineSetup.one.lastChild.should.equal(outlineSetup.five);
		outlineSetup.one.firstChild.nextSibling.should.equal(outlineSetup.five);
		outlineSetup.one.lastChild.previousSibling.should.equal(outlineSetup.two);
	});

	it('should calculate cover items', function() {
		Item.coverItems([
			outlineSetup.three,
			outlineSetup.five,
			outlineSetup.six,
		]).should.eql([outlineSetup.three, outlineSetup.five]);
	});

	describe('Body', function() {
		it('should get', function() {
			outlineSetup.one.bodyText.should.equal('one');
			outlineSetup.one.bodyHTML.should.equal('one');
			outlineSetup.one.bodyTextLength.should.equal(3);
		});

		it('should get empy', function() {
			var item = outline.createItem('');
			item.bodyText.should.equal('');
			item.bodyHTML.should.equal('');
			item.bodyTextLength.should.equal(0);
		});

		it('should get/set by Text', function() {
			outlineSetup.one.bodyText = 'one <b>two</b> three';
			outlineSetup.one.bodyText.should.equal('one <b>two</b> three');
			outlineSetup.one.bodyHTML.should.equal('one &lt;b&gt;two&lt;/b&gt; three');
			outlineSetup.one.bodyTextLength.should.equal(20);
		});

		it('should get/set by HTML', function() {
			outlineSetup.one.bodyHTML = 'one <b>two</b> three';
			outlineSetup.one.bodyText.should.equal('one two three');
			outlineSetup.one.bodyHTML.should.equal('one <b>two</b> three');
			outlineSetup.one.bodyTextLength.should.equal(13);
		});

		xit('should fill existing tag with replaced text if present', function() {
			outlineSetup.one.bodyHTML = 'one <b>two</b> three';
			outlineSetup.one.replaceBodyTextInRange('hi', 4, 3);
			outlineSetup.one.bodyHTML.should.equal('one <b>hi</b> three');
		});

		describe('Inline Elements', function() {
			it('should get elements', function() {
				outlineSetup.one.bodyHTML = '<b>one</b> <img src="boo.png">two three';
				outlineSetup.one.elementsAtBodyTextIndex(0).should.eql({ B: null });
				outlineSetup.one.elementsAtBodyTextIndex(4).should.eql({ IMG: { src: 'boo.png' } });
			});

			it('should get empty elements', function() {
				outlineSetup.one.bodyText = 'one two three';
				outlineSetup.one.elementsAtBodyTextIndex(0).should.eql({});
			});

			it('should add elements', function() {
				outlineSetup.one.bodyText = 'one two three';
				outlineSetup.one.addElementInBodyTextRange('B', null, 4, 3);
				outlineSetup.one.bodyHTML.should.equal('one <b>two</b> three');
			});

			it('should add overlapping back element', function() {
				outlineSetup.one.bodyText = 'one two three';
				outlineSetup.one.addElementInBodyTextRange('B', null, 0, 7);
				outlineSetup.one.addElementInBodyTextRange('I', null, 4, 9);
				outlineSetup.one.bodyHTML.should.equal('<b>one <i>two</i></b><i> three</i>');
			});

			it('should add overlapping front and back element', function() {
				outlineSetup.one.bodyText = 'three';
				outlineSetup.one.addElementInBodyTextRange('B', null, 0, 2);
				outlineSetup.one.addElementInBodyTextRange('U', null, 1, 3);
				outlineSetup.one.addElementInBodyTextRange('I', null, 3, 2);
				outlineSetup.one.bodyHTML.should.equal('<b>t<u>h</u></b><u>r<i>e</i></u><i>e</i>');
			});

			it('should remove element', function() {
				outlineSetup.one.bodyHTML = '<b>one</b>';
				outlineSetup.one.removeElementInBodyTextRange('B', 0, 3);
				outlineSetup.one.bodyHTML.should.equal('one');
			});

			it('should remove middle of element span', function() {
				outlineSetup.one.bodyHTML = '<b>one</b>';
				outlineSetup.one.removeElementInBodyTextRange('B', 1, 1);
				outlineSetup.one.bodyHTML.should.equal('<b>o</b>n<b>e</b>');
			});

			describe('Void Elements', function() {
				it('should remove tags when they become empty if they are not void tags', function() {
					outlineSetup.one.bodyHTML = 'one <b>two</b> three';
					outlineSetup.one.replaceBodyTextInRange('', 4, 3);
					outlineSetup.one.bodyText.should.equal('one  three');
					outlineSetup.one.bodyHTML.should.equal('one  three');
				});

				it('should not remove void tags that are empty', function() {
					outlineSetup.one.bodyHTML = 'one <br><img> three';
					outlineSetup.one.bodyTextLength.should.equal(12);
					outlineSetup.one.bodyHTML.should.equal('one <br><img> three');
				});

				it('void tags should count as length 1 in outline range', function() {
					outlineSetup.one.bodyHTML = 'one <br><img> three';
					outlineSetup.one.replaceBodyTextInRange('', 7, 3);
					outlineSetup.one.bodyHTML.should.equal('one <br><img> ee');
				});

				it('void tags should be replaceable', function() {
					outlineSetup.one.bodyHTML = 'one <br><img> three';
					outlineSetup.one.replaceBodyTextInRange('', 4, 1);
					outlineSetup.one.bodyHTML.should.equal('one <img> three');
					outlineSetup.one.bodyTextLength.should.equal(11);
				});

				xit('text content enocde <br> using "New Line Character"', function() {
					outlineSetup.one.bodyText = 'one \u2028 three';
					outlineSetup.one.bodyHTML.should.equal('one <br> three');
					outlineSetup.one.bodyText.should.equal('one \u2028 three');
					outlineSetup.one.bodyText(4, 1).should.equal(Constants.LineSeparatorCharacter);
				});

				it('text content encode <img> and other void tags using "Object Replacement Character"', function() {
					outlineSetup.one.bodyHTML = 'one <img> three';
					outlineSetup.one.bodyText.should.equal('one \ufffc three');
				});
			});
		});
	});

	describe('Aliases', function() {
		it('should alias item', function() {
			var twoAlias = outlineSetup.two.aliasItem();
			outlineSetup.two.isAliased.should.be.true;
			outlineSetup.two.firstChild.isAliased.should.be.true;
			twoAlias.isAliased.should.be.true;
			twoAlias.firstChild.isAliased.should.be.true;
		});

		it('should keep aliased item attributes in sync', function() {
			var twoAlias = outlineSetup.two.aliasItem();

			outlineSetup.two.setAttribute('hello', 'world');
			outlineSetup.two.getAttribute('hello').should.equal('world');
			twoAlias.getAttribute('hello').should.equal('world');

			twoAlias.setAttribute('hello', 'world!');
			outlineSetup.two.getAttribute('hello').should.equal('world!');
			twoAlias.getAttribute('hello').should.equal('world!');
		});

		it('should keep aliased item children in sync on remove', function() {
			var twoAlias = outlineSetup.two.aliasItem();

			twoAlias.lastChild.bodyText.should.equal('four');
			outlineSetup.two.lastChild.bodyText.should.equal('four');
			twoAlias.lastChild.removeFromParent();
			twoAlias.lastChild.bodyText.should.equal('three');
			outlineSetup.two.lastChild.bodyText.should.equal('three');
		});

		it('should keep aliased item children in sync on insert', function() {
			var twoAlias = outlineSetup.two.aliasItem(),
				newItem = outline.createItem('new!');

			twoAlias.appendChild(newItem);
			newItem.isAliased.should.be.true;
			twoAlias.lastChild.bodyText.should.equal('new!');
			outlineSetup.two.lastChild.bodyText.should.equal('new!');
		});
	});
});
