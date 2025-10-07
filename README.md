# Camera Photo Re-namer

A fast, cross-camera photo renamer powered by ExifTool. It safely renames RAW/JPEG/HEIF/PNG/TIFF/WebP photos using EXIF DateTimeOriginal and appends a counter for burst shots. Optionally prefixes filenames with a category and event, and creates XMP sidecars embedding the original filename in `XMP:Title` for traceability.

## Features

- **Multi-brand support**: RAF, CR2, NEF, ARW, ORF, RW2, PEF, DNG, JPG/JPEG, HEIC/HEIF, PNG, TIFF/TIF, WebP
- **Smart renaming**: `YYYY-MM-DD_HHMMSS[_Category]-Event[-c].ext` using `DateTimeOriginal` with a counter for duplicates
- **Pair-aware**: Keeps RAW/JPEG (e.g., Fujifilm SOOC) pairs aligned by timestamp and extension
- **XMP sidecars**: Writes original filename into `XMP:Title`
- **Backups**: Optional full backup with directory structure preserved
- **Interactive backup progress**: Live percentage shown while copying files (interactive mode)
- **Recursive mode**: Optionally process subdirectories
- **Clean output**: All output goes to stdout/stderr - redirect to file if logging desired

## Requirements

- **ExifTool** in your `PATH` (`exiftool -ver` should work)
- Bash shell (macOS/Linux by default; on Windows use WSL or Git Bash)

## Installation

No install needed. Clone/download this repository.

```bash
chmod +x camera_photo_renamer.sh
```

## Usage

### Interactive Mode

Run the script in the directory containing your photos (or at a parent directory if using recursive mode).

```bash
./camera_photo_renamer.sh
```

You will be prompted for:

- **Recursive processing**: Include subdirectories (default: No)
- **Backup creation**: Create a timestamped backup folder (default: Yes). In interactive mode, a live progress percentage is shown during the backup copy.
- **Category**: Optional prefix like `Fam`, `Street`, `Art` (default: `Fam` if enabled)
- **Event**: Short descriptor (1–3 words, no spaces, max 12 chars)
- **XMP sidecars**: Whether to create XMP sidecar files (default: Yes). Choose No to skip creating sidecars this run.

### Command Line Mode

For automation or batch processing, you can specify options directly:

```bash
./camera_photo_renamer.sh [OPTIONS]
```

**Options:**
- `-e, --event EVENT` - Event descriptor (1-3 words, no spaces, max 12 chars) [required]
- `-c, --category CATEGORY` - Category prefix (Fam, Street, Art, etc.) [default: Fam]
- `-r, --recursive` - Process subdirectories recursively [default: false]
- `-n, --no-backup` - Skip backup creation [default: backup enabled]
- `-x, --xmp-mode MODE` - XMP handling: backup, skip, overwrite [default: backup]
- `-s, --no-sidecar` - Do not create XMP sidecar files (CLI mode)
- `-h, --help` - Show help message

Note:
- If `--no-sidecar` is specified, no XMP files are created and `--xmp-mode` is ignored.

**Examples:**
```bash
# Basic usage with event only
./camera_photo_renamer.sh -e "Vacation2024"

# Full options with category, recursive processing
./camera_photo_renamer.sh -e "Wedding" -c "Art" -r

# Skip backup creation
./camera_photo_renamer.sh --event "Street" --category "Photo" --no-backup

# Handle existing XMP files safely (backup existing ones)
./camera_photo_renamer.sh -e "Portrait" --xmp-mode backup

# Skip images that already have XMP files
./camera_photo_renamer.sh -e "Landscape" --xmp-mode skip

# Overwrite existing XMP files (original behavior)
./camera_photo_renamer.sh -e "Event" --xmp-mode overwrite

# Show help
./camera_photo_renamer.sh --help
```

Resulting filenames look like:

```text
2025-09-24_142312_Fam-Birthday-1.RAF
2025-09-24_142312_Fam-Birthday-1.JPG
2025-09-24_142313_Fam-Birthday.RAF
```

Notes:

- The `-1`, `-2`, ... suffix appears when multiple files share the same `DateTimeOriginal` (common in bursts).
- An XMP sidecar is created per file (e.g., `photo.RAF.xmp`) with `XMP:Title = "Original: <old-filename>"`.

### XMP Sidecar Handling

The script provides an optional XMP sidecar step (interactive prompt, default Yes). When enabled, it uses one of three modes for handling existing XMP sidecar files:

- **`backup`** (default): Moves existing XMP files to the backup directory before creating new ones. This preserves any existing metadata while ensuring the new filename information is added.
- **`skip`**: Skips creating XMP files for images that already have them. Useful when you want to preserve existing XMP metadata completely.
- **`overwrite`**: Deletes existing XMP files and creates new ones (original behavior). Use with caution as this will permanently remove existing metadata.

## Supported Formats

- RAW: `RAF CR2 NEF ARW ORF RW2 PEF DNG`
- Images: `JPG JPEG HEIC HEIF PNG TIFF TIF WebP`

## Windows Tips

- Use **WSL** (Ubuntu) or **Git Bash** to run the script.
- Install ExifTool (e.g., `sudo apt install libimage-exiftool-perl` in WSL) and ensure `exiftool` is in `PATH`.

## Safety and Logging

- Backups are optional but recommended. When enabled, the script copies supported files to a folder like `backup_YYYYMMDD_HHMMSS/`, preserving subdirectory structure.
- All output goes to stdout/stderr. To log to a file, redirect the output:
  ```bash
  # Log everything to a file
  ./camera_photo_renamer.sh -e "Vacation2024" > rename.log 2>&1
  
  # Log only errors to a file
  ./camera_photo_renamer.sh -e "Vacation2024" 2> errors.log
  ```

## Recommended Workflow

- **1. Pre-sort by category**: Use a photo manager like XnView MP or an EXIF-aware tool (e.g., ExifTool GUI) to review and move images into category folders (e.g., `Fam/`, `Street/`, `Art/`). This step helps you apply meaningful categories consistently.
- **2. Rename per category**: In each category folder, run the script to rename files with the desired `Category` and `Event`. This keeps timestamps and counters consistent within that context and preserves RAW/JPEG pairs.
- **3. Merge back to a main library**: After renaming each category, copy or move all renamed files into your main photo library folder. Because names include timestamp, category, event, and a counter, collisions are avoided.
- Optional: Keep the generated XMP sidecars alongside files so the original filenames are always retained in metadata.

## Limitations

- Files missing `DateTimeOriginal` are renamed using the current scheme but may rely on fallback behavior; sidecars will still note the original filename.
- If multiple files share identical timestamps without subseconds, the `-c` counter ensures uniqueness but chronological order within the same second may vary by filesystem listing.

## Testing

The project includes a comprehensive test suite using Bats (Bash Automated Testing System).

### Install Bats

**macOS:**
```bash
brew install bats-core
```

**Linux/WSL:**
```bash
sudo apt-get install bats
```

### Run Tests

```bash
# Quick test run (recommended)
./run_tests.sh

# Run with verbose output
./run_tests.sh -v

# Run specific test pattern
./run_tests.sh -f "XMP"

# Or use bats directly
bats test/camera_photo_renamer.bats
bats test/camera_photo_renamer.bats --verbose-run
bats test/camera_photo_renamer.bats -f "displays help message"
```

See [test/README.md](test/README.md) for detailed testing documentation.

## Contributing

Issues and pull requests are welcome. Please keep changes focused and include a brief description of the use case.

**Before submitting:**
1. Run the test suite: `bats test/camera_photo_renamer.bats`
2. Add tests for new features
3. Ensure all tests pass

## License

MIT — see [LICENSE](https://github.com/Jmartgraphix/camera_photo_renamer/blob/main/LICENSE) for details.

## Related Projects

* [Camera Movie Re-namer](https://github.com/Jmartgraphix/camera_movie_renamer) - Similar tool for movie/video files (MP4/MOV/AVI/MTS/etc.)