#!/bin/bash
# Add Command - Add module or feature

cmd_add() {
    local type="$1"
    local name="$2"
    
    if [ -z "$type" ] || [ -z "$name" ]; then
        log_error "Usage: appfoundation add <type> <name>"
        echo "Types: module, feature"
        exit 1
    fi
    
    # Check if in project directory
    if [ ! -f ".appfoundation/config.json" ]; then
        log_error "Not in an AppFoundation project directory"
        exit 1
    fi
    
    case "$type" in
        feature)
            add_feature "$name"
            ;;
        module)
            add_module "$name"
            ;;
        *)
            log_error "Unknown type: $type"
            exit 1
            ;;
    esac
}

add_feature() {
    local name="$1"
    
    log_step "Adding feature: $name..."
    
    # Fetch templates
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    local cache_dir=$(fetch_templates "latest")
    
    # Check if feature template exists
    local feature_template="$cache_dir/Templates/Features/$name"
    if [ ! -d "$feature_template" ]; then
        log_error "Feature template '$name' not found"
        exit 1
    fi
    
    # Create feature directory
    local feature_dir="Features/$name"
    mkdir -p "$feature_dir"
    
    # Copy template
    cp -r "$feature_template/"* "$feature_dir/"
    
    # Personalize
    local project_name=$(jq -r '.project.name' .appfoundation/config.json)
    find "$feature_dir" -type f -name "*.swift" -exec sed -i '' \
        -e "s/{{PROJECT_NAME}}/$project_name/g" \
        -e "s/{{FEATURE_NAME}}/$name/g" \
        {} \;
    
    log_success "Feature '$name' added successfully!"
    echo "Files created in $feature_dir/"
}

add_module() {
    local name="$1"
    log_info "Module addition not yet implemented"
}
