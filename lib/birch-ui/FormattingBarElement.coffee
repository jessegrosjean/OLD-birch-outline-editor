# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

EventRegistery = require '../EventRegistery'

class FormattingBarElement extends HTMLElement
  constructor: ->
    super()

  createdCallback: ->
    @classList.add 'btn-toolbar'

    @buttonGroup = document.createElement 'div'
    @buttonGroup.classList.add 'btn-group'
    @appendChild @buttonGroup

    @boldButton = document.createElement 'button'
    @boldButton.textContent = 'B'
    @boldButton.classList.add 'btn'
    @buttonGroup.appendChild @boldButton

    @italicButton = document.createElement 'button'
    @italicButton.textContent = 'I'
    @italicButton.classList.add 'btn'
    @buttonGroup.appendChild @italicButton

    @linkButton = document.createElement 'button'
    @linkButton.textContent = 'Link'
    @linkButton.classList.add 'btn'
    @buttonGroup.appendChild @linkButton

  attachedCallback: ->


  detachedCallback: ->

module.exports = document.registerElement 'birch-formatting-bar', prototype: FormattingBarElement.prototype