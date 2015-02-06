'use strict';

var AttributeRun = require('birch/AttributeRun'),
	AttributedString = require('birch/AttributedString'),
	Outline = require('birch/Outline'),
	Item = require('birch/Item'),
	should = require('should');

describe('AttributedString', function() {
	var attributedString;

	beforeEach(function() {
		attributedString = new AttributedString('Hello world!');
	});

	afterEach(function() {
	});

	it('should create copy', function () {
		attributedString.addAttributeInRange('name', 'jesse', 0, 12);
		var copy = attributedString.copy();
		attributedString.toString().should.equal(copy.toString());
	});

	describe('Get Substrings', function() {
		it('should get string', function () {
			attributedString.string().should.equal('Hello world!');
		});

		it('should get substring', function () {
			attributedString.string(0, 5).should.equal('Hello');
			attributedString.string(6, 6).should.equal('world!');
		});

		it('should get attributed substring from start', function () {
			var substring = attributedString.attributedSubstring(0, 5);
			substring.toString().should.equal('(Hello/)');
		});

		it('should get attributed substring from end', function () {
			var substring = attributedString.attributedSubstring(6, 6);
			substring.toString().should.equal('(world!/)');
		});

		it('should get full attributed substring', function () {
			var substring = attributedString.attributedSubstring();
			substring.toString().should.equal(attributedString.toString());

			var substring = attributedString.attributedSubstring(0, 12);
			substring.toString().should.equal(attributedString.toString());
		});

		it('should get empty attributed substring', function () {
			attributedString.attributedSubstring(1, 0).toString().should.equal('(/)');
		});

		it('should get attributed substring with attributes', function () {
			attributedString.addAttributeInRange('name', 'jesse', 0, 5);

			var substring = attributedString.attributedSubstring(0, 12);
			substring.toString().should.equal(attributedString.toString());

			substring = attributedString.attributedSubstring(0, 5);
			substring.toString().should.equal('(Hello/name)');
		});

		it('should get attributed substring with overlapping attributes', function () {
			attributedString.addAttributeInRange('i', null, 0, 12);
			attributedString.addAttributeInRange('b', null, 4, 3);
			attributedString.toString().should.equal('(Hell/i)(o w/b, i)(orld!/i)');
			var substring = attributedString.attributedSubstring(6, 6);
			substring.toString().should.equal('(w/b, i)(orld!/i)');
		});
	});

	describe('Delete Characters', function() {
		it('should delete from start', function () {
			attributedString.deleteCharactersInRange(0, 6);
			attributedString.toString().should.equal('(world!/)');
		});

		it('should delete from end', function () {
			attributedString.deleteCharactersInRange(5, 7);
			attributedString.toString().should.equal('(Hello/)');
		});

		it('should delete from middle', function () {
			attributedString.deleteCharactersInRange(3, 5);
			attributedString.toString().should.equal('(Helrld!/)');
		});

		it('should adjust attribute run when deleting from start', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.deleteCharactersInRange(0, 1);
			attributedString.toString().should.equal('(ello/b)( world!/)');
		});

		it('should adjust attribute run when deleting from end', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.deleteCharactersInRange(3, 2);
			attributedString.toString().should.equal('(Hel/b)( world!/)');
		});

		it('should adjust attribute run when deleting from middle', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.deleteCharactersInRange(2, 2);
			attributedString.toString().should.equal('(Heo/b)( world!/)');
		});

		it('should adjust attribute run when overlapping start', function () {
			attributedString.addAttributeInRange('b', null, 6, 6);
			attributedString.deleteCharactersInRange(5, 2);
			attributedString.toString().should.equal('(Hello/)(orld!/b)');
		});

		it('should adjust attribute run when overlapping end', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.deleteCharactersInRange(4, 2);
			attributedString.toString().should.equal('(Hell/b)(world!/)');
		});

		it('should remove attribute run when covering from start', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.deleteCharactersInRange(0, 6);
			attributedString.toString().should.equal('(world!/)');
		});

		it('should remove attribute run when covering from end', function () {
			attributedString.addAttributeInRange('b', null, 6, 6);
			attributedString.deleteCharactersInRange(5, 7);
			attributedString.toString().should.equal('(Hello/)');
		});
	});

	describe('Insert String', function() {
		it('should insert at start', function () {
			attributedString.insertStringAtLocation('Boo!', 0);
			attributedString.toString().should.equal('(Boo!Hello world!/)');
		});

		it('should insert at end', function () {
			attributedString.insertStringAtLocation('Boo!', 12);
			attributedString.toString().should.equal('(Hello world!Boo!/)');
		});

		it('should insert in middle', function () {
			attributedString.insertStringAtLocation('Boo!', 6);
			attributedString.toString().should.equal('(Hello Boo!world!/)');
		});

		it('should insert into empty string', function () {
			attributedString.deleteCharactersInRange(0, 12);
			attributedString.insertStringAtLocation('Boo!', 0);
			attributedString.toString().should.equal('(Boo!/)');
		});

		it('should adjust attribute run when inserting at run start', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.insertStringAtLocation('Boo!', 0);
			attributedString.toString().should.equal('(Boo!Hello/b)( world!/)');
		});

		it('should adjust attribute run when inserting at run end', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.insertStringAtLocation('Boo!', 5);
			attributedString.toString().should.equal('(HelloBoo!/b)( world!/)');
		});

		it('should adjust attribute run when inserting in run middle', function () {
			attributedString.addAttributeInRange('b', null, 0, 5);
			attributedString.insertStringAtLocation('Boo!', 3);
			attributedString.toString().should.equal('(HelBoo!lo/b)( world!/)');
		});

		it('should insert attributed string including runs', function () {
			var insert = new AttributedString('Boo!');
			insert.addAttributeInRange('i', null, 0, 3);
			insert.addAttributeInRange('b', null, 1, 3);
			attributedString.insertStringAtLocation(insert, 0);
			attributedString.toString().should.equal('(B/i)(oo/b, i)(!/b)(Hello world!/)');
		});
	});

	describe('Replace Substrings', function() {
		it('should update attribute runs when attributed string is modified', function () {
			attributedString.addAttributeInRange('name', 'jesse', 0, 12);
			attributedString.replaceCharactersInRange('Hello', 0, 12);
			attributedString.toString(true).should.equal('(Hello/name="jesse")');
			attributedString.replaceCharactersInRange(' World!', 5, 0);
			attributedString.toString(true).should.equal('(Hello World!/name="jesse")');
		});

		it('should update attribute runs when node text is paritially updated', function () {
			attributedString.addAttributeInRange('name', 'jesse', 0, 5);
			attributedString.addAttributeInRange('name', 'joe', 5, 7);
			attributedString.toString(true).should.equal('(Hello/name="jesse")( world!/name="joe")');

			attributedString.replaceCharactersInRange('', 3, 5);
			attributedString.toString(true).should.equal('(Hel/name="jesse")(rld!/name="joe")');

			attributedString.replaceCharactersInRange('lo wo', 3, 0);
			attributedString.toString(true).should.equal('(Hello wo/name="jesse")(rld!/name="joe")');
		});

		it('should remove leading attribute run if text in run is fully replaced', function () {
			attributedString = new AttributedString('\ttwo');
			attributedString.addAttributeInRange('name', 'jesse', 0, 1);
			attributedString.replaceCharactersInRange('', 0, 1);
			attributedString.toString().should.equal('(two/)');
		});

		it('should allow inserting of another attributed string', function () {
			var newString = new AttributedString('two');
			newString.addAttributeInRange('b', null, 0, 3);

			attributedString.addAttributeInRange('i', null, 0, 12);
			attributedString.replaceCharactersInRange(newString, 5, 1);
			attributedString.toString().should.equal('(Hello/i)(two/b)(world!/i)');
		});
	});

	describe('Add/Remove/Find Attributes', function() {
		it('should add attribute run', function () {
			var effectiveRange = {};
			attributedString.addAttributeInRange('name', 'jesse', 0, 5);

			attributedString.attributesAtIndex(0, effectiveRange).name.should.equal('jesse');
			effectiveRange.location.should.equal(0);
			effectiveRange.length.should.equal(5);
			attributedString.attributesAtIndex(5, effectiveRange).should.eql({})
			effectiveRange.location.should.equal(5);
			effectiveRange.length.should.equal(7);
		});

		it('should add attribute run bordering start of string', function () {
			var effectiveRange = {};
			attributedString.addAttributeInRange('name', 'jesse', 0, 5);
			attributedString.attributesAtIndex(0, effectiveRange).name.should.equal('jesse');
			effectiveRange.location.should.equal(0);
			effectiveRange.length.should.equal(5);
		});

		it('should add attribute run bordering end of string', function () {
			var effectiveRange = {};
			attributedString.addAttributeInRange('name', 'jesse', 6, 6);
			attributedString.attributesAtIndex(6, effectiveRange).name.should.equal('jesse');
			effectiveRange.location.should.equal(6);
			effectiveRange.length.should.equal(6);
		});

		it('should find longest effective range for attribute', function () {
			var longestEffectiveRange = {};
			attributedString.addAttributeInRange('one', 'one', 0, 12);
			attributedString.addAttributeInRange('two', 'two', 6, 6);
			attributedString.attributeAtIndex('one', 6, null, longestEffectiveRange).should.equal('one');
			longestEffectiveRange.location.should.equal(0);
			longestEffectiveRange.length.should.equal(12);
		});

		it('should find longest effective range for attributes', function () {
			var longestEffectiveRange = {};
			attributedString.addAttributeInRange('one', 'one', 0, 12);
			attributedString.addAttributeInRange('two', 'two', 6, 6);
			attributedString._indexOfAttributeRunForCharacterIndex(10); // artificial split
			attributedString.attributesAtIndex(6, null, longestEffectiveRange);
			longestEffectiveRange.location.should.equal(6);
			longestEffectiveRange.length.should.equal(6);
		});

		it('should add multiple attributes in same attribute run', function () {
			var effectiveRange = {};
			attributedString.addAttributeInRange('name', 'jesse', 0, 5);
			attributedString.addAttributeInRange('age', '35', 0, 5);
			attributedString.attributesAtIndex(0, effectiveRange).name.should.equal('jesse');
			attributedString.attributesAtIndex(0, effectiveRange).age.should.equal('35');
			effectiveRange.location.should.equal(0);
			effectiveRange.length.should.equal(5);
		});

		it('should add attributes in overlapping ranges', function () {
			var effectiveRange = {};
			attributedString.addAttributeInRange('name', 'jesse', 0, 5);
			attributedString.addAttributeInRange('age', '35', 3, 5);

			attributedString.attributesAtIndex(0, effectiveRange).name.should.equal('jesse');
			(attributedString.attributesAtIndex(0, effectiveRange).age === undefined).should.be.true;
			effectiveRange.location.should.equal(0);
			effectiveRange.length.should.equal(3);

			attributedString.attributesAtIndex(3, effectiveRange).name.should.equal('jesse');
			attributedString.attributesAtIndex(3, effectiveRange).age.should.equal('35');
			effectiveRange.location.should.equal(3);
			effectiveRange.length.should.equal(2);

			(attributedString.attributesAtIndex(6, effectiveRange).name === undefined).should.be.true;
			attributedString.attributesAtIndex(6, effectiveRange).age.should.equal('35');
			effectiveRange.location.should.equal(5);
			effectiveRange.length.should.equal(3);
		});

		it('should allow removing attributes in range', function () {
			attributedString.addAttributeInRange('name', 'jesse', 0, 12);
			attributedString.removeAttributeInRange('name', 0, 12);
			attributedString.toString(true).should.equal('(Hello world!/)');

			attributedString.addAttributeInRange('name', 'jesse', 0, 12);
			attributedString.removeAttributeInRange('name', 0, 3);
			attributedString.toString(true).should.equal('(Hel/)(lo world!/name="jesse")');

			attributedString.removeAttributeInRange('name', 9, 3);
			attributedString.toString(true).should.equal('(Hel/)(lo wor/name="jesse")(ld!/)');
		});

		it('should return null when accessing attributes at end of string', function () {
			should(attributedString.attributesAtIndex(0, null) !== null).be.ok;
			should(attributedString.attributesAtIndex(11, null) !== null).be.ok;
			should(attributedString.attributesAtIndex(12, null) !== null).not.be.ok;
			attributedString.replaceCharactersInRange('', 0, 12);
			should(attributedString.attributesAtIndex(0, null) !== null).not.be.ok;
		});
	});
});