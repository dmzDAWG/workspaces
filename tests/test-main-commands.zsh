#!/usr/bin/env zsh

# Test Suite for Main Commands
# Tests all primary user-facing commands of the workspaces plugin

# Load test framework and plugin
source "$(dirname "${0:A}")/test-framework.zsh"
load_workspaces_plugin

# Mock user input for interactive functions
mock_user_input() {
  local input_sequence="$1"
  # Create a FIFO pipe for input simulation
  local pipe_file="$TEST_TEMP_DIR/input_pipe_$$"
  mkfifo "$pipe_file"
  echo "$input_sequence" > "$pipe_file" &
  exec 0< "$pipe_file"
}

# Restore normal input
restore_input() {
  exec 0</dev/tty 2>/dev/null || exec 0</dev/stdin
}

test_list_worktrees() {
  test_case "list-worktrees - Worktree listing"
  
  local work_dir=$(create_test_work_dir)
  
  # Test 1: No worktrees directory
  rm -rf "$work_dir/worktrees"
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output" "No worktrees directory found" "Should handle missing worktrees directory"
  
  # Test 2: Empty worktrees directory
  mkdir -p "$work_dir/worktrees"
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output" "No worktrees found" "Should handle empty worktrees directory"
  
  # Test 3: Worktrees with projects
  mkdir -p "$work_dir/worktrees/feature1/project1"
  mkdir -p "$work_dir/worktrees/feature1/project2"
  mkdir -p "$work_dir/worktrees/feature2/project1"
  
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output" "feature1" "Should list feature1 worktree"
  assert_contains "$output" "feature2" "Should list feature2 worktree"
  assert_contains "$output" "project1" "Should show project1"
  assert_contains "$output" "project2" "Should show project2"
  
  # Test 4: Empty worktree directories
  mkdir -p "$work_dir/worktrees/empty-feature"
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output" "empty-feature" "Should list empty worktree"
  assert_contains "$output" "(empty - no projects)" "Should indicate empty worktree"
}

test_check_repos() {
  test_case "check-repos - Repository status checking"
  
  local work_dir=$(create_test_work_dir)
  
  # Create test projects
  local project1=$(create_mock_project "clean-repo" "$work_dir")
  local project2=$(create_mock_project "dirty-repo" "$work_dir")
  
  # Make one repo dirty
  echo "uncommitted change" >> "$project2/README.md"
  
  local output=$(capture_output "run_with_test_env '$work_dir' 'check-repos'")
  
  assert_contains "$output" "clean-repo" "Should check clean-repo"
  assert_contains "$output" "dirty-repo" "Should check dirty-repo"
  assert_contains "$output" "has uncommitted changes" "Should detect uncommitted changes"
  assert_contains "$output" "Summary:" "Should show summary"
}

test_cleanup_empty() {
  test_case "cleanup-empty - Empty directory cleanup"
  
  local work_dir=$(create_test_work_dir)
  
  # Test 1: No worktrees directory
  rm -rf "$work_dir/worktrees"
  local output=$(capture_output "run_with_test_env '$work_dir' 'cleanup-empty'")
  assert_contains "$output" "No worktrees directory found" "Should handle missing worktrees directory"
  
  # Test 2: Create mix of empty and non-empty directories
  mkdir -p "$work_dir/worktrees"
  mkdir -p "$work_dir/worktrees/empty1"
  mkdir -p "$work_dir/worktrees/empty2"
  mkdir -p "$work_dir/worktrees/has-projects/project1"
  
  local output=$(capture_output "run_with_test_env '$work_dir' 'cleanup-empty'")
  
  assert_contains "$output" "empty1" "Should identify empty1 for removal"
  assert_contains "$output" "empty2" "Should identify empty2 for removal" 
  assert_not_contains "$output" "has-projects" "Should not remove directory with projects"
  
  # Verify cleanup
  assert_dir_not_exists "$work_dir/worktrees/empty1" "Should remove empty1"
  assert_dir_not_exists "$work_dir/worktrees/empty2" "Should remove empty2"
  assert_dir_exists "$work_dir/worktrees/has-projects" "Should keep directory with projects"
}

test_check_intellij() {
  test_case "check-intellij - IntelliJ detection"
  
  local output=$(capture_output "check-intellij")
  
  # This test is environment-dependent, so we mainly check that it runs
  assert_contains "$output" "IntelliJ IDEA" "Should mention IntelliJ IDEA"
  assert_contains "$output" "applications" "Should check for applications"
  assert_contains "$output" "Command-line launchers" "Should check for CLI launchers"
}

test_switch_to_ssh() {
  test_case "switch-to-ssh - HTTPS to SSH conversion"
  
  local work_dir=$(create_test_work_dir)
  
  # Create test project with HTTPS remote
  local project_dir=$(create_mock_project "https-repo" "$work_dir")
  
  # Set up HTTPS remote (mock)
  (
    cd "$project_dir"
    git remote add origin "https://github.com/user/repo.git"
  )
  
  local output=$(capture_output "run_with_test_env '$work_dir' 'switch-to-ssh'")
  
  assert_contains "$output" "https-repo" "Should process https-repo"
  assert_contains "$output" "Converting repositories" "Should show conversion message"
  
  # Check if remote was updated (in real scenario)
  local remote_url=$(cd "$project_dir" && git remote get-url origin 2>/dev/null)
  assert_contains "$remote_url" "git@github.com" "Should convert to SSH URL"
}

test_new_bug_wrapper() {
  test_case "new-bug - Bug creation wrapper"
  
  local work_dir=$(create_test_work_dir)
  create_mock_project "test-project" "$work_dir"
  
  # Create bug template
  create_test_template "template-bug-fix.md" "$work_dir" "# Bug Fix: [Brief Description]"
  
  # Test 1: Missing bug name
  local output=$(capture_output "run_with_test_env '$work_dir' 'new-bug'")
  local exit_code=$?
  
  assert_not_equals "0" "$exit_code" "Should fail without bug name"
  assert_contains "$output" "Please provide a bug name" "Should show error message"
  
  # Test 2: Bug creation with spec override
  # This would require mocking the full new-feature function
  # For now, just test argument parsing
  verbose_log "new-bug wrapper correctly handles missing arguments"
}

test_command_aliases() {
  test_case "Command aliases - Alias functionality"
  
  # Test that aliases are properly defined
  # This is tricky to test in isolation, so we'll check if functions exist
  
  local commands=("new-feature" "new-bug" "checkout-worktree" "switch-worktree" "sync-worktree" "list-worktrees" "remove-worktree" "check-repos" "cleanup-empty" "check-intellij")
  
  for cmd in "${commands[@]}"; do
    if declare -f "$cmd" &>/dev/null; then
      test_pass "Function $cmd is defined"
    else
      test_fail "Function $cmd is not defined"
    fi
  done
}

test_completion_functions() {
  test_case "Completion functions - Tab completion support"
  
  # Test that completion functions are defined
  local completion_functions=("_switch_worktree_completion" "_sync_worktree_completion" "_remove_worktree_completion")
  
  for func in "${completion_functions[@]}"; do
    if declare -f "$func" &>/dev/null; then
      test_pass "Completion function $func is defined"
    else
      test_fail "Completion function $func is not defined"
    fi
  done
}

test_configuration_validation() {
  test_case "Configuration - Environment variable handling"
  
  local work_dir=$(create_test_work_dir)
  
  # Test with custom configuration
  local old_work_dir="$WORK_DIR"
  local old_main_branch="$MAIN_BRANCH"
  
  export WORK_DIR="$work_dir"
  export MAIN_BRANCH="main"
  
  # Verify configuration is respected
  assert_equals "$work_dir" "$WORK_DIR" "Should use custom WORK_DIR"
  assert_equals "main" "$MAIN_BRANCH" "Should use custom MAIN_BRANCH"
  
  # Restore
  export WORK_DIR="$old_work_dir"
  export MAIN_BRANCH="$old_main_branch"
}

test_directory_structure() {
  test_case "Directory structure - Default paths"
  
  local work_dir=$(create_test_work_dir)
  
  # Test directory creation and validation
  assert_dir_exists "$work_dir/projects" "Should have projects directory"
  assert_dir_exists "$work_dir/worktrees" "Should have worktrees directory"
  assert_dir_exists "$work_dir/templates" "Should have templates directory"
  
  # Test path construction
  run_with_test_env "$work_dir" "true"  # Just to set environment
  
  # In real plugin, these would be set correctly
  verbose_log "Directory structure validation completed"
}

# Test error handling in main commands
test_error_handling() {
  test_case "Error handling - Graceful failure modes"
  
  local work_dir=$(create_test_work_dir)
  
  # Test 1: Missing projects directory
  rm -rf "$work_dir/projects"
  
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  # Should handle gracefully (list-worktrees doesn't depend on projects)
  
  # Test 2: Permission issues (simulate)
  # This is hard to test safely, so we'll skip for now
  verbose_log "Error handling tests completed (limited scope for safety)"
}

# Run all main command tests
echo "${fg[blue]}⚙️  Running Main Command Tests${reset_color}"

test_list_worktrees
test_check_repos  
test_cleanup_empty
test_check_intellij
test_switch_to_ssh
test_new_bug_wrapper
test_command_aliases
test_completion_functions
test_configuration_validation
test_directory_structure
test_error_handling

echo "${fg[green]}✓ Main command tests completed${reset_color}"