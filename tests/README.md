# Workspaces Plugin Test Suite

Comprehensive testing framework for the Oh My Zsh workspaces plugin.

## Overview

This test suite provides complete coverage of the workspaces plugin functionality, ensuring reliability and preventing regressions during development and enhancement.

## Test Structure

```
tests/
├── README.md                    # This documentation
├── test-framework.zsh          # Core testing utilities and assertions
├── test-runner.zsh             # Test execution and reporting system
├── test-main-commands.zsh      # Tests for all main user commands
├── test-helpers.zsh            # Tests for helper functions
├── test-git-operations.zsh     # Tests for git-related functionality
├── test-edge-cases.zsh         # Edge cases and error handling tests
├── test-integration.zsh        # End-to-end integration tests
└── fixtures/                   # Test templates and mock data
    ├── template-feature-implementation.md
    └── template-bug-fix.md
```

## Testing Approaches

### Automated Testing (Recommended)
All test suites use **mock repositories** created in isolated temporary environments:
- **Fast execution** - No network operations or real git repos
- **Complete isolation** - Each test gets fresh, clean environment
- **Safe testing** - No risk of affecting real code or repositories
- **Reproducible** - Same conditions every test run
- **Parallel ready** - Tests can run concurrently without conflicts

### Manual Testing (Optional)
For manual validation and demonstration, use the **workspaces-test** repository:
- **Location**: `~/Work/projects/workspaces-test` 
- **Remote**: `https://github.com/dmzDAWG/workspaces-test`
- **Purpose**: Manual verification, demos, documentation examples
- **Safety**: Non-critical test repository, safe for experimentation

## Running Tests

### Quick Start

```bash
# Run all tests
cd ~/.oh-my-zsh/custom/plugins/workspaces
./tests/test-runner.zsh

# Run with verbose output
./tests/test-runner.zsh -v

# Run only quick tests (skip integration)
./tests/test-runner.zsh -q
```

### Test Categories

```bash
# Run specific test suites
./tests/test-runner.zsh main          # Main command tests only
./tests/test-runner.zsh helpers       # Helper function tests only
./tests/test-runner.zsh git           # Git operation tests only
./tests/test-runner.zsh edge          # Edge case tests only
./tests/test-runner.zsh integration   # Integration tests only
```

### Command Line Options

- `-v, --verbose`: Show detailed test output
- `-q, --quick`: Skip slower integration tests
- `-h, --help`: Show usage information

## Test Coverage

### Main Commands (11 functions)
- ✅ `new-feature` / `nf` - Feature creation workflow
- ✅ `new-bug` / `nb` - Bug workflow  
- ✅ `checkout-worktree` / `cw` - Existing branch checkout
- ✅ `switch-worktree` / `sw` - Worktree navigation
- ✅ `sync-worktree` / `sync` - Master branch syncing
- ✅ `list-worktrees` / `lw` - Worktree listing
- ✅ `remove-worktree` / `rw` - Cleanup operations
- ✅ `check-repos` / `cr` - Repository status
- ✅ `cleanup-empty` / `ce` - Empty directory cleanup
- ✅ `check-intellij` / `ci` - IDE detection
- ✅ `switch-to-ssh` - HTTPS to SSH conversion

### Helper Functions (4 functions)
- ✅ `_create_java_version_file` - Maven XML parsing and Java version detection
- ✅ `_open_in_intellij` - IDE integration and detection
- ✅ `_copy_and_customize_template` - Template processing and customization
- ✅ Tab completion functions - Command completion logic

### Git Operations
- ✅ Repository validation and setup
- ✅ Branch operations (create, delete, switch)
- ✅ Remote operations (add, remove, URL changes)
- ✅ Worktree operations (create, remove, list)
- ✅ Commit operations and status checking
- ✅ Merge and rebase operations
- ✅ Fetch operations and conflict handling

### Edge Cases & Error Handling
- ✅ Missing directories and files
- ✅ Permission issues
- ✅ Special characters in names
- ✅ Large repository handling
- ✅ Corrupted git repositories
- ✅ Network operation failures
- ✅ Malformed configurations
- ✅ Unicode and encoding issues
- ✅ System command failures

### Integration Tests
- ✅ Complete feature development workflow
- ✅ Multi-project coordination
- ✅ Template system integration
- ✅ Java version management
- ✅ Error recovery and cleanup

## Safety Features

### Isolated Testing Environment
- All tests run in temporary directories
- No impact on real `~/Work` directory
- Automatic cleanup after test completion
- Mock git repositories for safe testing

### Non-Destructive Testing
- **Automated tests**: Use only mock repositories in temporary directories
- **Manual testing**: Uses `workspaces-test` repository (safe, non-critical)
- Never modifies production repositories
- All git operations in sandboxed environment
- Configuration preservation during tests

### Error Isolation
- Each test case runs independently
- Failures don't affect subsequent tests
- Comprehensive cleanup between tests
- Safe mock data and fixtures

## Test Framework Features

### Assertion Functions
```bash
# Basic assertions
assert_equals "expected" "$actual" "message"
assert_not_equals "unexpected" "$actual" "message"
assert_true "$condition" "message"
assert_false "$condition" "message"

# File system assertions
assert_file_exists "/path/to/file" "message"
assert_file_not_exists "/path/to/file" "message"
assert_dir_exists "/path/to/dir" "message"

# String assertions
assert_contains "$haystack" "$needle" "message"
assert_not_contains "$haystack" "$needle" "message"

# Exit code assertions
assert_exit_code 0 $? "message"
```

### Test Environment Functions
```bash
# Create isolated test environment
test_work_dir=$(create_test_work_dir)

# Create mock git repositories
project_dir=$(create_mock_project "project-name" "$work_dir")
project_dir=$(create_mock_project_with_pom "java-project" "$work_dir" "11")

# Create test templates
template_path=$(create_test_template "template.md" "$work_dir" "$content")

# Run commands in test environment
run_with_test_env "$work_dir" "command_to_test"

# Capture command output
output=$(capture_output "command_to_test")
```

### Mock Functions
```bash
# Mock git commands
mock_script=$(mock_git_command "status" "mock output" 0)
restore_git_command

# Mock user input for interactive commands
mock_user_input "1\ny\n"  # Simulate user selections
restore_input
```

## Manual Testing with workspaces-test Repository

For manual validation and demonstration purposes, you can use the dedicated test repository:

### Repository Setup
```bash
# Clone the test repository (if not already in your Work directory)
cd ~/Work/projects
git clone https://github.com/dmzDAWG/workspaces-test

# Verify the repository
cd workspaces-test
ls -la  # Should see README.md, pom.xml, src/, docs/
```

### Manual Testing Workflow
```bash
# Test creating a feature worktree
nf test-feature
# Select workspaces-test when prompted
# Work on the feature
# Test sync, cleanup, etc.

# Test multi-project coordination
# Create other test projects alongside workspaces-test
# Test cross-project features
```

### When to Use Manual Testing
- **Demonstrating the plugin** to team members
- **Validating end-to-end workflows** before releases
- **Testing with real git remotes** (push/pull operations)
- **Debugging complex interaction issues**
- **Creating documentation examples**

### When to Use Automated Testing
- **Continuous integration** and regression testing
- **Development workflow** (test-driven development)
- **Quick validation** of changes
- **Edge case and error handling** verification
- **Performance testing** and benchmarking

## Writing New Tests

### Test Case Structure
```bash
test_new_functionality() {
  test_case "Description of what this tests"
  
  # Setup
  local work_dir=$(create_test_work_dir)
  local project_dir=$(create_mock_project "test-project" "$work_dir")
  
  # Execute
  local output=$(capture_output "run_with_test_env '$work_dir' 'command_to_test'")
  local exit_code=$?
  
  # Assert
  assert_equals "0" "$exit_code" "Command should succeed"
  assert_contains "$output" "expected text" "Should show expected output"
  assert_file_exists "$expected_file" "Should create expected file"
  
  # Cleanup is automatic
}
```

### Best Practices

1. **Descriptive Test Names**: Use clear, descriptive names for test functions
2. **Isolated Tests**: Each test should be independent and not rely on other tests
3. **Clear Assertions**: Use descriptive messages for all assertions
4. **Comprehensive Coverage**: Test both success and failure paths
5. **Mock External Dependencies**: Use mocks for git remotes, file system, etc.
6. **Clean Setup/Teardown**: Use framework functions for consistent test environments

### Adding New Test Suites

1. Create new test file: `test-new-feature.zsh`
2. Follow the established pattern:
   ```bash
   #!/usr/bin/env zsh
   source "$(dirname "${0:A}")/test-framework.zsh"
   load_workspaces_plugin
   
   test_function1() { ... }
   test_function2() { ... }
   
   echo "${fg[blue]}🔧 Running New Feature Tests${reset_color}"
   test_function1
   test_function2
   echo "${fg[green]}✓ New feature tests completed${reset_color}"
   ```
3. Add to test runner in `test-runner.zsh`

## Troubleshooting

### Common Issues

**Tests fail with git errors:**
- Ensure git is installed and configured
- Check that test repositories are being created correctly
- Verify git user configuration in test environment

**Permission errors:**
- Ensure test directory is writable
- Check that temporary directory creation works
- Verify no conflicts with existing files

**Template tests fail:**
- Check that fixture templates exist in `tests/fixtures/`
- Verify template content formatting
- Ensure test environment variables are set correctly

**Integration tests hang:**
- May be waiting for user input in interactive commands
- Check mock input functions are working
- Verify timeout settings for long-running operations

### Debugging

```bash
# Run with verbose output
./tests/test-runner.zsh -v

# Run specific failing test
./tests/test-runner.zsh edge

# Check test environment
echo $TEST_TEMP_DIR
ls -la $TEST_TEMP_DIR

# Manual test environment setup
source tests/test-framework.zsh
test_init
work_dir=$(create_test_work_dir)
# ... manual testing
test_cleanup
```

## Contributing

When adding new features to the workspaces plugin:

1. **Write tests first** - Add tests for new functionality before implementation
2. **Update existing tests** - Modify tests when changing existing behavior
3. **Run full test suite** - Ensure all tests pass before submitting changes
4. **Add integration tests** - For complex features, add end-to-end tests
5. **Update documentation** - Keep test documentation current

### Test Development Workflow

1. Identify functionality to test
2. Write failing test case
3. Implement feature to make test pass
4. Run full test suite to check for regressions
5. Refactor if needed while keeping tests green

## Performance

The test suite is designed to be fast and efficient:

- **Quick tests**: Run in under 30 seconds
- **Full suite**: Completes in under 2 minutes
- **Parallel safe**: Tests can be run concurrently (future enhancement)
- **Minimal I/O**: Uses in-memory operations where possible

## Future Enhancements

- **Parallel test execution**: Run test suites concurrently
- **Performance benchmarking**: Track plugin performance over time
- **Cross-platform testing**: Ensure compatibility across different systems
- **Continuous integration**: Automated testing on code changes
- **Test coverage reporting**: Detailed coverage metrics
- **Property-based testing**: Randomized input testing for edge cases

---

This comprehensive test suite ensures the workspaces plugin remains reliable and maintainable as it evolves. The testing framework provides a solid foundation for continued development and enhancement.