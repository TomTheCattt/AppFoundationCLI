#!/bin/bash
# Init Command - Initialize new project

cmd_init() {
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/../utils/prompt.sh"
    
    local project_name="$1"
    
    # Show banner
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   AppFoundation Project Generator      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    # Get project name
    if [ -z "$project_name" ]; then
        read -p "Project Name: " project_name
    fi
    
    validate_project_name "$project_name" || exit 1
    
    # Check if directory exists
    if [ -d "$project_name" ]; then
        log_info "Directory '$project_name' already exists. Supplementing missing files..."
    fi
    
    # Fetch templates
    local cache_dir=$(fetch_templates "latest")
    if [ $? -ne 0 ]; then
        log_error "Failed to fetch templates"
        exit 1
    fi
    
    local version=$(get_remote_version "$cache_dir")
    log_info "Using AppFoundation v$version"
    
    # Interactive prompts
    echo ""
    log_step "Project Configuration"
    
    local bundle_id
    # Use tr for lowercase conversion (Bash 3.x compatibility)
    local project_name_lower=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')
    read -p "Bundle ID [com.example.$project_name_lower]: " bundle_id
    bundle_id=${bundle_id:-"com.example.$project_name_lower"}
    validate_bundle_id "$bundle_id" || exit 1
    
    local ios_target
    read -p "iOS Deployment Target [16.0]: " ios_target
    ios_target=${ios_target:-"16.0"}
    validate_ios_version "$ios_target" || exit 1
    
    local team_id
    if check_command_exists security; then
        log_step "Detecting Team IDs..."
        local team_ids=($(security find-identity -p codesigning -v | grep -oE "\([A-Z0-9]{10}\)" | tr -d "()" | sort -u))
        
        if [ ${#team_ids[@]} -gt 0 ]; then
            team_id="${team_ids[0]}"
            log_info "Auto-selected Team ID: $team_id"
        else
            log_warn "No Team IDs found. Setup will proceed without signing configuration."
        fi
    fi
    
    # Create project structure
    log_step "Creating project structure..."
    mkdir -p "$project_name"/{Foundation,Features,Tests,App}
    
    # Copy Foundation
    # Copy Foundation
    log_step "Installing Foundation modules..."
    cp -rn "$cache_dir/Sources/AppFoundation/"* "$project_name/Foundation/"
    cp -rn "$cache_dir/Sources/AppFoundationResources/"* "$project_name/Foundation/"
    # Remove RealmStorage.swift as Realm is optional and not included by default
    rm -f "$project_name/Foundation/Storage/RealmStorage.swift"
    
    # Copy Tests
    log_step "Installing Test templates..."
    cp -rn "$cache_dir/Tests/"* "$project_name/Tests/"
    
    # Copy templates
    cp -n "$cache_dir/Templates/Foundation/Core/project.yml.template" "$project_name/project.yml"
    cp -n "$cache_dir/Templates/Foundation/Core/swiftgen.yml.template" "$project_name/swiftgen.yml"
    cp -n "$cache_dir/Templates/Foundation/Core/Podfile.template" "$project_name/Podfile"
    cp -n "$cache_dir/.swiftlint.yml" "$project_name/.swiftlint.yml"
    
    # Personalize templates
    log_step "Personalizing templates..."
    local bundle_prefix=$(echo "$bundle_id" | sed 's/\.[^.]*$//')
    find "$project_name" -type f \( -name "*.swift" -o -name "*.yml" -o -name "*.yaml" -o -name "Podfile" \) -exec sed -i '' \
        -e "s/{{PROJECT_NAME}}/$project_name/g" \
        -e "s/{{BUNDLE_ID}}/$bundle_id/g" \
        -e "s/{{BUNDLE_ID_PREFIX}}/$bundle_prefix/g" \
        -e "s/{{DEPLOYMENT_TARGET}}/$ios_target/g" \
        -e "s/{{DEVELOPMENT_TEAM}}/$team_id/g" \
        {} \;
    
    # Create metadata
    log_step "Creating project metadata..."
    mkdir -p "$project_name/.appfoundation"
    cat > "$project_name/.appfoundation/config.json" <<EOF
{
  "version": "$version",
  "remote": "$AF_REMOTE",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lastSync": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "modules": [
    {"name": "core.network", "version": "$version", "customized": false},
    {"name": "core.di", "version": "$version", "customized": false}
  ],
  "features": [],
  "customizations": {},
  "project": {
    "name": "$project_name",
    "bundleId": "$bundle_id",
    "teamId": "$team_id",
    "deploymentTarget": "$ios_target"
  }
}
EOF
    
    # Generate Xcode project
    if check_command_exists xcodegen; then
        log_step "Generating Xcode project..."
        cd "$project_name"
        xcodegen generate --spec project.yml
        cd - > /dev/null
    else
        log_warn "xcodegen not found. Install with: brew install xcodegen"
    fi
    
    # Install pods
    if check_command_exists pod; then
        log_step "Installing CocoaPods dependencies..."
        cd "$project_name"
        pod install
        cd - > /dev/null
    else
        log_warn "CocoaPods not found. Install with: sudo gem install cocoapods"
    fi
    
    echo ""
    log_success "Project '$project_name' created successfully!"
    echo ""
    echo "Next steps:"
    echo "  cd $project_name"
    echo "  open $project_name.xcworkspace"
    echo ""
}
