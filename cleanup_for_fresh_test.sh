#!/bin/bash

# SpineAI Complete Cleanup Script
# This removes everything so you can test the setup instructions from scratch

echo "=================================================="
echo "SpineAI Complete Cleanup"
echo "=================================================="
echo ""
echo "This will remove:"
echo "  - Docker containers and volumes"
echo "  - Downloaded SpineAI and ragflow folders"
echo "  - Xcode build cache"
echo "  - Python virtual environment"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# 1. Stop and remove Docker containers
echo "1. Stopping and removing Docker containers..."
cd ~/Downloads/ragflow/docker 2>/dev/null
if [ $? -eq 0 ]; then
    docker compose down -v
    echo "   ✓ Docker containers stopped and removed"
else
    echo "   ℹ No ragflow/docker directory found (skipping)"
fi
echo ""

# 2. Remove downloaded folders
echo "2. Removing downloaded folders..."

if [ -d ~/Downloads/SpineAI ]; then
    # Save the cleanup script itself before deleting
    if [ -f ~/Downloads/SpineAI/cleanup_for_fresh_test.sh ]; then
        cp ~/Downloads/SpineAI/cleanup_for_fresh_test.sh ~/Downloads/cleanup_for_fresh_test_backup.sh
    fi
    rm -rf ~/Downloads/SpineAI
    echo "   ✓ Removed ~/Downloads/SpineAI"
else
    echo "   ℹ SpineAI folder not found (skipping)"
fi

if [ -d ~/Downloads/ragflow ]; then
    rm -rf ~/Downloads/ragflow
    echo "   ✓ Removed ~/Downloads/ragflow"
else
    echo "   ℹ ragflow folder not found (skipping)"
fi
echo ""

# 3. Clean Xcode DerivedData
echo "3. Cleaning Xcode build cache..."
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    rm -rf ~/Library/Developer/Xcode/DerivedData
    echo "   ✓ Cleaned Xcode DerivedData"
else
    echo "   ℹ DerivedData not found (skipping)"
fi
echo ""

# 4. Remove Docker volumes (optional, but thorough)
echo "4. Removing Docker volumes..."
docker volume prune -f >/dev/null 2>&1
echo "   ✓ Docker volumes cleaned"
echo ""

echo "=================================================="
echo "Cleanup Complete!"
echo "=================================================="
echo ""
echo "Your system is now clean. You can now:"
echo "1. Follow SETUP.md from Step 1"
echo "2. Test that every step works exactly as written"
echo ""
echo "Docker Desktop is still running - you can leave it open or quit it."
echo ""

# Restore the cleanup script if it was in SpineAI
if [ -f ~/Downloads/cleanup_for_fresh_test_backup.sh ]; then
    mv ~/Downloads/cleanup_for_fresh_test_backup.sh ~/Downloads/cleanup_for_fresh_test.sh
    echo "NOTE: This cleanup script has been moved to ~/Downloads/"
    echo ""
fi

