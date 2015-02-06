function createLIForItem(item, renderContext) {
	renderContext.addViewItemClass();
	renderContext.addViewItemAttribute();

	renderContext.addViewBodyElementInBodyTextRange();
	renderContext.viewBodyElementAtBodyTextIndex();

	//

	// add gutter elements
	// add before item elements
	// add after item elements
	// add add trail elements
}

function createPForItemBody(item, itemBodyRenderContext) {
	// Add attributes to string
}

module.exports = {
	createLIForItem: createLIForItem,
	createPForItemBody: createPForItemBody
};