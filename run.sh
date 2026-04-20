#!/bin/bash
# Run the Central Banker game.
# Xcode's SDK must take precedence over Homebrew headers.
SDKROOT=$(xcrun --show-sdk-path) swift run
