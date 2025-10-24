#!/usr/bin/env zsh

# Simple validation script for test files
# Checks syntax and basic structure without running full tests

echo "🔍 Validating test framework..."

test_dir="$(dirname "${0:A}")"
errors=0

# Check if all test files exist
required_files=(
  "test-framework.zsh"
  "test-runner.zsh" 
  "test-main-commands.zsh"
  "test-helpers.zsh"
  "test-git-operations.zsh"
  "test-edge-cases.zsh"
  "test-integration.zsh"
  "README.md"
)

for file in "${required_files[@]}"; do
  if [[ -f "$test_dir/$file" ]]; then
    echo "✓ $file exists"
  else
    echo "✗ $file missing"
    ((errors++))
  fi
done

# Check fixtures directory
if [[ -d "$test_dir/fixtures" ]]; then
  echo "✓ fixtures directory exists"
  
  fixture_count=$(find "$test_dir/fixtures" -name "*.md" | wc -l)
  echo "  - Found $fixture_count template fixtures"
else
  echo "✗ fixtures directory missing"
  ((errors++))
fi

# Basic syntax check for zsh files
echo ""
echo "🔍 Checking syntax..."

for file in "$test_dir"/*.zsh; do
  if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    if zsh -n "$file" 2>/dev/null; then
      echo "✓ $filename syntax OK"
    else
      echo "✗ $filename has syntax errors"
      ((errors++))
    fi
  fi
done

# Check for required functions in framework
echo ""
echo "🔍 Checking framework functions..."

framework_file="$test_dir/test-framework.zsh"
required_functions=(
  "test_init"
  "test_cleanup"
  "test_case"
  "assert_equals"
  "assert_file_exists"
  "create_test_work_dir"
  "create_mock_project"
  "load_workspaces_plugin"
)

for func in "${required_functions[@]}"; do
  if grep -q "^${func}()" "$framework_file" 2>/dev/null; then
    echo "✓ Function $func defined"
  else
    echo "✗ Function $func missing"
    ((errors++))
  fi
done

# Summary
echo ""
if [[ $errors -eq 0 ]]; then
  echo "🎉 All validation checks passed!"
  echo ""
  echo "Test framework is ready to use:"
  echo "  ./tests/test-runner.zsh -h     # Show help"
  echo "  ./tests/test-runner.zsh -q     # Quick tests"
  echo "  ./tests/test-runner.zsh -v     # Verbose output"
  echo "  ./tests/test-runner.zsh helpers # Test specific suite"
else
  echo "❌ Validation failed with $errors errors"
  echo ""
  echo "Please fix the issues above before running tests."
fi

exit $errors