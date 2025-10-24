#!/usr/bin/env zsh

# Debug script to understand isolation issue

source "$(dirname "${0:A}")/test-framework.zsh"

test_init

echo "=== Testing directory creation ==="

echo "Creating first directory..."
work_dir1=$(create_test_work_dir)
echo "work_dir1: $work_dir1"

echo "Counter value after first: $WORK_DIR_COUNTER"

echo "Creating second directory..."  
work_dir2=$(create_test_work_dir)
echo "work_dir2: $work_dir2"

echo "Counter value after second: $WORK_DIR_COUNTER"

echo "Checking if they are equal: $work_dir1 == $work_dir2"
if [[ "$work_dir1" == "$work_dir2" ]]; then
  echo "ERROR: Directories are the same!"
else
  echo "SUCCESS: Directories are different!"
fi

echo "Creating test files..."
echo "test1" > "$work_dir1/test-file.txt"
echo "test2" > "$work_dir2/test-file.txt"

echo "Reading back..."
content1=$(cat "$work_dir1/test-file.txt")
content2=$(cat "$work_dir2/test-file.txt")

echo "content1: '$content1'"
echo "content2: '$content2'"

echo "Checking directory contents:"
echo "work_dir1 contents:"
ls -la "$work_dir1"
echo "work_dir2 contents:"
ls -la "$work_dir2"

test_cleanup