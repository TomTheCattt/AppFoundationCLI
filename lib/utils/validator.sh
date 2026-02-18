#!/bin/bash
# Validator Utility

validate_project_name() {
    local name="$1"
    
    if [ -z "$name" ]; then
        log_error "Project name cannot be empty"
        return 1
    fi
    
    if [[ ! "$name" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
        log_error "Project name must start with a letter and contain only letters, numbers, and underscores"
        return 1
    fi
    
    return 0
}

validate_bundle_id() {
    local bundle_id="$1"
    
    if [ -z "$bundle_id" ]; then
        log_error "Bundle ID cannot be empty"
        return 1
    fi
    
    if [[ ! "$bundle_id" =~ ^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*)+$ ]]; then
        log_error "Bundle ID must be in reverse domain format (e.g., com.example.app)"
        return 1
    fi
    
    return 0
}

validate_ios_version() {
    local version="$1"
    local min_version="16.0"
    
    if [ -z "$version" ]; then
        log_error "iOS version cannot be empty"
        return 1
    fi
    
    # Simple major version check
    local major=$(echo "$version" | cut -d'.' -f1)
    if [ "$major" -lt 16 ]; then
        log_error "Minimum iOS version is 16.0"
        return 1
    fi
    
    return 0
}

check_command_exists() {
    local cmd="$1"
    
    if ! command -v "$cmd" &> /dev/null; then
        return 1
    fi
    
    return 0
}
