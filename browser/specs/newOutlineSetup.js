var Outline = Outline = require('birch/Outline');

//	one
//		two
//			three
//			four
//		five
//			six

module.exports = function () {
	var xmlhttp = new XMLHttpRequest(),
		parser = new DOMParser(),
		htmlDoc;

	xmlhttp.open('GET', './fixtures/newOutline.bml', false);
	xmlhttp.send();
	htmlDoc = parser.parseFromString(xmlhttp.responseText, 'text/html');

	var outline = new Outline({outlineStore: htmlDoc}),
		root = outline.root,
		one = outline.getItemForID('1'),
		two = outline.getItemForID('2'),
		three = outline.getItemForID('3'),
		four = outline.getItemForID('4'),
		five = outline.getItemForID('5'),
		six = outline.getItemForID('6');

	return {
		outline: outline,
		root: root,
		one: one,
		two: two,
		three: three,
		four: four,
		five: five,
		six: six
	}
}