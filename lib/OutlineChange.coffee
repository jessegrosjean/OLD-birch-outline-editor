# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

OutlineChangeDelta = require './OutlineChangeDelta'

# Essential: An {Outline} change event.
#
# This event is fired after an Outline has changed and {Outline::endUpdates()}
# is called. Individual {OutlineChangeDelta}s are accessed through
# {OutlineChange::deltas}.
#
# See {Outline} Examples for an example of subscribing to {OutlineChange}s.
module.exports =
class OutlineChange

  # Public: {Array} of {OutlineChangeDelta}s.
  deltas: null

  constructor: (mutations) ->
    deltas = []
    for mutation in mutations
      delta = OutlineChangeDelta.createFromDOMMutation(mutation)
      if delta
        deltas.push(delta)
    @deltas = deltas