var OutlineEditorService = require('birch/OutlineEditorService'),
	OutlineEditor = OutlineEditorService.OutlineEditor,
	Outline = OutlineEditorService.Outline,
	date = new Date(),
	count = 1;

require('../../packages/durations');
require('../../packages/mentions');
require('../../packages/priorities');
require('../../packages/status');
require('../../packages/tags');

function createBranch(outline, depth, breadth) {
	var item = outline.createItem(count++ + ' ' + date);

	if (depth > 0) {
		for (var i = 0; i < breadth; i++) {
			item.appendChild(createBranch(outline, depth - 1, breadth));
		}
		//item.setAttribute('type', 'h');
	} else {
		//item.setAttribute('type', 'ol');
	}

	return item;
}


//require('birch/eventhandlers/ItemHandleDragHandler');
//require('birch/eventhandlers/EditorDropHandler');


var outline = new Outline();
//outline.root.appendChild(createBranch(outline, 3, 5));

//outline.root.appendChild(createBranch(outline, 3, 20));
//outline.root.firstChild.setBodyHTML('one <strong>two</strong><br /> <i>three</i>');

//outline.root.appendChild(outline.createItem('two'));
//outline.root.appendChild(outline.createItem('three'));
//outline.root.appendChild(outline.createItem('four'));

/*setTimeout(function() {
	for (var i = 0; i < 3; i++) {
		var three = outline.root.lastChild.previousSibling;
		three.removeFromParent();
		outline.root.insertChildBefore(three, outline.root.lastChild);
	}

}, 1000);*/

for (var i = 0; i < 10000; i++) {
//	outline.root.appendChild(outline.createItem('Lota nodes here: ' + i));
}

outline.root.appendChild(outline.createItem('a'));
outline.root.appendChild(outline.createItem('b'));
outline.root.appendChild(outline.createItem('c'));

outline.root.firstChild.setAttribute('data-tags', 'one, two, three');
outline.root.lastChild.setAttribute('data-mentions', 'jesse');

var outline3 = new Outline();
outline3.root.appendChild(outline3.createItem('one'));
outline3.root.appendChild(outline3.createItem('two'));
outline3.root.appendChild(outline3.createItem('three'));
outline3.root.lastChild.appendChild(outline3.createItem('four'));
outline3.root.appendChild(outline3.createItem('five'));

var container1 = document.getElementById('container1'),
	container2 = document.getElementById('container2'),
	container3 = document.getElementById('container3'),
	editor1 = new OutlineEditor(outline, { hostElement: container1 }),
	editor2 = new OutlineEditor(outline, { hostElement: container2 }),
	editor3 = new OutlineEditor(outline3, { hostElement: container3 });
	//keyMap1 = new KeyMap(editor1.shadowRoot, editor1.outlineEditorElement),
	//keyMap2 = new KeyMap(editor2.shadowRoot, editor2.outlineEditorElement),
	//keyMap3 = new KeyMap(editor3.shadowRoot, editor3.outlineEditorElement);

editor3.setExpanded(outline3.root.lastChild.previousSibling);

//editor1.tag1 = true;
//editor2.tag2 = true;

//keyMap1.addKeybindings(keybindings);
//keyMap2.addKeybindings(keybindings);
//keyMap3.addKeybindings(keybindings);

//document.head.appendChild(editor.styleElement);
//document.body.appendChild(editor1.hostElement);
//document.body.appendChild(editor2.hostElement);

//editor.renderer.disableAnimation();
//debugger;
//editor.itemFilterPath = '//li/p[contains(text(),\'two\')]';
//editor.itemFilterPath = '//li/p[contains(text(),\'Mon\')]';

//editor.renderer.disableAnimation();

//editor.setExpanded([outline.root.firstChild, outline.root.firstChild.firstChild], true)