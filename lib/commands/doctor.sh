#!/bin/bash
# Doctor Command - Health check

cmd_doctor() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   AppFoundation Health Check           ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    local issues=0
    
    # Check dependencies
    echo "Dependencies:"
    
    if check_command_exists git; then
        echo "  ✓ git: $(git --version | head -n1)"
    else
        echo "  ✗ git: not found"
        ((issues++))
    fi
    
    if check_command_exists xcodegen; then
        echo "  ✓ xcodegen: $(xcodegen --version)"
    else
        echo "  ⚠ xcodegen: not found (optional)"
    fi
    
    if check_command_exists pod; then
        echo "  ✓ CocoaPods: $(pod --version)"
    else
        echo "  ⚠ CocoaPods: not found (optional)"
    fi
    
    if check_command_exists jq; then
        echo "  ✓ jq: $(jq --version)"
    else
        echo "  ⚠ jq: not found (recommended)"
    fi
    
    echo ""
    
    # Check config
    echo "Configuration:"
    if [ -f "$CONFIG_FILE" ]; then
        echo "  ✓ Config file: $CONFIG_FILE"
        echo "  ✓ Remote: $AF_REMOTE"
        echo "  ✓ Cache dir: $AF_CACHE_DIR"
    else
        echo "  ✗ Config file not found"
        ((issues++))
    fi
    
    echo ""
    
    # Check if in project
    if [ -f ".appfoundation/config.json" ]; then
        echo "Project:"
        local project_name=$(jq -r '.project.name' .appfoundation/config.json)
        local version=$(jq -r '.version' .appfoundation/config.json)
        echo "  ✓ Project: $project_name"
        echo "  ✓ AppFoundation version: $version"
        
        # Check for updates
        source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
        local cache_dir=$(fetch_templates "latest" 2>/dev/null)
        local latest=$(get_remote_version "$cache_dir")
        
        if [ "$version" != "$latest" ]; then
            echo "  ⚠ Update available: $version → $latest"
        fi
    fi
    
    echo ""
    
    if [ $issues -eq 0 ]; then
        log_success "All checks passed!"
    else
        log_warn "$issues issue(s) found"
    fi
}
