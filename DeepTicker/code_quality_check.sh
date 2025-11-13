#!/bin/bash

# DeepTicker Code Quality Check Script
# Run this after cleanup to verify everything is working

echo "🔍 DeepTicker Code Quality Check"
echo "================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counter
ISSUES=0

echo "1️⃣  Checking for dead code references..."
echo "----------------------------------------"

# Check if old files are still being imported
if grep -r "import ConfigurationManager" --include="*.swift" . 2>/dev/null | grep -v "DELETED\|DEBUG_ONLY"; then
    echo -e "${RED}❌ Found references to ConfigurationManager${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ No ConfigurationManager references${NC}"
fi

if grep -r "AppSettingsView()" --include="*.swift" . 2>/dev/null | grep -v "DELETED\|DEBUG_ONLY"; then
    echo -e "${RED}❌ Found references to AppSettingsView${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ No AppSettingsView references${NC}"
fi

if grep -r "AISettings.shared" --include="*.swift" . 2>/dev/null | grep -v "DELETED\|DEBUG_ONLY"; then
    echo -e "${RED}❌ Found references to old AISettings${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ No old AISettings references${NC}"
fi

if grep -r "KeychainStore()" --include="*.swift" . 2>/dev/null | grep -v "DELETED\|DEBUG_ONLY"; then
    echo -e "${RED}❌ Found references to KeychainStore${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ No KeychainStore references${NC}"
fi

echo ""
echo "2️⃣  Checking for duplicate implementations..."
echo "----------------------------------------------"

# Check for duplicate IAPAnalytics
ANALYTICS_COUNT=$(grep -r "struct IAPAnalytics\|class IAPAnalytics" --include="*.swift" . 2>/dev/null | grep -v "DELETED\|DEBUG_ONLY" | wc -l)
if [ $ANALYTICS_COUNT -gt 1 ]; then
    echo -e "${RED}❌ Found $ANALYTICS_COUNT IAPAnalytics implementations${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ Single IAPAnalytics implementation${NC}"
fi

echo ""
echo "3️⃣  Checking for common issues..."
echo "----------------------------------"

# Check for force unwrapping
FORCE_UNWRAP_COUNT=$(grep -r "!" --include="*.swift" . 2>/dev/null | grep -v "//\|!=\|!=" | wc -l)
if [ $FORCE_UNWRAP_COUNT -gt 50 ]; then
    echo -e "${YELLOW}⚠️  Found $FORCE_UNWRAP_COUNT potential force unwraps (consider safe unwrapping)${NC}"
else
    echo -e "${GREEN}✅ Force unwrapping usage is reasonable${NC}"
fi

# Check for print statements (should use proper logging)
PRINT_COUNT=$(grep -r "print(" --include="*.swift" . 2>/dev/null | grep -v "//\|DEBUG" | wc -l)
if [ $PRINT_COUNT -gt 20 ]; then
    echo -e "${YELLOW}⚠️  Found $PRINT_COUNT print statements (consider using Logger)${NC}"
else
    echo -e "${GREEN}✅ Print statement usage is reasonable${NC}"
fi

echo ""
echo "4️⃣  Checking file structure..."
echo "------------------------------"

# List files marked for deletion
echo "Files marked for deletion:"
ls -la *Manager.swift *Settings.swift *Store.swift 2>/dev/null | while read -r line; do
    FILE=$(echo "$line" | awk '{print $NF}')
    if grep -q "DEBUG_ONLY_DO_NOT_USE" "$FILE" 2>/dev/null; then
        echo -e "${YELLOW}  ⚠️  $FILE (marked for deletion)${NC}"
    fi
done

echo ""
echo "5️⃣  Summary"
echo "-----------"
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Code is clean.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Delete files marked as 'DEBUG_ONLY_DO_NOT_USE' from Xcode"
    echo "2. Clean build folder (Shift+Cmd+K)"
    echo "3. Build and test the app"
else
    echo -e "${RED}❌ Found $ISSUES issues that need attention${NC}"
    echo ""
    echo "Review the issues above and fix before proceeding."
fi

echo ""
echo "================================="
echo "🎉 Check complete!"
