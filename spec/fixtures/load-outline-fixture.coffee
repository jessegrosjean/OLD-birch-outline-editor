Constants = require '../../lib/core/constants'
Outline = require '../../lib/core/outline'
path = require 'path'
fs = require 'fs'
Q = require 'q'

# one
#   two
#     three
#     four
#   five
#     six

outlinePath = path.join(__dirname, 'outline.bml')

outlineValues = (outline, outlineEditor) ->
  {} =
    editor: outlineEditor
    outline: outline
    root: outline.root
    one: outline.getItemForID('1')
    two: outline.getItemForID('2')
    three: outline.getItemForID('3')
    four: outline.getItemForID('4')
    five: outline.getItemForID('5')
    six: outline.getItemForID('6')

openOutlineSync = ->
  unless @outlineRootTemplate
    parser = new DOMParser()
    outlineBML = fs.readFileSync(outlinePath, 'utf8')
    outlineHTMLTemplate = parser.parseFromString(outlineBML, 'text/html')
    @outlineRootTemplate = outlineHTMLTemplate.getElementById Constants.RootID

  outlineHTML = document.implementation.createHTMLDocument()
  outlineRoot = outlineHTML.importNode @outlineRootTemplate, true
  outlineHTML.documentElement.lastChild.appendChild(outlineRoot)
  outline = new Outline({outlineStore: outlineHTML})
  outlineValues outline

openOutlineEditorPromise = ->
  workspaceElement = atom.views.getView(atom.workspace)
  atom.packages.activatePackage('birch-outline-editor').then ->
    atom.workspace.open(outlinePath).then (outlineEditor) ->
      outlineValues outlineEditor.outline, outlineEditor

module.exports =
  openOutlineSync: openOutlineSync
  openOutlineEditorPromise: openOutlineEditorPromise