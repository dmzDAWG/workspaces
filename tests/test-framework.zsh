#!/usr/bin/env zsh

# Test Framework for Workspaces Plugin
# Provides testing utilities, assertions, and mock functionality

# Colors for test output
autoload -U colors && colors

# Test configuration
TEST_TEMP_DIR=""
TEST_RESULTS=()
TEST_CURRENT=""
TESTS_PASSED=0
TESTS_FAILED=0

# Initialize test framework
test_init() {
  TEST_TEMP_DIR=$(mktemp -d)
  TEST_RESULTS=()
  TESTS_PASSED=0
  TESTS_FAILED=0
  echo "${fg[cyan]}🧪 Test Framework Initialized${reset_color}"
  echo "${fg[cyan]}Test directory: $TEST_TEMP_DIR${reset_color}\n"
}

# Clean up test environment
test_cleanup() {
  if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
  echo "\n${fg[cyan]}🧹 Test cleanup complete${reset_color}"
}

# Start a test case
test_case() {
  local test_name="$1"
  TEST_CURRENT="$test_name"
  echo "${fg[blue]}▶ Testing: $test_name${reset_color}"
}

# Assert functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values should be equal}"
  
  if [[ "$expected" == "$actual" ]]; then
    test_pass "$message"
  else
    test_fail "$message (expected: '$expected', got: '$actual')"
  fi
}

assert_not_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values should not be equal}"
  
  if [[ "$expected" != "$actual" ]]; then
    test_pass "$message"
  else
    test_fail "$message (both values: '$expected')"
  fi
}

assert_true() {
  local condition="$1"
  local message="${2:-Condition should be true}"
  
  if [[ "$condition" == "true" ]] || [[ "$condition" == "0" ]]; then
    test_pass "$message"
  else
    test_fail "$message (got: '$condition')"
  fi
}

assert_false() {
  local condition="$1"
  local message="${2:-Condition should be false}"
  
  if [[ "$condition" == "false" ]] || [[ "$condition" != "0" ]]; then
    test_pass "$message"
  else
    test_fail "$message (got: '$condition')"
  fi
}

assert_file_exists() {
  local file_path="$1"
  local message="${2:-File should exist}"
  
  if [[ -f "$file_path" ]]; then
    test_pass "$message: $file_path"
  else
    test_fail "$message: $file_path (file not found)"
  fi
}

assert_file_not_exists() {
  local file_path="$1"
  local message="${2:-File should not exist}"
  
  if [[ ! -f "$file_path" ]]; then
    test_pass "$message: $file_path"
  else
    test_fail "$message: $file_path (file exists)"
  fi
}

assert_dir_exists() {
  local dir_path="$1"
  local message="${2:-Directory should exist}"
  
  if [[ -d "$dir_path" ]]; then
    test_pass "$message: $dir_path"
  else
    test_fail "$message: $dir_path (directory not found)"
  fi
}

assert_dir_not_exists() {
  local dir_path="$1"
  local message="${2:-Directory should not exist}"
  
  if [[ ! -d "$dir_path" ]]; then
    test_pass "$message: $dir_path"
  else
    test_fail "$message: $dir_path (directory exists)"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should contain substring}"
  
  if [[ "$haystack" == *"$needle"* ]]; then
    test_pass "$message"
  else
    test_fail "$message (haystack: '$haystack', needle: '$needle')"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should not contain substring}"
  
  if [[ "$haystack" != *"$needle"* ]]; then
    test_pass "$message"
  else
    test_fail "$message (found '$needle' in '$haystack')"
  fi
}

assert_exit_code() {
  local expected_code="$1"
  local actual_code="$2"
  local message="${3:-Exit code should match}"
  
  if [[ "$expected_code" -eq "$actual_code" ]]; then
    test_pass "$message (exit code: $actual_code)"
  else
    test_fail "$message (expected: $expected_code, got: $actual_code)"
  fi
}

# Test result functions
test_pass() {
  local message="$1"
  echo "  ${fg[green]}✓${reset_color} $message"
  ((TESTS_PASSED++))
  TEST_RESULTS+=("PASS: $TEST_CURRENT - $message")
}

test_fail() {
  local message="$1"
  echo "  ${fg[red]}✗${reset_color} $message"
  ((TESTS_FAILED++))
  TEST_RESULTS+=("FAIL: $TEST_CURRENT - $message")
}

test_skip() {
  local message="$1"
  echo "  ${fg[yellow]}⚠${reset_color} SKIP: $message"
  TEST_RESULTS+=("SKIP: $TEST_CURRENT - $message")
}

# Global counter for unique directories
WORK_DIR_COUNTER=${WORK_DIR_COUNTER:-0}

# Test environment functions
create_test_work_dir() {
  # Create unique directory for each test - use counter and process info
  ((WORK_DIR_COUNTER++))
  # Create a more unique identifier using multiple sources
  local unique_id="${WORK_DIR_COUNTER}_$$_$(date +%s%3N 2>/dev/null || date +%s)_$RANDOM"
  local unique_work_dir="$TEST_TEMP_DIR/Work_$unique_id"
  mkdir -p "$unique_work_dir/projects"
  mkdir -p "$unique_work_dir/worktrees"
  mkdir -p "$unique_work_dir/templates"
  echo "$unique_work_dir"
}

create_mock_project() {
  local project_name="$1"
  local work_dir="$2"
  local project_dir="$work_dir/projects/$project_name"
  
  mkdir -p "$project_dir"
  
  # Initialize git repo
  (
    cd "$project_dir"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit
    echo "# $project_name" > README.md
    git add README.md
    git commit --quiet -m "Initial commit"
    
    # Create master branch if it doesn't exist
    git branch -M master 2>/dev/null || true
  )
  
  echo "$project_dir"
}

create_mock_project_with_pom() {
  local project_name="$1"
  local work_dir="$2"
  local java_version="${3:-11}"
  
  local project_dir=$(create_mock_project "$project_name" "$work_dir")
  
  # Create pom.xml with Java version
  cat > "$project_dir/pom.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  
  <groupId>com.example</groupId>
  <artifactId>$project_name</artifactId>
  <version>1.0.0</version>
  
  <properties>
    <java.version>$java_version</java.version>
    <maven.compiler.source>$java_version</maven.compiler.source>
    <maven.compiler.target>$java_version</maven.compiler.target>
  </properties>
</project>
EOF
  
  # Commit pom.xml
  (
    cd "$project_dir"
    git add pom.xml
    git commit --quiet -m "Add pom.xml"
  )
  
  echo "$project_dir"
}

create_test_template() {
  local template_name="$1"
  local work_dir="$2"
  local content="$3"
  
  local template_path="$work_dir/templates/$template_name"
  echo "$content" > "$template_path"
  echo "$template_path"
}

# Mock command functions
mock_git_command() {
  local command="$1"
  local mock_output="$2"
  local mock_exit_code="${3:-0}"
  
  # Create a temporary mock script
  local mock_script="$TEST_TEMP_DIR/mock_git_$RANDOM"
  cat > "$mock_script" << EOF
#!/bin/bash
echo "$mock_output"
exit $mock_exit_code
EOF
  chmod +x "$mock_script"
  
  # Replace git command temporarily
  alias git="$mock_script"
  echo "$mock_script"
}

restore_git_command() {
  unalias git 2>/dev/null || true
}

# Test execution functions
run_with_test_env() {
  local work_dir="$1"
  shift
  local command="$@"
  
  # Set test environment variables
  local old_work_dir="$WORK_DIR"
  local old_projects_dir="$PROJECTS_DIR"
  local old_worktrees_dir="$WORKTREES_DIR"
  local old_templates_dir="$TEMPLATES_DIR"
  
  export WORK_DIR="$work_dir"
  export PROJECTS_DIR="$work_dir/projects"
  export WORKTREES_DIR="$work_dir/worktrees"
  export TEMPLATES_DIR="$work_dir/templates"
  
  # Execute command
  eval "$command"
  local exit_code=$?
  
  # Restore environment
  export WORK_DIR="$old_work_dir"
  export PROJECTS_DIR="$old_projects_dir"
  export WORKTREES_DIR="$old_worktrees_dir"
  export TEMPLATES_DIR="$old_templates_dir"
  
  return $exit_code
}

# Capture function output
capture_output() {
  local command="$@"
  local output_file="$TEST_TEMP_DIR/capture_$$"
  
  eval "$command" > "$output_file" 2>&1
  local exit_code=$?
  
  cat "$output_file"
  rm -f "$output_file"
  
  return $exit_code
}

# Report test results
test_report() {
  local total=$((TESTS_PASSED + TESTS_FAILED))
  
  echo "\n${fg[cyan]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
  echo "${fg[cyan]}Test Results Summary${reset_color}"
  echo "${fg[cyan]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "${fg[green]}✓ All tests passed!${reset_color}"
  else
    echo "${fg[red]}✗ Some tests failed${reset_color}"
  fi
  
  echo "${fg[green]}Passed: $TESTS_PASSED${reset_color}"
  echo "${fg[red]}Failed: $TESTS_FAILED${reset_color}"
  echo "Total: $total"
  
  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo "\n${fg[red]}Failed tests:${reset_color}"
    for result in "${TEST_RESULTS[@]}"; do
      if [[ "$result" == FAIL:* ]]; then
        echo "  ${fg[red]}✗${reset_color} ${result#FAIL: }"
      fi
    done
  fi
  
  echo "\n${fg[cyan]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
  
  return $TESTS_FAILED
}

# Helper to load workspaces plugin in test environment
load_workspaces_plugin() {
  local plugin_path="$(dirname "${0:A}")/../workspaces.plugin.zsh"
  if [[ -f "$plugin_path" ]]; then
    source "$plugin_path"
  else
    echo "Warning: Could not load workspaces plugin from $plugin_path"
    return 1
  fi
}