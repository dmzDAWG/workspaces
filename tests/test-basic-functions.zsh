#!/usr/bin/env zsh

# Basic Function Tests - Simplified version to verify core functionality
# Tests template and Java version functions without full plugin integration

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

test_create_test_work_dir() {
  test_case "create_test_work_dir - Test environment creation"
  
  local work_dir=$(create_test_work_dir)
  
  assert_dir_exists "$work_dir" "Should create work directory"
  assert_dir_exists "$work_dir/projects" "Should create projects subdirectory"
  assert_dir_exists "$work_dir/worktrees" "Should create worktrees subdirectory"
  assert_dir_exists "$work_dir/templates" "Should create templates subdirectory"
  
  # Test path structure
  assert_contains "$work_dir" "/tmp" "Should be in temporary directory"
}

test_create_mock_project() {
  test_case "create_mock_project - Mock repository creation"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "test-app" "$work_dir")
  
  assert_dir_exists "$project_dir" "Should create project directory"
  assert_dir_exists "$project_dir/.git" "Should initialize git repository"
  assert_file_exists "$project_dir/README.md" "Should create README file"
  
  # Test git functionality
  (
    cd "$project_dir"
    local status_output=$(git status --porcelain 2>/dev/null)
    local exit_code=$?
    assert_equals "0" "$exit_code" "Git should work in mock project"
  )
}

test_create_mock_project_with_pom() {
  test_case "create_mock_project_with_pom - Java project creation"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project_with_pom "java-app" "$work_dir" "17")
  
  assert_dir_exists "$project_dir" "Should create Java project directory"
  assert_file_exists "$project_dir/pom.xml" "Should create pom.xml file"
  
  # Test pom.xml content
  local pom_content=$(cat "$project_dir/pom.xml")
  assert_contains "$pom_content" "<java.version>17</java.version>" "Should set correct Java version"
  assert_contains "$pom_content" "java-app" "Should include project name"
}

test_create_test_template() {
  test_case "create_test_template - Template creation"
  
  local work_dir=$(create_test_work_dir)
  local template_content="# Test Template\nThis is test content: [Feature Name]"
  local template_path=$(create_test_template "test-template.md" "$work_dir" "$template_content")
  
  assert_file_exists "$template_path" "Should create template file"
  
  local saved_content=$(cat "$template_path")
  assert_contains "$saved_content" "Test Template" "Should save template content"
  assert_contains "$saved_content" "[Feature Name]" "Should preserve placeholders"
}

test_java_version_detection_basic() {
  test_case "Java version detection - Basic functionality"
  
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "java-test" "$work_dir")
  
  # Create a simple pom.xml
  cat > "$project_dir/pom.xml" << 'EOF'
<?xml version="1.0"?>
<project>
  <properties>
    <java.version>11</java.version>
  </properties>
</project>
EOF
  
  # Test the Java version extraction logic directly
  local java_version=$(grep -o '<java\.version>[^<]*</java\.version>' "$project_dir/pom.xml" | sed 's/<java\.version>\([^<]*\)<\/java\.version>/\1/')
  assert_equals "11" "$java_version" "Should extract Java version from pom.xml"
  
  # Test version validation
  if [[ "$java_version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    test_pass "Java version format is valid"
  else
    test_fail "Java version format is invalid"
  fi
}

test_environment_isolation() {
  test_case "Environment isolation - Temporary directory usage"
  
  # Test 1: Directory creation works
  local work_dir=$(create_test_work_dir)
  assert_dir_exists "$work_dir" "Should create work directory"
  assert_contains "$work_dir" "/tmp" "Should be in temporary directory"
  
  # Test 2: Directories can hold separate content
  local test_file="$work_dir/test-file.txt"
  echo "isolated content" > "$test_file"
  local content=$(cat "$test_file")
  assert_equals "isolated content" "$content" "Should maintain separate file content"
  
  # Test 3: Cleanup works
  assert_dir_exists "$work_dir" "Directory should exist before cleanup"
  rm -rf "$work_dir"
  assert_dir_not_exists "$work_dir" "Directory should be removed after cleanup"
  
  # Test 4: Subdirectories are properly created
  local work_dir2=$(create_test_work_dir)
  assert_dir_exists "$work_dir2/projects" "Should create projects subdirectory"
  assert_dir_exists "$work_dir2/worktrees" "Should create worktrees subdirectory"
  assert_dir_exists "$work_dir2/templates" "Should create templates subdirectory"
}

test_run_with_test_env() {
  test_case "run_with_test_env - Environment variable management"
  
  local work_dir=$(create_test_work_dir)
  
  # Save original values
  local original_work_dir="$WORK_DIR"
  
  # Test environment setting
  local result=$(run_with_test_env "$work_dir" 'echo "$WORK_DIR"')
  assert_equals "$work_dir" "$result" "Should set WORK_DIR in test environment"
  
  # Test environment restoration
  assert_equals "$original_work_dir" "$WORK_DIR" "Should restore original WORK_DIR after test"
}

# Initialize test framework
test_init

echo "${fg[blue]}🔧 Running Basic Function Tests${reset_color}"

test_create_test_work_dir
test_create_mock_project
test_create_mock_project_with_pom
test_create_test_template
test_java_version_detection_basic
test_environment_isolation
test_run_with_test_env

echo "${fg[green]}✓ Basic function tests completed${reset_color}"

# Generate report
test_report

# Cleanup
test_cleanup

exit $?