#!/bin/bash
# OpenClaw Juju Charm - Common Functions

set -e

# Logging functions
log_info() {
    juju-log -l INFO "$1"
    echo "[INFO] $1" >&2
}

log_error() {
    juju-log -l ERROR "$1"
    echo "[ERROR] $1" >&2
}

log_debug() {
    juju-log -l DEBUG "$1"
    echo "[DEBUG] $1" >&2
}

log_warn() {
    juju-log -l WARNING "$1"
    echo "[WARN] $1" >&2
}

# Run systemctl --user command as ubuntu with proper environment
run_systemctl_user() {
    systemctl --user --machine=ubuntu@ "$@"
}

# Check if charm should manage OpenClaw configuration
# Returns: "true" if charm manages config (manual=false), "false" if user manages (manual=true)
should_manage_config() {
    local manual_mode
    local manual_raw
    manual_raw="$(config-get manual)"
    manual_mode="$(echo "$manual_raw" | tr '[:upper:]' '[:lower:]')"
    
    log_debug "manual config check: raw='$manual_raw' normalized='$manual_mode'"
    
    if [ "$manual_mode" = "true" ]; then
        log_debug "Manual mode enabled - charm will not manage configuration"
        echo "false"
    else
        log_debug "Automatic mode - charm manages configuration"
        echo "true"
    fi
}

# Check if this unit is the leader
is_leader() {
    local result
    result=$(is-leader 2>/dev/null || echo "False")
    log_debug "is-leader output: $result"
    
    if [ "$result" = "True" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Get the role of this unit (gateway or node)
get_unit_role() {
    local leader_status
    leader_status="$(is_leader)"
    log_debug "Leader status: $leader_status"
    
    if [ "$leader_status" = "true" ]; then
        log_debug "Unit role: gateway"
        echo "gateway"
    else
        log_debug "Unit role: node"
        echo "node"
    fi
}

# Get Gateway connection info from peer relation
# Returns: gateway_unit gateway_host gateway_port gateway_token (space-separated)
# Usage: read -r gateway_unit gateway_host gateway_port gateway_token <<< "$(get_gateway_info)"
get_gateway_info() {
    local gateway_unit="" gateway_host="" gateway_port="" gateway_token="" relation_id
    
    # Get the peer relation ID
    relation_id=$(relation-ids openclaw-cluster 2>/dev/null | head -1)
    if [ -z "$relation_id" ]; then
        log_debug "No peer relation found"
        echo "   "
        return 1
    fi
    
    # Find the leader unit in the relation (unit that has gateway-host set)
    for unit in $(relation-list -r "$relation_id" 2>/dev/null); do
        local test_host
        test_host="$(relation-get -r "$relation_id" gateway-host "$unit" 2>/dev/null || echo '')"
        if [ -n "$test_host" ]; then
            gateway_unit="$unit"
            gateway_host="$test_host"
            gateway_port="$(relation-get -r "$relation_id" gateway-port "$unit" 2>/dev/null || echo '')"
            gateway_token="$(relation-get -r "$relation_id" gateway-token "$unit" 2>/dev/null || echo '')"
            log_debug "Found Gateway: $unit at ${gateway_host}:${gateway_port}"
            break
        fi
    done
    
    echo "$gateway_unit $gateway_host $gateway_port $gateway_token"
}

# Check if deployment has multiple units
# Returns: 0 (true) if multiple units exist, 1 (false) otherwise
is_multi_unit() {
    local relation_id unit_count
    relation_id=$(relation-ids openclaw-cluster 2>/dev/null | head -1)
    
    if [ -z "$relation_id" ]; then
        # No peer relation = single unit
        return 1
    fi
    
    # Count units in relation (including self)
    unit_count=$(relation-list -r "$relation_id" 2>/dev/null | wc -l)
    # Add 1 for current unit
    unit_count=$((unit_count + 1))
    
    if [ "$unit_count" -gt 1 ]; then
        log_debug "Multi-unit deployment detected: $unit_count units"
        return 0
    else
        log_debug "Single-unit deployment"
        return 1
    fi
}

# Validate gateway-bind setting for multi-unit deployments
# Returns: 0 if valid, 1 if invalid with warning message
validate_gateway_bind() {
    local bind
    bind="$(config-get gateway-bind)"
    
    if ! is_multi_unit; then
        # Single unit - any bind mode is fine
        return 0
    fi
    
    # Multi-unit deployment - check bind mode
    if [ "$bind" = "loopback" ]; then
        log_warn "Multi-unit deployment detected with gateway-bind=loopback - Nodes cannot connect!"
        log_warn "Recommendation: Set gateway-bind=lan for multi-unit deployments"
        return 1
    fi
    
    return 0
}

# Install Node.js using NodeSource repository
install_nodejs() {
    local node_version
    node_version="$(config-get node-version)"
    
    log_info "Installing Node.js version $node_version via nvm for ubuntu user"
    
    # Check if nvm is already installed
    local nvm_dir="/home/ubuntu/.nvm"
    if [ -d "$nvm_dir" ]; then
        log_info "nvm already installed at $nvm_dir"
    else
        # Install nvm as ubuntu user
        log_info "Installing nvm for ubuntu user"
        sudo -u ubuntu bash -l -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
        
        if [ ! -d "$nvm_dir" ]; then
            log_error "nvm installation failed - directory not found"
            exit 1
        fi
        
        chown -R ubuntu:ubuntu "$nvm_dir"
        log_info "nvm installed successfully"
    fi
    
    # Install Node.js using nvm
    log_info "Installing Node.js v${node_version} via nvm"
    sudo -u ubuntu bash -l -c "
        export NVM_DIR=\"$nvm_dir\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        nvm install ${node_version}
        nvm alias default ${node_version}
        nvm use default
    "
    
    # Verify installation
    local installed_version
    installed_version=$(sudo -u ubuntu bash -l -c "
        export NVM_DIR=\"$nvm_dir\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        node --version
    ")
    
    if [ -z "$installed_version" ]; then
        log_error "Node.js installation failed - command not found"
        exit 1
    fi
    
    log_info "Node.js installed via nvm: $installed_version"
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
    
    sudo -u ubuntu bash -l -c "curl -fsSL https://bun.sh/install | bash"
    
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

# Install Google Chrome for browser automation
install_chrome() {
    log_info "Checking if Chrome needs to be installed"
    
    if command -v google-chrome >/dev/null 2>&1; then
        local chrome_version
        chrome_version=$(google-chrome --version 2>/dev/null || echo "unknown")
        log_info "Chrome already installed: $chrome_version"
        return 0
    fi
    
    log_info "Installing Google Chrome for browser automation"
    
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
    
    apt-get update
    apt-get install -y google-chrome-stable
    
    if ! command -v google-chrome >/dev/null 2>&1; then
        log_error "Chrome installation failed - command not found"
        return 1
    fi
    
    local chrome_version
    chrome_version=$(google-chrome --version)
    log_info "Chrome installed successfully: $chrome_version"
    return 0
}

ensure_chrome_installed() {
    if [ "$(should_manage_config)" = "false" ]; then
        log_info "Manual mode enabled - skipping Chrome installation management"
        return 0
    fi
    
    local enable_browser_tool
    enable_browser_tool="$(config-get enable-browser-tool)"
    
    if [ "$enable_browser_tool" = "True" ]; then
        if ! command -v google-chrome >/dev/null 2>&1; then
            log_info "enable-browser-tool is True but Chrome not found - installing"
            install_chrome
        else
            log_debug "enable-browser-tool is True and Chrome is already installed"
        fi
    else
        log_debug "enable-browser-tool is False - skipping Chrome installation"
    fi
}

# Ensure environment file exists (required by systemd service)
ensure_environment_file() {
    local env_file="/home/ubuntu/.openclaw/environment"
    local gateway_port gateway_bind
    
    gateway_port="$(config-get gateway-port)"
    gateway_bind="$(config-get gateway-bind)"
    
    # Create .openclaw directory if it doesn't exist
    mkdir -p /home/ubuntu/.openclaw
    
    # Create environment file
    cat > "$env_file" <<EOF
# OpenClaw Environment Variables
NODE_ENV=production
NODE_VERSION=$(config-get node-version)
OPENCLAW_GATEWAY_PORT=${gateway_port}
OPENCLAW_GATEWAY_BIND=${gateway_bind}
EOF
    
    chown ubuntu:ubuntu "$env_file"
    chmod 600 "$env_file"
    log_debug "Environment file created at $env_file"
}

# Generate OpenClaw configuration
generate_config() {
    # Always ensure environment file exists (required by systemd)
    ensure_environment_file
    
    if [ "$(should_manage_config)" = "false" ]; then
        log_info "Manual mode enabled - skipping OpenClaw configuration generation"
        return 0
    fi
    
    local config_file="/home/ubuntu/.openclaw/openclaw.json"
    local temp_file="${config_file}.tmp"
    local ai_provider ai_model api_key
    local gateway_port gateway_bind log_level
    
    ai_provider="$(config-get ai-provider)"
    ai_model="$(config-get ai-model)"
    api_key="$(config-get ai-api-key)"
    gateway_port="$(config-get gateway-port)"
    gateway_bind="$(config-get gateway-bind)"
    log_level="$(config-get log-level)"
    
    log_info "Generating OpenClaw configuration using jq"
    
    local gateway_token
    if [ -f "$config_file" ]; then
        gateway_token=$(jq -r '.gateway.auth.token // empty' "$config_file" 2>/dev/null || echo "")
        if [ -n "$gateway_token" ]; then
            log_info "Preserving existing gateway token"
        fi
    fi
    
    if [ -z "$gateway_token" ]; then
        gateway_token=$(openssl rand -hex 24)
        log_info "Generated new gateway token"
    fi
    
    echo '{}' | jq \
        --arg token "$gateway_token" \
        --arg bind "$gateway_bind" \
        --argjson port "$gateway_port" \
        --arg model "${ai_provider}/${ai_model}" \
        --arg log_level "$log_level" \
        '{
            gateway: {
                mode: "local",
                auth: {
                    mode: "token",
                    token: $token
                },
                bind: $bind,
                port: $port
            },
            agents: {
                defaults: {
                    model: {
                        primary: $model
                    }
                }
            },
            logging: {
                level: $log_level
            },
            channels: {}
        }' > "$temp_file"
    
    local telegram_bot_token discord_bot_token slack_bot_token slack_app_token
    local line_channel_access_token line_channel_secret
    telegram_bot_token="$(config-get telegram-bot-token)"
    discord_bot_token="$(config-get discord-bot-token)"
    slack_bot_token="$(config-get slack-bot-token)"
    slack_app_token="$(config-get slack-app-token)"
    line_channel_access_token="$(config-get line-channel-access-token)"
    line_channel_secret="$(config-get line-channel-secret)"
    
    if [ -n "$telegram_bot_token" ]; then
        jq --arg token "$telegram_bot_token" \
           '.channels.telegram = {botToken: $token}' \
           "$temp_file" > "${temp_file}.2" && mv "${temp_file}.2" "$temp_file"
    fi
    
    if [ -n "$discord_bot_token" ]; then
        jq --arg token "$discord_bot_token" \
           '.channels.discord = {token: $token}' \
           "$temp_file" > "${temp_file}.2" && mv "${temp_file}.2" "$temp_file"
    fi
    
    if [ -n "$slack_bot_token" ] && [ -n "$slack_app_token" ]; then
        jq --arg bot_token "$slack_bot_token" \
           --arg app_token "$slack_app_token" \
           '.channels.slack = {botToken: $bot_token, appToken: $app_token}' \
           "$temp_file" > "${temp_file}.2" && mv "${temp_file}.2" "$temp_file"
    fi
    
    if [ -n "$line_channel_access_token" ] && [ -n "$line_channel_secret" ]; then
        jq --arg access_token "$line_channel_access_token" \
           --arg secret "$line_channel_secret" \
           '.channels.line = {dmPolicy: "pairing", channelAccessToken: $access_token, channelSecret: $secret}' \
           "$temp_file" > "${temp_file}.2" && mv "${temp_file}.2" "$temp_file"
    fi
    
    local base_url
    base_url="$(config-get ai-base-url)"
    
    if [ -n "$base_url" ] && [ -n "$ai_provider" ]; then
        log_info "Adding custom base URL for primary provider ($ai_provider): $base_url"
        jq --arg provider "$ai_provider" \
           --arg baseUrl "$base_url" \
           '.models.providers[$provider] = {baseUrl: $baseUrl, models: []}' \
           "$temp_file" > "${temp_file}.2" && mv "${temp_file}.2" "$temp_file"
    fi
    
    for i in 0 1 2 3 4 5 6 7 8 9; do
        local slot_provider slot_base_url
        slot_provider="$(config-get "ai${i}-provider")"
        slot_base_url="$(config-get "ai${i}-base-url")"
        
        if [ -n "$slot_provider" ] && [ -n "$slot_base_url" ]; then
            log_info "Adding custom base URL for slot $i provider ($slot_provider): $slot_base_url"
            jq --arg provider "$slot_provider" \
               --arg baseUrl "$slot_base_url" \
               '.models.providers[$provider] = {baseUrl: $baseUrl, models: []}' \
               "$temp_file" > "${temp_file}.2" && mv "${temp_file}.2" "$temp_file"
        fi
    done
    
    mv "$temp_file" "$config_file"

    # Set ownership and permissions (600 for config as it contains token)
    chown ubuntu:ubuntu "$config_file"
    chmod 600 "$config_file"

    # Create agent directory structure
    local agent_dir="/home/ubuntu/.openclaw/agents/main/agent"
    local session_dir="/home/ubuntu/.openclaw/agents/main/sessions"
    mkdir -p "$agent_dir" "$session_dir"

    local auth_file="$agent_dir/auth-profiles.json"
    local auth_temp="${auth_file}.tmp"
    
    echo '{"version": 1, "profiles": {}}' > "$auth_temp"
    
    if [ -n "$api_key" ] && [ -n "$ai_provider" ]; then
        local profile_id="${ai_provider}:manual"
        log_info "Configuring primary auth profile for provider: $ai_provider"
        
        jq --arg id "$profile_id" \
           --arg provider "$ai_provider" \
           --arg token "$api_key" \
           '.profiles[$id] = {type: "token", provider: $provider, token: $token}' \
           "$auth_temp" > "${auth_temp}.2" && mv "${auth_temp}.2" "$auth_temp"
    fi
    
    for i in 0 1 2 3 4 5 6 7 8 9; do
        local slot_provider slot_model slot_api_key
        slot_provider="$(config-get "ai${i}-provider")"
        slot_model="$(config-get "ai${i}-model")"
        slot_api_key="$(config-get "ai${i}-api-key")"
        
        if [ -n "$slot_provider" ] && [ -n "$slot_model" ] && [ -n "$slot_api_key" ]; then
            local slot_profile_id="${slot_provider}:slot${i}"
            log_info "Configuring auth profile for slot $i: $slot_provider/$slot_model"
            
            jq --arg id "$slot_profile_id" \
               --arg provider "$slot_provider" \
               --arg token "$slot_api_key" \
               '.profiles[$id] = {type: "token", provider: $provider, token: $token}' \
               "$auth_temp" > "${auth_temp}.2" && mv "${auth_temp}.2" "$auth_temp"
        fi
    done
    
    if [ -s "$auth_temp" ]; then
        local profile_count
        profile_count=$(jq '.profiles | length' "$auth_temp")
        if [ "$profile_count" -gt 0 ]; then
            mv "$auth_temp" "$auth_file"
            chown ubuntu:ubuntu "$auth_file"
            chmod 600 "$auth_file"
            log_info "Auth profile created at $auth_file with $profile_count profile(s)"
        else
            rm -f "$auth_temp"
        fi
    fi

    # Set proper ownership and permissions for all OpenClaw directories
    chown -R ubuntu:ubuntu /home/ubuntu/.openclaw
    chmod 700 /home/ubuntu/.openclaw

    log_info "Configuration generated at $config_file"
}

# Generate OpenClaw Node configuration
generate_node_config() {
    local config_file="/home/ubuntu/.openclaw/node.json"
    local gateway_host gateway_port gateway_token
    local relation_id leader_unit
    local node_id display_name
    
    log_info "Generating OpenClaw Node configuration (peer relations work in both automatic and manual modes)"
    
    # Get the peer relation ID
    relation_id=$(relation-ids openclaw-cluster 2>/dev/null | head -1)
    if [ -z "$relation_id" ]; then
        log_error "Peer relation not found"
        return 1
    fi
    
    # Find the leader unit in the relation
    for unit in $(relation-list -r "$relation_id" 2>/dev/null); do
        local test_host
        test_host="$(relation-get -r "$relation_id" gateway-host "$unit" 2>/dev/null || echo '')"
        if [ -n "$test_host" ]; then
            leader_unit="$unit"
            break
        fi
    done
    
    if [ -z "$leader_unit" ]; then
        log_error "Gateway connection info not available from leader"
        return 1
    fi
    
    gateway_host="$(relation-get -r "$relation_id" gateway-host "$leader_unit" 2>/dev/null || echo '')"
    gateway_port="$(relation-get -r "$relation_id" gateway-port "$leader_unit" 2>/dev/null || echo '')"
    gateway_token="$(relation-get -r "$relation_id" gateway-token "$leader_unit" 2>/dev/null || echo '')"
    
    if [ -z "$gateway_host" ] || [ -z "$gateway_port" ]; then
        log_error "Gateway connection info incomplete"
        return 1
    fi
    
    log_info "Configuring Node to connect to Gateway: ${gateway_host}:${gateway_port}"
    
    # Generate or reuse node ID
    if [ -f "$config_file" ]; then
        node_id=$(jq -r '.nodeId // empty' "$config_file" 2>/dev/null || echo "")
    fi
    
    if [ -z "$node_id" ]; then
        node_id=$(uuidgen)
    fi
    
    # Use Juju unit name for display (e.g., openclaw/1) to match Juju status
    display_name="${JUJU_UNIT_NAME:-$(hostname)}"
    
    mkdir -p /home/ubuntu/.openclaw
    
    jq -n \
        --arg version "1" \
        --arg nodeId "$node_id" \
        --arg displayName "$display_name" \
        --arg host "$gateway_host" \
        --argjson port "$gateway_port" \
        '{
            version: ($version | tonumber),
            nodeId: $nodeId,
            displayName: $displayName,
            gateway: {
                host: $host,
                port: $port,
                tls: false
            }
        }' > "$config_file"
    
    chown ubuntu:ubuntu "$config_file"
    chmod 600 "$config_file"
    
    log_info "Node configuration generated at $config_file"
}

create_systemd_service() {
    local service_dir="/home/ubuntu/.config/systemd/user"
    local service_file="$service_dir/openclaw-gateway.service"
    local exec_start
    
    log_info "Creating systemd user service for OpenClaw Gateway"
    
    sudo -u ubuntu bash -l -c "mkdir -p $service_dir"
    
    if [ -d "/home/ubuntu/.nvm" ]; then
        exec_start="/home/ubuntu/.nvm/nvm-exec openclaw gateway --verbose"
    elif [ -d "/home/ubuntu/.bun" ]; then
        exec_start="/home/ubuntu/.bun/bin/bun run openclaw gateway --verbose"
    else
        exec_start="openclaw gateway --verbose"
    fi
    
    local systemd_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    if [ -d "/home/ubuntu/.bun" ]; then
        systemd_path="/home/ubuntu/.bun/bin:${systemd_path}"
    fi
    if [ -d "/home/ubuntu/.nvm" ]; then
        local nvm_node_version
        # shellcheck disable=SC2012
        nvm_node_version="$(ls -1 /home/ubuntu/.nvm/versions/node | sort -V | tail -1)"
        systemd_path="/home/ubuntu/.nvm/versions/node/${nvm_node_version}/bin:${systemd_path}"
    fi
    
    sudo -u ubuntu bash -l -c "cat > $service_file" <<EOF
[Unit]
Description=OpenClaw Gateway - Personal AI Assistant
Documentation=https://docs.openclaw.ai
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=%h
Environment=PATH=${systemd_path}
EnvironmentFile=%h/.openclaw/environment
ExecStart=$exec_start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw-gateway

NoNewPrivileges=true
PrivateTmp=true

LimitNOFILE=65535
LimitNPROC=4096

[Install]
WantedBy=default.target
EOF
    
    chown ubuntu:ubuntu "$service_file"
    chmod 644 "$service_file"
    
    loginctl enable-linger ubuntu || log_warn "Failed to enable lingering for ubuntu user"
    
    log_info "Systemd user service file created: openclaw-gateway.service (will be enabled on start)"
}

create_node_systemd_service() {
    local service_dir="/home/ubuntu/.config/systemd/user"
    local service_file="$service_dir/openclaw-node.service"
    local exec_start
    
    log_info "Creating OpenClaw Node systemd user service"
    
    sudo -u ubuntu bash -l -c "mkdir -p $service_dir"
    
    if [ -d "/home/ubuntu/.nvm" ]; then
        exec_start="/home/ubuntu/.nvm/nvm-exec openclaw node run"
    elif [ -d "/home/ubuntu/.bun" ]; then
        exec_start="/home/ubuntu/.bun/bin/bun run openclaw node run"
    else
        exec_start="openclaw node run"
    fi
    
    local systemd_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    if [ -d "/home/ubuntu/.bun" ]; then
        systemd_path="/home/ubuntu/.bun/bin:${systemd_path}"
    fi
    if [ -d "/home/ubuntu/.nvm" ]; then
        local nvm_node_version
        # shellcheck disable=SC2012
        nvm_node_version="$(ls -1 /home/ubuntu/.nvm/versions/node | sort -V | tail -1)"
        systemd_path="/home/ubuntu/.nvm/versions/node/${nvm_node_version}/bin:${systemd_path}"
    fi
    
    sudo -u ubuntu bash -l -c "cat > $service_file" <<EOF
[Unit]
Description=OpenClaw Node - Remote Capabilities Host
Documentation=https://docs.openclaw.ai
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=%h
Environment=PATH=${systemd_path}
Environment="NODE_VERSION=$(config-get node-version)"
ExecStart=$exec_start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw-node

NoNewPrivileges=true
PrivateTmp=true

LimitNOFILE=65535
LimitNPROC=4096

[Install]
WantedBy=default.target
EOF
    
    chown ubuntu:ubuntu "$service_file"
    chmod 644 "$service_file"
    
    loginctl enable-linger ubuntu || log_warn "Failed to enable lingering for ubuntu user"
    
    log_info "Node systemd user service file created: openclaw-node.service (will be enabled on start)"
}

update_node_service_token() {
    local gateway_token relation_id leader_unit
    local override_dir="/home/ubuntu/.config/systemd/user/openclaw-node.service.d"
    local override_file="$override_dir/gateway-token.conf"
    
    relation_id=$(relation-ids openclaw-cluster 2>/dev/null | head -1)
    if [ -z "$relation_id" ]; then
        log_warn "Peer relation not found - cannot set gateway token"
        return 0
    fi
    
    for unit in $(relation-list -r "$relation_id" 2>/dev/null); do
        local test_host
        test_host="$(relation-get -r "$relation_id" gateway-host "$unit" 2>/dev/null || echo '')"
        if [ -n "$test_host" ]; then
            leader_unit="$unit"
            break
        fi
    done
    
    if [ -z "$leader_unit" ]; then
        log_warn "Gateway unit not found - cannot retrieve token"
        return 0
    fi
    
    gateway_token="$(relation-get -r "$relation_id" gateway-token "$leader_unit" 2>/dev/null || echo '')"
    
    if [ -z "$gateway_token" ]; then
        log_warn "Gateway token not available yet"
        return 0
    fi
    
    log_info "Updating Node service with gateway token via systemd drop-in"
    
    sudo -u ubuntu bash -l -c "mkdir -p $override_dir"
    
    sudo -u ubuntu bash -l -c "cat > $override_file" <<EOF
[Service]
Environment="OPENCLAW_GATEWAY_TOKEN=${gateway_token}"
EOF
    
    chown ubuntu:ubuntu "$override_file"
    chmod 644 "$override_file"
    
    log_info "Gateway token set in systemd drop-in: $override_file"
}

start_openclaw() {
    log_info "Starting OpenClaw Gateway service"
    run_systemctl_user daemon-reload
    run_systemctl_user enable openclaw-gateway.service
    run_systemctl_user start openclaw-gateway.service
    
    sleep 5
    
    if run_systemctl_user is-active --quiet openclaw-gateway.service; then
        log_info "OpenClaw Gateway service started successfully"
        return 0
    else
        log_error "OpenClaw Gateway service failed to start"
        run_systemctl_user status openclaw-gateway.service || true
        return 1
    fi
}

stop_openclaw() {
    log_info "Stopping OpenClaw Gateway service"
    run_systemctl_user stop openclaw-gateway.service || true
}

restart_openclaw() {
    log_info "Restarting OpenClaw Gateway service"
    run_systemctl_user daemon-reload
    run_systemctl_user restart openclaw-gateway.service
    
    sleep 5
    
    if run_systemctl_user is-active --quiet openclaw-gateway.service; then
        log_info "OpenClaw Gateway service restarted successfully"
        return 0
    else
        log_error "OpenClaw Gateway service failed to restart"
        run_systemctl_user status openclaw-gateway.service || true
        return 1
    fi
}

start_openclaw_node() {
    log_info "Starting OpenClaw Node service"
    run_systemctl_user daemon-reload
    run_systemctl_user enable openclaw-node.service
    run_systemctl_user start openclaw-node.service
    
    sleep 5
    
    if run_systemctl_user is-active --quiet openclaw-node.service; then
        log_info "OpenClaw Node service started successfully"
        return 0
    else
        log_error "OpenClaw Node service failed to start"
        run_systemctl_user status openclaw-node.service || true
        return 1
    fi
}

stop_openclaw_node() {
    log_info "Stopping OpenClaw Node service"
    run_systemctl_user stop openclaw-node.service || true
}

restart_openclaw_node() {
    log_info "Restarting OpenClaw Node service"
    run_systemctl_user daemon-reload
    run_systemctl_user restart openclaw-node.service
    
    sleep 5
    
    if run_systemctl_user is-active --quiet openclaw-node.service; then
        log_info "OpenClaw Node service restarted successfully"
        return 0
    else
        log_error "OpenClaw Node service failed to restart"
        run_systemctl_user status openclaw-node.service || true
        return 1
    fi
}

# Check if OpenClaw Gateway service is currently running
is_gateway_running() {
    run_systemctl_user is-active --quiet openclaw-gateway.service 2>/dev/null
}

# Check if OpenClaw Node service is currently running
is_node_running() {
    run_systemctl_user is-active --quiet openclaw-node.service 2>/dev/null
}

get_status() {
    if is_gateway_running; then
        local port
        port="$(config-get gateway-port)"
        echo "OpenClaw Gateway running on port $port"
        return 0
    else
        echo "OpenClaw Gateway not running"
        return 1
    fi
}

# Validate configuration
validate_config() {
    if [ "$(should_manage_config)" = "false" ]; then
        log_info "Manual mode enabled - skipping configuration validation"
        return 0
    fi
    
    local errors=0
    
    local ai_provider
    ai_provider="$(config-get ai-provider)"
    
    if [ -z "$ai_provider" ]; then
        log_error "ai-provider must be configured"
        log_error "Supported providers: anthropic, openai, openai-codex, google, opencode, github-copilot, openrouter, xai, groq, cerebras, mistral, zai, vercel-ai-gateway, ollama, bedrock"
        errors=$((errors + 1))
    else
        case "$ai_provider" in
            anthropic|openai|google|opencode|github-copilot|openrouter|xai|groq|cerebras|mistral|zai|vercel-ai-gateway)
                if [ -z "$(config-get ai-api-key)" ]; then
                    log_error "$ai_provider provider selected but no API key configured"
                    errors=$((errors + 1))
                fi
                ;;
            openai-codex)
                log_info "OpenAI Codex provider selected - uses OAuth authentication (no API key needed)"
                ;;
            ollama)
                log_info "Ollama provider selected - ensure Ollama is installed and running separately"
                ;;
            bedrock)
                log_info "AWS Bedrock provider selected - ensure AWS credentials are configured"
                ;;
            *)
                log_error "Invalid ai-provider: $ai_provider"
                log_error "Supported providers: anthropic, openai, openai-codex, google, opencode, github-copilot, openrouter, xai, groq, cerebras, mistral, zai, vercel-ai-gateway, ollama, bedrock"
                errors=$((errors + 1))
                ;;
        esac
    fi
    
    local ai_model
    ai_model="$(config-get ai-model)"
    
    if [ -z "$ai_model" ]; then
        log_error "ai-model must be configured (e.g., claude-opus-4-5, gpt-4, gemini-2.5-flash-lite)"
        errors=$((errors + 1))
    fi
    
    local ai_base_url
    ai_base_url="$(config-get ai-base-url)"
    if [ -n "$ai_base_url" ]; then
        if ! echo "$ai_base_url" | grep -qE '^https?://'; then
            log_error "ai-base-url must start with http:// or https://"
            errors=$((errors + 1))
        fi
    fi
    
    # Validate additional AI model slots (ai0-ai9)
    for i in 0 1 2 3 4 5 6 7 8 9; do
        local slot_provider slot_model slot_api_key slot_base_url
        slot_provider="$(config-get "ai${i}-provider")"
        slot_model="$(config-get "ai${i}-model")"
        slot_api_key="$(config-get "ai${i}-api-key")"
        slot_base_url="$(config-get "ai${i}-base-url")"
        
        # If any ai slot config is provided, validate completeness
        if [ -n "$slot_provider" ] || [ -n "$slot_model" ] || [ -n "$slot_api_key" ]; then
            if [ -z "$slot_provider" ]; then
                log_error "AI slot $i: provider configured but missing ai${i}-provider"
                errors=$((errors + 1))
            fi
            
            if [ -z "$slot_model" ]; then
                log_error "AI slot $i: model configured but missing ai${i}-model"
                errors=$((errors + 1))
            fi
            
            # Validate API key requirement for providers
            if [ -n "$slot_provider" ]; then
                case "$slot_provider" in
                    anthropic|openai|google|opencode|github-copilot|openrouter|xai|groq|cerebras|mistral|zai|vercel-ai-gateway)
                        if [ -z "$slot_api_key" ]; then
                            log_error "AI slot $i: $slot_provider provider requires ai${i}-api-key"
                            errors=$((errors + 1))
                        fi
                        ;;
                    openai-codex)
                        log_info "AI slot $i: OpenAI Codex provider (OAuth, no API key needed)"
                        ;;
                    ollama)
                        log_info "AI slot $i: Ollama provider selected"
                        ;;
                    bedrock)
                        log_info "AI slot $i: AWS Bedrock provider selected"
                        ;;
                    *)
                        log_error "AI slot $i: Invalid provider $slot_provider"
                        log_error "Supported: anthropic, openai, openai-codex, google, opencode, github-copilot, openrouter, xai, groq, cerebras, mistral, zai, vercel-ai-gateway, ollama, bedrock"
                        errors=$((errors + 1))
                        ;;
                esac
            fi
        fi
        
        if [ -n "$slot_base_url" ]; then
            if ! echo "$slot_base_url" | grep -qE '^https?://'; then
                log_error "AI slot $i: ai${i}-base-url must start with http:// or https://"
                errors=$((errors + 1))
            fi
        fi
    done
    
    local slack_bot_token slack_app_token
    local line_channel_access_token line_channel_secret
    slack_bot_token="$(config-get slack-bot-token)"
    slack_app_token="$(config-get slack-app-token)"
    line_channel_access_token="$(config-get line-channel-access-token)"
    line_channel_secret="$(config-get line-channel-secret)"
    
    if [ -n "$slack_bot_token" ] && [ -z "$slack_app_token" ]; then
        log_error "Slack bot-token configured but app-token is missing"
        errors=$((errors + 1))
    fi
    
    if [ -z "$slack_bot_token" ] && [ -n "$slack_app_token" ]; then
        log_error "Slack app-token configured but bot-token is missing"
        errors=$((errors + 1))
    fi
    
    if [ -n "$line_channel_access_token" ] && [ -z "$line_channel_secret" ]; then
        log_error "LINE channel-access-token configured but channel-secret is missing"
        errors=$((errors + 1))
    fi
    
    if [ -z "$line_channel_access_token" ] && [ -n "$line_channel_secret" ]; then
        log_error "LINE channel-secret configured but channel-access-token is missing"
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

# Run command as ubuntu user with appropriate runtime environment (nvm or bun)
run_as_user() {
    local cmd="$1"
    sudo -u ubuntu bash -l -c "
        export NVM_DIR=\"/home/ubuntu/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && nvm use \${NODE_VERSION:-24} >/dev/null 2>&1
        export BUN_INSTALL=\"/home/ubuntu/.bun\"
        [ -d \"\$BUN_INSTALL/bin\" ] && export PATH=\"\$BUN_INSTALL/bin:\$PATH\"
        $cmd
    "
}

# Check if this node is paired and connected to the gateway
# Returns: 0 if paired and connected, 1 if not
is_node_paired() {
    local pid recent_errors node_id
    
    pid=$(pgrep -u ubuntu -f "openclaw-node" | head -1)
    if [ -z "$pid" ]; then
        log_debug "Node process is not running"
        return 1
    fi
    
    log_debug "Node process PID $pid is running"
    
    # Check for recent connection errors - use grep -E and count lines properly
    recent_errors=$(sudo -u ubuntu bash -l -c "journalctl --user -u openclaw-node.service --since '5 seconds ago' --no-pager 2>/dev/null" | grep -cE 'pairing required|connect failed|ECONNREFUSED' 2>/dev/null || echo "0")
    # Ensure recent_errors is a single integer
    recent_errors=$(echo "$recent_errors" | head -1 | tr -d '\n')
    
    if [ -n "$recent_errors" ] && [ "$recent_errors" -gt 0 ] 2>/dev/null; then
        log_debug "Node has recent connection errors ($recent_errors errors in last 5s)"
        return 1
    fi
    
    # Additional check: verify node is actually connected by checking for successful connection log
    if sudo -u ubuntu bash -l -c "journalctl --user -u openclaw-node.service --since '30 seconds ago' --no-pager 2>/dev/null" | grep -qE 'node host connected|gateway.*connected'; then
        log_debug "Node successfully connected to gateway"
        return 0
    fi
    
    log_debug "Node process stable and connected (no errors in last 5s)"
    return 0
}

check_gateway_connection() {
    local gateway_host gateway_port
    
    read -r _ gateway_host gateway_port _ <<< "$(get_gateway_info)"
    
    if [ -z "$gateway_host" ] || [ -z "$gateway_port" ]; then
        log_debug "Gateway info not available"
        return 1
    fi
    
    if timeout 3 bash -c "echo > /dev/tcp/$gateway_host/$gateway_port" 2>/dev/null; then
        log_debug "Gateway reachable at $gateway_host:$gateway_port"
        return 0
    else
        log_warn "Cannot reach Gateway at $gateway_host:$gateway_port"
        return 1
    fi
}
