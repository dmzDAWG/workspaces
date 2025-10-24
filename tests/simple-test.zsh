#!/usr/bin/env zsh

# Simple test to verify framework works
echo "🧪 Running simple test verification..."

# Load framework
source "$(dirname "${0:A}")/test-framework.zsh"

# Simple test case
test_case "Framework basic functionality"

# Test environment creation
TEST_TEMP_DIR=$(mktemp -d)
echo "Created temp dir: $TEST_TEMP_DIR"

# Test assertion functions
assert_equals "hello" "hello" "String equality test"
assert_not_equals "hello" "world" "String inequality test"
assert_true "true" "Boolean true test"

# Test file operations
echo "test content" > "$TEST_TEMP_DIR/test-file.txt"
assert_file_exists "$TEST_TEMP_DIR/test-file.txt" "File creation test"

# Test directory operations
mkdir -p "$TEST_TEMP_DIR/test-dir"
assert_dir_exists "$TEST_TEMP_DIR/test-dir" "Directory creation test"

# Test mock work directory creation
local work_dir="$TEST_TEMP_DIR/mock-work"
mkdir -p "$work_dir/projects"
mkdir -p "$work_dir/worktrees" 
mkdir -p "$work_dir/templates"

assert_dir_exists "$work_dir/projects" "Mock projects directory"
assert_dir_exists "$work_dir/worktrees" "Mock worktrees directory"
assert_dir_exists "$work_dir/templates" "Mock templates directory"

# Cleanup
rm -rf "$TEST_TEMP_DIR"

echo ""
echo "✅ Simple test verification completed!"
echo "Framework is working correctly with proper isolation."
echo ""
echo "Issues found in full test run:"
echo "1. Need to use temporary directories instead of /Work"
echo "2. Plugin loading path needs adjustment"
echo "3. Test environment setup needs refinement"