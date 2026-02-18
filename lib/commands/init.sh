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
    
    # 1. Intelligent Bundle ID
    local project_name_lower=$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    local default_bundle="com.example.$project_name_lower"
    read -p "Bundle ID [$default_bundle]: " bundle_id
    bundle_id=${bundle_id:-"$default_bundle"}
    validate_bundle_id "$bundle_id" || exit 1
    
    # 2. UI Framework Selection
    echo ""
    echo "Choose UI Framework:"
    echo "  1) SwiftUI (Default)"
    echo "  2) UIKit"
    read -p "Selection [1]: " ui_choice
    local ui_framework="SwiftUI"
    [ "$ui_choice" == "2" ] && ui_framework="UIKit"
    log_info "Selected UI Framework: $ui_framework"
    
    # 3. Database Selection
    echo ""
    echo "Choose Database Engine:"
    echo "  1) CoreData (Default)"
    echo "  2) Realm"
    echo "  3) SQLite"
    echo "  4) InMemory"
    echo "  5) None / Protocol Only"
    read -p "Selection [1]: " db_choice
    local db_engine="CoreData"
    case "$db_choice" in
        2) db_engine="Realm" ;;
        3) db_engine="SQLite" ;;
        4) db_engine="InMemory" ;;
        5) db_engine="None" ;;
    esac
    log_info "Selected Database: $db_engine"
    
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
    
    # Copy Foundation (Base)
    log_step "Installing Foundation Core..."
    if command -v rsync >/dev/null 2>&1; then
        # Exclude storage adapters and Realm specifics for now
        rsync -au --ignore-existing --exclude="Storage/Adapters/*" --exclude="Storage/RealmStorage.swift" "$cache_dir/Sources/AppFoundation/" "$project_name/Foundation/"
        rsync -au --ignore-existing "$cache_dir/Sources/AppFoundationResources/" "$project_name/Foundation/"
    else
        cp -rn "$cache_dir/Sources/AppFoundation/"* "$project_name/Foundation/" 2>/dev/null || true
        cp -rn "$cache_dir/Sources/AppFoundationResources/"* "$project_name/Foundation/" 2>/dev/null || true
    fi
    
    # Install Selected Database Adapter
    if [ "$db_engine" != "None" ]; then
        log_step "Installing $db_engine storage adapter..."
        mkdir -p "$project_name/Foundation/Storage/Adapters/$db_engine"
        if command -v rsync >/dev/null 2>&1; then
            rsync -au --ignore-existing "$cache_dir/Sources/AppFoundation/Storage/Adapters/$db_engine/" "$project_name/Foundation/Storage/Adapters/$db_engine/"
            # If Realm, also copy RealmStorage.swift if it exists in templates
            if [ "$db_engine" == "Realm" ]; then
                [ -f "$cache_dir/Sources/AppFoundation/Storage/RealmStorage.swift" ] && cp -n "$cache_dir/Sources/AppFoundation/Storage/RealmStorage.swift" "$project_name/Foundation/Storage/RealmStorage.swift"
            fi
        else
            cp -rn "$cache_dir/Sources/AppFoundation/Storage/Adapters/$db_engine/"* "$project_name/Foundation/Storage/Adapters/$db_engine/" 2>/dev/null || true
        fi
    fi

    # Explicitly ensure Generated folder is copied
    mkdir -p "$project_name/Foundation/Generated"
    cp -n "$cache_dir/Sources/AppFoundationResources/Generated/"* "$project_name/Foundation/Generated/" 2>/dev/null || true
    
    # Copy Tests
    log_step "Installing Test templates..."
    cp -rn "$cache_dir/Tests/"* "$project_name/Tests/" 2>/dev/null || true
    
    # Copy App base based on UI framework
    log_step "Installing $ui_framework app base..."
    if [ -d "$cache_dir/Templates/Foundation/App/$ui_framework" ]; then
        if command -v rsync >/dev/null 2>&1; then
            rsync -au --ignore-existing "$cache_dir/Templates/Foundation/App/$ui_framework/" "$project_name/App/"
        else
            cp -rn "$cache_dir/Templates/Foundation/App/$ui_framework/"* "$project_name/App/" 2>/dev/null || true
        fi
    fi
    # Copy entitlements if it exists
    if [ -f "$cache_dir/Templates/Foundation/App/entitlements.template" ]; then
        cp -n "$cache_dir/Templates/Foundation/App/entitlements.template" "$project_name/App/$project_name.entitlements" 2>/dev/null || true
    fi

    # Copy templates
    cp -n "$cache_dir/Templates/Foundation/Core/project.yml.template" "$project_name/project.yml" 2>/dev/null || true
    cp -n "$cache_dir/Templates/Foundation/Core/swiftgen.yml.template" "$project_name/swiftgen.yml" 2>/dev/null || true
    cp -n "$cache_dir/Templates/Foundation/Core/Podfile.template" "$project_name/Podfile" 2>/dev/null || true
    cp -n "$cache_dir/.swiftlint.yml" "$project_name/.swiftlint.yml" 2>/dev/null || true
    
    # Personalize templates
    log_step "Personalizing templates..."
    local bundle_prefix=$(echo "$bundle_id" | sed 's/\.[^.]*$//')
    
    # Update Podfile based on DB choice
    if [ "$db_engine" == "Realm" ]; then
        sed -i '' "s/# pod 'RealmSwift'/pod 'RealmSwift'/g" "$project_name/Podfile" 2>/dev/null || true
    fi

    find "$project_name" -type f \( -name "*.swift" -o -name "*.yml" -o -name "*.yaml" -o -name "Podfile" \) -exec sed -i '' \
        -e "s/{{PROJECT_NAME}}/$project_name/g" \
        -e "s/{{BUNDLE_ID}}/$bundle_id/g" \
        -e "s/{{BUNDLE_ID_PREFIX}}/$bundle_prefix/g" \
        -e "s/{{DEPLOYMENT_TARGET}}/$ios_target/g" \
        -e "s/{{DEVELOPMENT_TEAM}}/$team_id/g" \
        {} \; 2>/dev/null || true
    
    # Create metadata
    log_step "Creating project metadata..."
    mkdir -p "$project_name/.appfoundation"
    cat > "$project_name/.appfoundation/config.json" <<EOF
{
  "version": "$version",
  "remote": "$AF_REMOTE",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lastSync": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": {
    "name": "$project_name",
    "bundleId": "$bundle_id",
    "teamId": "$team_id",
    "deploymentTarget": "$ios_target",
    "uiFramework": "$ui_framework",
    "database": "$db_engine"
  }
}
EOF
    
    # Generate Xcode project
    if check_command_exists xcodegen; then
        log_step "Generating Xcode project..."
        (cd "$project_name" && xcodegen generate --spec project.yml) || log_warn "XcodeGen generation failed. Check your project.yml"
    else
        log_warn "xcodegen not found. Install with: brew install xcodegen"
    fi
    
    # Install pods
    if check_command_exists pod; then
        log_step "Installing CocoaPods dependencies..."
        (cd "$project_name" && pod install) || log_warn "CocoaPods installation failed. Check your Podfile"
    else
        log_warn "CocoaPods not found. Install with: sudo gem install cocoapods"
    fi
    
    echo ""
    log_success "Project '$project_name' initialized successfully!"
    echo "UI Framework: $ui_framework"
    echo "Database:     $db_engine"
    echo ""
    echo "Next steps:"
    echo "  cd $project_name"
    echo "  open $project_name.xcworkspace"
    echo ""
}
