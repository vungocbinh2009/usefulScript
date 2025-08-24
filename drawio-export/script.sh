#!/bin/bash

FILE="myfile.drawio"
APP="./drawio.AppImage"

# 1. Detect number of pages by counting <diagram> tags in XML
#    Works if .drawio is saved in uncompressed XML format (File → Advanced → Format → XML)
page_count=$(grep -o "<diagram " "$FILE" | wc -l)

if [[ $page_count -eq 0 ]]; then
    echo "❌ Could not detect pages. Make sure your .drawio file is saved as uncompressed XML."
    exit 1
fi

echo "📄 Found $page_count pages."

# 2. Export each page
for ((page=0; page<page_count; page++)); do
    out="page_${page}.png"
    $APP --export --format png --page-index $page --output "$out" "$FILE"
    if [[ $? -ne 0 ]]; then
        echo "❌ Failed to export page $page"
        exit 1
    fi
    echo "✅ Exported page $page -> $out"
done
