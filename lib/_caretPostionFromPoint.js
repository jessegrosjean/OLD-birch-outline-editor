//
// Can't use build in because they don't work in shadow DOM. So need to
// manually calculate caretPostionFromPoint.
//

function sqr(x) { 
	return x * x 
}

function dist2(v, w) { 
	return sqr(v.x - w.x) + sqr(v.y - w.y) 
}

function distToSegmentSquared(p, v, w) {
	var l2 = dist2(v, w);
	if (l2 == 0) return dist2(p, v);		
	var t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2;
	if (t < 0) return dist2(p, v);
	if (t > 1) return dist2(p, w);
	return dist2(p, { x: v.x + t * (w.x - v.x), y: v.y + t * (w.y - v.y) });
}

function distToSegment(p, v, w) { 
	return Math.sqrt(distToSegmentSquared(p, v, w));
}

function pointInRect(x, y, rect) {
	return (
		x >= rect.left &&
		x <= rect.right &&
		y >= rect.top &&
		y <= rect.bottom
	);
}

function pointRectSquareDistance(x, y, rect) {
	if (pointInRect(x, y, rect)) {
		return 0;
	}

	var p = { x: x, y: y };
	var tl = { x: rect.left, y: rect.top };
	var tr = { x: rect.right, y: rect.top };
	var bl = { x: rect.left, y: rect.bottom };
	var br = { x: rect.right, y: rect.bottom };
	var d1 = distToSegmentSquared(p, tl, tr);
	var d2 = distToSegmentSquared(p, tr, br);
	var d3 = distToSegmentSquared(p, br, bl);
	var d4 = distToSegmentSquared(p, bl, tl);

	return Math.min(d1, Math.min(d2, Math.min(d3, d4)));
}

function caretPostionFromPointInTextNodeAtOffsetWithRect(x, y, textNode, offset, rect) {
	if (x > (rect.left + (rect.width / 2.0))) {
		offset++;
	}
	return {
		offsetItem: textNode,
		offset: offset
	}
}

function caretPostionFromPointInTextNode(x, y, textNode) {
	var range = document.createRange();
	var length = textNode.data.length;
	var minDistanceOffset = undefined;
	var minDistanceUpstreamRect = undefined;
	var minDistanceDownstreamRect = undefined;
	var minDistanceIsDownstream = false;
	var minDistance = Number.MAX_VALUE;

	for (var offset = 0; offset < length; offset++) {
		range.setStart(textNode, offset);
		range.setEnd(textNode, offset + 1);

		var clientRects = range.getClientRects();
		var upstreamRect = clientRects[0];
		var downstreamRect = clientRects[1];
		var upstreamRectDist = pointRectSquareDistance(x, y, upstreamRect);
		var downstreamRectDist = downstreamRect ? pointRectSquareDistance(x, y, downstreamRect) : Number.MAX_VALUE;

		if (upstreamRectDist < minDistance) {
			minDistance = upstreamRectDist;
			minDistanceOffset = offset;
			minDistanceUpstreamRect = upstreamRect;
			minDistanceDownstreamRect = downstreamRect;
			minDistanceIsDownstream = false;
		}

		if (downstreamRectDist < minDistance) {
			minDistance = downstreamRectDist;
			minDistanceOffset = offset;
			minDistanceUpstreamRect = upstreamRect;
			minDistanceDownstreamRect = downstreamRect;
			minDistanceIsDownstream = true;
		}
	}

	if (minDistanceOffset !== undefined) {
		var rect = minDistanceIsDownstream ? minDistanceDownstreamRect : minDistanceUpstreamRect;
		if (x > (rect.left + (rect.width / 2.0))) {
			minDistanceOffset++;
		}
		return {
			offsetItem: textNode,
			offset: minDistanceOffset
		}
	}
}

function caretPostionFromPoint(x, y) {
	var element = document.elementFromPoint(x, y);
	var eachChild = element.firstChild;
	var range = document.createRange();
	var minDistanceNode = null;
	var minDistance = Number.MAX_VALUE;

	while (eachChild) {
		if (eachChild.nodeType === Node.TEXT_NODE) {
			range.setStart(eachChild, 0);
			range.setEnd(eachChild, eachChild.data.length);
			
			var clientRects = range.getClientRects();
			for (var i = 0; i < clientRects.length; i++) {
				var eachRect = clientRects[i];
				var eachDistance = pointRectSquareDistance(x, y, eachRect);

				if (eachDistance === 0) {
					return caretPostionFromPointInTextNode(x, y, eachChild);
				} else if (eachDistance < minDistance) {
					minDistance = eachDistance;
					minDistanceNode = eachChild;
				}
			}
		}
		eachChild = eachChild.nextSibling;
	}

	if (minDistanceNode) {
		return caretPostionFromPointInTextNode(x, y, minDistanceNode);
	} else {
		return {
			offsetItem: element,
			offset: 0
		}        
	}
}

module.exports = caretPostionFromPoint;