/**
 * Test Fixture: NJS-001 - Dangerous eval() and Code Execution
 * 
 * Pattern: njs-001-eval-code-execution
 * Severity: CRITICAL
 * 
 * Expected Violations: 8
 * Expected Safe Patterns: 4
 */

// =============================================================================
// VIOLATIONS - These should ALL be flagged by the scanner
// =============================================================================

// VIOLATION 1: Basic eval with variable
function processUserInput(input) {
  eval(input);  // CRITICAL: Direct code execution
}

// VIOLATION 2: eval with string concatenation
function calculateExpression(expr) {
  eval('result = ' + expr);  // CRITICAL: Concatenated code execution
}

// VIOLATION 3: eval in template literal
function runTemplate(code) {
  eval(`console.log(${code})`);  // CRITICAL: Template literal injection
}

// VIOLATION 4: Function constructor (equivalent to eval)
function createFunction(body) {
  return new Function('x', body);  // CRITICAL: Dynamic function creation
}

// VIOLATION 5: Function constructor with user input
function dynamicCalculator(operation) {
  const calc = new Function('a', 'b', 'return a ' + operation + ' b');
  return calc(5, 3);
}

// VIOLATION 6: Indirect eval via window
function windowEval(code) {
  window.eval(code);  // CRITICAL: Indirect eval still dangerous
}

// VIOLATION 7: setTimeout with string (acts like eval)
function delayedExec(code, delay) {
  setTimeout(code, delay);  // When code is string, acts like eval
}

// VIOLATION 8: setInterval with string
function repeatedExec(code, interval) {
  setInterval(code, interval);  // When code is string, acts like eval
}

// =============================================================================
// SAFE PATTERNS - These should NOT be flagged
// =============================================================================

// SAFE 1: JSON.parse is safe alternative
function parseData(jsonString) {
  return JSON.parse(jsonString);  // Safe: Only parses JSON, doesn't execute
}

// SAFE 2: setTimeout with function reference
function safeDelay(callback, delay) {
  setTimeout(callback, delay);  // Safe: Function reference, not string
}

// SAFE 3: setInterval with arrow function
function safeInterval(task, interval) {
  setInterval(() => task(), interval);  // Safe: Arrow function
}

// SAFE 4: Static Function (no user input)
const staticMultiply = new Function('a', 'b', 'return a * b');  // Safe: Hardcoded body

// =============================================================================
// EDGE CASES - May or may not be flagged depending on context
// =============================================================================

// EDGE 1: eval in comment (should NOT be flagged)
// eval(userInput);  // This is just documentation

// EDGE 2: Variable named eval (should NOT be flagged as violation)
const evalResults = { passed: true, score: 95 };

// EDGE 3: Method called eval on custom object (may be flagged - false positive)
const customParser = {
  eval: function(data) {
    return JSON.parse(data);
  }
};

