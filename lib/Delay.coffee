module.exports =
class Delay
  constructor: ->
    @id = null

  set: (ms, f) ->
    @clear()
    @id = setTimeout(f, ms)

  clear: ->
    clearTimeout(this.id)