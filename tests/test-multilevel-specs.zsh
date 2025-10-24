#!/usr/bin/env zsh

# Test Suite for Multi-Level Spec Implementation
# Tests the new multi-level spec functionality

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

test_single_project_feature() {
  test_case "Single project feature - Should create project spec only"
  
  local work_dir=$(create_test_work_dir)
  create_mock_project "single-app" "$work_dir"
  
  # Create plugin template directory and files
  local plugin_templates="$(dirname "${(%):-%x}")/../templates"
  mkdir -p "$plugin_templates"
  
  cat > "$plugin_templates/template-project-feature.md" << 'EOF'
# [Feature Name] - [Project Name] Implementation

**Project**: [Project Name]

## Project-Specific Tasks
- [ ] Task 1
- [ ] Task 2
EOF
  
  local worktree_base="$work_dir/worktrees/single-feature"
  mkdir -p "$worktree_base/single-app"
  
  # Test single project feature creation
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' 'single-feature' 'feature/single-feature' '$worktree_base' 'single-app'"
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Should succeed with single project"
  assert_file_not_exists "$worktree_base/SPEC.md" "Should not create main spec for single project"
  assert_file_exists "$worktree_base/single-app/PROJECT-SPEC.md" "Should create project spec"
  
  if [[ -f "$worktree_base/single-app/PROJECT-SPEC.md" ]]; then
    local project_spec=$(cat "$worktree_base/single-app/PROJECT-SPEC.md")
    assert_contains "$project_spec" "single-feature" "Should customize feature name"
    assert_contains "$project_spec" "single-app" "Should customize project name"
  fi
}

test_multi_project_feature() {
  test_case "Multi-project feature - Should create main + project specs"
  
  local work_dir=$(create_test_work_dir)
  create_mock_project "frontend" "$work_dir"
  create_mock_project "backend" "$work_dir"
  
  # Create plugin template directory and files
  local plugin_templates="$(dirname "${(%):-%x}")/../templates"
  mkdir -p "$plugin_templates"
  
  cat > "$plugin_templates/template-feature-coordination.md" << 'EOF'
# [Feature Name] Implementation Spec

**Type**: Multi-Project Feature Coordination

## Project Breakdown
{{#each projects}}
- **{{name}}**: See `{{name}}/PROJECT-SPEC.md` - [Brief description of {{name}} role]
{{/each}}
EOF

  cat > "$plugin_templates/template-project-feature.md" << 'EOF'
# [Feature Name] - [Project Name] Implementation

**Project**: [Project Name]

## Project-Specific Tasks
- [ ] Task 1
- [ ] Task 2
EOF
  
  local worktree_base="$work_dir/worktrees/multi-feature"
  mkdir -p "$worktree_base/frontend"
  mkdir -p "$worktree_base/backend"
  
  # Test multi-project feature creation
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' 'multi-feature' 'feature/multi-feature' '$worktree_base' 'frontend' 'backend'"
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Should succeed with multiple projects"
  assert_file_exists "$worktree_base/SPEC.md" "Should create main coordination spec"
  assert_file_exists "$worktree_base/frontend/PROJECT-SPEC.md" "Should create frontend project spec"
  assert_file_exists "$worktree_base/backend/PROJECT-SPEC.md" "Should create backend project spec"
  
  if [[ -f "$worktree_base/SPEC.md" ]]; then
    local main_spec=$(cat "$worktree_base/SPEC.md")
    assert_contains "$main_spec" "multi-feature" "Should customize feature name in main spec"
    assert_contains "$main_spec" "frontend" "Should list frontend project"
    assert_contains "$main_spec" "backend" "Should list backend project"
  fi
}

test_bug_workflow() {
  test_case "Bug workflow - Should create project spec only"
  
  local work_dir=$(create_test_work_dir)
  create_mock_project "app" "$work_dir"
  
  # Create plugin template
  local plugin_templates="$(dirname "${(%):-%x}")/../templates"
  mkdir -p "$plugin_templates"
  
  cat > "$plugin_templates/template-project-bug.md" << 'EOF'
# Bug Fix: [Brief Description] - [Project Name]

**Project**: [Project Name]

## Issue Description
Bug: [Brief Description]
EOF
  
  local worktree_base="$work_dir/worktrees/bug-fix"
  mkdir -p "$worktree_base/app"
  
  # Test bug creation
  run_with_test_env "$work_dir" "_copy_and_customize_template 'bug' 'bug-fix' 'bugfix/bug-fix' '$worktree_base' 'app'"
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Should succeed with bug workflow"
  assert_file_not_exists "$worktree_base/SPEC.md" "Should not create main spec for bugs"
  assert_file_exists "$worktree_base/app/PROJECT-SPEC.md" "Should create project spec for bug"
}

test_template_fallback() {
  test_case "Template fallback - Reference templates from plugin"
  
  local work_dir=$(create_test_work_dir)
  create_mock_project "app" "$work_dir"
  
  # Don't create user templates - should fall back to plugin templates
  local worktree_base="$work_dir/worktrees/fallback-test"
  mkdir -p "$worktree_base/app"
  
  # This should succeed using plugin reference templates
  local output=$(capture_output "run_with_test_env '$work_dir' '_copy_and_customize_template \"feature\" \"fallback-test\" \"feature/fallback-test\" \"$worktree_base\" \"app\"'")
  
  assert_contains "$output" "Using reference template from plugin" "Should indicate using plugin template"
  assert_file_exists "$worktree_base/app/PROJECT-SPEC.md" "Should create spec using plugin template"
}

# Initialize test framework
test_init

echo "${fg[blue]}🔀 Running Multi-Level Spec Tests${reset_color}"

test_single_project_feature
test_multi_project_feature  
test_bug_workflow
test_template_fallback

echo "${fg[green]}✓ Multi-level spec tests completed${reset_color}"

# Generate report
test_report

# Cleanup
test_cleanup

exit $?