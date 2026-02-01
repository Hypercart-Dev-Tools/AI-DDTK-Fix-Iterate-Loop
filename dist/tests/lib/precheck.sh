#!/usr/bin/env bash
#
# WP Code Check - Pre-flight Checks Library
# Version: 2.0.0
#
# Validates dependencies, environment, and fixtures before running tests.
# Designed for cross-platform compatibility (macOS, Ubuntu).
#

# ============================================================
# Dependency Validation
# ============================================================

# Check if a command exists
# Usage: _command_exists "command_name"
_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check all required dependencies
# Returns: 0 if all dependencies present, 1 if any missing
precheck_dependencies() {
  local missing=()
  
  # Required dependencies (no version checking for simplicity)
  local required_deps=("jq" "perl" "bash")
  
  for dep in "${required_deps[@]}"; do
    if ! _command_exists "$dep"; then
      missing+=("$dep")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    log ERROR "Missing required dependencies: ${missing[*]}"
    log INFO "Install on Ubuntu:  sudo apt-get install -y ${missing[*]}"
    log INFO "Install on macOS:   brew install ${missing[*]}"
    return 1
  fi
  
  # Log versions for debugging
  log DEBUG "Dependency versions:"
  log DEBUG "  jq:   $(jq --version 2>&1)"
  log DEBUG "  perl: $(perl -v 2>&1 | grep 'This is perl' | head -1)"
  log DEBUG "  bash: $BASH_VERSION"
  
  return 0
}

# ============================================================
# Environment Validation
# ============================================================

# Detect and normalize environment
# Sets: CI, TERM, NO_COLOR environment variables
precheck_environment() {
  # Detect CI environment
  export CI="${CI:-false}"
  export TERM="${TERM:-dumb}"
  
  # Disable colors in CI or dumb terminal
  if [ "$CI" = "true" ] || [ "$TERM" = "dumb" ]; then
    export NO_COLOR=1
  fi
  
  # Warn about TTY absence (informational, not fatal)
  if [ ! -e /dev/tty ]; then
    log DEBUG "No /dev/tty available (CI environment detected)"
  fi
  
  # Log environment info
  log DEBUG "Environment:"
  log DEBUG "  OS:   $(uname -s) $(uname -r)"
  log DEBUG "  CI:   $CI"
  log DEBUG "  TERM: $TERM"
  log DEBUG "  PWD:  $(pwd)"
  
  return 0
}

# Validate working directory
# Usage: precheck_working_directory
precheck_working_directory() {
  # Check if we're in the dist directory
  if [ ! -f "./bin/check-performance.sh" ]; then
    log ERROR "Must run from dist/ directory"
    log ERROR "Current directory: $(pwd)"
    log ERROR "Expected to find: ./bin/check-performance.sh"
    return 1
  fi
  
  log DEBUG "Working directory validated: $(pwd)"
  return 0
}

# ============================================================
# Fixture Validation
# ============================================================

# Validate fixtures directory and expectations file
# Usage: precheck_fixtures "fixtures_dir" "expectations_file"
precheck_fixtures() {
  local fixtures_dir="$1"
  local expectations_file="$2"
  local missing=()
  
  # Validate fixtures directory exists
  if [ ! -d "$fixtures_dir" ]; then
    log ERROR "Fixtures directory not found: $fixtures_dir"
    return 1
  fi
  
  # Validate expectations file exists
  if [ ! -f "$expectations_file" ]; then
    log ERROR "Expectations file not found: $expectations_file"
    log INFO "Create it with: tests/expected/fixture-expectations.json"
    return 1
  fi
  
  # Validate expectations file is valid JSON
  if ! jq empty "$expectations_file" 2>/dev/null; then
    log ERROR "Expectations file is not valid JSON: $expectations_file"
    return 1
  fi
  
  # Validate each fixture referenced in expectations exists
  while IFS= read -r fixture; do
    # Skip meta key
    [ "$fixture" = "_meta" ] && continue
    
    if [ ! -f "$fixtures_dir/$fixture" ]; then
      missing+=("$fixture")
    fi
  done < <(jq -r 'keys[]' "$expectations_file")
  
  if [ ${#missing[@]} -gt 0 ]; then
    log ERROR "Missing fixture files referenced in expectations:"
    for fixture in "${missing[@]}"; do
      log ERROR "  - $fixture"
    done
    return 1
  fi
  
  # Count fixtures
  local fixture_count
  fixture_count=$(jq 'keys | length' "$expectations_file")
  fixture_count=$((fixture_count - 1))  # Subtract _meta key
  
  log DEBUG "Fixtures validated: $fixture_count files"
  
  return 0
}

