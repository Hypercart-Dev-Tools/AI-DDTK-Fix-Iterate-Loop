/**
 * JavaScript Security Anti-patterns Test Fixture
 * 
 * This file contains intentional security violations for testing WP Code Check detection.
 * DO NOT use these patterns in production code!
 * 
 * @package WP_Code_Check
 * @subpackage Tests/Fixtures/JS
 * @since 1.0.81
 */

// =============================================================================
// EVAL AND CODE EXECUTION VIOLATIONS
// =============================================================================

// VIOLATION 1: eval() with user input - Code injection risk
function executeUserCode(userInput) {
  eval(userInput);  // CRITICAL: Never eval user input
}

// VIOLATION 2: eval() with string concatenation
function dynamicEval(operation, value) {
  eval('result = ' + operation + '(' + value + ')');
}

// VIOLATION 3: Function constructor (equivalent to eval)
function createFunction(body) {
  return new Function(body);  // Same risk as eval
}

// VIOLATION 4: Function constructor with arguments
function createDynamicFunction(args, body) {
  return new Function(args, body);
}

// VIOLATION 5: setTimeout/setInterval with string (implicit eval)
function delayedExecution(code) {
  setTimeout(code, 1000);  // When string, acts like eval
}

function repeatedExecution(code) {
  setInterval(code, 5000);  // When string, acts like eval
}

// =============================================================================
// CHILD_PROCESS / COMMAND INJECTION VIOLATIONS
// =============================================================================

// VIOLATION 6: child_process.exec with user input - Command injection
const { exec } = require('child_process');

function runCommand(userCommand) {
  exec(userCommand, (error, stdout) => {  // CRITICAL: Command injection
    console.log(stdout);
  });
}

// VIOLATION 7: exec with string concatenation
function searchFiles(pattern) {
  exec('grep -r "' + pattern + '" /var/www', callback);
}

// VIOLATION 8: execSync with user input
const { execSync } = require('child_process');

function runSyncCommand(cmd) {
  return execSync(cmd);
}

// VIOLATION 9: spawn with shell: true and user input
const { spawn } = require('child_process');

function spawnShellCommand(userCmd) {
  spawn(userCmd, { shell: true });  // shell: true is dangerous with user input
}

// =============================================================================
// FILE SYSTEM VIOLATIONS
// =============================================================================

// VIOLATION 10: Path traversal - fs.readFile with user input
const fs = require('fs');

function readUserFile(filename) {
  fs.readFile('/uploads/' + filename, callback);  // Path traversal: ../../../etc/passwd
}

// VIOLATION 11: fs.readFileSync with user input
function readFileSync(userPath) {
  return fs.readFileSync(userPath);  // Path traversal risk
}

// VIOLATION 12: fs.writeFile with user-controlled path
function writeToPath(userPath, content) {
  fs.writeFile(userPath, content, callback);  // Can overwrite system files
}

// VIOLATION 13: fs.unlink (delete) with user input
function deleteFile(filename) {
  fs.unlink('/uploads/' + filename, callback);  // Path traversal for deletion
}

// =============================================================================
// SAFE PATTERNS (Should NOT trigger)
// =============================================================================

// SAFE 1: JSON.parse instead of eval
function parseJSON(jsonString) {
  return JSON.parse(jsonString);  // Safe alternative to eval for JSON
}

// SAFE 2: setTimeout with function reference
function safeTimeout(callback) {
  setTimeout(callback, 1000);  // Function reference, not string
}

// SAFE 3: setTimeout with arrow function
function safeTimeoutArrow() {
  setTimeout(() => {
    console.log('Safe');
  }, 1000);
}

// SAFE 4: execFile with arguments array (no shell injection)
const { execFile } = require('child_process');

function safeExecFile(filename) {
  // execFile with argument array is safer than exec with string
  execFile('grep', ['-r', 'pattern', filename], callback);
}

// SAFE 5: Path validation before fs operations
const path = require('path');

function safeReadFile(userFilename) {
  const safePath = path.join('/uploads', path.basename(userFilename));
  // path.basename strips directory traversal attempts
  fs.readFile(safePath, callback);
}

// SAFE 6: spawn without shell: true
function safeSpawn(args) {
  spawn('ls', args);  // No shell: true, safer
}

