'use strict';

var Outline = require('birch/Outline'),
	should = require('should');

describe('Outline', function() {
	var outlineSetup, outline;

	beforeEach(function() {
		outlineSetup = require('./newOutlineSetup')();
		outline = outlineSetup.outline;
	});

	it('should create item', function() {
		var item = outline.createItem('hello');
		item.isInOutline.should.be.false;
	});

	it('should get item by id', function() {
		var item = outline.createItem('hello');
		outline.root.appendChild(item);
		outline.getItemForID(item.id).should.equal(item);
	});

	it('should copy item', function() {
		var one = outlineSetup.one;
		var oneCopy = outline.cloneItem(one);
		oneCopy.isInOutline.should.be.false;
		oneCopy.id.should.not.equal(one.id);
		oneCopy.bodyText.should.equal('one');
		oneCopy.firstChild.bodyText.should.equal('two');
		oneCopy.firstChild.firstChild.bodyText.should.equal('three');
		oneCopy.firstChild.lastChild.bodyText.should.equal('four');
		oneCopy.lastChild.bodyText.should.equal('five');
		oneCopy.lastChild.firstChild.bodyText.should.equal('six');
	});

	it('should import item', function() {
		var one = outlineSetup.one;
		var outline2 = new Outline();

		var oneImport = outline2.importItem(one);
		oneImport.outline.should.equal(outline2);
		oneImport.isInOutline.should.be.false;
		oneImport.id.should.equal(one.id);
		oneImport.bodyText.should.equal('one');
		oneImport.firstChild.bodyText.should.equal('two');
		oneImport.firstChild.firstChild.bodyText.should.equal('three');
		oneImport.firstChild.lastChild.bodyText.should.equal('four');
		oneImport.lastChild.bodyText.should.equal('five');
		oneImport.lastChild.firstChild.bodyText.should.equal('six');
	});

	describe('Search', function() {
		it('should find DOM using xpath', function() {
			outline.evaluateXPath('//li', null, XPathResult.ANY_TYPE, null).iterateNext().should.equal(outlineSetup.one._liOrRootUL);
		});

		it('should find items using xpath', function() {
			var items = outline.getItemsForXPath('//li');
			items.should.eql([
				outlineSetup.one,
				outlineSetup.two,
				outlineSetup.three,
				outlineSetup.four,
				outlineSetup.five,
				outlineSetup.six
			]);
		});

		it('should only return item once even if multiple xpath matches', function() {
			var items = outline.getItemsForXPath('//*');
			items.should.eql([
				outlineSetup.root,
				outlineSetup.one,
				outlineSetup.two,
				outlineSetup.three,
				outlineSetup.four,
				outlineSetup.five,
				outlineSetup.six
			]);
		});
	});

	describe('Undo', function() {
		it('should undo body change', function() {
			outlineSetup.one.bodyText = 'hello word';
			outline.undoManager.undo();
			outlineSetup.one.bodyText.should.equal('one');
		});

		it('should undo append child', function() {
			var child = outline.createItem('hello');
			outlineSetup.one.appendChild(child);
			outline.undoManager.undo();
			should(child.parent === null);
		});

		it('should undo remove child', function() {
			outlineSetup.one.removeChild(outlineSetup.two);
			outline.undoManager.undo();
			outlineSetup.two.parent.should.equal(outlineSetup.one);
		});

		it('should undo move child', function() {
			outline.undoManager.beginUndoGrouping();
			outlineSetup.one.appendChild(outlineSetup.six);
			outline.undoManager.endUndoGrouping();
			outline.undoManager.undo();
			outlineSetup.six.parent.should.equal(outlineSetup.five);
		});
	});

	describe('Performance', function() {
		it('should create/copy/remove 10,000 items', function() {
			// Create, copy, past a all relatively slow compared to load
			// because of time taken to generate IDs and validate that they
			// are unique to the document. Seems there should be a better
			// solution for that part of the code.
			var branch = outline.createItem('branch');

			console.profile('Create Many');
			console.time('Create Many');
			var items = [];
			for (var i = 0; i < 10000; i++) {
				items.push(outline.createItem('hello'));
			}
			branch.appendChildren(items);
			outline.root.appendChild(branch);
			console.timeEnd('Create Many Items');
			console.profileEnd();

			console.time('Copy Many');
			branch.cloneItem();
			console.timeEnd('Copy Many');

			console.time('Remove Many');
			branch.removeChildren(items);
			console.timeEnd('Remove Many');
		});

		it('should load 100,000 items', function() {
			var xmlhttp = new XMLHttpRequest(),
				parser = new DOMParser(),
				htmlDoc;

			this.timeout(5000);

			xmlhttp.open('GET', './fixtures/performanceOutline.html', false);
			xmlhttp.send();
			htmlDoc = parser.parseFromString(xmlhttp.responseText, 'text/html');

			console.profile('Load Many');
			console.time('Load Many');
			var outline = new Outline(htmlDoc);
			console.timeEnd('Load Many');
			console.profileEnd();
		});
	});
});
