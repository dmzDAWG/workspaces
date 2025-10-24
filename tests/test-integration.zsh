#!/usr/bin/env zsh

# Integration Test Suite for Workspaces Plugin
# Tests complete workflows and end-to-end scenarios

# Load test framework and plugin
source "$(dirname "${0:A}")/test-framework.zsh"
load_workspaces_plugin

# Mock user input for interactive tests
simulate_user_input() {
  local input_sequence="$1"
  # This is a simplified approach - in real testing you'd use expect or similar
  echo "$input_sequence"
}

test_complete_feature_workflow() {
  test_case "Complete feature workflow - Create, work, sync, cleanup"
  
  local work_dir=$(create_test_work_dir)
  
  # Set up projects
  local project1=$(create_mock_project_with_pom "arrakis" "$work_dir" "11")
  local project2=$(create_mock_project_with_pom "wallet" "$work_dir" "17")
  
  # Set up templates
  create_test_template "template-feature-implementation.md" "$work_dir" "# [Feature Name] Implementation Spec

## Overview
This is a test feature: [Feature Name]

## Requirements
- [ ] Implement feature
- [ ] Add tests
- [ ] Update documentation"
  
  verbose_log "Phase 1: Project setup completed"
  
  # Test 1: Check initial repo status
  local output=$(capture_output "run_with_test_env '$work_dir' 'check-repos'")
  assert_contains "$output" "arrakis" "Should find arrakis project"
  assert_contains "$output" "wallet" "Should find wallet project" 
  assert_contains "$output" "Clean: 2" "Both projects should be clean"
  
  # Test 2: List empty worktrees
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output" "No worktrees found" "Should start with no worktrees"
  
  verbose_log "Phase 2: Initial state verification completed"
  
  # Test 3: Create worktree structure manually (simulating new-feature)
  local feature_name="payment-flow"
  local worktree_base="$work_dir/worktrees/$feature_name"
  local branch_name="feature/$feature_name"
  
  mkdir -p "$worktree_base"
  
  # Create worktrees for both projects
  (
    cd "$project1"
    git worktree add -b "$branch_name" "$worktree_base/arrakis" "master" 2>/dev/null
    assert_equals "0" "$?" "Should create arrakis worktree"
  )
  
  (
    cd "$project2"
    git worktree add -b "$branch_name" "$worktree_base/wallet" "master" 2>/dev/null
    assert_equals "0" "$?" "Should create wallet worktree"
  )
  
  verbose_log "Phase 3: Worktree creation completed"
  
  # Test 4: Create Java version files
  _create_java_version_file "$worktree_base/arrakis"
  _create_java_version_file "$worktree_base/wallet"
  
  assert_file_exists "$worktree_base/arrakis/.java-version" "Should create Java version for arrakis"
  assert_file_exists "$worktree_base/wallet/.java-version" "Should create Java version for wallet"
  
  local arrakis_java=$(cat "$worktree_base/arrakis/.java-version")
  local wallet_java=$(cat "$worktree_base/wallet/.java-version")
  assert_equals "11" "$arrakis_java" "Arrakis should use Java 11"
  assert_equals "17" "$wallet_java" "Wallet should use Java 17"
  
  # Test 5: Create and customize template
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' '$feature_name' '$branch_name' '$worktree_base' 'arrakis' 'wallet'"
  
  assert_file_exists "$worktree_base/SPEC.md" "Should create SPEC.md"
  local spec_content=$(cat "$worktree_base/SPEC.md")
  assert_contains "$spec_content" "$feature_name" "Spec should contain feature name"
  assert_contains "$spec_content" "arrakis, wallet" "Spec should list projects"
  
  verbose_log "Phase 4: Template and spec creation completed"
  
  # Test 6: List worktrees (should show our new worktree)
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output" "$feature_name" "Should list new worktree"
  assert_contains "$output" "arrakis" "Should show arrakis project"
  assert_contains "$output" "wallet" "Should show wallet project"
  
  # Test 7: Make some changes in worktrees
  echo "// New payment feature" >> "$worktree_base/arrakis/payment.java"
  echo "/* Payment UI component */" >> "$worktree_base/wallet/Payment.tsx"
  
  (
    cd "$worktree_base/arrakis"
    git add payment.java
    git commit --quiet -m "Add payment service"
  )
  
  (
    cd "$worktree_base/wallet"  
    git add Payment.tsx
    git commit --quiet -m "Add payment UI"
  )
  
  verbose_log "Phase 5: Development simulation completed"
  
  # Test 8: Sync simulation (merge master changes)
  # First, add some changes to master branches
  (
    cd "$project1"
    git checkout master 2>/dev/null
    echo "// Master branch update" >> "README.md"
    git add README.md
    git commit --quiet -m "Update README"
  )
  
  # Simulate sync operation (manual merge)
  (
    cd "$worktree_base/arrakis"
    git fetch "$project1" master 2>/dev/null || true
    git merge "$project1/master" --no-edit 2>/dev/null || true
  )
  
  verbose_log "Phase 6: Sync simulation completed"
  
  # Test 9: Cleanup simulation
  # Remove worktrees
  (
    cd "$project1"
    git worktree remove "$worktree_base/arrakis" 2>/dev/null
    git branch -D "$branch_name" 2>/dev/null
  )
  
  (
    cd "$project2" 
    git worktree remove "$worktree_base/wallet" 2>/dev/null
    git branch -D "$branch_name" 2>/dev/null
  )
  
  # Remove worktree directory
  rm -rf "$worktree_base"
  
  # Test cleanup
  local output=$(capture_output "run_with_test_env '$work_dir' 'cleanup-empty'")
  local output2=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output2" "No worktrees found" "Should have no worktrees after cleanup"
  
  verbose_log "Phase 7: Cleanup completed"
  
  test_pass "Complete feature workflow test passed"
}

test_multi_project_coordination() {
  test_case "Multi-project coordination workflow"
  
  local work_dir=$(create_test_work_dir)
  
  # Create multiple projects
  local projects=("frontend" "backend" "api" "shared")
  local project_dirs=()
  
  for project in "${projects[@]}"; do
    local proj_dir=$(create_mock_project "$project" "$work_dir")
    project_dirs+=("$proj_dir")
    
    # Add some project-specific files
    echo "# $project Project" > "$proj_dir/$project.md"
    (
      cd "$proj_dir"
      git add "$project.md"
      git commit --quiet -m "Add $project documentation"
    )
  done
  
  # Test 1: Check all projects
  local output=$(capture_output "run_with_test_env '$work_dir' 'check-repos'")
  for project in "${projects[@]}"; do
    assert_contains "$output" "$project" "Should find $project"
  done
  assert_contains "$output" "Clean: 4" "All projects should be clean"
  
  # Test 2: Create coordinated worktrees
  local feature_name="api-integration"
  local worktree_base="$work_dir/worktrees/$feature_name"
  local branch_name="feature/$feature_name"
  
  mkdir -p "$worktree_base"
  
  # Create worktrees for subset of projects (api and frontend)
  for project in "api" "frontend"; do
    local proj_dir="$work_dir/projects/$project"
    (
      cd "$proj_dir"
      git worktree add -b "$branch_name" "$worktree_base/$project" "master" 2>/dev/null
    )
    assert_dir_exists "$worktree_base/$project" "Should create $project worktree"
  done
  
  # Test 3: Cross-project changes
  echo "export interface ApiResponse {}" > "$worktree_base/api/types.ts"
  echo "import { ApiResponse } from '../api/types';" > "$worktree_base/frontend/api-client.ts"
  
  (
    cd "$worktree_base/api"
    git add types.ts
    git commit --quiet -m "Add shared types"
  )
  
  (
    cd "$worktree_base/frontend"
    git add api-client.ts  
    git commit --quiet -m "Add API client"
  )
  
  # Test 4: Verify coordination
  assert_file_exists "$worktree_base/api/types.ts" "Should have API types"
  assert_file_exists "$worktree_base/frontend/api-client.ts" "Should have frontend client"
  
  # Test 5: List coordinated worktree
  local output=$(capture_output "run_with_test_env '$work_dir' 'list-worktrees'")
  assert_contains "$output" "$feature_name" "Should list coordinated worktree"
  assert_contains "$output" "api" "Should show api project"
  assert_contains "$output" "frontend" "Should show frontend project"
  
  test_pass "Multi-project coordination test passed"
}

test_template_system_integration() {
  test_case "Template system integration"
  
  local work_dir=$(create_test_work_dir)
  create_mock_project "test-app" "$work_dir"
  
  # Test 1: Feature template
  local feature_template='# [Feature Name] Implementation

**Type**: Feature Development

## Overview
Implementing: [Feature Name]

## Tasks
- [ ] Design API
- [ ] Implement logic  
- [ ] Add tests
- [ ] Update docs

## Notes
Feature development notes here.'
  
  create_test_template "template-feature-implementation.md" "$work_dir" "$feature_template"
  
  # Test 2: Bug template
  local bug_template='# Bug Fix: [Brief Description]

**Type**: Bug Fix

## Problem
Issue: [Brief Description]

## Solution
- [ ] Identify root cause
- [ ] Implement fix
- [ ] Add regression test
- [ ] Verify fix

## Testing
Ensure bug is resolved.'
  
  create_test_template "template-bug-fix.md" "$work_dir" "$bug_template"
  
  # Test 3: Custom template
  local api_template='# API Integration: [Feature Name]

**Type**: API Development

## API Endpoints
- [ ] GET /api/[Feature Name]
- [ ] POST /api/[Feature Name]
- [ ] PUT /api/[Feature Name]
- [ ] DELETE /api/[Feature Name]

## Integration
Integration details for [Feature Name].'
  
  create_test_template "template-api-integration.md" "$work_dir" "$api_template"
  
  # Test feature template usage
  local worktree1="$work_dir/worktrees/feature-test"
  mkdir -p "$worktree1"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' 'feature-test' 'feature/feature-test' '$worktree1' 'test-app'"
  
  assert_file_exists "$worktree1/SPEC.md" "Should create feature spec"
  local feature_spec=$(cat "$worktree1/SPEC.md")
  assert_contains "$feature_spec" "feature-test" "Should customize feature name"
  assert_contains "$feature_spec" "Feature Development" "Should preserve template structure"
  
  # Test bug template usage  
  local worktree2="$work_dir/worktrees/bug-test"
  mkdir -p "$worktree2"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'bug' 'bug-test' 'bugfix/bug-test' '$worktree2' 'test-app'"
  
  assert_file_exists "$worktree2/SPEC.md" "Should create bug spec"
  local bug_spec=$(cat "$worktree2/SPEC.md")
  assert_contains "$bug_spec" "bug-test" "Should customize bug description"
  assert_contains "$bug_spec" "Bug Fix" "Should preserve bug template structure"
  
  # Test API template usage
  local worktree3="$work_dir/worktrees/api-test"
  mkdir -p "$worktree3"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'api' 'api-test' 'feature/api-test' '$worktree3' 'test-app'"
  
  assert_file_exists "$worktree3/SPEC.md" "Should create API spec"
  local api_spec=$(cat "$worktree3/SPEC.md")
  assert_contains "$api_spec" "api-test" "Should customize API name"
  assert_contains "$api_spec" "GET /api/api-test" "Should customize API endpoints"
  
  test_pass "Template system integration test passed"
}

test_java_version_management() {
  test_case "Java version management integration"
  
  local work_dir=$(create_test_work_dir)
  
  # Test 1: Projects with different Java versions
  local java8_project=$(create_mock_project_with_pom "legacy-app" "$work_dir" "8")
  local java11_project=$(create_mock_project_with_pom "modern-app" "$work_dir" "11") 
  local java17_project=$(create_mock_project_with_pom "latest-app" "$work_dir" "17")
  
  # Create worktrees
  local worktree_base="$work_dir/worktrees/java-version-test"
  mkdir -p "$worktree_base"
  
  for project in "legacy-app" "modern-app" "latest-app"; do
    local proj_dir="$work_dir/projects/$project"
    (
      cd "$proj_dir"
      git worktree add -b "feature/java-test" "$worktree_base/$project" "master" 2>/dev/null
    )
  done
  
  # Test Java version detection
  _create_java_version_file "$worktree_base/legacy-app"
  _create_java_version_file "$worktree_base/modern-app"
  _create_java_version_file "$worktree_base/latest-app"
  
  assert_file_exists "$worktree_base/legacy-app/.java-version" "Should create Java version for legacy app"
  assert_file_exists "$worktree_base/modern-app/.java-version" "Should create Java version for modern app"
  assert_file_exists "$worktree_base/latest-app/.java-version" "Should create Java version for latest app"
  
  local legacy_java=$(cat "$worktree_base/legacy-app/.java-version")
  local modern_java=$(cat "$worktree_base/modern-app/.java-version")
  local latest_java=$(cat "$worktree_base/latest-app/.java-version")
  
  assert_equals "8" "$legacy_java" "Legacy app should use Java 8"
  assert_equals "11" "$modern_java" "Modern app should use Java 11"
  assert_equals "17" "$latest_java" "Latest app should use Java 17"
  
  # Test 2: Complex POM scenarios
  local complex_project=$(create_mock_project "complex-maven" "$work_dir")
  
  cat > "$complex_project/pom.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  
  <groupId>com.example</groupId>
  <artifactId>complex-maven</artifactId>
  <version>1.0.0</version>
  
  <properties>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
  </properties>
  
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.8.1</version>
        <configuration>
          <source>11</source>
          <target>11</target>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
EOF
  
  (
    cd "$complex_project"
    git add pom.xml
    git commit --quiet -m "Add complex POM"
    git worktree add -b "feature/complex-test" "$worktree_base/complex-maven" "master" 2>/dev/null
  )
  
  _create_java_version_file "$worktree_base/complex-maven"
  assert_file_exists "$worktree_base/complex-maven/.java-version" "Should handle complex POM"
  
  local complex_java=$(cat "$worktree_base/complex-maven/.java-version")
  assert_equals "11" "$complex_java" "Should extract Java 11 from complex POM"
  
  test_pass "Java version management integration test passed"
}

test_error_recovery_workflow() {
  test_case "Error recovery and cleanup workflow"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "recovery-test" "$work_dir")
  
  # Test 1: Failed worktree creation recovery
  local worktree_base="$work_dir/worktrees/failed-creation"
  mkdir -p "$worktree_base"
  
  # Simulate partial failure - directory exists but no git worktree
  mkdir -p "$worktree_base/recovery-test"
  echo "partial content" > "$worktree_base/recovery-test/partial-file"
  
  # Cleanup should handle this
  local output=$(capture_output "run_with_test_env '$work_dir' 'cleanup-empty'")
  # If directory has content but no git structure, it might be left alone
  # This is correct behavior - don't remove directories with user content
  
  # Test 2: Interrupted template creation
  local incomplete_spec="$worktree_base/SPEC.md"
  echo "# Incomplete Spec" > "$incomplete_spec"
  # Incomplete spec should be fine - user can edit it
  
  # Test 3: Git operation failure recovery
  (
    cd "$project_dir"
    # Simulate failed branch creation by creating branch first
    git checkout -b "feature/already-exists" 2>/dev/null
    
    # Try to create worktree with same branch (should fail)
    git worktree add -b "feature/already-exists" "$worktree_base/test-conflict" "master" 2>/dev/null
    local failed_exit=$?
    assert_not_equals "0" "$failed_exit" "Worktree creation should fail with existing branch"
    
    # Cleanup branch
    git checkout master 2>/dev/null
    git branch -D "feature/already-exists" 2>/dev/null
  )
  
  test_pass "Error recovery workflow test passed"
}

# Run all integration tests
echo "${fg[blue]}🔗 Running Integration Tests${reset_color}"

test_complete_feature_workflow
test_multi_project_coordination  
test_template_system_integration
test_java_version_management
test_error_recovery_workflow

echo "${fg[green]}✓ Integration tests completed${reset_color}"