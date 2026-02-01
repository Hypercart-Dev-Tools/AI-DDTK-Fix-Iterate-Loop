/**
 * Test Fixture: NJS-002 - Command Injection via child_process
 * 
 * Pattern: njs-002-command-injection
 * Severity: CRITICAL
 * 
 * Expected Violations: 8
 * Expected Safe Patterns: 4
 */

const { exec, execSync, spawn, spawnSync, execFile } = require('child_process');

// =============================================================================
// VIOLATIONS - These should ALL be flagged by the scanner
// =============================================================================

// VIOLATION 1: exec with user input in command
function runUserCommand(userInput) {
  exec(userInput, (error, stdout) => {
    console.log(stdout);
  });
}

// VIOLATION 2: exec with string concatenation
function listDirectory(path) {
  exec('ls -la ' + path, (error, stdout) => {  // CRITICAL: path could be "; rm -rf /"
    console.log(stdout);
  });
}

// VIOLATION 3: exec with template literal
function findFiles(pattern) {
  exec(`find /var -name "${pattern}"`, callback);  // CRITICAL: pattern injection
}

// VIOLATION 4: execSync with user input
function syncCommand(cmd) {
  return execSync(cmd);  // CRITICAL: Synchronous command injection
}

// VIOLATION 5: execSync with concatenation
function gitClone(repoUrl) {
  execSync('git clone ' + repoUrl);  // CRITICAL: URL could contain malicious commands
}

// VIOLATION 6: Shell option enables command chaining
function processFile(filename) {
  spawn('cat', [filename], { shell: true });  // shell:true allows command chaining
}

// VIOLATION 7: exec in callback chain
async function fetchAndProcess(url) {
  const data = await fetch(url);
  exec(`process-data ${data}`);  // CRITICAL: External data in command
}

// VIOLATION 8: execSync in Express route
function handleRequest(req, res) {
  const result = execSync('grep ' + req.query.search + ' /var/log/app.log');
  res.send(result);
}

// =============================================================================
// SAFE PATTERNS - These should NOT be flagged
// =============================================================================

// SAFE 1: execFile with array arguments (no shell interpretation)
function safeListDir(directory) {
  execFile('ls', ['-la', directory], (error, stdout) => {
    console.log(stdout);
  });
}

// SAFE 2: spawn with array arguments (recommended approach)
function safeSpawn(filename) {
  const child = spawn('cat', [filename]);  // Safe: Arguments as array
  child.stdout.on('data', (data) => console.log(data));
}

// SAFE 3: Hardcoded command (no user input)
function getSystemInfo() {
  exec('uname -a', (error, stdout) => {  // Safe: No user input
    console.log(stdout);
  });
}

// SAFE 4: Using parameterized query-like approach
function safeDatabaseBackup(dbName) {
  // Whitelist validation before use
  const allowedDbs = ['users', 'products', 'orders'];
  if (!allowedDbs.includes(dbName)) {
    throw new Error('Invalid database name');
  }
  execFile('pg_dump', [dbName], callback);  // Safe: Validated + execFile
}

// =============================================================================
// EDGE CASES
// =============================================================================

// EDGE 1: exec in comment (should NOT be flagged)
// exec(userInput);  // Documentation example

// EDGE 2: Variable named exec
const execResults = [];
execResults.push('test');

// EDGE 3: Different exec (not child_process)
const customExec = (fn) => fn();  // Custom function, not child_process

