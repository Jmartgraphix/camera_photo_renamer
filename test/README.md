# Camera Photo Re-namer Test Suite

This directory contains the test suite for the Camera Photo Re-namer script using [Bats (Bash Automated Testing System)](https://github.com/bats-core/bats-core).

## Prerequisites

### Install Bats

**macOS:**
```bash
brew install bats-core
```

**Ubuntu/Debian (WSL):**
```bash
sudo apt-get update
sudo apt-get install bats
```

**Manual Installation:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Install ExifTool

The script requires ExifTool to be installed and available in your PATH.

**macOS:**
```bash
brew install exiftool
```

**Ubuntu/Debian (WSL):**
```bash
sudo apt-get install libimage-exiftool-perl
```

**Verify Installation:**
```bash
exiftool -ver
```

## Running Tests

### Quick Test Run (Recommended)

Use the provided test runner script:
```bash
./run_tests.sh                    # Run all tests
./run_tests.sh -v                 # Run with verbose output
./run_tests.sh -f "XMP"          # Run tests matching "XMP"
```

### Run All Tests

From the project root directory:
```bash
bats test/camera_photo_renamer.bats
```

From the test directory:
```bash
cd test
bats camera_photo_renamer.bats
```

### Run Tests with Verbose Output

```bash
bats test/camera_photo_renamer.bats --verbose-run
```

### Run Specific Test

```bash
bats test/camera_photo_renamer.bats -f "displays help message"
```

### Run Tests Matching Pattern

```bash
# Run all XMP-related tests
bats test/camera_photo_renamer.bats -f "XMP"

# Run all backup tests
bats test/camera_photo_renamer.bats -f "backup"
```

## Test Coverage

The test suite covers the following functionality:

### Help and Usage
- ✓ Help message display with `--help` and `-h`
- ✓ Usage examples and documentation

### Argument Validation
- ✓ Event descriptor requirement in CLI mode
- ✓ Event descriptor length validation (max 12 chars)
- ✓ XMP mode validation (backup/skip/overwrite)
- ✓ Unknown option rejection
- ✓ Valid argument acceptance

### File Detection
- ✓ Empty directory handling
- ✓ JPEG file detection
- ✓ RAW file detection (RAF, CR2, NEF, etc.)
- ✓ Mixed format detection
- ✓ Camera type detection (Fujifilm, Sony, Nikon, etc.)
- ✓ Separate RAW and image file counting

### Backup Functionality
- ✓ Backup directory creation
- ✓ Original file preservation in backup
- ✓ `--no-backup` flag functionality
- ✓ Backup directory exclusion from processing

### File Renaming
- ✓ Event descriptor in filename
- ✓ Category prefix handling
- ✓ Filename without category when not specified
- ✓ Burst shot counter suffix (`-1`, `-2`, etc.)
- ✓ RAF/JPG pair alignment by timestamp
- ✓ DateTimeOriginal-based renaming

### XMP Sidecar Files
- ✓ XMP sidecar creation by default
- ✓ Original filename storage in XMP:Title
- ✓ `--no-sidecar` flag functionality
- ✓ XMP mode: backup (move existing to backup)
- ✓ XMP mode: skip (preserve existing XMP)
- ✓ XMP mode: overwrite (delete and recreate)

### Recursive Processing
- ✓ Subdirectory processing with `-r` flag
- ✓ Non-recursive mode (current directory only)
- ✓ Backup directory exclusion from recursion

### Output and Summary
- ✓ Processing summary display
- ✓ File count reporting
- ✓ Category display in summary
- ✓ XMP sidecar count in summary
- ✓ Backup location reporting

### Edge Cases
- ✓ Files without DateTimeOriginal metadata
- ✓ Mixed case file extensions (`.jpg`, `.JPG`, `.JPEG`)
- ✓ Duplicate timestamp detection and reporting

### Default Values
- ✓ Default category `Fam` when not specified
- ✓ Default XMP mode `backup`
- ✓ Default backup enabled

## Test Structure

Each test follows this pattern:

```bash
@test "descriptive test name" {
    # Setup test files
    create_test_image "filename.jpg" "2024:09:24 14:23:12"
    
    # Run script
    run bash "$SCRIPT_PATH" -e "Event" [options]
    
    # Assert exit status
    [ "$status" -eq 0 ]
    
    # Assert output
    [[ "$output" =~ "expected string" ]]
    
    # Assert file state
    [ -f "expected_file.jpg" ]
}
```

## Helper Functions

### `create_test_image`
Creates a minimal valid JPEG file with EXIF metadata.

```bash
create_test_image "photo.jpg" "2024:09:24 14:23:12"
```

### `create_test_raf`
Creates a mock Fujifilm RAF file with EXIF metadata.

```bash
create_test_raf "photo.RAF" "2024:09:24 14:23:12"
```

## Test Environment

- Each test runs in an isolated temporary directory
- Test directories are automatically cleaned up after each test
- The `setup()` function creates a fresh environment before each test
- The `teardown()` function removes test artifacts after each test

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

### GitHub Actions Example

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y bats libimage-exiftool-perl
      - name: Run tests
        run: bats test/camera_photo_renamer.bats
```

## Adding New Tests

When adding new features to the script:

1. Create a test that verifies the feature works correctly
2. Create tests for edge cases and error conditions
3. Follow the existing test naming conventions
4. Use descriptive test names that explain what is being tested
5. Add appropriate comments for complex test logic
6. Update this README with new test coverage information

## Troubleshooting

### Tests Fail with "exiftool: command not found"

Ensure ExifTool is installed and in your PATH:
```bash
which exiftool
exiftool -ver
```

### Tests Fail with Permission Errors

Ensure the test script has execute permissions:
```bash
chmod +x test/camera_photo_renamer.bats
```

### Temporary Directory Not Cleaned Up

If tests are interrupted, temporary directories may remain:
```bash
# Find and remove test directories
find /tmp -name "tmp.*" -type d -mtime +1 -exec rm -rf {} +
```

### Bats Not Found

Verify Bats is installed:
```bash
which bats
bats --version
```

## Test Output Examples

### Successful Test Run
```
✓ displays help message
✓ requires event descriptor in command line mode
✓ renames file with event descriptor
✓ creates XMP sidecar files by default
...

35 tests, 0 failures
```

### Failed Test Run
```
✓ displays help message
✗ requires event descriptor in command line mode
  (in test file test/camera_photo_renamer.bats, line 85)
  `[ "$status" -eq 1 ]' failed
...

35 tests, 1 failure
```

## WSL-Specific Notes

When running tests in WSL (Windows Subsystem for Linux):

1. Ensure ExifTool is installed in the WSL environment, not just Windows
2. File path handling may differ - tests account for this
3. Temporary directories are created in WSL's `/tmp` directory
4. Use WSL-native Bats installation for best compatibility

### Running Tests in WSL

```bash
# Open WSL terminal
wsl

# Navigate to project directory
cd /mnt/c/Projects/camera_photo_renamer

# Run tests
bats test/camera_photo_renamer.bats
```

## Contributing

When contributing tests:

- Ensure all tests pass before submitting PR
- Add tests for new features
- Update test documentation
- Follow existing code style and patterns
- Use meaningful assertions and error messages

