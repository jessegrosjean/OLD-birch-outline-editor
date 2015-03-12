# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

AttributeRun = require './AttributeRun'
deepEqual = require 'deep-equal'
assert = require 'assert'
Util = require './Util'

# Public: A text container holding both characters and formatting attributes.
#
# AttributedStrings are opaque and immutable. They are only useful for moving
# text and attributes from on {Item}s body text to another items body text.
# See:
#
# - {Item::attributedBodyTextSubstring}
# - {Item::replaceBodyTextInRange}
class AttributedString

  @fromTextOrAttributedString: (textOrAttributedString) ->
    if textOrAttributedString instanceof AttributedString
      textOrAttributedString.copy()
    else
      new AttributedString textOrAttributedString

  constructor: (string) ->
    string ?= ''
    @length = string.length
    @_string = string
    @_clean = false
    @_pendingAddAttributes = []

  attributesAtIndex: (index, effectiveRange, longestEffectiveRange) ->
    if index == -1
      index = @_string.length - location

    @_validateRange(index)
    @_ensureClean()

    runIndex = @_indexOfAttributeRunWithCharacterIndex(index)
    if runIndex == -1
      return null

    attributeRun = this.attributeRuns()[runIndex]
    if effectiveRange
      effectiveRange.location = attributeRun.location
      effectiveRange.length = attributeRun.length
      effectiveRange.end = attributeRun.location + attributeRun.length

    if longestEffectiveRange
      attributes = attributeRun.attributes
      @_longestEffectiveRange runIndex, attributeRun, longestEffectiveRange, (candiateRun) ->
        deepEqual(candiateRun.attributes, attributes)
    attributeRun.attributes

  copy: ->
    @_ensureClean()
    theCopy = new AttributedString @_string
    attributeRuns = @attributeRuns()
    if attributeRuns
      attributeRunsCopy = []
      for each in attributeRuns
        attributeRunsCopy.push each.copy()
      theCopy._attributeRuns = attributeRunsCopy
    theCopy

`

//
// String
//

AttributedString.prototype.string = function(location, length) {
  if (location !== undefined) {
    if (length === -1) {
      length = this._string.length - location;
    }
    this._validateRange(location, length);
    return this._string.substr(location, length);
  }
  return this._string;
};

//
// Changing String
//

AttributedString.prototype.deleteCharactersInRange = function(location, length) {
  this._validateAttributeRuns();

  if (length === -1) {
    length = this._string.length - location;
  }
  this._validateRange(location, length);

  if (length === 0) {
    return;
  }

  var string = this._string,
    deleteStart = location,
    deleteEnd = deleteStart + length,
    attributeRuns = this.attributeRuns(),
    attributeRunsLength = attributeRuns.length,
    startingRunIndex = this._indexOfAttributeRunWithCharacterIndex(deleteStart),
    eachRunIndex = startingRunIndex;

  while (eachRunIndex < attributeRunsLength) {
    var eachRun = attributeRuns[eachRunIndex],
      eachRunStart = eachRun.location,
      eachRunEnd = eachRunStart + eachRun.length;

    if (deleteStart >= eachRunStart) {
      // adjust this runs length
      eachRun.length -= (Math.min(eachRunEnd, deleteEnd) - deleteStart);
    } else if (deleteEnd <= eachRunStart) {
      // adjust trailing run start location
      eachRun.location -= length;
    } else if (deleteEnd < eachRunEnd) {
      // ajust this runs location and length
      eachRun.length -= (deleteEnd - eachRunStart);
      eachRun.location = deleteStart;
    } else {
      // delete this run
      eachRun.length = 0;
    }

    // If run is empty and more runs exist, then delete this run. If more
    // runs don't exist then delete all attributes in remaining empy run.
    // In either case we'll advance to the next run.
    if (eachRun.length === 0) {
      if (attributeRunsLength > 0) {
        attributeRuns.splice(eachRunIndex, 1);
        attributeRunsLength--;
      } else {
        eachRun.attributes = {};
        eachRunIndex++;
      }
    } else {
      eachRunIndex++;
    }
  }

  this._string = string.substring(0, deleteStart) + string.substring(deleteEnd);
  this.length = this._string.length;

  this._clean = false;
  this._validateAttributeRuns();
};

AttributedString.prototype.insertStringAtLocation = function(insertedString, location) {
  this._validateAttributeRuns();

  if (length === -1) {
    length = this._string.length - location;
  }
  this._validateRange(location);

  var insertedAttributedString;

  if (insertedString instanceof AttributedString) {
    insertedAttributedString = insertedString;
    insertedString = insertedAttributedString.string();
  }

  if (insertedString.length === 0) {
    return;
  }

  var string = this._string,
    attributeRuns = this.attributeRuns(),
    attributeRunsLength = attributeRuns.length,
    startingRunIndex;

  if (location > 0) {
    startingRunIndex = this._indexOfAttributeRunWithCharacterIndex(location - 1);
  } else {
    startingRunIndex = this._indexOfAttributeRunWithCharacterIndex(location);
  }

  if (startingRunIndex === -1) {
    startingRunIndex = attributeRunsLength - 1;
  }

  var startRun = attributeRuns[startingRunIndex];
  startRun.length += insertedString.length;

  var eachRunIndex = startingRunIndex + 1,
    eachRun;

  while (eachRunIndex < attributeRunsLength) {
    eachRun = attributeRuns[eachRunIndex];
    eachRun.location += insertedString.length;
    eachRunIndex++;
  }

  this._string = string.substring(0, location) + insertedString + string.substring(location);
  this.length = this._string.length;

  // If inserting an attributed string replace attributed runs covered by
  // the inserted with attribute runs from the original inserted string.
  if (insertedAttributedString) {
    var startReplaceRunsIndex = this._indexOfAttributeRunForCharacterIndex(location),
      endReplaceRunsIndex = this._indexOfAttributeRunForCharacterIndex(location + insertedString.length),
      insertedRuns = insertedAttributedString.attributeRuns(),
      insertedRunsLength = insertedRuns.length,
      eachInserted;

    if (endReplaceRunsIndex === -1) {
      endReplaceRunsIndex = attributeRuns.length;
    }

    attributeRuns.splice(startReplaceRunsIndex, endReplaceRunsIndex - startReplaceRunsIndex);

    var i = 0;
    while (i < insertedRunsLength) {
      eachInserted = insertedRuns[i].copy();
      eachInserted.location += location;
      attributeRuns.splice(startReplaceRunsIndex, 0, eachInserted);
      startReplaceRunsIndex++;
      i++;
    }
  }

  this._clean = false;
  this._validateAttributeRuns();
};

AttributedString.prototype.appendString = function(insertedString) {
  this.insertStringAtLocation(insertedString, this.length);
};

AttributedString.prototype.replaceCharactersInRange = function(insertedString, location, length) {
  this._validateAttributeRuns();

  if (length === -1) {
    length = this._string.length - location;
  }
  this._validateRange(location, length);

  // The reason for this logic is so that inserted string gets attributes at
  // "location" if the inserted string doesn't contain it's own attributes.
  // The problem is if deleteCharactersInRange fully covers the range at
  // that location then those attributes will be removed before the insert
  // phase begins. So need to first copy them out into attributed string here.
  if (!(insertedString instanceof AttributedString)) {
    insertedString = new AttributedString(insertedString);

    var attributeRuns = this.attributeRuns(),
      attributeRunsLength = attributeRuns.length,
      startingRunIndex;

    if (location > 0) {
      startingRunIndex = this._indexOfAttributeRunWithCharacterIndex(location - 1);
    } else {
      startingRunIndex = this._indexOfAttributeRunWithCharacterIndex(location);
    }

    if (startingRunIndex === -1) {
      startingRunIndex = attributeRunsLength - 1;
    }

    var copyOfRunAtLocation = attributeRuns[startingRunIndex].copy();
    insertedString.attributeRuns()[0].attributes = copyOfRunAtLocation.attributes;
  }

  this.deleteCharactersInRange(location, length);
  this.insertStringAtLocation(insertedString, location);
};

//
// Attributes
//

AttributedString.prototype.attributeRuns = function() {
  var runs = this._attributeRuns,
    pendingAddAttributes = this._pendingAddAttributes;

  if (!runs || runs.length === 0) {
    runs = [new AttributeRun(0, this._string.length, {})];
    this._attributeRuns = runs;
  }

  var length = pendingAddAttributes.length;
  if (length) {
    this._pendingAddAttributes = [];
    var eachPending;
    for (var i = 0; i < length; i++) {
      eachPending = pendingAddAttributes[i];
      this._addAttributeInRange(eachPending.attribute, eachPending.value, eachPending.location, eachPending.length);
    }
  }

  return runs;
};

AttributedString.prototype.attributeAtIndex = function(attribute, index, effectiveRange, longestEffectiveRange) {
  if (index === -1) {
    index = this._string.length - location;
  }
  this._validateRange(index);
  this._ensureClean();

  var runIndex = this._indexOfAttributeRunWithCharacterIndex(index);
  if (runIndex === -1) {
    return null;
  }
  var attributeRun = this.attributeRuns()[runIndex];
  if (effectiveRange) {
    effectiveRange.location = attributeRun.location;
    effectiveRange.length = attributeRun.length;
    effectiveRange.end = attributeRun.location + attributeRun.length;
  }

  if (longestEffectiveRange) {
    var comparisonAttribute = attributeRun.attributes[attribute];
    this._longestEffectiveRange(runIndex, attributeRun, longestEffectiveRange, function (candiateRun) {
      return candiateRun.attributes[attribute] === comparisonAttribute;
    });
  }

  return attributeRun.attributes[attribute];
};

AttributedString.prototype._longestEffectiveRange = function(runIndex, attributeRun, longestEffectiveRange, shouldExtendRunToInclude) {
  var attributeRuns = this.attributeRuns(),
    length = attributeRuns.length,
    nextRun,
    nextIndex = runIndex - 1,
    currentRun = attributeRun;
  // scan backwards
  while (nextIndex >= 0) {
    nextRun = attributeRuns[nextIndex];
    if (shouldExtendRunToInclude(nextRun)) {
      currentRun = nextRun;
      nextIndex--;
    } else {
      break;
    }
  }

  longestEffectiveRange.location = currentRun.location;

  nextIndex = runIndex + 1;
  currentRun = attributeRun;
  // scan forwards
  while (nextIndex < length) {
    nextRun = attributeRuns[nextIndex];
    if (shouldExtendRunToInclude(nextRun)) {
      currentRun = nextRun;
      nextIndex++;
    } else {
      break;
    }
  }

  longestEffectiveRange.length = (currentRun.location + currentRun.length) - longestEffectiveRange.location;
  longestEffectiveRange.end = longestEffectiveRange.location + longestEffectiveRange.length;
};

AttributedString.prototype._addAttributeInRange = function(attribute, value, location, length) {
  this._validateAttributeRuns();

  if (length === -1) {
    length = this._string.length - location;
  }
  this._validateRange(location, length);

  if (length === 0) {
    return;
  }

  var attributeRuns = this.attributeRuns(),
    startRunIndex = this._indexOfAttributeRunForCharacterIndex(location),
    endRunIndex = this._indexOfAttributeRunForCharacterIndex(location + length),
    i = startRunIndex;

  if (endRunIndex === -1) {
    endRunIndex = attributeRuns.length;
  }

  while (i < endRunIndex) {
    attributeRuns[i].attributes[attribute] = value;
    i++;
  }

  this._clean = false;
  this._validateAttributeRuns();
};

//
// Changing Attributes
//

AttributedString.prototype.addAttributeInRange = function(attribute, value, location, length) {
  this._validateAttributeRuns();

  if (length === -1) {
    length = this._string.length - location;
  }
  this._validateRange(location, length);

  if (length === 0) {
    return;
  }

  this._pendingAddAttributes.push({
    attribute: attribute,
    value: value,
    location: location,
    length: length
  });

  this._clean = false;
  this._validateAttributeRuns();
};

AttributedString.prototype.addAttributesInRange = function(attributes, location, length) {
  var outerThis = this;
  Object.keys(attributes).forEach(function(key) {
    outerThis.addAttributeInRange(key, attributes[key], location, length);
  });
};

AttributedString.prototype.hasAttributes = function() {
  return this._attributeRuns || (this._pendingAddAttributes && this._pendingAddAttributes.length > 0);
};

AttributedString.prototype.removeAttributeInRange = function(attribute, location, length) {
  if (length === -1) {
    length = this._string.length - location;
  }
  this._validateRange(location, length);

  if (length === 0 || !this.hasAttributes()) {
    return false;
  }
  return this.removeAttributesInRange([attribute], location, length);
};

AttributedString.prototype.removeAttributesInRange = function(attributes, location, length) {
  if (length === -1) {
    length = this._string.length - location;
  }
  this._validateRange(location, length);

  this._validateAttributeRuns();

  if (length === 0 || !this.hasAttributes()) {
    return false;
  }

  var didRemove = false,
    attributeRuns = this.attributeRuns(),
    startRunIndex = location === undefined ? 0 : this._indexOfAttributeRunForCharacterIndex(location),
    endRunIndex = location === undefined ? -1 : this._indexOfAttributeRunForCharacterIndex(location + length),
    attributesLength = attributes.length,
    i = startRunIndex,
    j;

  if (endRunIndex === -1) {
    endRunIndex = attributeRuns.length;
  }

  while (i < endRunIndex) {
    var attributeRunAttributes = attributeRuns[i].attributes;
    for (j = 0; j < attributesLength; j++) {
      var attribute = attributes[j];
      if (attributeRunAttributes[attribute] !== undefined) {
        delete attributeRunAttributes[attribute];
        didRemove = true;
      }
    }
    i++;
  }

  if (didRemove) {
    this._clean = false;
  }

  this._validateAttributeRuns();

  return didRemove;
};

//
// Extract Substring
//

AttributedString.prototype.attributedSubstring = function(location, length) {
  if (location !== undefined) {
    if (length === -1) {
      length = this._string.length - location;
    }
    this._validateRange(location, length);
  } else {
    return this.copy();
  }

  var runs = this.attributeRuns(),
    startRunIndex = this._indexOfAttributeRunWithCharacterIndex(location),
    endRunIndex = this._indexOfAttributeRunWithCharacterIndex(location + length),
    substring = new AttributedString(this.string(location, length));

  if (endRunIndex === -1) {
    endRunIndex = runs.length - 1;
  }

  var selectedRuns = runs.slice(startRunIndex, endRunIndex + 1);

  substring._attributeRuns = selectedRuns.map(function(eachRun) {
    var eachRunCopy = eachRun.copy(),
      eachRunStart = eachRunCopy.location;

    if (eachRunStart < location) {
      eachRunCopy.length -= (location - eachRunStart);
      eachRunCopy.location = 0;
    } else {
      eachRunCopy.location -= location;
    }

    var eachRunEnd = eachRunCopy.location + eachRunCopy.length;
    if (eachRunEnd > length) {
      eachRunCopy.length -= (eachRunEnd - length);
    }

    return eachRunCopy;
  }).filter(function (eachRun) {
    return eachRun.length > 0;
  });

  substring._validateAttributeRuns();

  return substring;
};

//
// Debug
//

AttributedString.prototype.toString = function(showAttributeValues) {
  this._ensureClean();

  var string = this._string,
    attributeRuns = this.attributeRuns(),
    length = attributeRuns.length,
    results = [];

  for (var i = 0; i < length; i++) {
    var eachRun = attributeRuns[i],
      eachRunAttributes = eachRun.attributes;

    var sortedNames = [];
    for (var each in eachRunAttributes) {
      if (eachRunAttributes[each] !== undefined) {
        sortedNames.push(each);
      }
    }

    sortedNames.sort();

    var nameValues = [],
      sortedNamesLength = sortedNames.length;
    for (var j = 0; j < sortedNamesLength; j++) {
      var name = sortedNames[j];
      if (showAttributeValues) {
        nameValues.push(name + '=' + JSON.stringify(eachRunAttributes[name]));
      } else {
        nameValues.push(name);
      }
    }

    results.push(string.substr(eachRun.location, eachRun.length) + '/' + nameValues.join(', '));
  }

  return '(' + results.join(')(') + ')';
};

//
// Private
//

AttributedString.prototype._ensureClean = function() {
  if (this._clean) {
    return;
  }

  var attributeRuns = this.attributeRuns(),
    length = attributeRuns.length,
    previousAttributeRun = attributeRuns[0],
    attributeRun;

  for (var i = 1; i < length; i++) {
    attributeRun = attributeRuns[i];
    if (previousAttributeRun._mergeWithNext(attributeRun)) {
      attributeRuns.splice(i, 1);
      length--;
      i--;
    } else {
      previousAttributeRun = attributeRun;
    }
  }

  this._clean = true;
};

AttributedString.prototype._indexOfAttributeRunWithCharacterIndex = function(characterIndex) {
  assert.ok(characterIndex >= 0 || characterIndex <= this._string.length, 'Invalid character index');

  var attributeRuns = this.attributeRuns(),
    low = 0,
    high = attributeRuns.length - 1,
    i, comparison,
    run, location, length, end,
    result = -1;

  while (low <= high) {
    /*jshint bitwise: false */
    i = (low + high) >> 1;
    /*jshint bitwise: true */
    run = attributeRuns[i];
    location = run.location;
    length = run.length;
    end = location + length;

    if (characterIndex >= location && characterIndex < end) {
      result = i;
      break;
    } else if (end <= characterIndex) {
      low = i + 1;
      continue;
    } else {
      high = i - 1;
      continue;
    }
  }

  return result;
};

AttributedString.prototype._indexOfAttributeRunForCharacterIndex = function(characterIndex) {
  var runIndex = this._indexOfAttributeRunWithCharacterIndex(characterIndex);

  if (runIndex === -1) {
    return -1;
  }

  var attributeRuns = this.attributeRuns(),
    attributeRun = attributeRuns[runIndex],
    location = attributeRun.location,
    length = attributeRun.length;

  if (location === characterIndex) {
    return runIndex;
  }

  var newAttributeRun = attributeRun.splitAtIndex(characterIndex);
  attributeRuns.splice(runIndex + 1, 0, newAttributeRun);
  return runIndex + 1;
};

AttributedString.prototype._validateRange = function(location, length) {
  assert.ok(location >= 0 && location <= this._string.length, 'Invalid location');
  if (length) {
    assert.ok(length >= 0, 'Length must be positive');
    assert.ok(location + length <= this._string.length, 'Length must not be beyond string');
  }
};

AttributedString.prototype._validateAttributeRuns = function() {
  if (/*Environment.debug*/ true) {
    var attributeRuns = this.attributeRuns();

    if (attributeRuns) {
      var length = attributeRuns.length;

      if (length) {
        var offset = 0;
        for (var i = 0; i < length; i++) {
          var eachRun = attributeRuns[i];

          assert.ok(eachRun.location >= 0, 'Location must be postive');
          assert.ok(eachRun.location <= this._string.length, 'Location must be less then or equal to end of string');
          assert.ok(eachRun.location + eachRun.length <= this._string.length, 'Location + length must be less then or equal to end of string');

          if (length > 1) {
            assert.ok(eachRun.length > 0, 'Attribute Run Empty');
          }
          assert.ok(eachRun.location === offset, 'Attribute Run Invalid Location');
          offset += eachRun.length;
        }
        assert.ok(offset === this._string.length, 'Attribute Run Invalid Location');
      } else {
        assert.ok(false, 'Empty Attribute Runs');
      }
    }
  }
};

module.exports = AttributedString;`