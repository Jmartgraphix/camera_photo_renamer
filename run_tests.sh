#!/usr/bin/env bash

# Camera Photo Re-namer Test Runner
# Quick script to run tests with various options

set -e

echo "========================================"
echo "  Camera Photo Re-namer Test Suite"
echo "========================================"
echo

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo "Error: Bats is not installed"
    echo "Install with: brew install bats-core (macOS) or sudo apt-get install bats (Linux)"
    exit 1
fi

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
    echo "Error: ExifTool is not installed"
    echo "Install with: brew install exiftool (macOS) or sudo apt-get install libimage-exiftool-perl (Linux)"
    exit 1
fi

# Parse command line arguments
VERBOSE=""
FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="--verbose-run"
            shift
            ;;
        -f|--filter)
            FILTER="-f $2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-v|--verbose] [-f|--filter <pattern>]"
            exit 1
            ;;
    esac
done

# Run tests
echo "Running tests..."
echo

if [ -n "$FILTER" ]; then
    bats test/camera_photo_renamer.bats $FILTER $VERBOSE
else
    bats test/camera_photo_renamer.bats $VERBOSE
fi

echo
echo "========================================"
echo "  Test run completed successfully!"
echo "========================================"


