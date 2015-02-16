# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

deepEqual = require 'deep-equal'

module.exports =
class AttributeRun
  constructor: (@location, @length, @attributes) ->

  copy: ->
    new AttributeRun(@location, @length, @copyAttributes())

  copyAttributes: ->
    JSON.parse(JSON.stringify(@attributes))

  splitAtIndex: (index) ->
    location = @location
    length = @length
    end = location + length
    @length = index - location
    newLength = (location + length) - index
    newAttributes = if index == end then {} else @copyAttributes()
    new AttributeRun(index, newLength, newAttributes)

  toString: ->
    attributes = @attributes
    sortedNames = for name of attributes then name
    sortedNames.sort()
    nameValues = ('#{name}=#{attributes[name]}' for name in sortedNames)
    '#{@location},#{@length}/#{nameValues.join("/")}'

  _mergeWithNext: (attributeRun) ->
    end = @location + @length
    endsAtStart = end == attributeRun.location
    attributesEqual = deepEqual(@attributes, attributeRun.attributes)
    if endsAtStart and attributesEqual
      @length += attributeRun.length;
      true
    else
      false