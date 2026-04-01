#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

PLIST="CCStatsOSX/Info.plist"

# Get current version
CURRENT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")

echo "Current version: $CURRENT_VERSION (build $CURRENT_BUILD)"
echo ""

# Determine new version
if [ -n "$1" ]; then
    NEW_VERSION="$1"
else
    # Parse semver and suggest bump
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    echo "Select version bump:"
    echo "  1) Patch: $MAJOR.$MINOR.$((PATCH + 1))"
    echo "  2) Minor: $MAJOR.$((MINOR + 1)).0"
    echo "  3) Major: $((MAJOR + 1)).0.0"
    echo "  4) Custom"
    echo ""
    read -p "Choice [1]: " CHOICE
    CHOICE=${CHOICE:-1}

    case $CHOICE in
        1) NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))" ;;
        2) NEW_VERSION="$MAJOR.$((MINOR + 1)).0" ;;
        3) NEW_VERSION="$((MAJOR + 1)).0.0" ;;
        4) read -p "Enter version: " NEW_VERSION ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

NEW_BUILD=$((CURRENT_BUILD + 1))

echo ""
echo "New version: $NEW_VERSION (build $NEW_BUILD)"
read -p "Continue? [Y/n] " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
    echo "Aborted."
    exit 0
fi

# Update Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"
echo "Updated $PLIST"

# Update download links in README.md
sed -i '' "s|releases/download/v[0-9.]*/CCStatsOSX\.dmg|releases/download/v${NEW_VERSION}/CCStatsOSX.dmg|g" README.md
sed -i '' "s|CCStatsOSX_v[0-9.]*|CCStatsOSX_v${NEW_VERSION}|g" README.md
echo "Updated README.md"

# Update download links and version strings in website
sed -i '' "s|releases/download/v[0-9.]*/CCStatsOSX\.dmg|releases/download/v${NEW_VERSION}/CCStatsOSX.dmg|g" index.html
sed -i '' "s|\"softwareVersion\": \"[0-9.]*\"|\"softwareVersion\": \"${NEW_VERSION}\"|g" index.html
sed -i '' "s|>v[0-9.]* · macOS|>v${NEW_VERSION} · macOS|g" index.html
echo "Updated index.html"

# Build DMG
echo ""
echo "Building release DMG..."
./scripts/build-dmg.sh

DMG_PATH=".build/release/CCStatsOSX.dmg"
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)

echo ""
echo "========================================="
echo "  CCStatsOSX v$NEW_VERSION (build $NEW_BUILD)"
echo "  DMG: $DMG_PATH ($DMG_SIZE)"
echo "========================================="
echo ""

# Commit version bump
echo "Committing version bump..."
git add "$PLIST" README.md index.html
git commit -m "Release v$NEW_VERSION"

TAG="v$NEW_VERSION"
git tag "$TAG"
echo "Tagged $TAG"

# Offer to push and create GitHub release
read -p "Push and create GitHub release? [y/N] " GH_RELEASE
GH_RELEASE=${GH_RELEASE:-N}

if [[ "$GH_RELEASE" =~ ^[Yy] ]]; then
    if ! command -v gh &> /dev/null; then
        echo "Error: gh CLI not installed. Install with: brew install gh"
        exit 1
    fi

    echo "Pushing to origin..."
    git push origin main --tags

    # Generate release notes from git log
    PREV_TAG=$(git describe --tags --abbrev=0 "$TAG^" 2>/dev/null || echo "")
    if [ -n "$PREV_TAG" ]; then
        NOTES=$(git log "$PREV_TAG".."$TAG" --oneline --no-decorate)
    else
        NOTES=$(git log --oneline --no-decorate -20)
    fi

    echo "Creating GitHub release $TAG..."
    gh release create "$TAG" \
        "$DMG_PATH#CCStatsOSX.dmg" \
        --title "CCStatsOSX v$NEW_VERSION" \
        --notes "## Changes

$NOTES

## Install

Download \`CCStatsOSX.dmg\`, open it, and drag the app to \`/Applications\`.

Requires macOS 13 (Ventura) or later and Claude Code installed."

    echo ""
    echo "Release created: $(gh release view "$TAG" --json url -q .url)"
else
    echo ""
    echo "Committed and tagged locally. To push:"
    echo "  git push origin main --tags"
fi
