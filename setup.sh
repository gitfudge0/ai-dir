#!/bin/bash

# Agent Setup Script
# Installs agents for OpenCode or Claude Code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
CONFIG_FILE="$SCRIPT_DIR/agents.config.json"
BACKUP_DIR="$HOME/.agent-backups/$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if required files exist
check_prerequisites() {
    if [[ ! -d "$AGENTS_DIR" ]]; then
        print_error "Agents directory not found: $AGENTS_DIR"
        exit 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq not found. Using simple JSON parsing."
    fi
}

# Create backup of existing agent directories
create_backup() {
    local target_tool="$1"
    
    print_info "Creating backup in $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    case "$target_tool" in
        "opencode"|"both")
            if [[ -d "$HOME/.config/opencode/agent" ]]; then
                print_info "Backing up OpenCode agents"
                cp -r "$HOME/.config/opencode/agent" "$BACKUP_DIR/opencode_agents" 2>/dev/null || true
            fi
            ;;
    esac
    
    case "$target_tool" in
        "claude"|"both")
            if [[ -d "$HOME/.claude/agents" ]]; then
                print_info "Backing up Claude Code agents"
                cp -r "$HOME/.claude/agents" "$BACKUP_DIR/claude_agents" 2>/dev/null || true
            fi
            ;;
    esac
}

# Parse JSON config (simple bash approach)
get_agent_config() {
    local agent_name="$1"
    local field="$2"
    
    # Extract the agent block and get the field value
    if command -v jq >/dev/null 2>&1; then
        jq -r ".agents[\"$agent_name\"][\"$field\"] // empty" "$CONFIG_FILE"
    else
        # Fallback: simple grep/sed approach
        grep -A 10 "\"$agent_name\":" "$CONFIG_FILE" | grep "\"$field\":" | sed 's/.*: *"\([^"]*\)".*/\1/' | head -n1
    fi
}

# Get tools array for an agent
get_agent_tools() {
    local agent_name="$1"
    
    if command -v jq >/dev/null 2>&1; then
        jq -r ".agents[\"$agent_name\"][\"tools\"] | join(\", \")" "$CONFIG_FILE"
    else
        # Fallback: extract tools array manually
        local tools_line=$(grep -A 5 "\"$agent_name\":" "$CONFIG_FILE" | grep "\"tools\":")
        echo "$tools_line" | sed 's/.*\[\(.*\)\].*/\1/' | sed 's/"//g'
    fi
}

# Generate frontmatter for OpenCode
generate_opencode_frontmatter() {
    local agent_name="$1"
    local description mode model
    
    description=$(get_agent_config "$agent_name" "description")
    mode=$(get_agent_config "$agent_name" "mode")
    model=$(get_agent_config "$agent_name" "opencode_model")
    
    cat << EOF
---
description: $description
mode: $mode
model: $model
---

EOF
}

# Generate frontmatter for Claude Code
generate_claude_frontmatter() {
    local agent_name="$1"
    local name description tools
    
    name=$(get_agent_config "$agent_name" "name")
    description=$(get_agent_config "$agent_name" "description")
    tools=$(get_agent_tools "$agent_name")
    
    cat << EOF
---
name: $name
description: $description
tools: [$tools]
model: sonnet
---

EOF
}

# Install agents for OpenCode
install_opencode_agents() {
    local opencode_dir="$HOME/.config/opencode/agent"
    
    print_info "Installing agents for OpenCode"
    mkdir -p "$opencode_dir"
    
    for agent_file in "$AGENTS_DIR"/*.md; do
        local agent_name=$(basename "$agent_file" .md)
        local target_file="$opencode_dir/$agent_name.md"
        
        print_info "Installing $agent_name for OpenCode"
        
        # Generate frontmatter and combine with agent content
        {
            generate_opencode_frontmatter "$agent_name"
            cat "$agent_file"
        } > "$target_file"
    done
    
    print_success "OpenCode agents installed to $opencode_dir"
}

# Install agents for Claude Code
install_claude_agents() {
    local claude_dir="$HOME/.claude/agents"
    
    print_info "Installing agents for Claude Code"
    mkdir -p "$claude_dir"
    
    for agent_file in "$AGENTS_DIR"/*.md; do
        local agent_name=$(basename "$agent_file" .md)
        local target_file="$claude_dir/$agent_name.md"
        
        print_info "Installing $agent_name for Claude Code"
        
        # Generate frontmatter and combine with agent content
        {
            generate_claude_frontmatter "$agent_name"
            cat "$agent_file"
        } > "$target_file"
    done
    
    print_success "Claude Code agents installed to $claude_dir"
}

# Show agent selection menu
select_agents() {
    print_info "Available agents:" >&2
    local agents=()
    local i=1
    
    for agent_file in "$AGENTS_DIR"/*.md; do
        local agent_name=$(basename "$agent_file" .md)
        local description=$(get_agent_config "$agent_name" "description")
        agents+=("$agent_name")
        echo "  $i) $agent_name - $description" >&2
        ((i++))
    done
    
    echo "  $i) All agents" >&2
    agents+=("all")
    
    echo "" >&2
    read -p "Select agents to install (comma-separated numbers or 'all'): " selection >&2
    
    if [[ "$selection" == "all" || "$selection" == "$i" ]]; then
        echo "all"
        return
    fi
    
    # Parse selected numbers
    local selected_agents=()
    IFS=',' read -ra ADDR <<< "$selection"
    for num in "${ADDR[@]}"; do
        num=$(echo "$num" | xargs) # trim whitespace
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#agents[@]}" ]; then
            selected_agents+=("${agents[$((num-1))]}")
        fi
    done
    
    echo "${selected_agents[@]}"
}

# Install selected agents
install_selected_agents() {
    local target_tool="$1"
    local selected_agents="$2"
    
    if [[ "$selected_agents" == "all" ]]; then
        case "$target_tool" in
            "opencode") install_opencode_agents ;;
            "claude") install_claude_agents ;;
            "both") 
                install_opencode_agents
                install_claude_agents
                ;;
        esac
        return
    fi
    
    # Install specific agents
    IFS=' ' read -ra agents_array <<< "$selected_agents"
    
    for agent_name in "${agents_array[@]}"; do
        local agent_file="$AGENTS_DIR/$agent_name.md"
        
        if [[ ! -f "$agent_file" ]]; then
            print_warning "Agent file not found: $agent_file"
            continue
        fi
        
        case "$target_tool" in
            "opencode"|"both")
                local opencode_dir="$HOME/.config/opencode/agent"
                mkdir -p "$opencode_dir"
                local target_file="$opencode_dir/$agent_name.md"
                {
                    generate_opencode_frontmatter "$agent_name"
                    cat "$agent_file"
                } > "$target_file"
                print_success "Installed $agent_name for OpenCode"
                ;;
        esac
        
        case "$target_tool" in
            "claude"|"both")
                local claude_dir="$HOME/.claude/agents"
                mkdir -p "$claude_dir"
                local target_file="$claude_dir/$agent_name.md"
                {
                    generate_claude_frontmatter "$agent_name"
                    cat "$agent_file"
                } > "$target_file"
                print_success "Installed $agent_name for Claude Code"
                ;;
        esac
    done
}

# Main function
main() {
    echo "========================================="
    echo "      Agent Setup Script"
    echo "========================================="
    echo ""
    
    check_prerequisites
    
    # Tool selection menu
    print_info "Select target tool:"
    select tool in "OpenCode" "Claude Code" "Both" "Quit"; do
        case $tool in
            "OpenCode") 
                target="opencode"
                break
                ;;
            "Claude Code") 
                target="claude"
                break
                ;;
            "Both") 
                target="both"
                break
                ;;
            "Quit") 
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid selection. Please choose 1-4."
                ;;
        esac
    done
    
    print_info "Selected: $tool"
    echo ""
    
    # Create backup
    create_backup "$target"
    echo ""
    
    # Agent selection
    selected_agents=$(select_agents)
    echo ""
    
    # Confirm installation
    if [[ "$selected_agents" == "all" ]]; then
        print_info "Installing ALL agents for $tool"
    else
        print_info "Installing selected agents for $tool: $selected_agents"
    fi
    
    read -p "Proceed with installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    print_info "Starting installation..."
    
    # Install agents
    install_selected_agents "$target" "$selected_agents"
    
    echo ""
    print_success "Installation completed successfully!"
    print_info "Backup created in: $BACKUP_DIR"
    
    # Show installation summary
    echo ""
    print_info "Installation Summary:"
    case "$target" in
        "opencode") 
            echo "  - OpenCode agents: $HOME/.config/opencode/agent"
            ;;
        "claude") 
            echo "  - Claude Code agents: $HOME/.claude/agents"
            ;;
        "both") 
            echo "  - OpenCode agents: $HOME/.config/opencode/agent"
            echo "  - Claude Code agents: $HOME/.claude/agents"
            ;;
    esac
    
    echo ""
    print_success "Setup complete! Your agents are ready to use."
}

# Run main function only when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi