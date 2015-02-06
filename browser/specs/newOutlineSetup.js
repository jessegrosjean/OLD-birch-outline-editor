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

	xmlhttp.open('GET', './fixtures/newOutline.html', false);
	xmlhttp.send();
	htmlDoc = parser.parseFromString(xmlhttp.responseText, 'text/html');

	var outline = new Outline({outlineStore: htmlDoc}),
		root = outline.root,
		one = outline.itemForID('1'),
		two = outline.itemForID('2'),
		three = outline.itemForID('3'),
		four = outline.itemForID('4'),
		five = outline.itemForID('5'),
		six = outline.itemForID('6');

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