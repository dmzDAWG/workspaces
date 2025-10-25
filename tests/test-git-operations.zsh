#!/usr/bin/env zsh

# Test Suite for Git Operations
# Tests git-related functionality in the workspaces plugin

# Source test framework from absolute path
TEST_DIR="$(dirname "${0:A}")"
source "$TEST_DIR/test-framework.zsh"

# Load plugin with absolute path
PLUGIN_PATH="$(dirname "$TEST_DIR")/workspaces.plugin.zsh"
if [[ -f "$PLUGIN_PATH" ]]; then
  source "$PLUGIN_PATH"
else
  echo "Error: Could not find plugin at $PLUGIN_PATH"
  exit 1
fi

test_git_repository_validation() {
  test_case "Git repository validation"
  
  local work_dir=$(create_test_work_dir)
  
  # Test 1: Valid git repository
  local project_dir=$(create_mock_project "valid-repo" "$work_dir")
  assert_dir_exists "$project_dir/.git" "Should create .git directory"
  
  # Verify git repository is functional
  (
    cd "$project_dir"
    local status_output=$(git status --porcelain 2>/dev/null)
    local exit_code=$?
    assert_equals "0" "$exit_code" "Git status should work in created repo"
  )
  
  # Test 2: Non-git directory
  local non_git_dir="$work_dir/projects/not-a-repo"
  mkdir -p "$non_git_dir"
  assert_dir_not_exists "$non_git_dir/.git" "Non-git directory should not have .git"
  
  # Test 3: Corrupted git repository
  local corrupted_dir="$work_dir/projects/corrupted-repo"
  mkdir -p "$corrupted_dir/.git"
  echo "not a git repo" > "$corrupted_dir/.git/HEAD"
  
  (
    cd "$corrupted_dir"
    git status 2>/dev/null
    local exit_code=$?
    assert_not_equals "0" "$exit_code" "Corrupted repo should fail git commands"
  )
}

test_branch_operations() {
  test_case "Branch operations"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "branch-test" "$work_dir")
  
  (
    cd "$project_dir"
    
    # Test 1: Current branch detection
    local current_branch=$(git branch --show-current)
    assert_equals "master" "$current_branch" "Should be on master branch initially"
    
    # Test 2: Create new branch
    git checkout -b "feature/test-branch" 2>/dev/null
    local new_branch=$(git branch --show-current)
    assert_equals "feature/test-branch" "$new_branch" "Should create and switch to new branch"
    
    # Test 3: Branch listing
    local branches=$(git branch --format='%(refname:short)')
    assert_contains "$branches" "master" "Should list master branch"
    assert_contains "$branches" "feature/test-branch" "Should list new feature branch"
    
    # Test 4: Switch back to master
    git checkout master 2>/dev/null
    local back_to_master=$(git branch --show-current)
    assert_equals "master" "$back_to_master" "Should switch back to master"
  )
}

test_remote_operations() {
  test_case "Remote operations"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "remote-test" "$work_dir")
  
  (
    cd "$project_dir"
    
    # Test 1: Add remote
    git remote add origin "https://github.com/test/repo.git"
    local remotes=$(git remote -v)
    assert_contains "$remotes" "origin" "Should add origin remote"
    assert_contains "$remotes" "github.com/test/repo.git" "Should set correct remote URL"
    
    # Test 2: Get remote URL
    local remote_url=$(git remote get-url origin 2>/dev/null)
    assert_equals "https://github.com/test/repo.git" "$remote_url" "Should get correct remote URL"
    
    # Test 3: Change remote URL (HTTPS to SSH)
    git remote set-url origin "git@github.com:test/repo.git"
    local ssh_url=$(git remote get-url origin 2>/dev/null)
    assert_equals "git@github.com:test/repo.git" "$ssh_url" "Should update to SSH URL"
    
    # Test 4: Remove remote
    git remote remove origin
    local no_remotes=$(git remote -v)
    assert_not_contains "$no_remotes" "origin" "Should remove origin remote"
  )
}

test_worktree_operations() {
  test_case "Worktree operations"
  
  local work_dir=$(create_test_work_dir)
  local main_project=$(create_mock_project "worktree-test" "$work_dir")
  local worktree_dir="$work_dir/worktrees/test-feature/worktree-test"
  
  (
    cd "$main_project"
    
    # Test 1: Create worktree
    mkdir -p "$(dirname "$worktree_dir")"
    git worktree add -b "feature/test-feature" "$worktree_dir" "master" 2>/dev/null
    local exit_code=$?
    assert_equals "0" "$exit_code" "Should create worktree successfully"
    
    # Test 2: Verify worktree
    assert_dir_exists "$worktree_dir" "Worktree directory should exist"
    assert_dir_exists "$worktree_dir/.git" "Worktree should have .git"
    
    # Test 3: Check worktree branch
    (
      cd "$worktree_dir"
      local worktree_branch=$(git branch --show-current)
      assert_equals "feature/test-feature" "$worktree_branch" "Worktree should be on feature branch"
    )
    
    # Test 4: List worktrees
    local worktree_list=$(git worktree list)
    assert_contains "$worktree_list" "$main_project" "Should list main repository"
    assert_contains "$worktree_list" "$worktree_dir" "Should list worktree"
    assert_contains "$worktree_list" "feature/test-feature" "Should show branch name"
    
    # Test 5: Remove worktree
    git worktree remove "$worktree_dir" 2>/dev/null
    local remove_exit=$?
    assert_equals "0" "$remove_exit" "Should remove worktree successfully"
    assert_dir_not_exists "$worktree_dir" "Worktree directory should be removed"
  )
}

test_commit_operations() {
  test_case "Commit operations"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "commit-test" "$work_dir")
  
  (
    cd "$project_dir"
    
    # Test 1: Check clean status
    git diff-index --quiet HEAD --
    local clean_exit=$?
    assert_equals "0" "$clean_exit" "Repository should start clean"
    
    # Test 2: Make changes
    echo "new content" >> "test-file.txt"
    git add "test-file.txt"
    
    # Test 3: Check dirty status
    git diff-index --quiet HEAD --
    local dirty_exit=$?
    assert_not_equals "0" "$dirty_exit" "Repository should be dirty after changes"
    
    # Test 4: Commit changes
    git commit --quiet -m "Test commit"
    local commit_exit=$?
    assert_equals "0" "$commit_exit" "Should commit changes successfully"
    
    # Test 5: Verify clean after commit
    git diff-index --quiet HEAD --
    local clean_after_commit=$?
    assert_equals "0" "$clean_after_commit" "Repository should be clean after commit"
    
    # Test 6: Check commit history
    local commit_count=$(git rev-list --count HEAD)
    assert_true "$((commit_count >= 2))" "Should have at least 2 commits (initial + test)"
  )
}

test_merge_rebase_operations() {
  test_case "Merge and rebase operations"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "merge-test" "$work_dir")
  
  (
    cd "$project_dir"
    
    # Set up branches for testing
    git checkout -b "feature/merge-test" 2>/dev/null
    echo "feature content" > "feature-file.txt"
    git add "feature-file.txt"
    git commit --quiet -m "Add feature content"
    
    # Switch back to master and add different content
    git checkout master 2>/dev/null
    echo "master content" > "master-file.txt"
    git add "master-file.txt"
    git commit --quiet -m "Add master content"
    
    # Test 1: Merge operation
    git checkout "feature/merge-test" 2>/dev/null
    git merge master --no-edit 2>/dev/null
    local merge_exit=$?
    assert_equals "0" "$merge_exit" "Should merge master into feature branch"
    
    # Verify merge
    assert_file_exists "feature-file.txt" "Should have feature file after merge"
    assert_file_exists "master-file.txt" "Should have master file after merge"
    
    # Test 2: Reset for rebase test
    git reset --hard HEAD~1 2>/dev/null  # Remove merge commit
    
    # Test 3: Rebase operation
    git rebase master 2>/dev/null
    local rebase_exit=$?
    assert_equals "0" "$rebase_exit" "Should rebase feature branch onto master"
    
    # Verify rebase
    assert_file_exists "feature-file.txt" "Should have feature file after rebase"
    assert_file_exists "master-file.txt" "Should have master file after rebase"
  )
}

test_git_fetch_operations() {
  test_case "Git fetch operations"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "fetch-test" "$work_dir")
  
  (
    cd "$project_dir"
    
    # Add a remote (even though we can't actually fetch from it)
    git remote add origin "https://github.com/test/repo.git"
    
    # Test 1: Fetch command (will fail but shouldn't crash)
    git fetch origin 2>/dev/null
    local fetch_exit=$?
    # Don't assert exit code since we can't actually fetch
    # Just verify the command doesn't crash the shell
    assert_true "true" "Fetch command should not crash shell"
    
    # Test 2: Show-ref operations
    local local_refs=$(git show-ref --heads 2>/dev/null)
    assert_contains "$local_refs" "master" "Should show local master branch"
    
    # Test 3: Branch tracking
    git branch --set-upstream-to=origin/master master 2>/dev/null
    local tracking_branch=$(git rev-parse --abbrev-ref master@{upstream} 2>/dev/null)
    assert_equals "origin/master" "$tracking_branch" "Should set upstream tracking"
  )
}

test_git_conflict_scenarios() {
  test_case "Git conflict scenarios"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "conflict-test" "$work_dir")
  
  (
    cd "$project_dir"
    
    # Create conflicting changes
    echo "original content" > "conflict-file.txt"
    git add "conflict-file.txt"
    git commit --quiet -m "Add original content"
    
    # Create feature branch
    git checkout -b "feature/conflict" 2>/dev/null
    echo "feature content" > "conflict-file.txt"
    git add "conflict-file.txt"
    git commit --quiet -m "Feature change"
    
    # Switch to master and make conflicting change
    git checkout master 2>/dev/null
    echo "master content" > "conflict-file.txt"
    git add "conflict-file.txt"
    git commit --quiet -m "Master change"
    
    # Test 1: Attempt merge (should create conflict)
    git checkout "feature/conflict" 2>/dev/null
    git merge master --no-edit 2>/dev/null
    local merge_exit=$?
    assert_not_equals "0" "$merge_exit" "Merge should fail due to conflict"
    
    # Test 2: Check conflict status
    local status_output=$(git status --porcelain 2>/dev/null)
    assert_contains "$status_output" "UU" "Should show unmerged status" || \
    assert_contains "$status_output" "conflict" "Should indicate conflict"
    
    # Test 3: Abort merge
    git merge --abort 2>/dev/null
    local abort_exit=$?
    assert_equals "0" "$abort_exit" "Should abort merge successfully"
    
    # Test 4: Verify clean state after abort
    git diff-index --quiet HEAD --
    local clean_exit=$?
    assert_equals "0" "$clean_exit" "Should be clean after merge abort"
  )
}

# Initialize test framework
test_init

# Run all git operation tests
echo "${fg[blue]}🔀 Running Git Operation Tests${reset_color}"

test_git_repository_validation
test_branch_operations
test_remote_operations
test_worktree_operations
test_commit_operations
test_merge_rebase_operations
test_git_fetch_operations
test_git_conflict_scenarios

echo "${fg[green]}✓ Git operation tests completed${reset_color}"

# Generate report
test_report

# Cleanup
test_cleanup

exit $?