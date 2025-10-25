#!/usr/bin/env zsh

# Test Runner for Workspaces Plugin
# Executes all test suites and provides reporting

# Load test framework
source "$(dirname "${0:A}")/test-framework.zsh"

# Test configuration
VERBOSE=${VERBOSE:-false}
QUICK=${QUICK:-false}
TEST_PATTERN=${TEST_PATTERN:-"*"}

# Usage information
show_usage() {
  cat << EOF
Test Runner for Workspaces Plugin

Usage: $0 [options] [test-pattern]

Options:
  -v, --verbose     Show detailed test output
  -q, --quick       Run only fast tests (skip integration tests)
  -h, --help        Show this help message

Test Patterns:
  main             Run main command tests only
  helpers          Run helper function tests only
  git              Run git operation tests only
  edge             Run edge case tests only
  integration      Run integration tests only
  all              Run all tests (default)

Examples:
  $0                    # Run all tests
  $0 -v main           # Run main command tests with verbose output
  $0 -q                # Run only quick tests
  $0 helpers           # Run only helper function tests

EOF
}

# Parse command line arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -q|--quick)
        QUICK=true
        shift
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      -*)
        echo "Unknown option: $1" >&2
        show_usage
        exit 1
        ;;
      *)
        TEST_PATTERN="$1"
        shift
        ;;
    esac
  done
}

# Test suite runner
run_test_suite() {
  local suite_name="$1"
  local suite_file="$2"
  
  if [[ ! -f "$suite_file" ]]; then
    echo "${fg[yellow]}⚠ Test suite not found: $suite_file${reset_color}"
    return 1
  fi
  
  echo "${fg[cyan]}🧪 Running test suite: $suite_name${reset_color}"
  echo "${fg[cyan]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
  
  # Simply execute the test file
  zsh "$suite_file"
  local exit_code=$?
  
  echo ""
  return $exit_code
}

# Main test execution
run_tests() {
  # Get the absolute path to the tests directory
  local script_path="${0:A}"
  local test_dir="$(dirname "$script_path")"
  
  # Ensure we're using the tests directory
  if [[ "$test_dir" != */tests ]]; then
    test_dir="$test_dir/tests"
  fi
  
  local total_exit_code=0
  
  echo "${fg[green]}🚀 Starting Workspaces Plugin Test Suite${reset_color}"
  echo "${fg[cyan]}Pattern: $TEST_PATTERN${reset_color}"
  echo "${fg[cyan]}Verbose: $VERBOSE${reset_color}"
  echo "${fg[cyan]}Quick: $QUICK${reset_color}"
  echo ""
  
  # Initialize test framework
  test_init
  
  # Define test suites
  local -A test_suites
  test_suites[multilevel]="$test_dir/test-multilevel-specs.zsh"
  test_suites[main]="$test_dir/test-main-commands.zsh"
  test_suites[basic]="$test_dir/test-basic-functions.zsh"
  test_suites[helpers]="$test_dir/test-helpers.zsh"
  test_suites[git]="$test_dir/test-git-operations.zsh"
  test_suites[edge]="$test_dir/test-edge-cases.zsh"
  
  if [[ "$QUICK" != "true" ]]; then
    test_suites[integration]="$test_dir/test-integration.zsh"
  fi
  
  # Debug: show what test_dir is and what files exist
  verbose_log "Test directory: $test_dir"
  verbose_log "Available test files:"
  verbose_log "$(ls -la "$test_dir"/test-*.zsh 2>/dev/null || echo 'No test files found')"
  
  # Run test suites based on pattern
  case "$TEST_PATTERN" in
    all|"*")
      # Run all test suites
      for suite_name in "${(@k)test_suites}"; do
        if run_test_suite "$suite_name" "${test_suites[$suite_name]}"; then
          echo "${fg[green]}✓ $suite_name tests completed${reset_color}"
        else
          echo "${fg[red]}✗ $suite_name tests failed${reset_color}"
          total_exit_code=1
        fi
        echo ""
      done
      ;;
    *)
      # Run specific test suite
      if [[ -n "${test_suites[$TEST_PATTERN]}" ]]; then
        if run_test_suite "$TEST_PATTERN" "${test_suites[$TEST_PATTERN]}"; then
          echo "${fg[green]}✓ $TEST_PATTERN tests completed${reset_color}"
        else
          echo "${fg[red]}✗ $TEST_PATTERN tests failed${reset_color}"
          total_exit_code=1
        fi
      else
        echo "${fg[red]}Unknown test pattern: $TEST_PATTERN${reset_color}"
        echo "Available patterns: ${(k)test_suites}"
        total_exit_code=1
      fi
      ;;
  esac
  
  # Generate final report
  test_report
  local report_exit_code=$?
  
  # Cleanup
  test_cleanup
  
  # Return worst exit code
  if [[ $total_exit_code -ne 0 ]]; then
    return $total_exit_code
  else
    return $report_exit_code
  fi
}

# Safety check function
safety_check() {
  # Check if we're in the right directory
  local current_dir=$(pwd)
  local plugin_dir="/Users/dbunin/.oh-my-zsh/custom/plugins/workspaces"
  
  if [[ "$current_dir" != "$plugin_dir"* ]]; then
    echo "${fg[yellow]}⚠ Warning: Not in workspaces plugin directory${reset_color}"
    echo "Current: $current_dir"
    echo "Expected: $plugin_dir"
    echo ""
  fi
  
  # Check for existing Work directory and warn about isolation
  if [[ -d "$HOME/Work" ]]; then
    echo "${fg[green]}✓ Found existing Work directory${reset_color}"
    echo "${fg[cyan]}ℹ Tests will run in isolation and won't affect your real workspace${reset_color}"
    echo ""
  fi
  
  # Check if git is available
  if ! command -v git &> /dev/null; then
    echo "${fg[red]}✗ Git command not found${reset_color}"
    echo "Git is required for testing"
    return 1
  fi
  
  return 0
}

# Verbose output function
verbose_log() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "$@"
  fi
}

# Main execution
main() {
  # Parse arguments
  parse_args "$@"
  
  # Safety checks
  if ! safety_check; then
    exit 1
  fi
  
  # Run tests
  run_tests
  exit $?
}

# Export functions for test suites
export -f verbose_log
export VERBOSE QUICK TEST_PATTERN

# Run main function if script is executed directly
# Simplified execution check for zsh compatibility
if [[ "${0:A}" == *"test-runner.zsh" ]]; then
  main "$@"
fi