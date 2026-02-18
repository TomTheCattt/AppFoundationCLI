#!/bin/bash
# Init Command - Initialize new project

cmd_init() {
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/../utils/prompt.sh"
    
    local project_name="$1"
    local is_update=false
    local reconfigure=false
    
    # Show banner
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   AppFoundation Project Generator      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    # 1. Detect existing project
    local config_path=""
    local project_cwd=""
    
    if [ -f ".appfoundation/config.json" ]; then
        config_path=".appfoundation/config.json"
        project_cwd="."
    elif [ -n "$project_name" ] && [ -f "$project_name/.appfoundation/config.json" ]; then
        config_path="$project_name/.appfoundation/config.json"
        project_cwd="$project_name"
    fi

    if [ -n "$config_path" ]; then
        local existing_name=$(grep -o '"name": "[^"]*"' "$config_path" | head -1 | cut -d'"' -f4)
        log_info "Detected existing AppFoundation project '$existing_name' at: ${project_cwd:-.}"
        read -p "Would you like to update project infrastructure? [y/N]: " update_choice
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            is_update=true
            # Extract values from config
            project_name="$existing_name"
            bundle_id=$(grep -o '"bundleId": "[^"]*"' "$config_path" | head -1 | cut -d'"' -f4)
            team_id=$(grep -o '"teamId": "[^"]*"' "$config_path" | head -1 | cut -d'"' -f4)
            ios_target=$(grep -o '"deploymentTarget": "[^"]*"' "$config_path" | head -1 | cut -d'"' -f4)
            ui_framework=$(grep -o '"uiFramework": "[^"]*"' "$config_path" | head -1| cut -d'"' -f4)
            db_engine=$(grep -o '"database": "[^"]*"' "$config_path" | head -1 | cut -d'"' -f4)
            
            read -p "Keep existing configuration (UI=$ui_framework, DB=$db_engine)? [Y/n]: " config_keep
            if [[ "$config_keep" =~ ^[Nn]$ ]]; then
                reconfigure=true
                ui_framework=""
                db_engine=""
            fi
            
            log_info "Auto-loaded configuration: UI=${ui_framework:-Check}, DB=${db_engine:-Check}"
        fi
    fi

    # 2. Get project name (if not update)
    if [ "$is_update" = false ]; then
        if [ -z "$project_name" ]; then
            read -p "Project Name: " project_name
        fi
        validate_project_name "$project_name" || exit 1
        project_cwd="$project_name"
        
        if [ -d "$project_name" ]; then
            log_info "Directory '$project_cwd' already exists. Supplementing..."
            project_cwd="$project_name"
        fi
    fi
    
    # 3. Fetch templates
    local cache_dir=$(fetch_templates "latest")
    if [ $? -ne 0 ]; then
        log_error "Failed to fetch templates"
        exit 1
    fi
    local version=$(get_remote_version "$cache_dir")
    log_info "Using AppFoundation v$version"
    
    # --- Intelligent Detection Section ---
    local detected_ui=""
    if [ -z "$ui_framework" ]; then
        if find "$project_cwd" -name "*App.swift" -print0 | xargs -0 grep -l "@main" >/dev/null 2>&1; then
            detected_ui="SwiftUI"
        elif find "$project_cwd" -name "AppDelegate.swift" -print0 | xargs -0 grep -l "UIApplicationDelegate" >/dev/null 2>&1; then
            detected_ui="UIKit"
        elif find "$project_cwd" -name "SceneDelegate.swift" -print0 | xargs -0 grep -l "UIWindowSceneDelegate" >/dev/null 2>&1; then
            detected_ui="UIKit"
        fi
    fi

    local detected_bundle_id=""
    if [ -z "$bundle_id" ]; then
        if [ -f "$project_cwd/project.yml" ]; then
            detected_bundle_id=$(grep "bundleIdPrefix:" "$project_cwd/project.yml" | head -1 | awk '{print $2}')
        fi
        if [ -z "$detected_bundle_id" ]; then
             local pbxproj=$(find "$project_cwd" -name "project.pbxproj" | head -1)
             if [ -n "$pbxproj" ]; then
                 detected_bundle_id=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "$pbxproj" | head -1 | cut -d'=' -f2 | tr -d ' ;"')
             fi
        fi
    fi
    # --- End Intelligent Detection ---

    # 4. Configuration
    if [ "$is_update" = false ] || [ "$reconfigure" = true ] || [ -z "$ui_framework" ] || [ -z "$db_engine" ]; then
        echo ""
        log_step "Project Configuration"
        
        if [ -z "$bundle_id" ]; then
            local project_name_lower=$(echo "$project_name" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
            local default_bundle="com.example.$project_name_lower"
            [ -n "$detected_bundle_id" ] && default_bundle="$detected_bundle_id"
            
            read -p "Bundle ID [$default_bundle]: " bundle_id
            bundle_id=${bundle_id:-"$default_bundle"}
            validate_bundle_id "$bundle_id" || exit 1
        fi
        
        if [ -z "$ui_framework" ]; then
            echo ""
            echo "Choose UI Framework:"
            local default_ui_choice="1"
            if [ "$detected_ui" == "UIKit" ]; then
                default_ui_choice="2"
                echo "  1) SwiftUI"
                echo "  2) UIKit (Detected Default)"
                echo "  3) Hybrid (UIKit Lifecycle + SwiftUI)"
            else
                echo "  1) SwiftUI (Default)"
                echo "  2) UIKit"
                echo "  3) Hybrid (UIKit Lifecycle + SwiftUI)"
            fi
            read -p "Selection [$default_ui_choice]: " ui_choice
            ui_choice=${ui_choice:-"$default_ui_choice"}
            ui_framework="SwiftUI"
            [ "$ui_choice" == "2" ] && ui_framework="UIKit"
            [ "$ui_choice" == "3" ] && ui_framework="Hybrid"
        fi
        
        if [ -z "$db_engine" ]; then
            echo ""
            echo "Choose Database Engine:"
            echo "  1) CoreData (Default)"
            echo "  2) Realm"
            echo "  3) SQLite"
            echo "  4) InMemory"
            echo "  5) None / Protocol Only"
            read -p "Selection [1]: " db_choice
            db_engine="CoreData"
            case "$db_choice" in
                2) db_engine="Realm" ;;
                3) db_engine="SQLite" ;;
                4) db_engine="InMemory" ;;
                5) db_engine="None" ;;
            esac
        fi
        
        if [ -z "$ios_target" ]; then
            read -p "iOS Deployment Target [16.0]: " ios_target
            ios_target=${ios_target:-"16.0"}
            validate_ios_version "$ios_target" || exit 1
        fi
        
        if [ -z "$team_id" ] && check_command_exists security; then
            log_step "Detecting Team IDs..."
            local team_ids=($(security find-identity -p codesigning -v | grep -oE "\([A-Z0-9]{10}\)" | tr -d "()" | sort -u))
            if [ ${#team_ids[@]} -gt 0 ]; then
                team_id="${team_ids[0]}"
                log_info "Auto-selected Team ID: $team_id"
            fi
        fi
    fi
    
    # 5. Execution
    log_step "Synchronizing project structure..."
    mkdir -p "$project_cwd"/{Foundation,Features,Tests,App}
    
    log_info "Installing Mandatory Foundation Components..."
    # Core internal modules that SHOULD NOT be excluded
    local mandatory_modules=("Network" "Logging" "ErrorHandling" "Utils" "Data" "Storage" "Concurrency")
    
    for mod in "${mandatory_modules[@]}"; do
        if [ -d "$cache_dir/Sources/AppFoundation/$mod" ]; then
            if command -v rsync >/dev/null 2>&1; then
                rsync -auv --exclude="Adapters/*" "$cache_dir/Sources/AppFoundation/$mod/" "$project_cwd/Foundation/$mod/" | grep -E '^>|^<' || true
            else
                cp -rf "$cache_dir/Sources/AppFoundation/$mod/"* "$project_cwd/Foundation/$mod/" 2>/dev/null || true
            fi
        fi
    done
    
    # Resources (Mandatory)
    if command -v rsync >/dev/null 2>&1; then
        rsync -auv "$cache_dir/Sources/AppFoundationResources/" "$project_cwd/Foundation/" | grep -E '^>|^<' || true
    else
        cp -rf "$cache_dir/Sources/AppFoundationResources/"* "$project_cwd/Foundation/" 2>/dev/null || true
    fi

    # Handle Database Support (Re-configuration logic)
    mkdir -p "$project_cwd/Foundation/Storage/Adapters"
    if [ "$db_engine" != "None" ] && [ -d "$cache_dir/Sources/AppFoundation/Storage/Adapters/$db_engine" ]; then
        log_info "Setting up $db_engine storage adapter..."
        # If reconfiguring, we might want to clean old adapters if they exist
        if [ "$reconfigure" = true ]; then
            rm -rf "$project_cwd/Foundation/Storage/Adapters/"*
        fi
        mkdir -p "$project_cwd/Foundation/Storage/Adapters/$db_engine"
        cp -rf "$cache_dir/Sources/AppFoundation/Storage/Adapters/$db_engine/"* "$project_cwd/Foundation/Storage/Adapters/$db_engine/" 2>/dev/null || true
    fi
    if [ "$db_engine" == "Realm" ]; then
       [ -f "$cache_dir/Sources/AppFoundation/Storage/RealmStorage.swift" ] && cp -f "$cache_dir/Sources/AppFoundation/Storage/RealmStorage.swift" "$project_cwd/Foundation/Storage/RealmStorage.swift"
    else
       rm -f "$project_cwd/Foundation/Storage/RealmStorage.swift"
    fi

    # 6. Templates
    log_info "Installing Test templates..."
    cp -rn "$cache_dir/Tests/"* "$project_cwd/Tests/" 2>/dev/null || true
    
    log_info "Syncing app entry points for $ui_framework..."
    if [ "$ui_framework" == "SwiftUI" ]; then
        local app_template="$cache_dir/Templates/Foundation/App/App.swift.template"
        local target_app_file="$project_cwd/App/${project_name}App.swift"
        [ -f "$project_cwd/App/App.swift" ] && target_app_file="$project_cwd/App/App.swift"

        if [ ! -f "$target_app_file" ]; then
            cp -n "$app_template" "$target_app_file" 2>/dev/null || true
        fi
    elif [ "$ui_framework" == "UIKit" ] || [ "$ui_framework" == "Hybrid" ]; then
        if [ -d "$cache_dir/Templates/Foundation/App/UIKit" ]; then
            cp -rn "$cache_dir/Templates/Foundation/App/UIKit/"* "$project_cwd/App/" 2>/dev/null || true
        fi
    fi

    # Entitlements
    local ent_target="$project_cwd/App/$project_name.entitlements"
    if [ ! -f "$ent_target" ]; then
        cat > "$ent_target" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
EOF
    fi

    log_info "Refreshing infrastructure files..."
    cp -fv "$cache_dir/Templates/Foundation/Core/project.yml.template" "$project_cwd/project.yml" >/dev/null
    cp -fv "$cache_dir/Templates/Foundation/Core/swiftgen.yml.template" "$project_cwd/swiftgen.yml" >/dev/null
    cp -fv "$cache_dir/Templates/Foundation/Core/Podfile.template" "$project_cwd/Podfile" >/dev/null
    cp -n "$cache_dir/.swiftlint.yml" "$project_cwd/.swiftlint.yml" 2>/dev/null || true
    
    log_step "Personalizing project..."
    local bundle_prefix=$(echo "$bundle_id" | sed 's/\.[^.]*$//')
    
    # Conditional Podfile modification
    [ "$db_engine" == "Realm" ] && sed -i '' "s/# pod 'RealmSwift'/pod 'RealmSwift'/g" "$project_cwd/Podfile" 2>/dev/null
    [ "$db_engine" == "SQLite" ] && sed -i '' "s/# pod 'SQLite.swift'/pod 'SQLite.swift'/g" "$project_cwd/Podfile" 2>/dev/null
    
    sed -i '' "1s/^/project '$project_name.xcodeproj'\n/" "$project_cwd/Podfile" 2>/dev/null

    # Mass personalization
    find "$project_cwd" -type f \( -name "*.swift" -o -name "*.yml" -o -name "*.yaml" -o -name "Podfile" \) -exec sed -i '' \
        -e "s/{{PROJECT_NAME}}/$project_name/g" \
        -e "s/{{BUNDLE_ID}}/$bundle_id/g" \
        -e "s/{{BUNDLE_ID_PREFIX}}/$bundle_prefix/g" \
        -e "s/{{DEPLOYMENT_TARGET}}/$ios_target/g" \
        -e "s/{{DEVELOPMENT_TEAM}}/$team_id/g" \
        -e "s/{{PROVISIONING_PROFILE}}//g" \
        {} \; 2>/dev/null || true
    
    log_step "Saving project metadata..."
    mkdir -p "$project_cwd/.appfoundation"
    cat > "$project_cwd/.appfoundation/config.json" <<EOF
{
  "version": "$version",
  "remote": "$AF_REMOTE",
  "project": {
    "name": "$project_name",
    "bundleId": "$bundle_id",
    "teamId": "$team_id",
    "deploymentTarget": "$ios_target",
    "uiFramework": "$ui_framework",
    "database": "$db_engine"
  },
  "updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Post-processing
    if check_command_exists xcodegen; then
        log_step "Regenerating Xcode project..."
        (cd "$project_cwd" && xcodegen generate --spec project.yml) || log_warn "XcodeGen failed"
    fi
    
    if check_command_exists pod; then
        log_step "Updating CocoaPods..."
        (cd "$project_cwd" && pod install) || log_warn "Pod install failed"
    fi
    
    echo ""
    log_success "Project '$project_name' synchronized successfully!"
    echo "Mode:         $([ "$is_update" = true ] && echo "UPDATE" || echo "INIT")"
    echo "UI Framework: $ui_framework"
    echo "Database:     $db_engine"
    echo ""
}
