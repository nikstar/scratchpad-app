#!/bin/bash
# Render the actual Icon Composer materials, rather than a flattened SVG mockup.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p)}"
icon_tool="$developer_dir/../Applications/Icon Composer.app/Contents/Executables/ictool"
output_dir="$project_dir/build/IconPreviews"

if [[ ! -x "$icon_tool" ]]; then
    echo "Set DEVELOPER_DIR to an Xcode installation that includes Icon Composer." >&2
    exit 1
fi
mkdir -p "$output_dir"
for appearance in Default Dark Mono ClearLight ClearDark; do
    "$icon_tool" "$project_dir/Scratchpad/Scratchpad.icon" --export-image \
        --output-file "$output_dir/$appearance.png" --platform macOS \
        --rendition "$appearance" --width 512 --height 512 --scale 1
done
"$icon_tool" "$project_dir/Scratchpad/Scratchpad.icon" --export-image \
    --output-file "$output_dir/Dock.png" --platform macOS \
    --rendition Default --width 64 --height 64 --scale 1
echo "Icon previews: $output_dir"
