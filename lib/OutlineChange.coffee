OutlineChangeDelta = require './OutlineChangeDelta'

module.exports =
class OutlineChange
  constructor: (mutations) ->
  	deltas = []
  	for mutation in mutations
  		delta = OutlineChangeDelta.createFromDOMMutation(mutation)
  		if delta
  			deltas.push(delta)
  	@deltas = deltas