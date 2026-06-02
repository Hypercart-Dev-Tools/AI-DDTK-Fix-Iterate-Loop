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

// Glob-to-regex for matching a literal file path against a glob pattern.
// Handles **, *, ?. No brace/char-class support — keep it small for the spike.
function globToRegex(glob) {
  let re = '';
  for (let i = 0; i < glob.length; i++) {
    const ch = glob[i];
    if (ch === '*') {
      if (glob[i + 1] === '*') {
        re += '.*';
        i++;
        // consume optional trailing slash so foo/** matches foo (no trailing /)
        if (glob[i + 1] === '/') i++;
      } else {
        re += '[^/]*';
      }
    } else if (ch === '?') {
      re += '[^/]';
    } else if ('.+^$()[]{}|\\'.includes(ch)) {
      re += '\\' + ch;
    } else {
      re += ch;
    }
  }
  return new RegExp('^' + re + '$');
}

function matchesAny(file, globs) {
  if (!globs || !globs.length) return false;
  return globs.some(g => globToRegex(g).test(file));
}

module.exports = { patternsOverlap, setsOverlap, literalPrefix, globToRegex, matchesAny };
