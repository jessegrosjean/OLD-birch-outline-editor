###
When running in webrowser require 'atom' resolves to this package. Return the
(or shim versions of) the atom packages that birch uses and also set the
global 'atom' instance and does things that atom would normally do such as
load styles and keybindings
###

{Emitter, Disposable, CompositeDisposable} = require './event-kit/lib/event-kit'
CommandRegistry = require './command-registry'
KeymapManager = require './atom-keymap/lib/keymap-manager'
cssTextFunction = require '../../styles/birch-outline-editor.less'
coreKeymap = require './core-keymap.cson'
birchKeymap = require '../../keymaps/birch-outline-editor.cson'
commands = new CommandRegistry
keymaps = new KeymapManager

styleElement = document.createElement 'style'
styleElement.type = 'text/css'
styleElement.textContent = cssTextFunction.toString()
document.head.appendChild(styleElement)

keymaps.add('core', coreKeymap)
keymaps.add('birch', birchKeymap)

document.addEventListener('keydown', (e) ->
  keymaps.handleKeyboardEvent(e)
  e.stopImmediatePropagation()
, true)

window.atom =
  commands: commands
  keymaps: keymaps
  workspace:
    getPaneItems: -> []
    onDidAddPaneItem: (callback) ->
      new Disposable()

  deserializers:
    add: ->
  inBrowserMode: -> true
  config:
    get: ->
    set: ->
    observe: -> new Disposable

module.exports =
  Emitter: Emitter
  Disposable: Disposable
  CompositeDisposable: CompositeDisposable