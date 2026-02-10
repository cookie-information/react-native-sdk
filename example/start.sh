#!/bin/bash

# Shutdown watchman completely to avoid case sensitivity issues
watchman shutdown-server 2>/dev/null || true
pkill -9 watchman 2>/dev/null || true

# Unset WATCHMAN_SOCK to prevent Metro from trying to use watchman
unset WATCHMAN_SOCK

# Set environment variables that Metro checks to disable watchman
export CI=false
export WATCHMAN_DISABLE_WARNING=1
export DISABLE_WATCHMAN=1

# Start Expo
exec expo start "$@"

