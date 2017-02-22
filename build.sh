#!/bin/sh

set -eu

xcodebuild -project FBRetainCycleDetector.xcodeproj \
           -scheme FBRetainCycleDetector \
           -destination "platform=iOS Simulator,name=iPhone 6s" \
           -sdk iphonesimulator \
           build test
