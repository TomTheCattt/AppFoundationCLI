#!/bin/bash
# Update Command - Check and apply updates

cmd_update() {
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    
    local action="check"
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                action="check"
                shift
                ;;
            --apply)
                action="apply"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Check if in project directory
    if [ ! -f ".appfoundation/config.json" ]; then
        log_error "Not in an AppFoundation project directory"
        exit 1
    fi
    
    # Load project config
    local current_version=$(jq -r '.version' .appfoundation/config.json 2>/dev/null || echo "unknown")
    
    log_step "Checking for updates..."
    log_info "Current version: $current_version"
    
    # Fetch latest
    local cache_dir=$(fetch_templates "latest")
    local latest_version=$(get_remote_version "$cache_dir")
    
    log_info "Latest version: $latest_version"
    
    if [ "$current_version" = "$latest_version" ]; then
        log_success "Already up to date!"
        return 0
    fi
    
    echo ""
    log_info "📦 Update available: $current_version → $latest_version"
    echo ""
    
    # Show changelog
    if [ -f "$cache_dir/CHANGELOG.md" ]; then
        echo "Changes:"
        grep -A 20 "## \[$latest_version\]" "$cache_dir/CHANGELOG.md" | head -n 20
        echo ""
    fi
    
    if [ "$action" = "check" ]; then
        echo "Run 'appfoundation update --apply' to update"
        return 0
    fi
    
    # Apply update
    log_warn "This will overwrite Foundation/ directory"
    read -p "Continue? (y/n): " confirm
    
    if [ "$confirm" != "y" ]; then
        log_info "Update cancelled"
        return 0
    fi
    
    # Backup
    local backup_dir=".appfoundation/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r Foundation "$backup_dir/"
    log_success "Backup created at $backup_dir"
    
    # Update Foundation
    log_step "Updating Foundation..."
    rm -rf Foundation
    cp -r "$cache_dir/Sources/AppFoundation/"* Foundation/
    
    # Update metadata
    jq ".version = \"$latest_version\" | .lastSync = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" .appfoundation/config.json > .appfoundation/config.json.tmp
    mv .appfoundation/config.json.tmp .appfoundation/config.json
    
    log_success "Update complete!"
}
