#!/bin/bash

# Camera Photo Re-namer — supports multiple camera brands and formats.
# Handles RAF/JPG pairs (Fujifilm SOOC), standalone RAW files, and JPG files.
# Creates XMP sidecars with the original filename stored in XMP:Title.
# Uses DateTimeOriginal with a counter (-c) to disambiguate burst shots.
# Run in the target directory. Requires ExifTool in PATH. Logs to rename_log.txt.
#
# Usage:
#   Interactive mode: ./camera_photo_renamer.sh
#   Command line mode: ./camera_photo_renamer.sh [OPTIONS]
#
# Options:
#   -e, --event EVENT        Event descriptor (1-3 words, no spaces, max 12 chars) [required]
#   -c, --category CATEGORY  Category prefix (Fam, Street, Art, etc.) [default: Fam]
#   -r, --recursive          Process subdirectories recursively [default: false]
#   -n, --no-backup          Skip backup creation [default: backup enabled]
#   -h, --help               Show this help message

# Help function
show_help() {
    echo "Camera Photo Re-namer v1.0"
    echo "Usage:"
    echo "  Interactive mode: $0"
    echo "  Command line mode: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -e, --event EVENT        Event descriptor (1-3 words, no spaces, max 12 chars) [required]"
    echo "  -c, --category CATEGORY  Category prefix (Fam, Street, Art, etc.) [default: Fam]"
    echo "  -r, --recursive          Process subdirectories recursively [default: false]"
    echo "  -n, --no-backup          Skip backup creation [default: backup enabled]"
    echo "  -h, --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -e \"Vacation2024\" -c \"Fam\" -r"
    echo "  $0 --event \"Wedding\" --category \"Art\" --no-backup"
    echo "  $0 -e \"Street\""
    exit 0
}

# Check ExifTool availability.
if ! command -v exiftool &> /dev/null; then
    echo "Error: ExifTool is not installed or not in PATH"
    echo "Please install ExifTool: https://exiftool.org/"
    exit 1
fi

# Initialize command line variables
EVENT=""
CATEGORY=""
RECURSIVE=""
NO_BACKUP=""
INTERACTIVE_MODE=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--event)
            EVENT="$2"
            INTERACTIVE_MODE=false
            shift 2
            ;;
        -c|--category)
            CATEGORY="$2"
            INTERACTIVE_MODE=false
            shift 2
            ;;
        -r|--recursive)
            RECURSIVE="y"
            INTERACTIVE_MODE=false
            shift
            ;;
        -n|--no-backup)
            NO_BACKUP="y"
            INTERACTIVE_MODE=false
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate command line arguments
if [[ "$INTERACTIVE_MODE" == "false" ]]; then
    if [[ -z "$EVENT" ]]; then
        echo "Error: Event descriptor is required in command line mode"
        echo "Use -e or --event to specify the event descriptor"
        echo "Use -h or --help for usage information"
        exit 1
    fi
    
    if [[ ${#EVENT} -gt 12 ]]; then
        echo "Error: Event descriptor too long (>12 chars)"
        echo "Use -h or --help for usage information"
        exit 1
    fi
    
    # Set defaults for command line mode
    if [[ -z "$CATEGORY" ]]; then
        CATEGORY="Fam"
    fi
fi

# Print header.
echo "========================================"
echo "      Camera Photo Re-namer v1.0"
echo "         Author: Jason K. Martin"
echo "            Date: 2025-09-24"
echo "========================================"
echo

# Initialize log file.
logfile="rename_log.txt"
echo "Starting universal rename process at $(date)" > "$logfile"

# Supported file extensions.
SUPPORTED_RAW="RAF CR2 NEF ARW ORF RW2 PEF DNG"
SUPPORTED_JPG="JPG JPEG HEIC HEIF PNG TIFF TIF"

# Initialize counters.
file_count=0
raw_count=0
jpg_count=0

# Count files by type.
for ext in $SUPPORTED_RAW; do
    count=$(find . -maxdepth 1 -type f -iname "*.$ext" -o -iname "*.$ext" | wc -l)
    raw_count=$((raw_count + count))
done

for ext in $SUPPORTED_JPG; do
    count=$(find . -maxdepth 1 -type f -iname "*.$ext" -o -iname "*.$ext" | wc -l)
    jpg_count=$((jpg_count + count))
done

file_count=$((raw_count + jpg_count))

if [ "$file_count" -eq 0 ]; then
    echo "Error: No supported photo files found in current directory"
    echo "Supported formats: $SUPPORTED_RAW $SUPPORTED_JPG"
    echo "Error: No supported photo files found in current directory" >> "$logfile"
    exit 1
fi

echo "Found $file_count photo files to process ($raw_count RAW, $jpg_count JPG)"
echo "File count: $file_count ($raw_count RAW, $jpg_count JPG)" >> "$logfile"

# Handle recursive processing
if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    # Ask about recursive processing (default: No).
    read -p "Process subdirectories recursively? [y/N] " recursive
    recursive=${recursive:-n}
else
    # Use command line argument
    recursive="$RECURSIVE"
fi

if [[ "$recursive" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    recursive_flag="-r"
    echo "Recursive processing: ENABLED" | tee -a "$logfile"
    # Recount files including subdirectories for accurate count.
    file_count=0
    raw_count=0
    jpg_count=0
    
    for ext in $SUPPORTED_RAW; do
        count=$(find . -type f -iname "*.$ext" | wc -l)
        raw_count=$((raw_count + count))
    done
    
    for ext in $SUPPORTED_JPG; do
        count=$(find . -type f -iname "*.$ext" | wc -l)
        jpg_count=$((jpg_count + count))
    done
    
    file_count=$((raw_count + jpg_count))
    echo "Total files including subdirectories: $file_count ($raw_count RAW, $jpg_count JPG)"
    echo "Total files including subdirectories: $file_count ($raw_count RAW, $jpg_count JPG)" >> "$logfile"
else
    recursive_flag=""
    echo "Recursive processing: DISABLED" | tee -a "$logfile"
fi

# Detect camera types.
echo "Detecting camera types..."
fujifilm_count=0
sony_count=0
nikon_count=0
canon_count=0
olympus_count=0
other_count=0

if [[ "$recursive" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    # Check for camera files — recursive.
    fujifilm_count=$(find . -type f -iname "*.RAF" | wc -l)
    sony_count=$(find . -type f -iname "*.ARW" | wc -l)
    nikon_count=$(find . -type f -iname "*.NEF" | wc -l)
    canon_count=$(find . -type f -iname "*.CR2" | wc -l)
    olympus_count=$(find . -type f -iname "*.ORF" | wc -l)
    other_formats=$(find . -type f \( -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" \) | wc -l)
else
    # Check for camera files — current directory only.
    fujifilm_count=$(find . -maxdepth 1 -type f -iname "*.RAF" | wc -l)
    sony_count=$(find . -maxdepth 1 -type f -iname "*.ARW" | wc -l)
    nikon_count=$(find . -maxdepth 1 -type f -iname "*.NEF" | wc -l)
    canon_count=$(find . -maxdepth 1 -type f -iname "*.CR2" | wc -l)
    olympus_count=$(find . -maxdepth 1 -type f -iname "*.ORF" | wc -l)
    other_formats=$(find . -maxdepth 1 -type f \( -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" \) | wc -l)
fi

# Report detected camera types.
if [ "$fujifilm_count" -gt 0 ]; then
    echo "- Fujifilm camera detected ($fujifilm_count RAF files)"
    echo "- Fujifilm camera detected ($fujifilm_count RAF files)" >> "$logfile"
fi
if [ "$sony_count" -gt 0 ]; then
    echo "- Sony camera detected ($sony_count ARW files)"
    echo "- Sony camera detected ($sony_count ARW files)" >> "$logfile"
fi
if [ "$nikon_count" -gt 0 ]; then
    echo "- Nikon camera detected ($nikon_count NEF files)"
    echo "- Nikon camera detected ($nikon_count NEF files)" >> "$logfile"
fi
if [ "$canon_count" -gt 0 ]; then
    echo "- Canon camera detected ($canon_count CR2 files)"
    echo "- Canon camera detected ($canon_count CR2 files)" >> "$logfile"
fi
if [ "$olympus_count" -gt 0 ]; then
    echo "- Olympus camera detected ($olympus_count ORF files)"
    echo "- Olympus camera detected ($olympus_count ORF files)" >> "$logfile"
fi
if [ "$other_formats" -gt 0 ]; then
    echo "- Other camera format detected ($other_formats files)"
    echo "- Other camera format detected ($other_formats files)" >> "$logfile"
fi

# Handle backup option
if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    # Ask about backup (default: Yes).
    read -p "Create backup before processing? [Y/n] " backup
    backup=${backup:-y}
else
    # Use command line argument
    if [[ "$NO_BACKUP" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
        backup="n"
    else
        backup="y"
    fi
fi

if [[ "$backup" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir "$backup_dir"
    
    if [[ "$recursive" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
        # Backup all files, including subdirectories, preserving structure.
        find . -type f \( -iname "*.RAF" -o -iname "*.CR2" -o -iname "*.NEF" -o -iname "*.ARW" -o -iname "*.ORF" -o -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" -o -iname "*.JPG" -o -iname "*.JPEG" -o -iname "*.HEIC" -o -iname "*.HEIF" -o -iname "*.PNG" -o -iname "*.TIFF" -o -iname "*.TIF" \) -not -path "./backup_*" | while read -r file; do
            # Create directory structure in backup
            file_dir=$(dirname "$file")
            if [ "$file_dir" != "." ]; then
                mkdir -p "$backup_dir/$file_dir"
                cp "$file" "$backup_dir/$file"
            else
                cp "$file" "$backup_dir/"
            fi
        done
        echo "Backup created in: $backup_dir (including subdirectories with preserved structure)" | tee -a "$logfile"
    else
        # Backup current directory only.
        find . -maxdepth 1 -type f \( -iname "*.RAF" -o -iname "*.CR2" -o -iname "*.NEF" -o -iname "*.ARW" -o -iname "*.ORF" -o -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" -o -iname "*.JPG" -o -iname "*.JPEG" -o -iname "*.HEIC" -o -iname "*.HEIF" -o -iname "*.PNG" -o -iname "*.TIFF" -o -iname "*.TIF" \) -exec cp {} "$backup_dir/" \;
        echo "Backup created in: $backup_dir (current directory only)" | tee -a "$logfile"
    fi
else
    echo "Backup skipped" >> "$logfile"
fi

# Handle category prefix
if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    # Ask about category (default: use it).
    read -p "Use category? [Y/n] " use_category
    use_category=${use_category:-y}
    if [[ "$use_category" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
        read -p "Enter category (Fam, Street, Art, etc., default Fam): " category
        category=${category:-Fam}
    else
        category=""
    fi
else
    # Use command line argument
    if [[ -n "$CATEGORY" ]]; then
        category="$CATEGORY"
    else
        category=""
    fi
fi
echo "Category: ${category:-"(none)"}" >> "$logfile"

# Handle event descriptor
if [[ "$INTERACTIVE_MODE" == "true" ]]; then
    # Prompt for event descriptor (1–3 words, no spaces, max 12 chars).
    read -p "Enter event descriptor (1-3 words, no spaces, max 12 chars): " event
    if [[ ${#event} -gt 12 ]]; then
        echo "Error: Event descriptor too long (>12 chars). Exiting." | tee -a "$logfile"
        exit 1
    fi
else
    # Use command line argument
    event="$EVENT"
fi
echo "Event: $event" >> "$logfile"

# Estimate burst shots via duplicate DateTimeOriginal timestamps.
if [[ "$recursive" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    duplicate_count=$(exiftool -ext RAF -ext CR2 -ext NEF -ext ARW -ext ORF -ext RW2 -ext PEF -ext DNG -ext JPG -ext JPEG -ext HEIC -ext HEIF -r . -DateTimeOriginal -s3 | sort | uniq -c | awk '$1 > 1' | wc -l)
else
    duplicate_count=$(exiftool -ext RAF -ext CR2 -ext NEF -ext ARW -ext ORF -ext RW2 -ext PEF -ext DNG -ext JPG -ext JPEG -ext HEIC -ext HEIF . -DateTimeOriginal -s3 | sort | uniq -c | awk '$1 > 1' | wc -l)
fi
echo "Duplicate timestamps found: $duplicate_count" >> "$logfile"

# Note about timestamp-based naming and burst counter.
echo "Note: Using DateTimeOriginal with counter for burst shots and unique identification." >> "$logfile"

# Remove existing XMP sidecars.
echo "Removing existing XMP sidecar files..." >> "$logfile"
if [[ "$recursive" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    find . -iname "*.xmp" -type f -not -path "./backup_*" -delete 2>>"$logfile"
else 
    find . -maxdepth 1 -iname "*.xmp" -type f -not -path "./backup_*" -delete 2>>"$logfile"
fi

# Create a mapping file keyed by DateTimeOriginal for reliable matching.
echo "Creating filename mapping using EXIF DateTimeOriginal..." >> "$logfile"
temp_mapping="/tmp/filename_mapping_$$"

# Build mapping of DateTimeOriginal to original filenames before renaming.
# Exclude backup directories from processing.
if [[ "$recursive" =~ ^[Yy][Ee][Ss]$ ]]; then
    find . -type f \( -iname "*.RAF" -o -iname "*.CR2" -o -iname "*.NEF" -o -iname "*.ARW" -o -iname "*.ORF" -o -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" -o -iname "*.JPG" -o -iname "*.JPEG" -o -iname "*.HEIC" -o -iname "*.HEIF" -o -iname "*.PNG" -o -iname "*.TIFF" -o -iname "*.TIF" \) -not -path "./backup_*" | while read -r file; do
        datetime=$(exiftool -DateTimeOriginal -s3 "$file" 2>/dev/null)
        original_name=$(basename "$file")
        if [ -n "$datetime" ]; then
            echo "$datetime|$original_name" >> "$temp_mapping"
        fi
    done
else
    find . -maxdepth 1 -type f \( -iname "*.RAF" -o -iname "*.CR2" -o -iname "*.NEF" -o -iname "*.ARW" -o -iname "*.ORF" -o -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" -o -iname "*.JPG" -o -iname "*.JPEG" -o -iname "*.HEIC" -o -iname "*.HEIF" -o -iname "*.PNG" -o -iname "*.TIFF" -o -iname "*.TIF" \) -not -path "./backup_*" | while read -r file; do
        datetime=$(exiftool -DateTimeOriginal -s3 "$file" 2>/dev/null)
        original_name=$(basename "$file")
        if [ -n "$datetime" ]; then
            echo "$datetime|$original_name" >> "$temp_mapping"
        fi
    done
fi

# Temporarily move backup directories to avoid processing them.
temp_backup_dir=""
if [[ "$backup" =~ ^([Yy]|[Yy][Ee][Ss])$ ]] && [ -d "$backup_dir" ]; then
    temp_backup_dir="/tmp/backup_move_$$"
    mv "$backup_dir" "$temp_backup_dir"
    echo "Temporarily moved backup directory to prevent processing: $temp_backup_dir" >> "$logfile"
fi

# Build rename expression (with or without category).
if [ -n "$category" ]; then
    rename_expr='-FileName<${DateTimeOriginal}_'"$category"'-'"$event"'%-c.%e'
else
    rename_expr='-FileName<${DateTimeOriginal}_'"$event"'%-c.%e'
fi

# Rename with DateTimeOriginal and a counter for duplicates.
echo "Renaming files with DateTimeOriginal and counter for burst shots..." | tee -a "$logfile"
if [[ "$recursive" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    exiftool -d %Y-%m-%d_%H%M%S "$rename_expr" -ext RAF -ext CR2 -ext NEF -ext ARW -ext ORF -ext RW2 -ext PEF -ext DNG -ext JPG -ext JPEG -ext HEIC -ext HEIF -ext PNG -ext TIFF -ext TIF -r . -q 2>>"$logfile"
else
    exiftool -d %Y-%m-%d_%H%M%S "$rename_expr" -ext RAF -ext CR2 -ext NEF -ext ARW -ext ORF -ext RW2 -ext PEF -ext DNG -ext JPG -ext JPEG -ext HEIC -ext HEIF -ext PNG -ext TIFF -ext TIF . -q 2>>"$logfile"
fi

# Restore backup directory to original location.
if [ -n "$temp_backup_dir" ] && [ -d "$temp_backup_dir" ]; then
    mv "$temp_backup_dir" "$backup_dir"
    echo "Restored backup directory to original location: $backup_dir" >> "$logfile"
fi

# Create XMP sidecars with original filename metadata.
echo "Creating XMP sidecar files..." >> "$logfile"

# Collect renamed files (excluding backup directories).
if [[ "$recursive" =~ ^[Yy][Ee][Ss]$ ]]; then
    renamed_files=$(find . -type f \( -iname "*.RAF" -o -iname "*.CR2" -o -iname "*.NEF" -o -iname "*.ARW" -o -iname "*.ORF" -o -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" -o -iname "*.JPG" -o -iname "*.JPEG" -o -iname "*.HEIC" -o -iname "*.HEIF" -o -iname "*.PNG" -o -iname "*.TIFF" -o -iname "*.TIF" \) -not -path "./backup_*" | sort)
else
    renamed_files=$(find . -maxdepth 1 -type f \( -iname "*.RAF" -o -iname "*.CR2" -o -iname "*.NEF" -o -iname "*.ARW" -o -iname "*.ORF" -o -iname "*.RW2" -o -iname "*.PEF" -o -iname "*.DNG" -o -iname "*.JPG" -o -iname "*.JPEG" -o -iname "*.HEIC" -o -iname "*.HEIF" -o -iname "*.PNG" -o -iname "*.TIFF" -o -iname "*.TIF" \) -not -path "./backup_*" | sort)
fi

total_files=$(echo "$renamed_files" | wc -l)
current_file=0

echo "Found $total_files renamed files to process..."
echo "Creating XMP sidecar files..." | tee -a "$logfile"

# Write sidecars embedding original filename in XMP:Title for each file.
while IFS= read -r new_file; do
    current_file=$((current_file + 1))
    percentage=$((current_file * 100 / total_files))
    current_filename=$(basename "$new_file")
    
    # Progress output.
    printf "\rProgress: %d/%d (%d%%) - Processing: %s" "$current_file" "$total_files" "$percentage" "$current_filename"
    
    # Extract DateTimeOriginal from renamed file for matching.
    file_datetime=$(exiftool -DateTimeOriginal -s3 "$new_file" 2>/dev/null)
    
    # Match by extension to handle RAF/JPG pairs with the same timestamp.
    file_ext="${new_file##*.}"
    
    # Find original filename using DateTimeOriginal + extension matching.
    original_filename=""
    if [ -n "$file_datetime" ]; then
        # First try exact match with same file extension
        original_filename=$(grep "^$file_datetime|.*\.$file_ext$" "$temp_mapping" | cut -d'|' -f2)
        # Fallback: take first match if no extension-specific match found
        if [ -z "$original_filename" ]; then
            original_filename=$(grep "^$file_datetime|" "$temp_mapping" | head -n1 | cut -d'|' -f2)
        fi
    fi
    
    # Final fallback: use current filename if no DateTimeOriginal match.
    if [ -z "$original_filename" ]; then
        original_filename="$current_filename"
        echo "Warning: Could not match DateTimeOriginal for $new_file, using current filename" >> "$logfile"
    fi
    
    # Create XMP sidecar file containing original filename in XMP:Title.
    exiftool -XMP:Title="Original: $original_filename" -o "$new_file.xmp" "$new_file" -q 2>>"$logfile"
    if [ $? -ne 0 ]; then
        echo "Warning: XMP sidecar creation failed for $new_file" >> "$logfile"
    fi
done <<< "$renamed_files"

# Clean up temporary file.
rm -f "$temp_mapping"

echo # New line after progress counter

# Confirm sidecar creation for all supported formats.
echo "XMP sidecar files created for all supported formats." >> "$logfile"

# Display summary.
echo
echo "========================================"
echo "              PROCESSING SUMMARY"
echo "========================================"
echo "Files renamed: $total_files" | tee -a "$logfile"
echo "XMP sidecar files created: $total_files" | tee -a "$logfile"
echo "Category: $category" | tee -a "$logfile"
echo "Event: $event" | tee -a "$logfile"
echo "Recursive processing: $([[ "$recursive" =~ ^[Yy][Ee][Ss]$ ]] && echo "ENABLED" || echo "DISABLED")" | tee -a "$logfile"
if [[ "$backup" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    echo "Backup created: $backup_dir" | tee -a "$logfile"
else
    echo "Backup: Not created" | tee -a "$logfile"
fi
echo "========================================"
echo
echo "Camera rename process completed. Check $logfile for details." | tee -a "$logfile"