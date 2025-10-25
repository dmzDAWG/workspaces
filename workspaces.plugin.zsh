#!/usr/bin/env zsh

# Workspace Management Plugin for Oh My Zsh
# Manages git worktrees across multiple projects

# Configuration
WORK_DIR="$HOME/Work"
PROJECTS_DIR="$WORK_DIR/projects"
WORKTREES_DIR="$WORK_DIR/worktrees"
MAIN_BRANCH="master"
TEMPLATES_DIR="$WORK_DIR/templates"

# Colors for output
autoload -U colors && colors

# Function to create .java-version file based on pom.xml
_create_java_version_file() {
    local project_path="$1"
    local pom_file="$project_path/pom.xml"
    local java_version_file="$project_path/.java-version"
    
    # Skip if .java-version already exists
    if [[ -f "$java_version_file" ]]; then
        return 0
    fi
    
    # Skip if no pom.xml exists
    if [[ ! -f "$pom_file" ]]; then
        return 0
    fi
    
    # Extract Java version from pom.xml
    local java_version=""
    
    # Helper function to extract version from a pom file
    _extract_java_version_from_pom() {
        local pom="$1"
        local version=""
        
        # Pattern 1: <java.version>11</java.version>
        version=$(grep -o '<java\.version>[^<]*</java\.version>' "$pom" 2>/dev/null | sed 's/<java\.version>\([^<]*\)<\/java\.version>/\1/' | head -1)
        
        # Pattern 2: <maven.compiler.source>11</maven.compiler.source>
        if [[ -z "$version" ]]; then
            version=$(grep -o '<maven\.compiler\.source>[^<]*</maven\.compiler\.source>' "$pom" 2>/dev/null | sed 's/<maven\.compiler\.source>\([^<]*\)<\/maven\.compiler\.source>/\1/' | head -1)
        fi
        
        # Pattern 3: <maven.compiler.target>11</maven.compiler.target>
        if [[ -z "$version" ]]; then
            version=$(grep -o '<maven\.compiler\.target>[^<]*</maven\.compiler\.target>' "$pom" 2>/dev/null | sed 's/<maven\.compiler\.target>\([^<]*\)<\/maven\.compiler\.target>/\1/' | head -1)
        fi
        
        # Pattern 4: <source>11</source> or <target>11</target> in maven-compiler-plugin
        if [[ -z "$version" ]]; then
            version=$(awk '/<plugin>/{p=0} /<groupId>org\.apache\.maven\.plugins<\/groupId>/{if(getline && /<artifactId>maven-compiler-plugin<\/artifactId>/) p=1} p && /<source>[^<]*<\/source>/{gsub(/<\/?source>/,""); print; exit}' "$pom" 2>/dev/null | tr -d ' ')
        fi
        
        # Pattern 5: Look for properties section with version definitions
        if [[ -z "$version" ]]; then
            version=$(awk '/<properties>/{p=1} /<\/properties>/{p=0} p && /<[^>]*version>[0-9]+<\/[^>]*version>/{gsub(/.*<[^>]*version>|<\/[^>]*version>.*/,""); if(/^[0-9]+$/) print}' "$pom" 2>/dev/null | head -1)
        fi
        
        echo "$version"
    }
    
    # Try root pom.xml first
    java_version=$(_extract_java_version_from_pom "$pom_file")
    
    # If not found in root pom.xml, search submodule pom.xml files
    if [[ -z "$java_version" ]]; then
        # Look for pom.xml files in subdirectories (common Maven structure)
        for subpom in "$project_path"/*/pom.xml; do
            if [[ -f "$subpom" ]]; then
                java_version=$(_extract_java_version_from_pom "$subpom")
                if [[ -n "$java_version" ]]; then
                    local submodule=$(basename $(dirname "$subpom"))
                    echo "    ${fg[cyan]}→ Java version found in submodule: $submodule${reset_color}"
                    break
                fi
            fi
        done
    fi
    
    # If we found a Java version, create .java-version file
    if [[ -n "$java_version" ]] && [[ "$java_version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        echo "$java_version" > "$java_version_file"
        echo "    ${fg[green]}✓ Created .java-version ($java_version)${reset_color}"
    fi
}

# Helper function to open project in IntelliJ IDEA
_open_in_intellij() {
    local project_path="$1"
    
    if [[ -z "$project_path" ]] || [[ ! -d "$project_path" ]]; then
        echo "${fg[red]}Error: Invalid project path${reset_color}"
        return 1
    fi
    
    echo "${fg[cyan]}🚀 Opening in IntelliJ IDEA...${reset_color}"
    
    # Try multiple methods to open IntelliJ
    if command -v idea &> /dev/null; then
        idea "$project_path" &
    elif command -v intellij-idea-ultimate &> /dev/null; then
        intellij-idea-ultimate "$project_path" &
    elif command -v intellij-idea-ce &> /dev/null; then
        intellij-idea-ce "$project_path" &
    elif [[ -d "/Applications/IntelliJ IDEA.app" ]]; then
        open -na "IntelliJ IDEA.app" --args "$project_path" &
    else
        echo "${fg[yellow]}Could not find IntelliJ IDEA command${reset_color}"
        echo "${fg[yellow]}Please open manually: $project_path${reset_color}"
        return 1
    fi
    
    return 0
}

# Function to create project-specific specs
_create_project_specs() {
    local template_type="$1"
    local feature_name="$2"
    local branch_name="$3"
    local worktree_base="$4"
    local -a projects=("${@:5}")
    
    # Determine project template file based on type
    local project_template=""
    case "$template_type" in
        feature)
            project_template="template-project-feature.md"
            ;;
        bug|bugfix)
            project_template="template-project-bug.md"
            ;;
        hotfix)
            project_template="template-project-hotfix.md"
            ;;
        chore)
            project_template="template-project-chore.md"
            ;;
        *)
            echo "${fg[yellow]}  ⚠️  Unknown template type: $template_type${reset_color}"
            return 1
            ;;
    esac
    
    local plugin_template_path="$(dirname "${(%):-%x}")/templates/$project_template"
    local user_template_path="$TEMPLATES_DIR/$project_template"
    local template_path=""
    
    # Check for user template first, then plugin template
    if [[ -f "$user_template_path" ]]; then
        template_path="$user_template_path"
    elif [[ -f "$plugin_template_path" ]]; then
        template_path="$plugin_template_path"
        echo "${fg[cyan]}  ℹ️  Using reference template from plugin${reset_color}"
    else
        echo "${fg[yellow]}  ⚠️  Project template not found: $project_template${reset_color}"
        echo "${fg[yellow]}     You can copy reference templates with:${reset_color}"
        echo "${fg[yellow]}     cp -r $(dirname "${(%):-%x}")/templates/* $TEMPLATES_DIR/${reset_color}"
        return 1
    fi
    
    # Create project spec for each project
    for project in "${projects[@]}"; do
        local project_spec_path="$worktree_base/$project/PROJECT-SPEC.md"
        
        # Only create if project directory exists
        if [[ -d "$worktree_base/$project" ]]; then
            # Copy and customize template
            cp "$template_path" "$project_spec_path"
            
            # Customize the project template
            local current_date=$(date +"%Y-%m-%d")
            local temp_file=$(mktemp)
            
            sed -e "s/\[Feature Name\]/$feature_name/g" \
                -e "s/\[Brief Description\]/$feature_name/g" \
                -e "s/\[Project Name\]/$project/g" \
                -e "1a\\
\\
**Created**: $current_date\\
**Branch**: \`$branch_name\`\\
**Project**: $project\\
" \
                "$project_spec_path" > "$temp_file"
            
            mv "$temp_file" "$project_spec_path"
            
            echo "${fg[green]}  ✓ Created project spec: $project/PROJECT-SPEC.md${reset_color}"
        fi
    done
    
    return 0
}

_copy_and_customize_template() {
    local template_type="$1"
    local feature_name="$2"
    local branch_name="$3"
    local worktree_base="$4"
    local -a projects=("${@:5}")
    
    # Determine if this should use multi-level specs
    local use_multilevel=false
    local project_count=${#projects[@]}
    
    # Use multi-level specs for features with multiple projects
    # For bugs/hotfixes/chores, always use project-level specs only
    if [[ "$template_type" == "feature" && $project_count -gt 1 ]]; then
        use_multilevel=true
    fi
    
    # For single project features, bugs, hotfixes, chores: create project spec only
    if [[ "$template_type" != "feature" || $project_count -eq 1 ]]; then
        echo "${fg[cyan]}📄 Creating project-specific specification...${reset_color}"
        _create_project_specs "$template_type" "$feature_name" "$branch_name" "$worktree_base" "${projects[@]}"
        return $?
    fi
    
    # Multi-project features: create both main coordination spec and project specs
    echo "${fg[cyan]}📄 Creating multi-level specifications...${reset_color}"
    
    # First create the main coordination spec
    local template_file=""
    case "$template_type" in
        feature)
            # Use coordination template for multi-project features
            template_file="template-feature-coordination.md"
            ;;
        bug|bugfix)
            template_file="template-bug-fix.md"
            ;;
        api)
            template_file="template-api-integration.md"
            ;;
        quick|task)
            template_file="template-quick-task.md"
            ;;
        refactor|refactoring)
            template_file="template-refactoring.md"
            ;;
        system|design)
            template_file="template-system-design.md"
            ;;
        *)
            echo "${fg[yellow]}  ⚠️  Unknown template type: $template_type${reset_color}"
            return 1
            ;;
    esac
    
    # Check for user template first, then plugin template
    local plugin_template_path="$(dirname "${(%):-%x}")/templates/$template_file"
    local user_template_path="$TEMPLATES_DIR/$template_file"
    local template_path=""
    
    if [[ -f "$user_template_path" ]]; then
        template_path="$user_template_path"
    elif [[ -f "$plugin_template_path" ]]; then
        template_path="$plugin_template_path"
        echo "${fg[cyan]}  ℹ️  Using reference template from plugin${reset_color}"
    else
        echo "${fg[yellow]}  ⚠️  Main template not found: $template_file${reset_color}"
        echo "${fg[yellow]}     You can copy reference templates with:${reset_color}"
        echo "${fg[yellow]}     cp -r $(dirname "${(%):-%x}")/templates/* $TEMPLATES_DIR/${reset_color}"
        return 1
    fi
    
    local spec_path="$worktree_base/SPEC.md"
    
    # Copy template
    cp "$template_path" "$spec_path"
    
    # Pre-fill template with known information
    local current_date=$(date +"%Y-%m-%d")
    local projects_list="${(j:, :)projects}"  # Join array with commas
    
    # Create a temporary file for sed operations
    local temp_file=$(mktemp)
    
    # Customize the template based on type
    case "$template_type" in
        feature)
            # For coordination template, add project breakdown section
            local project_breakdown=""
            for project in "${projects[@]}"; do
                project_breakdown="$project_breakdown- **$project**: See \`$project/PROJECT-SPEC.md\` - [Brief description of $project role]\\n"
            done
            
            sed -e "s/\[Feature Name\]/$feature_name/g" \
                -e "s/# \[Feature Name\] Implementation Spec/# $feature_name Implementation Spec/" \
                -e "s/{{#each projects}}//" \
                -e "s/- \*\*{{name}}\*\*: See \`{{name}}\/PROJECT-SPEC.md\` - \[Brief description of {{name}} role\]//" \
                -e "s/{{\/each}}//" \
                -e "/## Project Breakdown/a\\
$project_breakdown" \
                -e "1a\\
\\
**Created**: $current_date\\
**Branch**: \`$branch_name\`\\
**Projects**: $projects_list\\
" \
                "$spec_path" > "$temp_file"
            ;;
        bug|bugfix)
            sed -e "s/\[Brief Description\]/$feature_name/g" \
                -e "s/# Bug Fix: \[Brief Description\]/# Bug Fix: $feature_name/" \
                -e "1a\\
\\
**Created**: $current_date\\
**Branch**: \`$branch_name\`\\
**Projects**: $projects_list\\
" \
                "$spec_path" > "$temp_file"
            ;;
        *)
            # For other templates, just add header info
            sed -e "1a\\
\\
**Created**: $current_date\\
**Branch**: \`$branch_name\`\\
**Feature**: $feature_name\\
**Projects**: $projects_list\\
" \
                "$spec_path" > "$temp_file"
            ;;
    esac
    
    # Move temp file back to spec path
    mv "$temp_file" "$spec_path"
    
    echo "${fg[green]}  ✓ Created main coordination spec: $template_file${reset_color}"
    echo "${fg[cyan]}    Location: $spec_path${reset_color}"
    
    # Now create project-specific specs
    echo "${fg[cyan]}  📋 Creating project-specific specifications...${reset_color}"
    _create_project_specs "$template_type" "$feature_name" "$branch_name" "$worktree_base" "${projects[@]}"
    
    return 0
}

# Main command to create a new feature workspace
new-feature() {
    local feature_name=""
    local preset_type=""
    local spec_template=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --spec)
                spec_template="$2"
                shift 2
                ;;
            *)
                if [[ -z "$feature_name" ]]; then
                    feature_name="$1"
                elif [[ -z "$preset_type" ]]; then
                    preset_type="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate feature name
    if [[ -z "$feature_name" ]]; then
        echo "${fg[red]}Error: Please provide a feature name${reset_color}"
        echo "Usage: new-feature <feature-name> [type] [--spec <template-type>]"
        echo ""
        echo "Template types: feature, bug, api, quick, refactor, system"
        return 1
    fi
    
    # Sanitize feature name (replace spaces with hyphens, lowercase)
    feature_name=$(echo "$feature_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    
    # Ask for type (feature, bug, etc.) unless preset
    local branch_prefix
    if [[ -n "$preset_type" ]]; then
        branch_prefix="$preset_type"
    else
        echo "${fg[cyan]}What type of work is this?${reset_color}"
        echo "  1) Feature"
        echo "  2) Bug/Bugfix"
        echo "  3) Hotfix"
        echo "  4) Chore"
        echo -n "\nEnter number [1]: "
        read -r type_choice
        
        case "$type_choice" in
            2) branch_prefix="bugfix" ;;
            3) branch_prefix="hotfix" ;;
            4) branch_prefix="chore" ;;
            *) branch_prefix="feature" ;;
        esac
    fi
    
    # Determine spec template if not specified
    if [[ -z "$spec_template" ]]; then
        case "$branch_prefix" in
            bugfix|hotfix)
                spec_template="bug"
                ;;
            *)
                spec_template="feature"
                ;;
        esac
    fi
    
    local branch_name="$branch_prefix/$feature_name"
    local worktree_base="$WORKTREES_DIR/$feature_name"
    
    echo "\n${fg[cyan]}🚀 Setting up workspace for: $feature_name${reset_color}"
    echo "${fg[cyan]}Branch type: $branch_prefix${reset_color}"
    echo "${fg[cyan]}Spec template: $spec_template${reset_color}\n"
    
    # Check if worktree directory already exists
    if [[ -d "$worktree_base" ]]; then
        echo "${fg[yellow]}Warning: Worktree directory already exists: $worktree_base${reset_color}"
        echo -n "Do you want to continue and add more projects? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        mkdir -p "$worktree_base"
    fi
    
    # Get list of available projects
    local -a available_projects
    available_projects=()
    for project_dir in "$PROJECTS_DIR"/*(/); do
        local project_name=$(basename "$project_dir")
        # Check if it's a git repository
        if [[ -d "$project_dir/.git" ]]; then
            available_projects+=("$project_name")
        fi
    done
    
    if [[ ${#available_projects[@]} -eq 0 ]]; then
        echo "${fg[red]}Error: No git repositories found in $PROJECTS_DIR${reset_color}"
        return 1
    fi
    
    # Display available projects and prompt for selection
    echo "${fg[green]}Available projects:${reset_color}"
    local i=1
    for project in "${available_projects[@]}"; do
        echo "  $i) $project"
        ((i++))
    done
    
    echo "\n${fg[cyan]}Enter project numbers to include (space-separated, e.g., '1 3 5'):${reset_color}"
    read -r selection
    
    # Parse selected projects
    local -a selected_projects
    for num in ${=selection}; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#available_projects[@]} ]]; then
            selected_projects+=("${available_projects[$num]}")
        fi
    done
    
    if [[ ${#selected_projects[@]} -eq 0 ]]; then
        echo "${fg[red]}Error: No valid projects selected${reset_color}"
        return 1
    fi
    
    echo "\n${fg[green]}Selected projects:${reset_color} ${selected_projects[*]}\n"
    
    # Preflight check: validate all repos before creating anything
    echo "${fg[cyan]}🔍 Preflight check: validating all repositories...${reset_color}\n"
    
    local -a failed_checks=()
    for project in "${selected_projects[@]}"; do
        local project_path="$PROJECTS_DIR/$project"
        
        (
            cd "$project_path" || return 1
            
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo "${fg[red]}✗${reset_color}  $project - has uncommitted changes"
                return 1
            fi
            
            echo "${fg[green]}✓${reset_color}  $project - ready"
            return 0
        )
        
        if [[ $? -ne 0 ]]; then
            failed_checks+=("$project")
        fi
    done
    
    # If any checks failed, abort
    if [[ ${#failed_checks[@]} -gt 0 ]]; then
        echo "\n${fg[red]}❌ Preflight check failed!${reset_color}"
        echo "${fg[yellow]}The following repositories have uncommitted changes:${reset_color}"
        for proj in "${failed_checks[@]}"; do
            echo "  - $proj ($PROJECTS_DIR/$proj)"
        done
        echo "\n${fg[cyan]}Please commit, stash, or discard changes before creating worktrees.${reset_color}"
        echo "${fg[cyan]}You can use:${reset_color}"
        echo "  git stash         # Temporarily save changes"
        echo "  git commit -am    # Commit changes"
        echo "  git reset --hard  # Discard changes (careful!)"
        return 1
    fi
    
    echo "\n${fg[green]}✓ All repositories ready!${reset_color}\n"
    
    # Process each selected project
    local -a successful_projects
    for project in "${selected_projects[@]}"; do
        echo "${fg[blue]}━━━ Processing $project ━━━${reset_color}"
        
        local project_path="$PROJECTS_DIR/$project"
        local worktree_path="$worktree_base/$project"
        
        # Check if worktree already exists for this project
        if [[ -d "$worktree_path" ]]; then
            echo "${fg[yellow]}  ⚠️  Worktree already exists for $project, skipping...${reset_color}\n"
            successful_projects+=("$project")
            continue
        fi
        
        # Update main repository
        echo "  📥 Updating $MAIN_BRANCH branch..."
        (
            cd "$project_path" || return 1
            
            # Check if we're already on master
            current_branch=$(git branch --show-current)
            if [[ "$current_branch" != "$MAIN_BRANCH" ]]; then
                git checkout "$MAIN_BRANCH" 2>/dev/null
                if [[ $? -ne 0 ]]; then
                    echo "${fg[red]}    ✗ Failed to checkout $MAIN_BRANCH${reset_color}"
                    return 1
                fi
            fi
            
            git pull origin "$MAIN_BRANCH"
            if [[ $? -ne 0 ]]; then
                echo "${fg[yellow]}    ⚠️  Warning: Failed to pull from origin${reset_color}"
            fi
        )
        
        if [[ $? -ne 0 ]]; then
            echo "${fg[red]}  ✗ Failed to update $project${reset_color}\n"
            continue
        fi
        
        # Create worktree
        echo "  🌳 Creating worktree with branch $branch_name..."
        (
            cd "$project_path" || return 1
            git worktree add -b "$branch_name" "$worktree_path" "$MAIN_BRANCH"
            if [[ $? -ne 0 ]]; then
                echo "${fg[red]}    ✗ Failed to create worktree${reset_color}"
                return 1
            fi
        )
        
        if [[ $? -ne 0 ]]; then
            echo "${fg[red]}  ✗ Failed to create worktree for $project${reset_color}\n"
            continue
        fi
        
        # Push branch to remote
        echo "  📤 Pushing branch to remote..."
        (
            cd "$worktree_path" || return 1
            git push -u origin "$branch_name" 2>/dev/null
            if [[ $? -ne 0 ]]; then
                echo "${fg[yellow]}    ⚠️  Warning: Failed to push to remote (you may need to push manually)${reset_color}"
            else
                echo "${fg[green]}    ✓ Branch pushed and tracking set${reset_color}"
            fi
        )
        
        # Create .java-version file if needed
        echo "  ☕ Checking Java version..."
        _create_java_version_file "$worktree_path"
        
        successful_projects+=("$project")
        echo "${fg[green]}  ✓ $project worktree created successfully${reset_color}\n"
    done
    
    # Summary
    if [[ ${#successful_projects[@]} -eq 0 ]]; then
        echo "${fg[red]}❌ No worktrees were created successfully${reset_color}"
        return 1
    fi
    
    echo "${fg[green]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
    echo "${fg[green]}✓ Workspace setup complete!${reset_color}\n"
    echo "${fg[cyan]}Worktree location:${reset_color} $worktree_base"
    echo "${fg[cyan]}Branch name:${reset_color} $branch_name"
    echo "${fg[cyan]}Projects created:${reset_color} ${successful_projects[*]}\n"
    
    # Copy and customize template
    echo "${fg[cyan]}📄 Creating specification document...${reset_color}"
    _copy_and_customize_template "$spec_template" "$feature_name" "$branch_name" "$worktree_base" "${successful_projects[@]}"
    echo ""
    
    # Offer to open project in IntelliJ
    echo "${fg[cyan]}Which project would you like to open in IntelliJ?${reset_color}"
    local proj_num=1
    for project in "${successful_projects[@]}"; do
        echo "  $proj_num) $project"
        ((proj_num++))
    done
    echo "  0) None"
    
    echo -n "\nEnter number: "
    read -r choice
    
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [[ $choice -le ${#successful_projects[@]} ]]; then
        local selected_project="${successful_projects[$choice]}"
        local project_to_open="$worktree_base/$selected_project"
        _open_in_intellij "$project_to_open"
    fi
}

# Command to list existing worktrees
list-worktrees() {
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "${fg[yellow]}No worktrees directory found${reset_color}"
        return 0
    fi
    
    echo "${fg[cyan]}📁 Active worktrees:${reset_color}\n"
    
    local found=0
    setopt local_options null_glob
    for worktree_dir in "$WORKTREES_DIR"/*(/); do
        local feature_name=$(basename "$worktree_dir")
        echo "${fg[green]}$feature_name${reset_color}"
        
        local has_projects=0
        for project_dir in "$worktree_dir"/*(/); do
            local project_name=$(basename "$project_dir")
            echo "  └─ $project_name"
            has_projects=1
        done
        
        if [[ $has_projects -eq 0 ]]; then
            echo "  ${fg[yellow]}(empty - no projects)${reset_color}"
        fi
        
        echo ""
        found=1
    done
    
    if [[ $found -eq 0 ]]; then
        echo "${fg[yellow]}No worktrees found${reset_color}"
    fi
}

# Command to check status of all main repositories
check-repos() {
    echo "${fg[cyan]}🔍 Checking repository status...${reset_color}\n"
    
    local clean_count=0
    local dirty_count=0
    local -a dirty_repos
    
    for project_dir in "$PROJECTS_DIR"/*(/); do
        local project_name=$(basename "$project_dir")
        
        # Check if it's a git repository
        if [[ ! -d "$project_dir/.git" ]]; then
            continue
        fi
        
        (
            cd "$project_dir" || return 1
            
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo "${fg[yellow]}⚠️  $project_name${reset_color} - has uncommitted changes"
                dirty_repos+=("$project_name")
                ((dirty_count++))
            else
                echo "${fg[green]}✓${reset_color}  $project_name"
                ((clean_count++))
            fi
        )
    done
    
    echo "\n${fg[cyan]}Summary:${reset_color}"
    echo "  Clean: $clean_count"
    echo "  Need attention: $dirty_count"
    
    if [[ $dirty_count -gt 0 ]]; then
        echo "\n${fg[yellow]}💡 Tip: Review and commit/stash changes in repositories with uncommitted changes before creating worktrees.${reset_color}"
    fi
}

# Command to switch all repositories from HTTPS to SSH
switch-to-ssh() {
    echo "${fg[cyan]}🔄 Converting repositories from HTTPS to SSH...${reset_color}\n"
    
    local converted=0
    local already_ssh=0
    local failed=0
    
    for project_dir in "$PROJECTS_DIR"/*(/); do
        local project_name=$(basename "$project_dir")
        
        # Check if it's a git repository
        if [[ ! -d "$project_dir/.git" ]]; then
            continue
        fi
        
        # Get current remote URL
        local remote_url=$(cd "$project_dir" && git remote get-url origin 2>/dev/null)
        
        if [[ -z "$remote_url" ]]; then
            echo "${fg[yellow]}⚠️  $project_name${reset_color} - no origin remote found"
            continue
        fi
        
        # Check if already using SSH
        if [[ "$remote_url" == git@* ]]; then
            echo "${fg[green]}✓${reset_color}  $project_name - already using SSH"
            ((already_ssh++))
            continue
        fi
        
        # Convert HTTPS to SSH
        if [[ "$remote_url" =~ https://github.com/([^/]+)/(.+) ]]; then
            local org="${match[1]}"
            local repo="${match[2]}"
            # Remove .git extension if present
            repo="${repo%.git}"
            local ssh_url="git@github.com:${org}/${repo}.git"
            
            (cd "$project_dir" && git remote set-url origin "$ssh_url")
            if [[ $? -eq 0 ]]; then
                echo "${fg[green]}✓${reset_color}  $project_name - converted to SSH"
                echo "    $ssh_url"
                ((converted++))
            else
                echo "${fg[red]}✗${reset_color}  $project_name - failed to update remote"
                ((failed++))
            fi
        else
            echo "${fg[yellow]}⚠️  $project_name${reset_color} - not a GitHub HTTPS URL"
        fi
    done
    
    echo "\n${fg[cyan]}Summary:${reset_color}"
    echo "  Converted: $converted"
    echo "  Already SSH: $already_ssh"
    if [[ $failed -gt 0 ]]; then
        echo "  Failed: $failed"
    fi
    
    if [[ $converted -gt 0 ]]; then
        echo "\n${fg[green]}✓ Repositories converted to SSH!${reset_color}"
        echo "${fg[cyan]}💡 Make sure you have SSH keys set up with GitHub:${reset_color}"
        echo "   https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    fi
}

# Command to remove a worktree
remove-worktree() {
    local worktree_name="$1"
    
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "${fg[red]}No worktrees directory found${reset_color}"
        return 1
    fi
    
    # If no worktree name provided, show interactive list
    if [[ -z "$worktree_name" ]]; then
        setopt local_options null_glob
        local -a worktrees=()
        
        for worktree_dir in "$WORKTREES_DIR"/*(/); do
            local wt_name=$(basename "$worktree_dir")
            worktrees+=("$wt_name")
        done
        
        if [[ ${#worktrees[@]} -eq 0 ]]; then
            echo "${fg[yellow]}No worktrees found${reset_color}"
            return 0
        fi
        
        echo "${fg[cyan]}Select worktree to remove:${reset_color}\n"
        local i=1
        for wt in "${worktrees[@]}"; do
            echo "  $i) $wt"
            ((i++))
        done
        echo "  0) Cancel"
        
        echo -n "\nEnter number: "
        read -r choice
        
        if [[ "$choice" == "0" ]] || [[ -z "$choice" ]]; then
            return 0
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#worktrees[@]} ]]; then
            worktree_name="${worktrees[$choice]}"
        else
            echo "${fg[red]}Invalid choice${reset_color}"
            return 1
        fi
    fi
    
    local worktree_path="$WORKTREES_DIR/$worktree_name"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo "${fg[red]}Worktree not found: $worktree_name${reset_color}"
        return 1
    fi
    
    # Get list of projects in this worktree
    local -a projects=()
    for proj_dir in "$worktree_path"/*(/); do
        projects+=($(basename "$proj_dir"))
    done
    
    # Get branch name from first project (they should all be the same)
    local branch_name=""
    if [[ ${#projects[@]} -gt 0 ]]; then
        local first_proj="$worktree_path/${projects[1]}"
        local first_proj_name="${projects[1]}"
        local main_repo="$PROJECTS_DIR/$first_proj_name"
        
        # Method 1: Get from main repo's worktree list (most reliable)
        if [[ -d "$main_repo/.git" ]]; then
            branch_name=$(cd "$main_repo" && git worktree list --porcelain 2>/dev/null | \
                grep -A 3 "worktree $first_proj" | \
                grep "^branch " | \
                sed 's/^branch refs\/heads\///')
        fi
        
        # Method 2: Get from worktree itself
        if [[ -z "$branch_name" ]] && [[ -d "$first_proj/.git" ]]; then
            branch_name=$(cd "$first_proj" && git branch --show-current 2>/dev/null)
        fi
        
        # Method 3: Read from .git/HEAD file directly
        if [[ -z "$branch_name" ]] && [[ -f "$first_proj/.git/HEAD" ]]; then
            local head_content=$(cat "$first_proj/.git/HEAD")
            if [[ "$head_content" =~ ref:\ refs/heads/(.*) ]]; then
                branch_name="${match[1]}"
            fi
        fi
    fi
    
    echo "\n${fg[cyan]}Worktree:${reset_color} $worktree_name"
    echo "${fg[cyan]}Projects:${reset_color} ${projects[*]}"
    if [[ -n "$branch_name" ]]; then
        echo "${fg[cyan]}Branch:${reset_color} $branch_name\n"
    else
        echo "${fg[yellow]}Branch:${reset_color} ${fg[red]}(could not detect - branch deletion will be skipped)${reset_color}\n"
    fi
    
    # Ask what to do
    echo "${fg[yellow]}What do you want to do?${reset_color}"
    echo "  1) Remove worktree only (keep all branches)"
    echo "  2) Remove worktree + delete local branches (default)"
    echo "  0) Cancel"
    
    echo -n "\nEnter number [2]: "
    read -r remove_choice
    
    if [[ "$remove_choice" == "0" ]]; then
        return 0
    fi
    
    local delete_branches=false
    if [[ -z "$remove_choice" ]] || [[ "$remove_choice" == "2" ]]; then
        delete_branches=true
    fi
    
    # If deleting branches, ask about remote
    local delete_remote=false
    if [[ "$delete_branches" == true ]]; then
        echo ""
        echo -n "${fg[yellow]}Also delete remote branches? [y/N]:${reset_color} "
        read -r remote_choice
        if [[ "$remote_choice" =~ ^[Yy]$ ]]; then
            delete_remote=true
            echo "${fg[green]}✓ Will delete remote branches${reset_color}"
        else
            echo "${fg[cyan]}→ Remote branches will be kept${reset_color}"
        fi
    fi
    
    echo ""
    
    # Process each project
    for project in "${projects[@]}"; do
        echo "${fg[blue]}━━━ Processing $project ━━━${reset_color}"
        
        local project_dir="$worktree_path/$project"
        local main_repo="$PROJECTS_DIR/$project"
        
        if [[ ! -d "$main_repo/.git" ]]; then
            echo "${fg[yellow]}  ⚠️  Main repo not found, skipping...${reset_color}\n"
            continue
        fi
        
        # Get branch name for this project - use multiple methods for robustness
        local project_branch=""
        
        # Method 1: Get from main repo's worktree list (most reliable)
        if [[ -z "$project_branch" ]]; then
            project_branch=$(cd "$main_repo" && git worktree list --porcelain 2>/dev/null | \
                grep -A 3 "worktree $(cd "$project_dir" && pwd)" | \
                grep "^branch " | \
                sed 's/^branch refs\/heads\///')
        fi
        
        # Method 2: Get from worktree itself
        if [[ -z "$project_branch" ]] && [[ -d "$project_dir/.git" ]]; then
            project_branch=$(cd "$project_dir" && git branch --show-current 2>/dev/null)
        fi
        
        # Method 3: Read from .git/HEAD file directly
        if [[ -z "$project_branch" ]] && [[ -f "$project_dir/.git/HEAD" ]]; then
            local head_content=$(cat "$project_dir/.git/HEAD")
            if [[ "$head_content" =~ ref:\ refs/heads/(.*) ]]; then
                project_branch="${match[1]}"
            fi
        fi
        
        # If we still don't have a branch name, warn the user
        if [[ -z "$project_branch" ]]; then
            echo "${fg[yellow]}  ⚠️  Warning: Could not detect branch name for $project${reset_color}"
            if [[ "$delete_branches" == true ]]; then
                echo "${fg[yellow]}     Cannot delete branches without branch name${reset_color}"
            fi
        else
            echo "${fg[cyan]}  → Branch detected: $project_branch${reset_color}"
        fi
        
        # Remove worktree
        echo "  🗑️  Removing worktree..."
        (
            cd "$main_repo" || return 1
            git worktree remove "$project_dir" 2>/dev/null
            if [[ $? -ne 0 ]]; then
                # Try force remove if normal remove fails
                git worktree remove --force "$project_dir" 2>/dev/null
            fi
        )
        
        if [[ "$delete_branches" == true ]] && [[ -n "$project_branch" ]]; then
            # Check if branch is merged
            echo "  🗑️  Deleting local branch: $project_branch..."
            (
                cd "$main_repo" || return 1
                
                # Check if branch is merged
                if git branch --merged "$MAIN_BRANCH" | grep -q "^\s*${project_branch}$"; then
                    echo "    ${fg[green]}✓ Branch is merged${reset_color}"
                else
                    echo "    ${fg[yellow]}⚠️  Branch is NOT merged${reset_color}"
                fi
                
                git branch -d "$project_branch" 2>/dev/null
                if [[ $? -ne 0 ]]; then
                    echo "    ${fg[yellow]}⚠️  Could not delete (use -D to force). Trying force delete...${reset_color}"
                    git branch -D "$project_branch" 2>/dev/null
                    if [[ $? -eq 0 ]]; then
                        echo "    ${fg[green]}✓ Force deleted${reset_color}"
                    fi
                else
                    echo "    ${fg[green]}✓ Local branch deleted${reset_color}"
                fi
            )
            
            if [[ "$delete_remote" == true ]]; then
                echo "  🗑️  Deleting remote branch: $project_branch..."
                (
                    cd "$main_repo" || return 1
                    
                    # First check if the remote branch actually exists
                    if git ls-remote --heads origin "$project_branch" 2>/dev/null | grep -q "$project_branch"; then
                        # Branch exists on remote, try to delete it
                        if git push origin --delete "$project_branch" 2>&1; then
                            echo "    ${fg[green]}✓ Remote branch deleted${reset_color}"
                        else
                            echo "    ${fg[red]}✗ Failed to delete remote branch${reset_color}"
                            echo "    ${fg[yellow]}⚠️  You may need to delete it manually or check your permissions${reset_color}"
                        fi
                    else
                        echo "    ${fg[yellow]}⚠️  Remote branch does not exist (may have been deleted already)${reset_color}"
                    fi
                )
            fi
        fi
        
        echo ""
    done
    
    # Check if current directory is inside the worktree being deleted
    local current_dir=$(pwd 2>/dev/null)
    if [[ "$current_dir" == "$worktree_path"* ]]; then
        echo "${fg[yellow]}⚠️  You're currently inside this worktree, moving to safe location...${reset_color}"
        cd "$WORKTREES_DIR" 2>/dev/null || cd "$HOME"
        echo ""
    fi
    
    # Remove the worktree directory
    rm -rf "$worktree_path"
    
    echo "${fg[green]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
    echo "${fg[green]}✓ Worktree cleanup complete!${reset_color}"
    
    if [[ "$delete_branches" == "false" && "$delete_remote" == "false" ]]; then
        echo "${fg[yellow]}💡 Note: Local and remote branches still exist${reset_color}"
    elif [[ "$delete_remote" == "false" ]]; then
        echo "${fg[yellow]}💡 Note: Remote branches still exist${reset_color}"
    fi
}

# Command to clean up empty worktree directories
cleanup-empty() {
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "${fg[yellow]}No worktrees directory found${reset_color}"
        return 0
    fi
    
    echo "${fg[cyan]}🧹 Cleaning up empty worktree directories...${reset_color}\n"
    
    local removed=0
    setopt local_options null_glob
    
    for worktree_dir in "$WORKTREES_DIR"/*(/); do
        local feature_name=$(basename "$worktree_dir")
        
        # Check if directory is empty or has no subdirectories
        local has_projects=0
        for project_dir in "$worktree_dir"/*(/); do
            has_projects=1
            break
        done
        
        if [[ $has_projects -eq 0 ]]; then
            echo "  🗑️  Removing empty: $feature_name"
            rm -rf "$worktree_dir"
            ((removed++))
        fi
    done
    
    if [[ $removed -eq 0 ]]; then
        echo "${fg[green]}✓ No empty directories found${reset_color}"
    else
        echo "\n${fg[green]}✓ Removed $removed empty worktree directory/directories${reset_color}"
    fi
}

# Command to check IntelliJ IDEA installation
check-intellij() {
    echo "${fg[cyan]}🔍 Checking IntelliJ IDEA installation...${reset_color}\n"
    
    # Check macOS applications first
    echo "${fg[cyan]}IntelliJ IDEA applications:${reset_color}"
    local intellij_paths=(
        "/Applications/IntelliJ IDEA.app"
        "/Applications/IntelliJ IDEA Ultimate.app"
        "/Applications/IntelliJ IDEA CE.app"
        "/Applications/IntelliJ IDEA Community Edition.app"
        "$HOME/Applications/IntelliJ IDEA.app"
    )
    
    local found_app=false
    for app_path in "${intellij_paths[@]}"; do
        if [[ -d "$app_path" ]]; then
            echo "  ${fg[green]}✓${reset_color} Found: $app_path"
            found_app=true
        fi
    done
    
    if [[ "$found_app" == "false" ]]; then
        echo "  ${fg[yellow]}No IntelliJ IDEA applications found${reset_color}"
    fi
    
    echo ""
    
    # Check command-line launchers
    echo "${fg[cyan]}Command-line launchers:${reset_color}"
    local idea_commands=("idea" "intellij-idea-ultimate" "intellij-idea-ce")
    local found_cmd=false
    
    for cmd in "${idea_commands[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            local cmd_path=$(which $cmd)
            # Test if it's executable and not broken
            if "$cmd" --help &> /dev/null || "$cmd" -h &> /dev/null || [[ -x "$cmd_path" ]]; then
                echo "  ${fg[green]}✓${reset_color} $cmd found at: $cmd_path"
                found_cmd=true
            else
                echo "  ${fg[yellow]}⚠${reset_color}  $cmd found at $cmd_path but may be broken"
            fi
        else
            echo "  ${fg[red]}✗${reset_color} $cmd not found"
        fi
    done
    
    echo ""
    
    if [[ "$found_app" == "true" ]]; then
        echo "${fg[green]}✓ IntelliJ IDEA will open via macOS application${reset_color}"
    elif [[ "$found_cmd" == "true" ]]; then
        echo "${fg[green]}✓ IntelliJ IDEA will open via command-line launcher${reset_color}"
    else
        echo "${fg[yellow]}⚠️  IntelliJ IDEA not detected${reset_color}"
        echo "\n${fg[cyan]}To enable automatic opening:${reset_color}"
        echo "  1. Install IntelliJ IDEA to /Applications/"
        echo "  2. Or create command-line launcher:"
        echo "     IntelliJ IDEA → Tools → Create Command-line Launcher..."
    fi
}

# Convenience wrapper for creating bug worktrees
new-bug() {
    local bug_name="$1"
    local spec_template=""
    
    # Parse arguments for --spec flag
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --spec)
                spec_template="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ -z "$bug_name" ]]; then
        echo "${fg[red]}Error: Please provide a bug name${reset_color}"
        echo "Usage: new-bug <bug-name> [--spec <template-type>]"
        return 1
    fi
    
    # Call new-feature with bugfix preset and optional spec template
    if [[ -n "$spec_template" ]]; then
        new-feature "$bug_name" "bugfix" --spec "$spec_template"
    else
        new-feature "$bug_name" "bugfix"
    fi
}

# Command to checkout an existing remote branch into worktrees
checkout-worktree() {
    local branch_name="$1"
    shift  # Remove branch name from args
    
    if [[ -z "$branch_name" ]]; then
        echo "${fg[red]}Error: Please provide a branch name${reset_color}"
        echo "Usage: checkout-worktree <branch-name> [project1 project2 ...] [--all]"
        echo "Examples:"
        echo "  cw feature/payment-flow arrakis wallet  # Fast: only check specified projects"
        echo "  cw feature/payment-flow --all           # Slower: search all projects"
        echo "  cw feature/payment-flow                 # Interactive: ask which projects to check"
        return 1
    fi
    
    # Extract feature name from branch (remove prefix like feature/, bugfix/, etc.)
    local feature_name=$(echo "$branch_name" | sed 's|^[^/]*/||')
    local worktree_base="$WORKTREES_DIR/$feature_name"
    
    # Check if worktree directory already exists
    if [[ -d "$worktree_base" ]]; then
        echo "${fg[yellow]}Warning: Worktree directory already exists: $worktree_base${reset_color}"
        echo -n "Do you want to add more projects to it? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return 1
        fi
        echo ""
    else
        mkdir -p "$worktree_base"
    fi
    
    # Parse arguments: collect project names and check for --all flag
    local -a specified_projects=()
    local search_all=false
    
    for arg in "$@"; do
        if [[ "$arg" == "--all" ]]; then
            search_all=true
        else
            specified_projects+=("$arg")
        fi
    done
    
    # Get list of all available projects
    local -a all_available_projects=()
    for project_dir in "$PROJECTS_DIR"/*(/); do
        local project_name=$(basename "$project_dir")
        if [[ -d "$project_dir/.git" ]]; then
            all_available_projects+=("$project_name")
        fi
    done
    
    if [[ ${#all_available_projects[@]} -eq 0 ]]; then
        echo "${fg[red]}Error: No git repositories found in $PROJECTS_DIR${reset_color}"
        return 1
    fi
    
    # Determine which projects to check
    local -a projects_to_check=()
    
    if [[ "$search_all" == "true" ]]; then
        # --all flag: check all projects
        projects_to_check=("${all_available_projects[@]}")
        echo "${fg[cyan]}🔍 Searching ALL projects for branch '$branch_name'...${reset_color}"
        echo "${fg[yellow]}⚠️  This may take a while as it checks all ${#projects_to_check[@]} projects${reset_color}\n"
    elif [[ ${#specified_projects[@]} -gt 0 ]]; then
        # Projects specified: validate and use them
        for proj in "${specified_projects[@]}"; do
            if [[ ! -d "$PROJECTS_DIR/$proj/.git" ]]; then
                echo "${fg[yellow]}Warning: Project '$proj' not found, skipping${reset_color}"
            else
                projects_to_check+=("$proj")
            fi
        done
        
        if [[ ${#projects_to_check[@]} -eq 0 ]]; then
            echo "${fg[red]}Error: None of the specified projects exist${reset_color}"
            return 1
        fi
        
        echo "${fg[cyan]}🔍 Checking ${#projects_to_check[@]} specified project(s) for branch '$branch_name'...${reset_color}\n"
    else
        # No projects specified: interactive selection
        echo "${fg[cyan]}Which projects do you want to check?${reset_color}"
        echo "  1) Specify projects"
        echo "  2) Search all projects (slower)"
        echo "  0) Cancel"
        echo -n "\nEnter choice [1]: "
        read -r scope_choice
        
        case "$scope_choice" in
            0)
                echo "Cancelled"
                return 0
                ;;
            2)
                # Search all
                projects_to_check=("${all_available_projects[@]}")
                echo "\n${fg[yellow]}⚠️  Checking all ${#projects_to_check[@]} projects (this may take a while)...${reset_color}\n"
                ;;
            *)
                # Let user select specific projects
                echo "\n${fg[green]}Available projects:${reset_color}"
                local i=1
                for proj in "${all_available_projects[@]}"; do
                    echo "  $i) $proj"
                    ((i++))
                done
                
                echo -n "\n${fg[cyan]}Enter project numbers (space-separated, e.g., '1 3 5'):${reset_color} "
                read -r selection
                
                for num in ${=selection}; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#all_available_projects[@]} ]]; then
                        projects_to_check+=("${all_available_projects[$num]}")
                    fi
                done
                
                if [[ ${#projects_to_check[@]} -eq 0 ]]; then
                    echo "${fg[red]}Error: No valid projects selected${reset_color}"
                    return 1
                fi
                
                echo "\n${fg[cyan]}Checking selected projects:${reset_color} ${projects_to_check[*]}\n"
                ;;
        esac
    fi
    
    # Now check only the selected projects for the branch
    local -a projects_with_branch=()
    
    for project_name in "${projects_to_check[@]}"; do
        local project_dir="$PROJECTS_DIR/$project_name"
        
        # Fetch and check if branch exists on remote
        (
            cd "$project_dir" || return 1
            git fetch origin &>/dev/null
            if git show-ref --verify --quiet "refs/remotes/origin/$branch_name"; then
                return 0
            else
                return 1
            fi
        )
        
        if [[ $? -eq 0 ]]; then
            projects_with_branch+=("$project_name")
        fi
    done
    
    if [[ ${#projects_with_branch[@]} -eq 0 ]]; then
        echo "${fg[red]}Error: Branch '$branch_name' not found on remote in any checked project${reset_color}"
        echo "${fg[cyan]}Projects checked:${reset_color} ${projects_to_check[*]}"
        if [[ "$search_all" != "true" ]] && [[ ${#specified_projects[@]} -eq 0 ]]; then
            echo "${fg[cyan]}Tip: Try 'cw $branch_name --all' to search all projects${reset_color}"
        fi
        return 1
    fi
    
    # Display projects that have this branch
    echo "${fg[green]}Found branch '$branch_name' in:${reset_color}"
    for proj in "${projects_with_branch[@]}"; do
        echo "  ✓ $proj"
    done
    echo ""
    
    # Ask which projects to checkout
    echo "${fg[cyan]}Which projects do you want to checkout?${reset_color}"
    echo "  1) All projects with this branch (${#projects_with_branch[@]} projects)"
    echo "  2) Select specific projects"
    echo "  0) Cancel"
    echo -n "\nEnter choice [1]: "
    read -r choice
    
    local -a selected_projects
    case "$choice" in
        0)
            echo "Cancelled"
            return 0
            ;;
        2)
            # Interactive selection
            echo ""
            local i=1
            for proj in "${projects_with_branch[@]}"; do
                echo "  $i) $proj"
                ((i++))
            done
            
            echo -n "\n${fg[cyan]}Enter project numbers (space-separated, e.g., '1 3 5'):${reset_color} "
            read -r selection
            
            for num in ${=selection}; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#projects_with_branch[@]} ]]; then
                    selected_projects+=("${projects_with_branch[$num]}")
                fi
            done
            ;;
        *)
            # All projects
            selected_projects=("${projects_with_branch[@]}")
            ;;
    esac
    
    if [[ ${#selected_projects[@]} -eq 0 ]]; then
        echo "${fg[red]}Error: No projects selected${reset_color}"
        return 1
    fi
    
    echo "\n${fg[green]}Selected projects:${reset_color} ${selected_projects[*]}\n"
    
    # Process each selected project
    local -a successful_projects
    for project in "${selected_projects[@]}"; do
        echo "${fg[blue]}━━━ Processing $project ━━━${reset_color}"
        
        local project_path="$PROJECTS_DIR/$project"
        local worktree_path="$worktree_base/$project"
        
        # Check if worktree already exists for this project
        if [[ -d "$worktree_path" ]]; then
            echo "${fg[yellow]}  ⚠️  Worktree already exists for $project, skipping...${reset_color}\n"
            successful_projects+=("$project")
            continue
        fi
        
        # Create worktree tracking the remote branch
        echo "  🌳 Creating worktree tracking remote branch..."
        (
            cd "$project_path" || return 1
            
            # Check if local branch already exists
            if git show-ref --verify --quiet "refs/heads/$branch_name"; then
                echo "  ${fg[yellow]}  ⚠️  Local branch already exists, using it${reset_color}"
                git worktree add "$worktree_path" "$branch_name"
            else
                # Create new local branch tracking remote
                git worktree add -b "$branch_name" "$worktree_path" "origin/$branch_name"
            fi
            
            if [[ $? -ne 0 ]]; then
                echo "${fg[red]}    ✗ Failed to create worktree${reset_color}"
                return 1
            fi
        )
        
        if [[ $? -ne 0 ]]; then
            echo "${fg[red]}  ✗ Failed to create worktree for $project${reset_color}\n"
            continue
        fi
        
        # Create .java-version file if needed
        echo "  ☕ Checking Java version..."
        _create_java_version_file "$worktree_path"
        
        successful_projects+=("$project")
        echo "${fg[green]}  ✓ $project worktree created successfully${reset_color}\n"
    done
    
    # Summary
    if [[ ${#successful_projects[@]} -eq 0 ]]; then
        echo "${fg[red]}❌ No worktrees were created successfully${reset_color}"
        return 1
    fi
    
    echo "${fg[green]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
    echo "${fg[green]}✓ Checkout complete!${reset_color}\n"
    echo "${fg[cyan]}Worktree location:${reset_color} $worktree_base"
    echo "${fg[cyan]}Branch name:${reset_color} $branch_name"
    echo "${fg[cyan]}Projects:${reset_color} ${successful_projects[*]}\n"
    
    # Ask which project to open in IntelliJ
    if [[ ${#successful_projects[@]} -gt 1 ]]; then
        echo "${fg[cyan]}Which project would you like to open in IntelliJ?${reset_color}"
        local i=1
        for project in "${successful_projects[@]}"; do
            echo "  $i) $project"
            ((i++))
        done
        echo "  0) None"
        
        echo -n "\nEnter number: "
        read -r project_num
        
        if [[ "$project_num" =~ ^[0-9]+$ ]] && [[ $project_num -ge 1 ]] && [[ $project_num -le ${#successful_projects[@]} ]]; then
            local selected_project="${successful_projects[$project_num]}"
            _open_in_intellij "$worktree_base/$selected_project"
        fi
    elif [[ ${#successful_projects[@]} -eq 1 ]]; then
        echo -n "${fg[cyan]}Open ${successful_projects[1]} in IntelliJ? [Y/n]:${reset_color} "
        read -r response
        if [[ ! "$response" =~ ^[Nn]$ ]]; then
            _open_in_intellij "$worktree_base/${successful_projects[1]}"
        fi
    fi
}

# Command to switch to a worktree
switch-worktree() {
    local feature_name="$1"
    
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "${fg[red]}Error: No worktrees directory found${reset_color}"
        return 1
    fi
    
    # Get list of available worktrees
    setopt local_options null_glob
    local -a worktrees
    for worktree_dir in "$WORKTREES_DIR"/*(/); do
        local wt_name=$(basename "$worktree_dir")
        # Only include worktrees that have projects
        if [[ -n "$worktree_dir"/*(/N) ]]; then
            worktrees+=("$wt_name")
        fi
    done
    
    if [[ ${#worktrees[@]} -eq 0 ]]; then
        echo "${fg[yellow]}No worktrees found${reset_color}"
        return 1
    fi
    
    # If no feature name provided, show interactive list
    if [[ -z "$feature_name" ]]; then
        echo "${fg[cyan]}📁 Available worktrees:${reset_color}\n"
        local i=1
        for wt in "${worktrees[@]}"; do
            # Show projects in this worktree
            local -a wt_projects=()
            for project_dir in "$WORKTREES_DIR/$wt"/*(/); do
                wt_projects+=($(basename "$project_dir"))
            done
            echo "  $i) ${fg[green]}$wt${reset_color} (${wt_projects[*]})"
            ((i++))
        done
        
        echo -n "\nEnter number or name: "
        read -r selection
        
        # Check if it's a number
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#worktrees[@]} ]]; then
            feature_name="${worktrees[$selection]}"
        else
            feature_name="$selection"
        fi
    fi
    
    local worktree_path="$WORKTREES_DIR/$feature_name"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo "${fg[red]}Error: Worktree not found: $feature_name${reset_color}"
        echo "${fg[cyan]}Available worktrees:${reset_color} ${worktrees[*]}"
        return 1
    fi
    
    # Get list of projects in this worktree
    local -a projects=()
    for project_dir in "$worktree_path"/*(/); do
        local proj_name=$(basename "$project_dir")
        projects+=("$proj_name")
    done
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        echo "${fg[yellow]}Worktree has no projects${reset_color}"
        return 1
    fi
    
    echo "${fg[cyan]}Worktree: $feature_name${reset_color}"
    echo "${fg[cyan]}Projects: ${projects[*]}${reset_color}\n"
    
    # Ask which project to switch to
    if [[ ${#projects[@]} -eq 1 ]]; then
        local selected_project="${projects[1]}"
        cd "$worktree_path/$selected_project"
        echo "${fg[green]}✓ Switched to: $worktree_path/$selected_project${reset_color}"
    else
        echo "${fg[cyan]}Which project?${reset_color}"
        local i=1
        for proj in "${projects[@]}"; do
            echo "  $i) $proj"
            ((i++))
        done
        echo "  0) Just cd to worktree directory"
        
        echo -n "\nEnter number [1]: "
        read -r proj_num
        
        if [[ "$proj_num" == "0" ]]; then
            cd "$worktree_path"
            echo "${fg[green]}✓ Switched to: $worktree_path${reset_color}"
        elif [[ "$proj_num" =~ ^[0-9]+$ ]] && [[ $proj_num -ge 1 ]] && [[ $proj_num -le ${#projects[@]} ]]; then
            local selected_project="${projects[$proj_num]}"
            cd "$worktree_path/$selected_project"
            echo "${fg[green]}✓ Switched to: $worktree_path/$selected_project${reset_color}"
        else
            cd "$worktree_path/${projects[1]}"
            echo "${fg[green]}✓ Switched to: $worktree_path/${projects[1]}${reset_color}"
        fi
    fi
    
    # Ask if they want to open in IntelliJ
    echo -n "\n${fg[cyan]}Open in IntelliJ? [y/N]:${reset_color} "
    read -r open_response
    if [[ "$open_response" =~ ^[Yy]$ ]]; then
        if [[ ${#projects[@]} -eq 1 ]]; then
            _open_in_intellij "$worktree_path/${projects[1]}"
        else
            echo "${fg[cyan]}Which project to open?${reset_color}"
            local i=1
            for proj in "${projects[@]}"; do
                echo "  $i) $proj"
                ((i++))
            done
            
            echo -n "\nEnter number [1]: "
            read -r open_num
            
            if [[ "$open_num" =~ ^[0-9]+$ ]] && [[ $open_num -ge 1 ]] && [[ $open_num -le ${#projects[@]} ]]; then
                _open_in_intellij "$worktree_path/${projects[$open_num]}"
            else
                _open_in_intellij "$worktree_path/${projects[1]}"
            fi
        fi
    fi
}

# Command to sync worktree with master branch
sync-worktree() {
    local feature_name="$1"
    local strategy="${2:-merge}"  # merge or rebase
    
    # Detect current worktree if no feature name provided
    if [[ -z "$feature_name" ]]; then
        local current_dir=$(pwd)
        if [[ "$current_dir" == "$WORKTREES_DIR"* ]]; then
            # Extract feature name from path
            feature_name=$(echo "$current_dir" | sed "s|^$WORKTREES_DIR/||" | cut -d'/' -f1)
            echo "${fg[cyan]}Detected current worktree: $feature_name${reset_color}\n"
        else
            echo "${fg[red]}Error: Not in a worktree directory and no feature name provided${reset_color}"
            echo "Usage: sync-worktree [feature-name] [merge|rebase]"
            return 1
        fi
    fi
    
    local worktree_path="$WORKTREES_DIR/$feature_name"
    
    if [[ ! -d "$worktree_path" ]]; then
        echo "${fg[red]}Error: Worktree not found: $feature_name${reset_color}"
        return 1
    fi
    
    # Validate strategy
    if [[ "$strategy" != "merge" && "$strategy" != "rebase" ]]; then
        echo "${fg[red]}Error: Strategy must be 'merge' or 'rebase'${reset_color}"
        return 1
    fi
    
    echo "${fg[cyan]}🔄 Syncing worktree '$feature_name' with $MAIN_BRANCH using $strategy...${reset_color}\n"
    
    # Get list of projects in this worktree
    setopt local_options null_glob
    local -a projects=()
    for project_dir in "$worktree_path"/*(/); do
        projects+=($(basename "$project_dir"))
    done
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        echo "${fg[yellow]}No projects found in worktree${reset_color}"
        return 1
    fi
    
    local success_count=0
    local failed_count=0
    local -a failed_projects
    
    # Sync each project
    for project_name in "${projects[@]}"; do
        echo "${fg[blue]}━━━ Syncing $project_name ━━━${reset_color}"
        local project_dir="$worktree_path/$project_name"
        local main_repo="$PROJECTS_DIR/$project_name"
        
        if [[ ! -d "$main_repo/.git" ]]; then
            echo "${fg[yellow]}  ⚠️  Main repo not found, skipping...${reset_color}\n"
            ((failed_count++))
            failed_projects+=("$project_name")
            continue
        fi
        
        (
            cd "$project_dir" || return 1
            
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo "${fg[yellow]}  ⚠️  Uncommitted changes detected${reset_color}"
                echo "  Please commit or stash changes before syncing"
                return 1
            fi
            
            local current_branch=$(git branch --show-current)
            echo "  📍 Current branch: $current_branch"
            
            # Fetch latest from origin
            echo "  📥 Fetching latest from origin..."
            git fetch origin "$MAIN_BRANCH"
            if [[ $? -ne 0 ]]; then
                echo "${fg[red]}  ✗ Failed to fetch${reset_color}"
                return 1
            fi
            
            # Update main repo's master
            echo "  📥 Updating main repo's $MAIN_BRANCH..."
            (cd "$main_repo" && git fetch origin "$MAIN_BRANCH" && git checkout "$MAIN_BRANCH" && git pull origin "$MAIN_BRANCH") &> /dev/null
            
            # Perform merge or rebase
            if [[ "$strategy" == "rebase" ]]; then
                echo "  🔄 Rebasing onto origin/$MAIN_BRANCH..."
                git rebase "origin/$MAIN_BRANCH"
            else
                echo "  🔄 Merging origin/$MAIN_BRANCH..."
                git merge "origin/$MAIN_BRANCH"
            fi
            
            if [[ $? -ne 0 ]]; then
                echo "${fg[red]}  ✗ Conflicts detected!${reset_color}"
                echo "  Please resolve conflicts manually in: $project_dir"
                if [[ "$strategy" == "rebase" ]]; then
                    echo "  Then run: git rebase --continue"
                else
                    echo "  Then run: git merge --continue"
                fi
                return 1
            fi
            
            echo "${fg[green]}  ✓ Successfully synced with $MAIN_BRANCH${reset_color}"
            
            # Offer to push
            echo -n "  Push changes to remote? [y/N]: "
            read -r push_response
            if [[ "$push_response" =~ ^[Yy]$ ]]; then
                if [[ "$strategy" == "rebase" ]]; then
                    git push --force-with-lease
                else
                    git push
                fi
                if [[ $? -eq 0 ]]; then
                    echo "${fg[green]}  ✓ Pushed to remote${reset_color}"
                else
                    echo "${fg[yellow]}  ⚠️  Failed to push${reset_color}"
                fi
            fi
            
            return 0
        )
        
        if [[ $? -eq 0 ]]; then
            ((success_count++))
        else
            ((failed_count++))
            failed_projects+=("$project_name")
        fi
        
        echo ""
    done
    
    # Summary
    echo "${fg[cyan]}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset_color}"
    echo "${fg[cyan]}Summary:${reset_color}"
    echo "  Successful: $success_count"
    echo "  Failed: $failed_count"
    
    if [[ $failed_count -gt 0 ]]; then
        echo "  ${fg[yellow]}Failed projects: ${failed_projects[*]}${reset_color}"
    fi
    
    if [[ $success_count -eq ${#projects[@]} ]]; then
        echo "\n${fg[green]}✓ All projects synced successfully!${reset_color}"
    elif [[ $failed_count -eq ${#projects[@]} ]]; then
        echo "\n${fg[red]}✗ All projects failed to sync${reset_color}"
        return 1
    else
        echo "\n${fg[yellow]}⚠️  Some projects failed to sync${reset_color}"
        return 1
    fi
}

# Completion function for switch-worktree
_switch_worktree_completion() {
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        return
    fi
    
    setopt local_options null_glob
    local -a worktrees
    for worktree_dir in "$WORKTREES_DIR"/*(/); do
        local wt_name=$(basename "$worktree_dir")
        # Only include worktrees that have projects
        if [[ -n "$worktree_dir"/*(/N) ]]; then
            worktrees+=("$wt_name")
        fi
    done
    
    _describe 'worktree' worktrees
}

# Completion function for sync-worktree
_sync_worktree_completion() {
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        return
    fi
    
    case $CURRENT in
        2)
            # First argument: worktree name
            setopt local_options null_glob
            local -a worktrees
            for worktree_dir in "$WORKTREES_DIR"/*(/); do
                local wt_name=$(basename "$worktree_dir")
                if [[ -n "$worktree_dir"/*(/N) ]]; then
                    worktrees+=("$wt_name")
                fi
            done
            _describe 'worktree' worktrees
            ;;
        3)
            # Second argument: strategy
            local -a strategies
            strategies=('merge:Merge master into feature branch' 'rebase:Rebase feature branch onto master')
            _describe 'strategy' strategies
            ;;
    esac
}

# Completion function for remove-worktree (same as switch-worktree)
_remove_worktree_completion() {
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        return
    fi
    
    setopt local_options null_glob
    local -a worktrees
    for worktree_dir in "$WORKTREES_DIR"/*(/); do
        local wt_name=$(basename "$worktree_dir")
        worktrees+=("$wt_name")
    done
    
    _describe 'worktree' worktrees
}

# Aliases for convenience (must be defined before compdef registrations)
alias nf='new-feature'
alias nb='new-bug'
alias cw='checkout-worktree'
alias sw='switch-worktree'
alias sync='sync-worktree'
alias lw='list-worktrees'
alias rw='remove-worktree'
alias cr='check-repos'
alias ce='cleanup-empty'
alias ci='check-intellij'

# Register completion functions
if command -v compdef &> /dev/null; then
    compdef _switch_worktree_completion switch-worktree
    compdef _switch_worktree_completion sw
    compdef _sync_worktree_completion sync-worktree
    compdef _sync_worktree_completion sync
    compdef _remove_worktree_completion remove-worktree
    compdef _remove_worktree_completion rw
fi
