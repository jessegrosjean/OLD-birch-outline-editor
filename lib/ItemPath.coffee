ItemPathParser = require './ItemPathParser'
typechecker = require 'typechecker'

module.exports=
class ItemPath

  @SHOW_ALL_PATH = '///*'
  @DEFAULT_ATTRIBUTE_PATH = ['bodytext']
  @DEFAULT_RELATIOIN = 'contains'
  @DEFAULT_MODIFIER = 'i'

  @parse: (path, startRule, types) ->
    startRule ?= 'ItemPathExpression'
    exception = null
    keywords = []
    parsedPath

    try
      parsedPath = ItemPathParser.parse path,
        startRule: startRule
        types: types
    catch e
      exception = e

    if parsedPath
      keywords = parsedPath.keywords
      keywords.sort(keywordCompare)
      keywords.sortedUniquify(keywordCompare)

    {} =
      parsedPath: parsedPath
      keywords: keywords
      error: exception

  @evaluate: (itemPath, item, types) ->
    if typechecker.isString itemPath
      itemPath = new ItemPath itemPath, types or {}
    itemPath.evaluate item

  constructor: (@pathString, @types) ->
    @pathAST = @constructor.parse(@pathString, undefined, @types).parsedPath

  evaluate: (item) ->
    if @pathAST
      @evaluateItemPath @pathAST, item
    else
      []

  evaluateItemPath: (pathAST, item) ->
    union = pathAST.union
    intersect = pathAST.intersect
    except = pathAST.except
    results

    if union
      results = @evaluateUnion union, item
    else if intersect
      results = @evaluateIntersect intersect, item
    else if except
      results = @evaluateExcept except, item
    else
      results = @evaluatePath pathAST, item

    @sliceResultsFrom pathAST.slice, results, 0

    results

  unionOutlineOrderedResults: (results1, results2, outline) ->
    results = []
    i = 0
    j = 0

    while true
      r1 = results1[i]
      r2 = results2[j]
      unless r1
        if r2
          results.push.apply(results, results2.slice(j))
        return results
      else unless r2
        if r1
          results.push.apply(results, results1.slice(i))
        return results
      else if r1 is r2
        results.push(r2)
        i++
        j++
      else
        if r1.comparePosition(r2) & Node.DOCUMENT_POSITION_FOLLOWING
          results.push(r1)
          i++
        else
          results.push(r2)
          j++

  evaluateUnion: (pathsAST, item) ->
    results1 = @evaluateItemPath pathsAST[0], item
    results2 = @evaluateItemPath pathsAST[1], item
    @unionOutlineOrderedResults results1, results2, item.outline

  evaluateIntersect: (pathsAST, item) ->
    results1 = @evaluateItemPath pathsAST[0], item
    results2 = @evaluateItemPath pathsAST[1], item
    results = []
    i = 0
    j = 0

    while true
      r1 = results1[i]
      r2 = results2[j]

      unless r1
        return results
      else unless r2
        return results
      else if r1 is r2
        results.push(r2)
        i++
        j++
      else
        if r1.comparePosition(r2) & Node.DOCUMENT_POSITION_FOLLOWING
          i++
        else
          j++

  evaluateExcept: (pathsAST, item) ->
    results1 = @evaluateItemPath pathsAST[0], item
    results2 = @evaluateItemPath pathsAST[1], item
    results = []
    i = 0
    j = 0

    while true
      r1 = results1[i]
      r2 = results2[j]

      while r2 and (r1.comparePosition(r2) & Node.DOCUMENT_POSITION_PRECEDING)
        j++
        r2 = results2[j]

      unless r1
        return results
      else unless r2
        results.push.apply(results, results1.slice(i))
        return results
      else if r1 is r2
        r1Index = -1
        r2Index = -1
        i++
        j++
      else
        results.push(r1)
        r1Index = -1
        i++

  evaluatePath: (pathAST, item) ->
    outline = item.outline
    contexts = []
    results

    if pathAST.absolute
      item = item.root

    contexts.push item

    for stepAST in pathAST.steps
      results = []
      for context in contexts
        if results.length
          # If evaluating from multiple contexts and we have some results
          # already merge the new set of context results in with the existing.
          contextResults = []
          @evaluateStep stepAST, context, contextResults
          results = @unionOutlineOrderedResults results, contextResults, outline
        else
          @evaluateStep stepAST, context, results
      contexts = results
    results

  evaluateStep: (stepAST, item, results) ->
    predicate = stepAST.predicate
    from = results.length
    type = stepAST.type

    switch stepAST.axis
      when 'ancestor-or-self'
        each = item
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.parent

      when 'ancestor'
        each = item.parent
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.parent

      when 'child'
        each = item.firstChild
        while each
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextSibling

      when 'descendant-or-self'
        end = item.nextBranch
        each = item
        while each and each != end
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextItem

      when 'descendant'
        end = item.nextBranch
        each = item.firstChild
        while each and each != end
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextItem

      when 'filter-descendants'
        end = item.nextBranch
        each = item.firstChild
        originalFrom = from
        while each and each != end
          if @evaluatePredicate type, predicate, each
            lastMatch = results.lastObject()
            eachAncestor = each.parent
            # splice in ancestors as needed... this can be optimized
            while eachAncestor != item and results.indexOf(eachAncestor) is -1
              results.splice from, 0, eachAncestor
              eachAncestor = eachAncestor.parent
            results.push each
            from = results.length
          each = each.nextItem
        results.splice originalFrom, 0, item

      when 'following-sibling'
        each = item.nextSibling
        while each
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextSibling

      when 'following'
        each = item.nextItem
        while each
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextItem

      when 'parent'
        each = item.parent
        if each and @evaluatePredicate type, predicate, each
          results.push each

      when 'preceding-sibling'
        each = item.previousSibling
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.previousSibling

      when 'preceding'
        each = item.previousItem
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.previousItem

      when 'self'
        if @evaluatePredicate type, predicate, item
          results.push item

    @sliceResultsFrom stepAST.slice, results, from

  evaluatePredicate: (type, predicate, item) ->
    if type != '*' and type != item.getAttribute 'data-type'
      false
    else if predicate is '*'
      true
    else if andP = predicate.and
      @evaluatePredicate('*', andP[0], item) and @evaluatePredicate('*', andP[1], item)
    else if orP = predicate.or
      @evaluatePredicate('*', orP[0], item) or @evaluatePredicate('*', orP[1], item)
    else if notP = predicate.not
      not @evaluatePredicate '*', notP, item
    else
      attributePath = predicate.attributePath
      relation = predicate.relation
      modifier = predicate.modifier
      value = predicate.value

      attributePath ?= ItemPath.DEFAULT_ATTRIBUTE_PATH

      if !relation and !value
        return @valueForAttributePath(attributePath, item) != null

      relation ?= ItemPath.DEFAULT_RELATIOIN
      modifier ?= ItemPath.DEFAULT_MODIFIER

      predicateValueCache = predicate.predicateValueCache
      unless predicateValueCache
        predicateValueCache = @convertValueForModifier value, modifier
        predicate.predicateValueCache = predicateValueCache

      attributeValue = @valueForAttributePath attributePath, item
      if attributeValue != null
        attributeValue = @convertValueForModifier attributeValue.toString(), modifier

      @evaluateRelation attributeValue, relation, predicateValueCache, predicate

  valueForAttributePath: (attributePath, item) ->
    attributeName = attributePath[0]
    switch attributeName
      when 'bodytext'
        item.bodyText
      when 'bodyhtml'
        item.bodyHTML
      else
        item.getAttribute attributeName

  convertValueForModifier: (value, modifier) ->
    if modifier is 'i'
      value.toLowerCase()
    else if modifier is 'n'
      parseFloat(value)
    else if modifier is 'd'
      Date.parse(value) # weak
    else
      value

  evaluateRelation: (left, relation, right, predicate) ->
    switch relation
      when '='
        left is right
      when '!='
        left != right
      when '<'
        if left
          left < right
        else
          false
      when '>'
        if left
          left > right
        else
          false
      when '<='
        if left
          left <= right
        else
          false
      when '>='
        if left
          left >= right
        else
          false
      when 'beginswith'
        if left
          left.startsWith(right)
        else
          false
      when 'contains'
        if left
          left.indexOf(right) != -1
        else
          false
      when 'endswith'
        if left
          left.endsWith(right)
        else
          false
      when 'matches'
        if left
          joinedValueRegexCache = predicate.joinedValueRegexCache
          if joinedValueRegexCache is undefined
            try
              joinedValueRegexCache = new RegExp(right.toString());
            catch error
              joinedValueRegexCache = null
            predicate.joinedValueRegexCache = joinedValueRegexCache

          if joinedValueRegexCache
            left.toString().match joinedValueRegexCache
          else
            false
        else
          false

  sliceResultsFrom: (slice, results, from) ->
    if slice
      length = results.length - from
      start = slice.start
      end = slice.end

      if length is 0
        return

      if end > length
        end = length

      if start != 0 or end != length
        sliced
        if start < 0
          start += length
          if start < 0
            start = 0
        if start > length - 1
          start = length - 1
        if end is null
          sliced = results[from + start]
        else
          if end < 0 then end += length
          if end < start then end = start
          sliced = results.slice(from).slice(start, end)

        Array.prototype.splice.apply(results, [from, results.length - from].concat(sliced));

  ###
  leftmostItemPath: (itemPath) ->
    if itemPath.union
      @leftmostItemPath itemPath.union[0]
    else if itemPath.intersect
      @leftmostItemPath itemPath.intersect[0]
    else if itemPath.except
      @leftmostItemPath itemPath.except[0]
    else
      itemPath

  locationPathString: (minusLastPathStep) ->
    leftMosItemPath = @leftmostItemPath @itemPath
    path = JSON.parse(JSON.stringify(leftMosItemPath))
    locationSteps = []

    for each in steps
      if each.axis is 'filter-descendants'
        break
      locationSteps.push each

    if minusLastPathStep
      locationSteps.pop()

    if locationSteps.length is 0
      return ''
    else
      path.steps = locationSteps;
      @pathToString path

  @setLocationPathString = function setLocationPathString(newLocationPathString) {
    var oldLocationPathString = @locationPathString(),
      newItemPathString = newLocationPathString + @toString().substr(oldLocationPathString.length);
    @itemPath = ItemPath.parse(newItemPathString).parsedPath;
    @itemPathString = newItemPathString;
    return this;
  };

  @filterStepString = function filterStepString() {
    var leftMosItemPath = @leftmostItemPath(@itemPath),
      steps = leftMosItemPath.steps,
      length = steps.length,
      each,
      i;

    for (i = 0; i < length; i++) {
      each = steps[i];
      if (each.axis is 'filter-descendants') {
        return @_stepToString(each).substr(2);
      }
    }

    return '';
  };

  @setFilterStepString = function setFilterStepString(filterStepString) {
    var newItemPathString = @locationPathString();

    if (filterStepString) {
      newItemPathString += '///' + filterStepString;
    }

    @itemPath = ItemPath.parse(newItemPathString).parsedPath;
    @itemPathString = newItemPathString;

    return this;
  };

  //
  // Focus State
  //

  @updateItemPathByFocusingOutOneLevel = function updateItemPathByFocusingOutOneLevel() {
    var filterStepString = @filterStepString();
    if (filterStepString != '*') {
      @setFilterStepString('*');
    } else {
      var locationPathString = @locationPathString(true);
      if (!locationPathString) {
        locationPathString = '';
      }
      @setLocationPathString(locationPathString);
    }

    return this;
  };

  //
  // Convert to String
  //

  @_predicateToString = function _predicateToString(predicate, group) {
    if (predicate is '*') {
      return '*';
    }

    var openGroup = group ? '(' : '',
      closeGroup = group ? ')' : '';

    var and = predicate.and;
    if (and) {
      return openGroup + @_predicateToString(and[0], true) + ' and ' + @_predicateToString(and[1], true) + closeGroup;
    }

    var or = predicate.or;
    if (or) {
      return openGroup + @_predicateToString(or[0], true) + ' or ' + @_predicateToString(or[1], true) + closeGroup;
    }

    var not = predicate.not;
    if (not) {
      return 'not ' + @_predicateToString(not, true);
    }

    var attributePath = predicate.attributePath,
      relation = predicate.relation,
      modifier = predicate.modifier,
      value = predicate.value,
      result = [];

    if (attributePath) {
      result.push('@' + attributePath.join(':'));
    }

    if (relation) {
      result.push(relation);
    }

    if (modifier) {
      result.push('[' + modifier + ']');
    }

    if (value) {
      try {
        ItemPathParser.parse(value,  { startRule : 'Value' });
      } catch (e) {
        value = '"' + value + '"';
      }

      result.push(value);
    }

    return result.join(' ');
  };

  @_stepToString = function _stepToString(step) {
    switch (step.axis) {
    when 'child':
      return @_predicateToString(step.predicate);
    when 'descendant':
      return '/' + @_predicateToString(step.predicate);
    when 'filter-descendants':
      return '//' + @_predicateToString(step.predicate);
    when 'parent':
      return '..' + @_predicateToString(step.predicate);
    default:
      return step.axis + '::' + @_predicateToString(step.predicate);
    }
  };

  @pathToString = function pathToString(path) {
    var stepStrings = [],
      steps = path.steps,
      stepsLength = steps.length,
      step,
      i;

    for (i = 0; i < stepsLength; i++) {
      stepStrings.push(@_stepToString(steps[i]));
    }

    if (path.absolute) {
      return '/' + stepStrings.join('/');
    } else {
      return stepStrings.join('/');
    }
  };

  @_itemPathToString = function _itemPathToString(itemPath, group) {
    var openGroup = group ? '(' : '',
      closeGroup = group ? ')' : '';

    var union = itemPath.union;
    if (union) {
      return openGroup + @_itemPathToString(union[0], true) + ' union ' + @_itemPathToString(union[1], true) + closeGroup;
    }

    var intersect = itemPath.intersect;
    if (intersect) {
      return openGroup + @_itemPathToString(intersect[0], true) + ' intersect ' + @_itemPathToString(intersect[1], true) + closeGroup;
    }

    var except = itemPath.except;
    if (except) {
      return openGroup + @_itemPathToString(except[0], true) + ' except ' + @_itemPathToString(except[1], true) + closeGroup;
    }

    return @pathToString(itemPath);
  };

  @toString = function toString() {
    return @_itemPathToString(@itemPath);
  };
  ###

keywordCompare = (a, b) ->
  aOffset = a.offset
  bOffset = b.offset

  if aOffset != bOffset
    aOffset - bOffset
  else if a.text.length != b.text.length
    a.text.length - b.text.length
  else if a.label != b.label
    if a < b
      -1
    else
      1
  else
    0