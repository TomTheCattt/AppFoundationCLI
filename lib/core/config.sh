#!/bin/bash
# Config Management

CONFIG_FILE="$HOME/.appfoundation/config.json"

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Export config values as environment variables
    if command -v jq &> /dev/null; then
        export AF_REMOTE=$(jq -r '.remote' "$CONFIG_FILE")
        export AF_BRANCH=$(jq -r '.defaultBranch' "$CONFIG_FILE")
        export AF_CACHE_DIR=$(jq -r '.cacheDir' "$CONFIG_FILE")
    else
        # Fallback without jq
        export AF_REMOTE="https://github.com/TomTheCattt/AppFoundation.git"
        export AF_BRANCH="main"
        export AF_CACHE_DIR="$HOME/.appfoundation/cache"
    fi
}

get_config_value() {
    local key="$1"
    
    if command -v jq &> /dev/null; then
        jq -r ".$key" "$CONFIG_FILE"
    else
        echo ""
    fi
}

set_config_value() {
    local key="$1"
    local value="$2"
    
    if command -v jq &> /dev/null; then
        local tmp=$(mktemp)
        jq ".$key = \"$value\"" "$CONFIG_FILE" > "$tmp"
        mv "$tmp" "$CONFIG_FILE"
    fi
}

# Load config on source
load_config
