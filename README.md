# Camera Photo Re-namer

A fast, cross-camera photo renamer powered by ExifTool. It safely renames RAW/JPEG/HEIF/PNG/TIFF photos using EXIF DateTimeOriginal and appends a counter for burst shots. Optionally prefixes filenames with a category and event, and creates XMP sidecars embedding the original filename in `XMP:Title` for traceability.

## Features

- **Multi-brand support**: RAF, CR2, NEF, ARW, ORF, RW2, PEF, DNG, JPG/JPEG, HEIC/HEIF, PNG, TIFF/TIF
- **Smart renaming**: `YYYY-MM-DD_HHMMSS[_Category]-Event[-c].ext` using `DateTimeOriginal` with a counter for duplicates
- **Pair-aware**: Keeps RAW/JPEG (e.g., Fujifilm SOOC) pairs aligned by timestamp and extension
- **XMP sidecars**: Writes original filename into `XMP:Title`
- **Backups**: Optional full backup with directory structure preserved
- **Recursive mode**: Optionally process subdirectories
- **Logging**: Writes a detailed log to `rename_log.txt`

## Requirements

- **ExifTool** in your `PATH` (`exiftool -ver` should work)
- Bash shell (macOS/Linux by default; on Windows use WSL or Git Bash)

## Installation

No install needed. Clone/download this repository.

```bash
chmod +x camera_photo_renamer.sh
```

## Usage

Run the script in the directory containing your photos (or at a parent directory if using recursive mode).

```bash
./camera_photo_renamer.sh
```

You will be prompted for:

- **Recursive processing**: Include subdirectories (default: No)
- **Backup creation**: Create a timestamped backup folder (default: Yes)
- **Category**: Optional prefix like `Fam`, `Street`, `Art` (default: `Fam` if enabled)
- **Event**: Short descriptor (1–3 words, no spaces, max 12 chars)

Resulting filenames look like:

```text
2025-09-24_142312_Fam-Birthday-1.RAF
2025-09-24_142312_Fam-Birthday-1.JPG
2025-09-24_142313_Fam-Birthday.RAF
```

Notes:

- The `-1`, `-2`, ... suffix appears when multiple files share the same `DateTimeOriginal` (common in bursts).
- An XMP sidecar is created per file (e.g., `photo.RAF.xmp`) with `XMP:Title = "Original: <old-filename>"`.

## Supported Formats

- RAW: `RAF CR2 NEF ARW ORF RW2 PEF DNG`
- Images: `JPG JPEG HEIC HEIF PNG TIFF TIF`

## Windows Tips

- Use **WSL** (Ubuntu) or **Git Bash** to run the script.
- Install ExifTool (e.g., `sudo apt install libimage-exiftool-perl` in WSL) and ensure `exiftool` is in `PATH`.

## Safety and Logging

- Backups are optional but recommended. When enabled, the script copies supported files to a folder like `backup_YYYYMMDD_HHMMSS/`, preserving subdirectory structure.
- The script writes progress and warnings to `rename_log.txt`.

## Recommended Workflow

- **1. Pre-sort by category**: Use a photo manager like XnView MP or an EXIF-aware tool (e.g., ExifTool GUI) to review and move images into category folders (e.g., `Fam/`, `Street/`, `Art/`). This step helps you apply meaningful categories consistently.
- **2. Rename per category**: In each category folder, run the script to rename files with the desired `Category` and `Event`. This keeps timestamps and counters consistent within that context and preserves RAW/JPEG pairs.
- **3. Merge back to a main library**: After renaming each category, copy or move all renamed files into your main photo library folder. Because names include timestamp, category, event, and a counter, collisions are avoided.
- Optional: Keep the generated XMP sidecars alongside files so the original filenames are always retained in metadata.

## Limitations

- Files missing `DateTimeOriginal` are renamed using the current scheme but may rely on fallback behavior; sidecars will still note the original filename.
- If multiple files share identical timestamps without subseconds, the `-c` counter ensures uniqueness but chronological order within the same second may vary by filesystem listing.

## Contributing

Issues and pull requests are welcome. Please keep changes focused and include a brief description of the use case.

## License

MIT — see [LICENSE](https://github.com/Jmartgraphix/camera_photo_renamer/blob/main/LICENSE) for details.
