#!/bin/bash
# Add Command - Add module, feature, or model

cmd_add() {
    local type="$1"
    local name="$2"
    
    if [ -z "$type" ]; then
        log_error "Usage: appfoundation add <type> <name>"
        echo "Types: feature, model, module"
        exit 1
    fi
    
    # Check if in project directory
    if [ ! -f ".appfoundation/config.json" ]; then
        log_error "Not in an AppFoundation project directory"
        exit 1
    fi
    
    case "$type" in
        feature)
            if [ -z "$name" ]; then
                 list_features
            else
                 add_feature "$name"
            fi
            ;;
        model)
            if [ -z "$name" ]; then
                 log_error "Usage: appfoundation add model <ModelName>"
                 exit 1
            fi
            add_model "$name"
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

list_features() {
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    local cache_dir=$(fetch_templates "latest")
    
    echo "Available pre-built features:"
    ls -1 "$cache_dir/Templates/Features"
    echo ""
    echo "Or provide a new name to scaffold a generic feature."
    read -p "Feature Name: " feature_name
    [ -n "$feature_name" ] && add_feature "$feature_name"
}

add_feature() {
    local name="$1"
    log_step "Adding feature: $name..."
    
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    local cache_dir=$(fetch_templates "latest")
    local project_name=$(jq -r '.project.name' .appfoundation/config.json)
    local ui_framework=$(jq -r '.project.uiFramework' .appfoundation/config.json)
    
    local feature_dir="Features/$name"
    mkdir -p "$feature_dir"/{UI,ViewModel,Assembly}
    mkdir -p "Tests/FeatureTests/${name}Tests"
    
    # 1. Try pre-built first
    local prebuild_template="$cache_dir/Templates/Features/$name"
    if [ -d "$prebuild_template" ]; then
        log_info "Using pre-built template for $name"
        cp -r "$prebuild_template/"* "$feature_dir/"
    else
        log_info "Scaffolding generic feature $name"
        # Copy Assembly
        cp "$cache_dir/Templates/Feature/Assembly.swift.template" "$feature_dir/Assembly/${name}Assembly.swift"
        # Copy ViewModel
        cp "$cache_dir/Templates/Feature/ViewModel.swift.template" "$feature_dir/ViewModel/${name}ViewModel.swift"
        
        # UI based on project config
        if [ "$ui_framework" == "SwiftUI" ]; then
            mkdir -p "$feature_dir/UI"
            cp "$cache_dir/Templates/Feature/SwiftUI/View.swift.template" "$feature_dir/UI/${name}View.swift" 2>/dev/null || \
            echo "// SwiftUI View for $name" > "$feature_dir/UI/${name}View.swift"
        else
            mkdir -p "$feature_dir/UI"
            cp "$cache_dir/Templates/Feature/UIKit/ViewController.swift.template" "$feature_dir/UI/${name}ViewController.swift" 2>/dev/null || \
            echo "// UIKit ViewController for $name" > "$feature_dir/UI/${name}ViewController.swift"
        fi
        
        # Tests & Mocks
        cp "$cache_dir/Templates/Feature/ViewModelTests.swift.template" "Tests/FeatureTests/${name}Tests/${name}ViewModelTests.swift"
    fi
    
    # Personalize
    find "$feature_dir" "Tests/FeatureTests/${name}Tests" -type f \( -name "*.swift" -o -name "*.md" \) -exec sed -i '' \
        -e "s/{{PROJECT_NAME}}/$project_name/g" \
        -e "s/{{FEATURE_NAME}}/$name/g" \
        {} \; 2>/dev/null || true
    
    log_success "Feature '$name' added successfully!"
}

add_model() {
    local name="$1"
    local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    log_step "Adding model: $name..."
    
    source "$(dirname "${BASH_SOURCE[0]}")/../core/git.sh"
    local cache_dir=$(fetch_templates "latest")
    local project_name=$(jq -r '.project.name' .appfoundation/config.json)
    
    mkdir -p "Foundation/Data/Models"
    mkdir -p "Tests/FoundationTests/Models"
    
    local model_path="Foundation/Data/Models/$name.swift"
    local test_path="Tests/FoundationTests/Models/${name}Tests.swift"
    
    cp "$cache_dir/Templates/Data/Model.swift.template" "$model_path"
    cp "$cache_dir/Templates/Data/ModelTests.swift.template" "$test_path"
    
    # Personalize
    sed -i '' -e "s/{{PROJECT_NAME}}/$project_name/g" -e "s/{{MODEL_NAME}}/$name/g" -e "s/{{MODEL_NAME_LOWER}}/$name_lower/g" "$model_path" "$test_path"
    
    log_success "Model '$name' and Unit Tests created!"
}

add_module() {
    log_info "Module scaffolding not yet implemented. Use 'add feature' for business logic."
}
