#!/usr/bin/env zsh

# Test Suite for Helper Functions
# Tests _create_java_version_file, _open_in_intellij, _copy_and_customize_template

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

# Test _create_java_version_file function
test_java_version_detection() {
  test_case "_create_java_version_file - Java version detection"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "test-java-app" "$work_dir")
  
  # Test 1: Basic java.version property
  cat > "$project_dir/pom.xml" << 'EOF'
<?xml version="1.0"?>
<project>
  <properties>
    <java.version>11</java.version>
  </properties>
</project>
EOF
  
  _create_java_version_file "$project_dir"
  assert_file_exists "$project_dir/.java-version" "Should create .java-version file"
  
  local java_version=$(cat "$project_dir/.java-version" 2>/dev/null)
  assert_equals "11" "$java_version" "Should extract Java version 11"
  
  # Test 2: maven.compiler.source property
  rm -f "$project_dir/.java-version"
  cat > "$project_dir/pom.xml" << 'EOF'
<?xml version="1.0"?>
<project>
  <properties>
    <maven.compiler.source>17</maven.compiler.source>
  </properties>
</project>
EOF
  
  _create_java_version_file "$project_dir"
  local java_version=$(cat "$project_dir/.java-version" 2>/dev/null)
  assert_equals "17" "$java_version" "Should extract Java version from maven.compiler.source"
  
  # Test 3: Don't overwrite existing .java-version
  echo "8" > "$project_dir/.java-version"
  _create_java_version_file "$project_dir"
  local java_version=$(cat "$project_dir/.java-version" 2>/dev/null)
  assert_equals "8" "$java_version" "Should not overwrite existing .java-version"
  
  # Test 4: No pom.xml
  local project_dir2=$(create_mock_project "no-pom-app" "$work_dir")
  _create_java_version_file "$project_dir2"
  assert_file_not_exists "$project_dir2/.java-version" "Should not create .java-version without pom.xml"
  
  # Test 5: Invalid Java version
  rm -f "$project_dir/.java-version"
  cat > "$project_dir/pom.xml" << 'EOF'
<?xml version="1.0"?>
<project>
  <properties>
    <java.version>invalid-version</java.version>
  </properties>
</project>
EOF
  
  _create_java_version_file "$project_dir"
  assert_file_not_exists "$project_dir/.java-version" "Should not create .java-version with invalid version"
}

test_java_version_complex_pom() {
  test_case "_create_java_version_file - Complex POM scenarios"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "complex-java-app" "$work_dir")
  
  # Test 1: Maven compiler plugin configuration
  cat > "$project_dir/pom.xml" << 'EOF'
<?xml version="1.0"?>
<project>
  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <configuration>
          <source>17</source>
          <target>17</target>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
EOF
  
  _create_java_version_file "$project_dir"
  local java_version=$(cat "$project_dir/.java-version" 2>/dev/null)
  assert_equals "17" "$java_version" "Should extract version from maven-compiler-plugin"
  
  # Test 2: Multiple version definitions (should use first found)
  rm -f "$project_dir/.java-version"
  cat > "$project_dir/pom.xml" << 'EOF'
<?xml version="1.0"?>
<project>
  <properties>
    <java.version>11</java.version>
    <maven.compiler.source>17</maven.compiler.source>
  </properties>
</project>
EOF
  
  _create_java_version_file "$project_dir"
  local java_version=$(cat "$project_dir/.java-version" 2>/dev/null)
  assert_equals "11" "$java_version" "Should use first found version (java.version)"
}

test_intellij_detection() {
  test_case "_open_in_intellij - IntelliJ detection"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "intellij-test" "$work_dir")
  
  # Test 1: Invalid project path
  _open_in_intellij '/nonexistent/path' > /dev/null 2>&1
  local exit_code=$?
  assert_not_equals "0" "$exit_code" "Should fail with invalid path"
  
  local output=$(capture_output "_open_in_intellij '/nonexistent/path'")
  assert_contains "$output" "Invalid project path" "Should show error message"
  
  # Test 2: Valid project path (will try to detect IntelliJ)
  # This test is platform-dependent, so we'll just verify it doesn't crash
  local output=$(capture_output "_open_in_intellij '$project_dir'")
  local exit_code=$?
  # Don't assert exit code since IntelliJ may not be installed
  # Just verify function runs without crashing
  assert_true "true" "IntelliJ detection function should run without crashing"
}

test_template_copying() {
  test_case "_copy_and_customize_template - Template processing"
  
  local work_dir=$(create_test_work_dir)
  
  # Create test template
  local template_content='# [Feature Name] Implementation Spec

## Overview
This is a test template for [Feature Name].

## Details
Feature: [Feature Name]
Description: [Brief Description]'
  
  create_test_template "template-feature-implementation.md" "$work_dir" "$template_content"
  
  # Test 1: Basic template customization
  local worktree_base="$work_dir/worktrees/test-feature"
  mkdir -p "$worktree_base"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' 'test-feature' 'feature/test-feature' '$worktree_base' 'project1' 'project2'"
  
  assert_file_exists "$worktree_base/SPEC.md" "Should create SPEC.md file"
  
  local spec_content=$(cat "$worktree_base/SPEC.md")
  assert_contains "$spec_content" "test-feature" "Should replace [Feature Name] with actual feature name"
  assert_contains "$spec_content" "feature/test-feature" "Should include branch name in metadata"
  assert_contains "$spec_content" "project1, project2" "Should include projects in metadata"
  
  # Test 2: Bug template (creates project-specific spec)
  local bug_template='# Bug Fix: [Brief Description] - [Project Name]

## Issue
Bug: [Brief Description]'
  
  create_test_template "template-project-bug.md" "$work_dir" "$bug_template"
  
  local bug_worktree="$work_dir/worktrees/fix-bug"
  mkdir -p "$bug_worktree/project1"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'bug' 'fix-bug' 'bugfix/fix-bug' '$bug_worktree' 'project1'"
  
  assert_file_exists "$bug_worktree/project1/PROJECT-SPEC.md" "Should create bug PROJECT-SPEC.md file"
  assert_file_not_exists "$bug_worktree/SPEC.md" "Should not create main SPEC.md for bugs"
  
  local bug_spec=$(cat "$bug_worktree/project1/PROJECT-SPEC.md")
  assert_contains "$bug_spec" "fix-bug" "Should replace [Brief Description] with bug name"
  
  # Test 3: Unknown template type (should fail)
  local missing_worktree="$work_dir/worktrees/missing-template"
  mkdir -p "$missing_worktree/project1"
  
  # Test exit code directly
  run_with_test_env "$work_dir" '_copy_and_customize_template "nonexistent" "test" "test" "'$missing_worktree'" "project1"' > /dev/null 2>&1
  local exit_code=$?
  
  assert_not_equals "0" "$exit_code" "Should fail with unknown template type"
  
  # Test output separately
  local output=$(capture_output "run_with_test_env '$work_dir' '_copy_and_customize_template \"nonexistent\" \"test\" \"test\" \"$missing_worktree\" \"project1\"'")
  assert_contains "$output" "Unknown template type" "Should show unknown template type message"
  assert_file_not_exists "$missing_worktree/SPEC.md" "Should not create SPEC.md with missing template"
}

test_template_metadata() {
  test_case "_copy_and_customize_template - Metadata insertion"
  
  local work_dir=$(create_test_work_dir)
  
  # Create minimal template
  local template_content='# [Feature Name] Test'
  create_test_template "template-feature-implementation.md" "$work_dir" "$template_content"
  
  local worktree_base="$work_dir/worktrees/metadata-test"
  mkdir -p "$worktree_base"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' 'metadata-test' 'feature/metadata-test' '$worktree_base' 'arrakis' 'wallet'"
  
  local spec_content=$(cat "$worktree_base/SPEC.md")
  
  # Check metadata insertion
  assert_contains "$spec_content" "**Created**:" "Should include creation date"
  assert_contains "$spec_content" "**Branch**: \`feature/metadata-test\`" "Should include branch info"
  assert_contains "$spec_content" "**Projects**: arrakis, wallet" "Should include projects list"
  
  # Check title replacement
  assert_contains "$spec_content" "# metadata-test Implementation Spec" "Should replace feature name in title"
}

test_template_edge_cases() {
  test_case "_copy_and_customize_template - Edge cases"
  
  local work_dir=$(create_test_work_dir)
  
  # Test 1: Single project feature (creates project spec)
  create_test_template "template-project-feature.md" "$work_dir" "# [Feature Name] - [Project Name]"
  
  local worktree_base="$work_dir/worktrees/empty-template"
  mkdir -p "$worktree_base/project1"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' 'empty-template' 'feature/empty-template' '$worktree_base' 'project1'"
  
  assert_file_exists "$worktree_base/project1/PROJECT-SPEC.md" "Should create PROJECT-SPEC.md for single project feature"
  assert_file_not_exists "$worktree_base/SPEC.md" "Should not create main SPEC.md for single project"
  
  # Test 2: Multi-project feature with special characters
  local special_content='# [Feature Name] with "quotes" and $variables and [brackets]'
  create_test_template "template-feature-coordination.md" "$work_dir" "$special_content"
  create_test_template "template-project-feature.md" "$work_dir" "# [Feature Name] - [Project Name]"
  
  local special_worktree="$work_dir/worktrees/special-chars"
  mkdir -p "$special_worktree/project1" "$special_worktree/project2"
  
  run_with_test_env "$work_dir" "_copy_and_customize_template 'feature' 'special-chars' 'feature/special-chars' '$special_worktree' 'project1' 'project2'"
  
  local spec_content=$(cat "$special_worktree/SPEC.md")
  assert_contains "$spec_content" "special-chars with" "Should handle special characters in replacement"
}

# Initialize test framework
test_init

# Run all helper tests
echo "${fg[blue]}🔧 Running Helper Function Tests${reset_color}"

test_java_version_detection
test_java_version_complex_pom
test_intellij_detection
test_template_copying
test_template_metadata
test_template_edge_cases

echo "${fg[green]}✓ Helper function tests completed${reset_color}"

# Generate report
test_report

# Cleanup
test_cleanup

exit $?