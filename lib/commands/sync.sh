#!/bin/bash
# Sync Command - Sync local cache with remote

cmd_sync() {
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    
    log_step "Syncing with remote..."
    
    # Fetch latest
    fetch_templates "latest"
    
    # Cleanup old cache
    cleanup_old_cache
    
    # Update last check time
    set_config_value "lastUpdateCheck" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    
    log_success "Sync complete!"
}
