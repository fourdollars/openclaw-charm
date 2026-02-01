#!/bin/bash
# OpenClaw Juju Charm - Common Functions

set -e

# Logging functions
log_info() {
    juju-log -l INFO "$1"
    echo "[INFO] $1"
}

log_error() {
    juju-log -l ERROR "$1"
    echo "[ERROR] $1" >&2
}

log_debug() {
    juju-log -l DEBUG "$1"
    echo "[DEBUG] $1"
}

# Install Node.js using NodeSource repository
install_nodejs() {
    local node_version
    node_version="$(config-get node-version)"
    
    log_info "Installing Node.js version $node_version"
    
    # Check if Node.js is already installed with correct version
    if command -v node >/dev/null 2>&1; then
        local current_version
        current_version=$(node --version | cut -d'.' -f1 | sed 's/v//')
        if [ "$current_version" -eq "$node_version" ]; then
            log_info "Node.js $node_version already installed"
            return 0
        fi
    fi
    
    # Install from NodeSource
    curl -fsSL "https://deb.nodesource.com/setup_${node_version}.x" | bash -
    apt-get install -y nodejs
    
    # Verify installation
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js installation failed"
        exit 1
    fi
    
    local installed_version
    installed_version=$(node --version)
    log_info "Node.js installed: $installed_version"
}

# Install Bun runtime
install_bun() {
    log_info "Installing Bun runtime"
    
    # Check if Bun is already installed
    if command -v bun >/dev/null 2>&1; then
        local current_version
        current_version=$(bun --version)
        log_info "Bun already installed: v$current_version"
        return 0
    fi
    
    # Install Bun to /home/ubuntu/.bun as ubuntu user
    export BUN_INSTALL="/home/ubuntu/.bun"
    mkdir -p "$BUN_INSTALL"
    chown -R ubuntu:ubuntu "$BUN_INSTALL"
    
    su - ubuntu -c "curl -fsSL https://bun.sh/install | bash"
    
    if [ ! -f "$BUN_INSTALL/bin/bun" ]; then
        log_error "Bun installation failed - binary not found"
        exit 1
    fi
    
    # Make bun accessible system-wide
    ln -sf "$BUN_INSTALL/bin/bun" /usr/local/bin/bun
    
    # Verify installation
    if ! command -v bun >/dev/null 2>&1; then
        log_error "Bun installation failed - command not available"
        exit 1
    fi
    
    local installed_version
    installed_version=$(bun --version)
    log_info "Bun installed: v$installed_version"
}

# Generate OpenClaw configuration
generate_config() {
    local config_file="/home/ubuntu/.openclaw/openclaw.json"
    local ai_provider ai_model api_key
    local gateway_port gateway_bind log_level
    
    ai_provider="$(config-get ai-provider)"
    ai_model="$(config-get ai-model)"
    api_key="$(config-get api-key)"
    gateway_port="$(config-get gateway-port)"
    gateway_bind="$(config-get gateway-bind)"
    log_level="$(config-get log-level)"
    
    log_info "Generating OpenClaw configuration"
    
    # Generate gateway token (48 hex chars)
    local gateway_token
    gateway_token=$(openssl rand -hex 24)
    
    # Build minimal config with new format
    cat > "$config_file" <<EOF
{
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "${gateway_token}"
    },
    "bind": "${gateway_bind}",
    "port": ${gateway_port}
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "${ai_provider}/${ai_model}"
      }
    }
  },
  "logging": {
    "level": "${log_level}"
  },
  "channels": {
EOF
    
    # Add platform-specific messenger configs
    local telegram_bot_token discord_bot_token slack_bot_token slack_app_token
    telegram_bot_token="$(config-get telegram-bot-token)"
    discord_bot_token="$(config-get discord-bot-token)"
    slack_bot_token="$(config-get slack-bot-token)"
    slack_app_token="$(config-get slack-app-token)"
    
    if [ -n "$telegram_bot_token" ]; then
        cat >> "$config_file" <<EOF
    "telegram": {
      "botToken": "${telegram_bot_token}"
    },
EOF
    fi
    
    if [ -n "$discord_bot_token" ]; then
        cat >> "$config_file" <<EOF
    "discord": {
      "token": "${discord_bot_token}"
    },
EOF
    fi
    
    if [ -n "$slack_bot_token" ] && [ -n "$slack_app_token" ]; then
        cat >> "$config_file" <<EOF
    "slack": {
      "botToken": "${slack_bot_token}",
      "appToken": "${slack_app_token}"
    },
EOF
    fi
    
    # Close channels object (remove trailing comma if exists)
    sed -i '$ s/,$//' "$config_file"
    
    cat >> "$config_file" <<EOF
  }
}
EOF
    
    # Set environment variables for API keys
    local env_file="/home/ubuntu/.openclaw/environment"
    cat > "$env_file" <<EOF
# OpenClaw Environment Variables
NODE_ENV=production
OPENCLAW_GATEWAY_PORT=${gateway_port}
OPENCLAW_GATEWAY_BIND=${gateway_bind}
EOF
    
    # Set API key based on provider (legacy environment variable support)
    if [ -n "$api_key" ]; then
        case "$ai_provider" in
            anthropic)
                echo "ANTHROPIC_API_KEY=${api_key}" >> "$env_file"
                ;;
            openai)
                echo "OPENAI_API_KEY=${api_key}" >> "$env_file"
                ;;
            google)
                echo "GOOGLE_API_KEY=${api_key}" >> "$env_file"
                ;;
        esac
    fi
    
    # Set ownership and permissions (600 for config as it contains token)
    chown ubuntu:ubuntu "$config_file" "$env_file"
    chmod 600 "$config_file"
    chmod 600 "$env_file"
    
    # Create agent directory structure
    local agent_dir="/home/ubuntu/.openclaw/agents/main/agent"
    local session_dir="/home/ubuntu/.openclaw/agents/main/sessions"
    mkdir -p "$agent_dir" "$session_dir"
    
    # Configure auth profiles for OpenClaw 2026.x (required for agent authentication)
    # OpenClaw 2026.x requires API keys in auth-profiles.json, not environment variables
    if [ -n "$api_key" ] && [ -n "$ai_provider" ]; then
        local auth_file="$agent_dir/auth-profiles.json"
        local profile_id="${ai_provider}:manual"
        
        log_info "Configuring auth profile for provider: $ai_provider"
        
        cat > "$auth_file" <<EOF
{
  "version": 1,
  "profiles": {
    "$profile_id": {
      "type": "api_key",
      "provider": "$ai_provider",
      "key": "$api_key"
    }
  }
}
EOF
        chown ubuntu:ubuntu "$auth_file"
        chmod 600 "$auth_file"
        log_info "Auth profile created at $auth_file"
    fi
    
    # Set proper ownership and permissions for all OpenClaw directories
    chown -R ubuntu:ubuntu /home/ubuntu/.openclaw
    chmod 700 /home/ubuntu/.openclaw
    
    log_info "Configuration generated at $config_file"
}

# Create systemd service
create_systemd_service() {
    local service_file="/etc/systemd/system/openclaw.service"
    
    log_info "Creating systemd service"
    
    cat > "$service_file" <<'EOF'
[Unit]
Description=OpenClaw Gateway - Personal AI Assistant
Documentation=https://docs.openclaw.ai
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu
EnvironmentFile=/home/ubuntu/.openclaw/environment
ExecStart=/usr/bin/env openclaw gateway --verbose
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/home/ubuntu/.openclaw

# Resource limits
LimitNOFILE=65535
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable openclaw.service
    
    log_info "Systemd service created and enabled"
}

# Start OpenClaw service
start_openclaw() {
    log_info "Starting OpenClaw service"
    systemctl start openclaw.service
    
    # Wait for service to be ready
    sleep 5
    
    if systemctl is-active --quiet openclaw.service; then
        log_info "OpenClaw service started successfully"
        return 0
    else
        log_error "OpenClaw service failed to start"
        systemctl status openclaw.service || true
        return 1
    fi
}

# Stop OpenClaw service
stop_openclaw() {
    log_info "Stopping OpenClaw service"
    systemctl stop openclaw.service || true
}

# Restart OpenClaw service
restart_openclaw() {
    log_info "Restarting OpenClaw service"
    systemctl restart openclaw.service
    
    # Wait for service to be ready
    sleep 5
    
    if systemctl is-active --quiet openclaw.service; then
        log_info "OpenClaw service restarted successfully"
        return 0
    else
        log_error "OpenClaw service failed to restart"
        systemctl status openclaw.service || true
        return 1
    fi
}

# Get service status
get_status() {
    if systemctl is-active --quiet openclaw.service; then
        local port
        port="$(config-get gateway-port)"
        echo "OpenClaw running on port $port"
        return 0
    else
        echo "OpenClaw not running"
        return 1
    fi
}

# Validate configuration
validate_config() {
    local errors=0
    
    local ai_provider
    ai_provider="$(config-get ai-provider)"
    
    if [ -z "$ai_provider" ]; then
        log_error "ai-provider must be configured (anthropic, openai, google, bedrock, or ollama)"
        errors=$((errors + 1))
    else
        case "$ai_provider" in
            anthropic|openai|google)
                if [ -z "$(config-get api-key)" ]; then
                    log_error "$ai_provider provider selected but no API key configured"
                    errors=$((errors + 1))
                fi
                ;;
            ollama)
                log_info "Ollama provider selected - ensure Ollama is installed and running separately"
                ;;
            bedrock)
                log_info "AWS Bedrock provider selected - ensure AWS credentials are configured"
                ;;
            *)
                log_error "Invalid ai-provider: $ai_provider (valid: anthropic, openai, google, bedrock, ollama)"
                errors=$((errors + 1))
                ;;
        esac
    fi
    
    local ai_model
    ai_model="$(config-get ai-model)"
    
    if [ -z "$ai_model" ]; then
        log_error "ai-model must be configured (e.g., claude-opus-4-5, gpt-4, gemini-2.0-flash)"
        errors=$((errors + 1))
    fi
    
    local slack_bot_token slack_app_token
    slack_bot_token="$(config-get slack-bot-token)"
    slack_app_token="$(config-get slack-app-token)"
    
    if [ -n "$slack_bot_token" ] && [ -z "$slack_app_token" ]; then
        log_error "Slack bot-token configured but app-token is missing"
        errors=$((errors + 1))
    fi
    
    if [ -z "$slack_bot_token" ] && [ -n "$slack_app_token" ]; then
        log_error "Slack app-token configured but bot-token is missing"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Open required ports
open_ports() {
    local gateway_port
    gateway_port="$(config-get gateway-port)"
    
    log_info "Opening port $gateway_port"
    open-port "$gateway_port/tcp"
}

# Close ports
close_ports() {
    local gateway_port
    gateway_port="$(config-get gateway-port)"
    
    log_info "Closing port $gateway_port"
    close-port "$gateway_port/tcp"
}
