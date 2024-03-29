loadOutlineFixture = require '../load-outline-fixture'
OutlineEditor = require '../../lib/editor/outline-editor'
Outline = require '../../lib/core/outline'

describe 'OutlineEditorElement', ->
  [jasmineContent, editorElement, editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    jasmineContent = document.body.querySelector('#jasmine-content')
    editor = new OutlineEditor(outline)
    editorElement = editor.outlineEditorElement
    jasmineContent.appendChild editorElement
    editor.outlineEditorElement.disableAnimation() # otherwise breaks geometry tests sometimes
    editor.setExpanded [one, two, five]

  afterEach ->
    editor.destroy()

  describe 'Render', ->
    describe 'Model', ->
      it 'should render outline', ->
        editorElement.textContent.should.equal('onetwothreefourfivesix')

      it 'should update when text changes', ->
        three.bodyText = 'NEW'
        editorElement.textContent.should.equal('onetwoNEWfourfivesix')

      it 'should update when child is added', ->
        two.appendChild(outline.createItem('Howdy!'))
        editorElement.textContent.should.equal('onetwothreefourHowdy!fivesix')

      it 'should update when child is removed', ->
        editorElement.disableAnimation()
        two.removeFromParent()
        editorElement.enableAnimation()
        editorElement.textContent.should.equal('onefivesix')

      it 'should update when attribute is changed', ->
        viewLI = document.getElementById(three.id)
        expect(viewLI.getAttribute('my')).toBe(null)
        three.setAttribute('my', 'test')
        viewLI.getAttribute('my').should.equal('test')

      it 'should update when body text is changed', ->
        viewLI = document.getElementById(one.id)
        one.bodyText = 'one two three'
        one.addElementInBodyTextRange('B', null, 4, 3)
        editorElement._itemViewBodyP(viewLI).innerHTML.should.equal('one <b>two</b> three')

      it 'should not crash when offscreen item is changed', ->
        editor.setCollapsed(one)
        four.bodyText = 'one two three'

      it 'should not crash when child is added to offscreen item', ->
        editor.setCollapsed(one)
        four.appendChild(outline.createItem('Boo!'))

      it 'should update correctly when child is inserted into filtered view', ->
        editor.hoistItem(one)
        editor.setSearch('five')

        item = editor.insertItem('Boo!')
        item.nextSibling.should.equal(five)
        renderedItemLI = editorElement.renderedLIForItem(item)
        renderedItemLI.nextSibling.should.equal(editorElement.renderedLIForItem(item.nextSibling))

      it 'should update correctly when child is inserted before filtered sibling', ->
        editor.hoistItem(one)
        editor.setSearch('five')

        item = editor.outline.createItem('Boo!')
        one.insertChildBefore(item, one.firstChild)
        renderedItemLI = editorElement.renderedLIForItem(item)
        nextRenderedItemLI = editorElement.renderedLIForItem(editor.getNextVisibleSibling(item))
        renderedItemLI.nextSibling.should.equal(nextRenderedItemLI)

    describe 'Editor State', ->
      it 'should render selection state', ->
        li = editorElement.renderedLIForItem(one)
        editor.moveSelectionRange(one)
        li.classList.contains('ft-itemselected').should.be.true
        editor.moveSelectionRange(two)
        li.classList.contains('ft-itemselected').should.be.false

      it 'should render expanded state', ->
        li = editorElement.renderedLIForItem(one)
        li.classList.contains('ft-expanded').should.be.true
        editor.setCollapsed(one)
        li.classList.contains('ft-expanded').should.be.false

  describe 'Picking', ->
    it 'should above/before', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.left, rect.top).itemCaretPosition
      itemCaretPosition.offsetItem.should.eql(one)
      itemCaretPosition.offset.should.eql(0)

    it 'should above/after', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.right, rect.top).itemCaretPosition
      itemCaretPosition.offsetItem.should.eql(one)
      itemCaretPosition.offset.should.eql(0)

    it 'should below/before', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.left, rect.bottom).itemCaretPosition
      itemCaretPosition.offsetItem.should.eql(six)
      itemCaretPosition.offset.should.eql(3)

    it 'should below/after', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.right, rect.bottom).itemCaretPosition
      itemCaretPosition.offsetItem.should.eql(six)
      itemCaretPosition.offset.should.eql(3)

    it 'should pick with no items without stackoverflow', ->
      one.removeFromParent()
      pick = editorElement.pick(0, 0)

    it 'should pick at line wrap boundaries', ->
      LI = editorElement.renderedLIForItem(one)
      P = editorElement._itemViewBodyP(LI)
      bounds = P.getBoundingClientRect()
      appendText = ' makethislinewrap'
      newBounds = bounds

      # First grow text in one so that it wraps to next line. So tests
      # will pass no matter what browser window width/font/etc is.
      while bounds.height is newBounds.height
        one.appendBodyText(appendText)
        P = editorElement._itemViewBodyP(LI)
        newBounds = P.getBoundingClientRect()

      pickRightTop = editorElement.pick(newBounds.right - 1, newBounds.top + 1).itemCaretPosition
      pickLeftBottom = editorElement.pick(newBounds.left + 1, newBounds.bottom - 1).itemCaretPosition

      pickRightTop.selectionAffinity.should.equal('SelectionAffinityUpstream')
      pickLeftBottom.selectionAffinity.should.equal('SelectionAffinityDownstream')

      # Setup problematic special case... when first text to wrap also
      # starts an attribute run.
      length = appendText.length - 1
      start = one.bodyText.length - length
      one.addElementInBodyTextRange('I', null, start, length)
      P = editorElement._itemViewBodyP(LI)

      newBounds = P.getBoundingClientRect()
      pickRightTop = editorElement.pick(newBounds.right - 1, newBounds.top + 1).itemCaretPosition
      pickLeftBottom = editorElement.pick(newBounds.left + 1, newBounds.bottom - 1).itemCaretPosition

      pickRightTop.selectionAffinity.should.equal('SelectionAffinityUpstream')
      pickLeftBottom.selectionAffinity.should.equal('SelectionAffinityDownstream')

  describe 'Offset Encoding', ->
    it 'should translate from outline to DOM offsets', ->
      viewLI = document.getElementById(one.id)
      p = editorElement._itemViewBodyP(viewLI)

      editorElement.itemOffsetToNodeOffset(one, 0).should.eql
        node: p
        offset: 0

      editorElement.itemOffsetToNodeOffset(one, 2).should.eql
        node: p.firstChild
        offset: 2

      one.bodyHTML = 'one <b>two</b> three'

      p = editorElement._itemViewBodyP(viewLI)
      editorElement.itemOffsetToNodeOffset(one, 4).should.eql
        node: p.firstChild
        offset: 4

      editorElement.itemOffsetToNodeOffset(one, 5).offset.should.equal(1)
      editorElement.itemOffsetToNodeOffset(one, 7).offset.should.equal(3)
      editorElement.itemOffsetToNodeOffset(one, 8).offset.should.equal(1)

    it 'should translate from DOM to outline', ->
      viewLI = document.getElementById(one.id)
      p = editorElement._itemViewBodyP(viewLI)

      editorElement.nodeOffsetToItemOffset(p, 0).should.equal(0)
      editorElement.nodeOffsetToItemOffset(p.firstChild, 0).should.equal(0)

      one.bodyHTML = 'one <b>two</b> three'
      p = editorElement._itemViewBodyP(viewLI)

      editorElement.nodeOffsetToItemOffset(p, 0).should.equal(0)
      editorElement.nodeOffsetToItemOffset(p, 1).should.equal(4)
      editorElement.nodeOffsetToItemOffset(p, 2).should.equal(7)

      b = p.firstChild.nextSibling
      editorElement.nodeOffsetToItemOffset(b, 0).should.equal(4)
      editorElement.nodeOffsetToItemOffset(b.firstChild, 2).should.equal(6)

      editorElement.nodeOffsetToItemOffset(p.lastChild, 0).should.equal(7)
      editorElement.nodeOffsetToItemOffset(p.lastChild, 3).should.equal(10)
