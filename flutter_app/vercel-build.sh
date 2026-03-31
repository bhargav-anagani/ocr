#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable

echo "Adding Flutter to PATH..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Running flutter doctor..."
flutter doctor

echo "Fetching dependencies..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release

echo "Build complete."
