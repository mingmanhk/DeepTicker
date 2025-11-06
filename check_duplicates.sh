#!/bin/bash

# Script to check for duplicate AlphaVantageManager.swift files
# Run this in your project directory

echo "🔍 Searching for AlphaVantageManager.swift files..."
echo ""

# Find all AlphaVantageManager.swift files
find . -name "AlphaVantageManager.swift" -type f 2>/dev/null | while read file; do
    lines=$(wc -l < "$file" | tr -d ' ')
    echo "Found: $file"
    echo "  → Lines: $lines"
    echo "  → Size: $(du -h "$file" | cut -f1)"
    echo ""
done

echo "---"
echo ""
echo "📋 Files in project root:"
ls -lh AlphaVantageManager.swift 2>/dev/null || echo "  No AlphaVantageManager.swift in root"
echo ""

echo "✅ The clean version should have approximately 318 lines"
echo "❌ Any file with 493 lines is the OLD version and should be deleted"
echo ""
echo "To fix in Xcode:"
echo "1. Open Xcode"
echo "2. In Project Navigator, search for 'AlphaVantageManager'"
echo "3. Remove all duplicate references (Right-click → Delete → Remove Reference)"
echo "4. Clean build folder: ⌘ + Shift + K"
echo "5. Rebuild: ⌘ + B"
