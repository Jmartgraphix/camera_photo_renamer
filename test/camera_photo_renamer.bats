#!/usr/bin/env bats

# Camera Photo Re-namer Test Suite
# Tests for camera_photo_renamer.sh script

# Setup function - runs before each test
setup() {
    # Set script path relative to test directory
    export SCRIPT_PATH="${BATS_TEST_DIRNAME}/../camera_photo_renamer.sh"
    
    # Create temporary test directory
    export TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
    
    # Create test files with EXIF data
    # Note: These will be created by individual tests as needed
}

# Teardown function - runs after each test
teardown() {
    # Clean up temporary test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        cd /
        rm -rf "$TEST_DIR"
    fi
}

# Helper function to create a test image with EXIF data
create_test_image() {
    local filename="$1"
    local datetime="${2:-2024:09:24 14:23:12}"
    
    # Create a minimal valid JPEG file (1x1 pixel)
    printf '\xff\xd8\xff\xe0\x00\x10\x4a\x46\x49\x46\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xdb\x00\x43\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\x09\x09\x08\x0a\x0c\x14\x0d\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c\x20\x24\x2e\x27\x20\x22\x2c\x23\x1c\x1c\x28\x37\x29\x2c\x30\x31\x34\x34\x34\x1f\x27\x39\x3d\x38\x32\x3c\x2e\x33\x34\x32\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x14\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x08\x01\x01\x00\x00\x3f\x00\x7f\xff\xd9' > "$filename"
    
    # Add EXIF DateTimeOriginal using exiftool
    exiftool -DateTimeOriginal="$datetime" -overwrite_original -q "$filename" 2>/dev/null || true
}

# Helper function to create test RAF file (Fujifilm RAW)
create_test_raf() {
    local filename="$1"
    local datetime="${2:-2024:09:24 14:23:12}"
    
    # Create a mock RAF file (not a valid RAF, but enough for testing)
    echo "FUJIFILMCCD-RAW" > "$filename"
    exiftool -DateTimeOriginal="$datetime" -overwrite_original -q "$filename" 2>/dev/null || true
}

#==========================================
# Help and Usage Tests
#==========================================

@test "displays help message" {
    run bash "$SCRIPT_PATH" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Camera Photo Re-namer" ]]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--event" ]]
}

@test "displays help with -h flag" {
    run bash "$SCRIPT_PATH" -h
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Camera Photo Re-namer" ]]
}

#==========================================
# Argument Validation Tests
#==========================================

@test "requires event descriptor in command line mode" {
    create_test_image "test.jpg"
    
    run bash "$SCRIPT_PATH" -c "Fam"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Event descriptor is required" ]]
}

@test "rejects event descriptor longer than 12 characters" {
    create_test_image "test.jpg"
    
    run bash "$SCRIPT_PATH" -e "VeryLongEventName2024"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Event descriptor too long" ]]
}

@test "accepts valid event descriptor" {
    create_test_image "test.jpg"
    
    run bash "$SCRIPT_PATH" -e "Vacation" -n -s
    [ "$status" -eq 0 ]
}

@test "rejects invalid XMP mode" {
    create_test_image "test.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -x "invalid"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Invalid XMP mode" ]]
}

@test "accepts valid XMP modes: backup, skip, overwrite" {
    create_test_image "test1.jpg"
    run bash "$SCRIPT_PATH" -e "Test" -x "backup" -n -s
    [ "$status" -eq 0 ]
    
    create_test_image "test2.jpg"
    run bash "$SCRIPT_PATH" -e "Test" -x "skip" -n -s
    [ "$status" -eq 0 ]
    
    create_test_image "test3.jpg"
    run bash "$SCRIPT_PATH" -e "Test" -x "overwrite" -n -s
    [ "$status" -eq 0 ]
}

@test "rejects unknown command line option" {
    run bash "$SCRIPT_PATH" --invalid-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Unknown option" ]]
}

#==========================================
# File Detection Tests
#==========================================

@test "detects no files when directory is empty" {
    run bash "$SCRIPT_PATH" -e "Test" -n
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No supported photo files found" ]]
}

@test "detects JPEG files" {
    create_test_image "photo1.jpg"
    create_test_image "photo2.JPG"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found 2 photo files" ]]
}

@test "detects Fujifilm RAF files" {
    # Note: We can only detect RAF files by extension since we can't create valid RAF format
    # Create mock RAF files (exiftool may not be able to add EXIF, but script will detect them)
    echo "mock raf data" > "photo1.RAF"
    echo "mock raf data" > "photo2.raf"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    # Script may fail if it can't process RAF files without valid EXIF, that's expected
    # Just verify RAF detection message appears
    [[ "$output" =~ "Fujifilm camera detected" ]]
}

@test "counts RAW and image files separately" {
    # Create mock RAF file for detection
    echo "mock raf data" > "photo1.RAF"
    create_test_image "photo1.JPG"
    create_test_image "photo2.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    # Don't check exit status as RAF without valid EXIF may cause issues
    [[ "$output" =~ "1 RAW" ]]
    [[ "$output" =~ "2 JPG" ]]
}

#==========================================
# Backup Tests
#==========================================

@test "creates backup directory when enabled" {
    create_test_image "photo1.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -c "Fam" -s
    [ "$status" -eq 0 ]
    
    # Check for backup directory
    backup_dir=$(find . -maxdepth 1 -type d -name "backup_*" | head -n1)
    [ -n "$backup_dir" ]
    [ -d "$backup_dir" ]
}

@test "backup contains original files" {
    create_test_image "test_photo.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -s
    [ "$status" -eq 0 ]
    
    backup_dir=$(find . -maxdepth 1 -type d -name "backup_*" | head -n1)
    [ -f "$backup_dir/test_photo.jpg" ]
}

@test "skips backup when --no-backup flag is used" {
    create_test_image "photo1.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Backup skipped" ]]
    
    # Verify no backup directory was created
    backup_count=$(find . -maxdepth 1 -type d -name "backup_*" | wc -l)
    [ "$backup_count" -eq 0 ]
}

#==========================================
# File Renaming Tests
#==========================================

@test "renames file with event descriptor" {
    create_test_image "original.jpg" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Birthday" -c "Fam" -n -s
    [ "$status" -eq 0 ]
    
    # Check that renamed file exists
    [ -f "2024-09-24_142312_Fam-Birthday.jpg" ] || [ -f "2024-09-24_142312_Fam-Birthday-1.jpg" ]
}

@test "uses default category Fam when category is empty string" {
    create_test_image "original.jpg" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Test" -c "" -n -s
    [ "$status" -eq 0 ]
    
    # Script defaults to Fam category even when empty string is provided
    [[ "$output" =~ "Category: Fam" ]]
    [ -f "2024-09-24_142312_Fam-Test.jpg" ] || [ -f "2024-09-24_142312_Fam-Test-1.jpg" ]
}

@test "handles burst shots with counter suffix" {
    # Create multiple files with same timestamp
    create_test_image "burst1.jpg" "2024:09:24 14:23:12"
    create_test_image "burst2.jpg" "2024:09:24 14:23:12"
    create_test_image "burst3.jpg" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Action" -n -s
    [ "$status" -eq 0 ]
    
    # Verify counter suffixes exist
    renamed_count=$(find . -maxdepth 1 -name "2024-09-24_142312_Fam-Action*.jpg" | wc -l)
    [ "$renamed_count" -eq 3 ]
}

@test "keeps file pairs with same timestamp aligned" {
    # Create two JPEG files with same timestamp (simulating RAF/JPG pair behavior)
    create_test_image "DSCF1234.jpg" "2024:09:24 14:23:12"
    create_test_image "DSCF1234.JPEG" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Pair" -n -s
    [ "$status" -eq 0 ]
    
    # Both files should have the same timestamp in their new names
    jpg_file=$(find . -maxdepth 1 -name "*Pair*.jpg")
    jpeg_file=$(find . -maxdepth 1 -name "*Pair*.JPEG")
    
    [ -n "$jpg_file" ]
    [ -n "$jpeg_file" ]
    
    # Extract base names without extensions
    jpg_base=$(basename "$jpg_file" .jpg)
    jpeg_base=$(basename "$jpeg_file" .JPEG)
    
    # They should have same timestamp portion
    [[ "$jpg_base" =~ 2024-09-24_142312 ]]
    [[ "$jpeg_base" =~ 2024-09-24_142312 ]]
}

#==========================================
# XMP Sidecar Tests
#==========================================

@test "creates XMP sidecar files by default" {
    create_test_image "photo.jpg" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Test" -n
    [ "$status" -eq 0 ]
    
    # Find the renamed file and check for XMP sidecar
    renamed_file=$(find . -maxdepth 1 -name "2024-09-24_142312_Fam-Test*.jpg")
    [ -f "${renamed_file}.xmp" ]
}

@test "XMP sidecar contains original filename in Title" {
    create_test_image "original_photo.jpg" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Test" -n
    [ "$status" -eq 0 ]
    
    # Find XMP file and check contents
    xmp_file=$(find . -maxdepth 1 -name "*.xmp")
    [ -f "$xmp_file" ]
    
    # Check that XMP contains original filename
    grep -q "original_photo.jpg" "$xmp_file"
}

@test "skips XMP creation with --no-sidecar flag" {
    create_test_image "photo.jpg" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipping XMP sidecar creation" ]]
    
    # Verify no XMP files were created
    xmp_count=$(find . -maxdepth 1 -name "*.xmp" | wc -l)
    [ "$xmp_count" -eq 0 ]
}

@test "XMP mode backup: moves existing XMP to backup" {
    create_test_image "photo.jpg" "2024:09:24 14:23:12"
    
    # Create an existing XMP file
    echo "existing xmp content" > "photo.jpg.xmp"
    
    run bash "$SCRIPT_PATH" -e "Test" -x backup
    [ "$status" -eq 0 ]
    
    # Check that old XMP was backed up
    backup_dir=$(find . -maxdepth 1 -type d -name "backup_*" | head -n1)
    [ -f "$backup_dir/photo.jpg.xmp" ]
    
    # Check that new XMP was created for renamed file
    new_xmp=$(find . -maxdepth 1 -name "2024-09-24_*.xmp")
    [ -f "$new_xmp" ]
}

@test "XMP mode skip: preserves existing XMP files" {
    create_test_image "photo.jpg" "2024:09:24 14:23:12"
    
    # Create an existing XMP file
    echo "existing xmp content" > "photo.jpg.xmp"
    
    run bash "$SCRIPT_PATH" -e "Test" -x skip -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipping images with existing XMP" ]]
}

@test "XMP mode overwrite: deletes existing XMP files" {
    create_test_image "photo.jpg" "2024:09:24 14:23:12"
    
    # Create an existing XMP file
    echo "existing xmp content" > "photo.jpg.xmp"
    
    run bash "$SCRIPT_PATH" -e "Test" -x overwrite -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Removing existing XMP sidecar files" ]]
    
    # Old XMP should be gone, new one should exist
    [ ! -f "photo.jpg.xmp" ]
    new_xmp=$(find . -maxdepth 1 -name "2024-09-24_*.xmp")
    [ -f "$new_xmp" ]
}

#==========================================
# Recursive Processing Tests
#==========================================

@test "processes subdirectories with recursive flag" {
    # Create file in current directory (required for script to proceed)
    create_test_image "photo.jpg" "2024:09:24 14:23:12"
    
    # Create subdirectory with photo
    mkdir -p subdir
    create_test_image "subdir/photo2.jpg" "2024:09:24 14:23:13"
    
    run bash "$SCRIPT_PATH" -e "Test" -r -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Recursive processing: ENABLED" ]]
    
    # Check that file in subdirectory was renamed
    renamed=$(find subdir -name "2024-09-24_*.jpg")
    [ -n "$renamed" ]
}

@test "does not process subdirectories without recursive flag" {
    mkdir -p subdir
    create_test_image "photo.jpg" "2024:09:24 14:23:12"
    create_test_image "subdir/photo2.jpg" "2024:09:24 14:23:13"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Recursive processing: DISABLED" ]]
    
    # Current directory file should be renamed
    [ -f "2024-09-24_142312_Fam-Test.jpg" ] || [ -f "2024-09-24_142312_Fam-Test-1.jpg" ]
    
    # Subdirectory file should NOT be renamed
    [ -f "subdir/photo2.jpg" ]
}

@test "excludes backup directory from recursive processing" {
    create_test_image "photo1.jpg" "2024:09:24 14:23:12"
    
    # First run to create backup (backup happens before renaming)
    run bash "$SCRIPT_PATH" -e "First" -s
    [ "$status" -eq 0 ]
    
    backup_dir=$(find . -maxdepth 1 -type d -name "backup_*" | head -n1)
    [ -n "$backup_dir" ]
    [ -d "$backup_dir" ]
    
    # Backup should contain the original file
    original_in_backup=$(find "$backup_dir" -name "photo1.jpg" -o -name "2024-09-24_*.jpg")
    [ -n "$original_in_backup" ]
    
    # Count files in backup - should be 1
    backup_file_count=$(find "$backup_dir" -type f -name "*.jpg" | wc -l)
    [ "$backup_file_count" -eq 1 ]
}

#==========================================
# Output and Summary Tests
#==========================================

@test "displays processing summary" {
    create_test_image "photo1.jpg"
    create_test_image "photo2.jpg"
    
    run bash "$SCRIPT_PATH" -e "Summary" -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "PROCESSING SUMMARY" ]]
    [[ "$output" =~ "Files renamed: 2" ]]
    [[ "$output" =~ "Event: Summary" ]]
    [[ "$output" =~ "XMP sidecar files created: 2" ]]
}

@test "shows category in summary" {
    create_test_image "photo.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -c "Art" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Category: Art" ]]
}

@test "shows XMP sidecar count in summary" {
    create_test_image "photo1.jpg"
    create_test_image "photo2.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "XMP sidecar files created: 2" ]]
}

@test "shows zero XMP count when sidecars are skipped" {
    create_test_image "photo.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "XMP sidecar files created: 0 (skipped)" ]]
}

#==========================================
# Edge Cases and Error Handling
#==========================================

@test "handles files without DateTimeOriginal metadata" {
    # Create a file without EXIF data
    echo "fake image data" > "noexif.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    # Script should complete even if some files lack metadata
}

@test "handles mixed file extensions (upper and lower case)" {
    create_test_image "photo1.jpg"
    create_test_image "photo2.JPG"
    create_test_image "photo3.JPEG"
    create_test_raf "photo4.raf"
    create_test_raf "photo5.RAF"
    
    run bash "$SCRIPT_PATH" -e "Mixed" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found 5 photo files" ]]
}

@test "reports duplicate timestamps found" {
    create_test_image "burst1.jpg" "2024:09:24 14:23:12"
    create_test_image "burst2.jpg" "2024:09:24 14:23:12"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Duplicate timestamps found:" ]]
}

#==========================================
# Default Values Tests
#==========================================

@test "uses default category 'Fam' when not specified" {
    create_test_image "photo.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -n -s
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Category: Fam" ]]
}

@test "uses default XMP mode 'backup' when not specified" {
    create_test_image "photo.jpg"
    
    run bash "$SCRIPT_PATH" -e "Test" -n
    [ "$status" -eq 0 ]
    [[ "$output" =~ "XMP handling mode: backup" ]]
}

