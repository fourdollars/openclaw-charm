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
    
    # Install Bun using official installer
    curl -fsSL https://bun.sh/install | bash
    
    # Add Bun to system PATH by symlinking to /usr/local/bin
    if [ -f "$HOME/.bun/bin/bun" ]; then
        ln -sf "$HOME/.bun/bin/bun" /usr/local/bin/bun
    else
        log_error "Bun installation failed - binary not found"
        exit 1
    fi
    
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
    local config_file="/home/openclaw/.openclaw/openclaw.json"
    local ai_provider ai_model anthropic_key openai_key claude_key
    local gateway_port gateway_bind dm_policy sandbox_mode log_level
    
    ai_provider="$(config-get ai-provider)"
    ai_model="$(config-get ai-model)"
    anthropic_key="$(config-get anthropic-api-key)"
    openai_key="$(config-get openai-api-key)"
    claude_key="$(config-get claude-session-key)"
    gateway_port="$(config-get gateway-port)"
    gateway_bind="$(config-get gateway-bind)"
    dm_policy="$(config-get dm-policy)"
    sandbox_mode="$(config-get sandbox-mode)"
    log_level="$(config-get log-level)"
    
    log_info "Generating OpenClaw configuration"
    
    # Build base config
    cat > "$config_file" <<EOF
{
  "agent": {
    "model": "${ai_provider}/${ai_model}"
  },
  "gateway": {
    "bind": "${gateway_bind}",
    "port": ${gateway_port}
  },
  "agents": {
    "defaults": {
      "dmPolicy": "${dm_policy}",
      "sandbox": {
        "mode": "${sandbox_mode}"
      }
    }
  },
  "logging": {
    "level": "${log_level}"
  },
  "channels": {
EOF
    
    # Add Telegram config if enabled
    if [ "$(config-get enable-telegram)" = "True" ]; then
        local telegram_token
        telegram_token="$(config-get telegram-bot-token)"
        if [ -n "$telegram_token" ]; then
            cat >> "$config_file" <<EOF
    "telegram": {
      "botToken": "${telegram_token}"
    },
EOF
        fi
    fi
    
    # Add Discord config if enabled
    if [ "$(config-get enable-discord)" = "True" ]; then
        local discord_token
        discord_token="$(config-get discord-bot-token)"
        if [ -n "$discord_token" ]; then
            cat >> "$config_file" <<EOF
    "discord": {
      "token": "${discord_token}"
    },
EOF
        fi
    fi
    
    # Add Slack config if enabled
    if [ "$(config-get enable-slack)" = "True" ]; then
        local slack_bot_token slack_app_token
        slack_bot_token="$(config-get slack-bot-token)"
        slack_app_token="$(config-get slack-app-token)"
        if [ -n "$slack_bot_token" ] && [ -n "$slack_app_token" ]; then
            cat >> "$config_file" <<EOF
    "slack": {
      "botToken": "${slack_bot_token}",
      "appToken": "${slack_app_token}"
    },
EOF
        fi
    fi
    
    # Close channels object (remove trailing comma if exists)
    sed -i '$ s/,$//' "$config_file"
    
    cat >> "$config_file" <<EOF
  }
}
EOF
    
    # Set environment variables for API keys
    local env_file="/home/openclaw/.openclaw/environment"
    cat > "$env_file" <<EOF
# OpenClaw Environment Variables
NODE_ENV=production
OPENCLAW_GATEWAY_PORT=${gateway_port}
OPENCLAW_GATEWAY_BIND=${gateway_bind}
EOF
    
    if [ -n "$anthropic_key" ]; then
        echo "ANTHROPIC_API_KEY=${anthropic_key}" >> "$env_file"
    fi
    
    if [ -n "$openai_key" ]; then
        echo "OPENAI_API_KEY=${openai_key}" >> "$env_file"
    fi
    
    if [ -n "$claude_key" ]; then
        echo "CLAUDE_AI_SESSION_KEY=${claude_key}" >> "$env_file"
    fi
    
    chown openclaw:openclaw "$config_file" "$env_file"
    chmod 644 "$config_file"
    chmod 600 "$env_file"
    
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
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw
EnvironmentFile=/home/openclaw/.openclaw/environment
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
ProtectHome=true
ReadWritePaths=/home/openclaw/.openclaw

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
    
    # Check for AI provider credentials
    local ai_provider
    ai_provider="$(config-get ai-provider)"
    
    case "$ai_provider" in
        anthropic)
            if [ -z "$(config-get anthropic-api-key)" ] && [ -z "$(config-get claude-session-key)" ]; then
                log_error "Anthropic provider selected but no API key or session key configured"
                errors=$((errors + 1))
            fi
            ;;
        openai)
            if [ -z "$(config-get openai-api-key)" ]; then
                log_error "OpenAI provider selected but no API key configured"
                errors=$((errors + 1))
            fi
            ;;
        ollama)
            log_info "Ollama provider selected - ensure Ollama is installed and running separately"
            ;;
    esac
    
    # Check channel configuration
    if [ "$(config-get enable-telegram)" = "True" ] && [ -z "$(config-get telegram-bot-token)" ]; then
        log_error "Telegram enabled but no bot token configured"
        errors=$((errors + 1))
    fi
    
    if [ "$(config-get enable-discord)" = "True" ] && [ -z "$(config-get discord-bot-token)" ]; then
        log_error "Discord enabled but no bot token configured"
        errors=$((errors + 1))
    fi
    
    if [ "$(config-get enable-slack)" = "True" ]; then
        if [ -z "$(config-get slack-bot-token)" ] || [ -z "$(config-get slack-app-token)" ]; then
            log_error "Slack enabled but missing bot token or app token"
            errors=$((errors + 1))
        fi
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
