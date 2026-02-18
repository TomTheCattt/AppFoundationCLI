#!/bin/bash
# Git Operations

source "$(dirname "${BASH_SOURCE[0]}")/../utils/logger.sh"

fetch_templates() {
    local version="${1:-latest}"
    local cache_dir="$AF_CACHE_DIR/$version"
    
    log_step "Fetching templates (version: $version)..."
    
    # Create cache directory
    mkdir -p "$AF_CACHE_DIR"
    
    if [ "$version" = "latest" ]; then
        # Get latest version from remote
        # Get latest version from remote (supports v1.0.0 or 1.0.0)
        local latest_tag=$(git ls-remote --tags "$AF_REMOTE" | grep -o 'refs/tags/[v0-9.]*$' | sed 's|refs/tags/||' | sed 's|^v||' | sort -V | tail -n1)
        
        if [ -z "$latest_tag" ]; then
            # No tags, use main branch
            version="main"
            cache_dir="$AF_CACHE_DIR/main"
        else
            version="$latest_tag"
            cache_dir="$AF_CACHE_DIR/$version"
        fi
    fi
    
    # Check if already cached
    if [ -d "$cache_dir/.git" ]; then
        log_info "Using cached templates at $cache_dir"
        cd "$cache_dir"
        git pull --quiet origin "$AF_BRANCH" 2>/dev/null || true
        cd - > /dev/null
    else
        # Clone fresh
        log_step "Downloading templates from $AF_REMOTE..."
        
        if [ "$version" = "main" ]; then
            git clone --depth 1 --branch "$AF_BRANCH" "$AF_REMOTE" "$cache_dir" 2>&1 | grep -v "Cloning into" || true
        else
            git clone --depth 1 --branch "v$version" "$AF_REMOTE" "$cache_dir" 2>&1 | grep -v "Cloning into" || true
        fi
        
        if [ ! -d "$cache_dir" ]; then
            log_error "Failed to fetch templates"
            return 1
        fi
    fi
    
    log_success "Templates ready at $cache_dir"
    echo "$cache_dir"
}

get_remote_version() {
    local cache_dir="$1"
    
    if [ -f "$cache_dir/VERSION" ]; then
        cat "$cache_dir/VERSION"
    else
        echo "unknown"
    fi
}

cleanup_old_cache() {
    local keep_count=3
    
    log_step "Cleaning up old cache..."
    
    # Keep only the latest N versions
    ls -t "$AF_CACHE_DIR" | tail -n +$((keep_count + 1)) | while read dir; do
        rm -rf "$AF_CACHE_DIR/$dir"
        log_info "Removed old cache: $dir"
    done
}
