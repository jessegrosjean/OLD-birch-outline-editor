# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

LiveQuery = require './LiveQuery'
{CompositeDisposable} = require 'atom'

# Public: A live query over an {Outline}.
module.exports =
class OutlineLiveQuery extends LiveQuery

  # Public: Read-only the {Outline} being queried.
  outline: null
  querySubscriptions: null
  outlineDestroyedSubscription: null

  constructor: (@outline, xpathExpression) ->
    super xpathExpression

    @outlineDestroyedSubscription = @outline.onDidDestroy =>
      @stopQuery()
      @outlineDestroyedSubscription.dispose()
      @emitter.emit 'did-destroy'

  ###
  Section: Running Queries
  ###

  startQuery: ->
    return if @started

    @started = true
    @querySubscriptions = new CompositeDisposable
    @querySubscriptions.add @outline.onDidChange (e) =>
      @scheduleRun()
    @querySubscriptions.add @outline.onDidChangePath (path) =>
      @scheduleRun()

  stopQuery: ->
    return unless @started

    @started = false
    @querySubscriptions.dispose()
    @querySubscriptions = null

  run: ->
    return unless @started

    @results = @outline.itemsForXPath(
      @xpathExpression,
      @namespaceResolver
    )
    @emitter.emit 'did-change', @results