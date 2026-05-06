'use strict';

// Conservative path-overlap detection for the spike.
// Two glob patterns "overlap" if there exists at least one path matching both.
// We don't fully decide intersection of arbitrary globs; we use a sound but
// conservative test: convert each pattern to a literal prefix (text up to the
// first wildcard char), then declare overlap iff one prefix is a prefix of the
// other. This may report overlap when there isn't one (false positive = safer)
// but never misses a real overlap.

function literalPrefix(glob) {
  const m = glob.match(/^([^*?[{]*)/);
  return m ? m[1] : '';
}

function patternsOverlap(a, b) {
  const pa = literalPrefix(a);
  const pb = literalPrefix(b);
  return pa.startsWith(pb) || pb.startsWith(pa);
}

function setsOverlap(setA, setB) {
  if (!setA || !setB || !setA.length || !setB.length) return false;
  for (const a of setA) {
    for (const b of setB) {
      if (patternsOverlap(a, b)) return true;
    }
  }
  return false;
}

module.exports = { patternsOverlap, setsOverlap, literalPrefix };
