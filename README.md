# OpenClaw Juju Charm (edge)

[![Charm Tests](https://github.com/fourdollars/openclaw-charm/actions/workflows/test.yaml/badge.svg)](https://github.com/fourdollars/openclaw-charm/actions/workflows/test.yaml)
[![CharmHub](https://charmhub.io/openclaw/badge.svg)](https://charmhub.io/openclaw)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Deploy OpenClaw, your self-hosted personal AI assistant, with a single command using Juju.**

[Website](https://fourdollars.github.io/openclaw-charm/) • [CharmHub](https://charmhub.io/openclaw) • [OpenClaw Docs](https://docs.openclaw.ai) • [Report Bug](https://github.com/fourdollars/openclaw-charm/issues)

---

## What is OpenClaw?

[OpenClaw](https://openclaw.ai) is an open-source, self-hosted personal AI assistant that runs on your own hardware and integrates with multiple messaging platforms. It acts as your persistent, 24/7 assistant accessible through WhatsApp, Telegram, Slack, Discord, and 10+ other channels.

### Key Features

- 🤖 **AI-Powered**: Works with Claude, GPT-4, or local models via Ollama
- 💬 **Multi-Platform**: Supports 13+ messaging platforms simultaneously
- 🔒 **Self-Hosted**: Your data stays on your infrastructure
- 🌐 **Browser Automation**: Integrated Playwright for web tasks
- ⚡ **Production-Ready**: Systemd service with automatic restarts
- 🛡️ **Security-First**: Built-in sandboxing and pairing mode for DMs

---

## Quick Start

### Prerequisites

- A Juju controller (version 3.1+)
- An Ubuntu machine or LXD container (Noble 24.04)
- API keys for your chosen AI provider (Anthropic, OpenAI, etc.)

### Deploy

```bash
# Deploy OpenClaw
juju deploy openclaw --channel edge

# Configure with your AI provider
juju config openclaw \
  ai-provider="anthropic" \
  ai-api-key="sk-ant-xxx" \
  ai-model="claude-opus-4-5"

# Wait for deployment
juju status --watch 1s

# Get the gateway URL
juju status openclaw

# Get the gateway token and dashboard URL
juju run openclaw/0 get-gateway-token format=url
```

Access the OpenClaw Gateway at `http://<unit-ip>:18789`

**For remote access**, see the [FAQ - SSH Tunnel Setup](FAQ.md#how-do-i-access-the-gateway-remotely)

---

## Actions

The OpenClaw charm provides several actions for managing your deployment.

### Get Gateway Token

Retrieve the authentication token for accessing the OpenClaw Gateway:

```bash
# Get token only
juju run openclaw/0 get-gateway-token

# Get structured JSON with URLs
juju run openclaw/0 get-gateway-token format=json

# Get tokenized dashboard URL
juju run openclaw/0 get-gateway-token format=url
```

### Approve Nodes

When deploying multiple units, Node devices are **automatically approved** via the peer relation within ~15 seconds of connecting to the Gateway. This action is provided for manual intervention if needed (e.g., troubleshooting or forcing re-approval):

```bash
# Manually approve all pending Node devices (usually not needed)
juju run openclaw/leader approve-nodes

# Check which devices are pending
juju ssh openclaw/0 'openclaw devices list'
```

**Note**: In normal operation, nodes automatically pair with the Gateway through the `openclaw-cluster` peer relation. This action is only needed if automatic approval fails or for administrative purposes.

### Backup Data

Create a timestamped compressed backup of all OpenClaw data including conversations, memory, and configurations. The service will be gracefully stopped during backup and automatically restarted.

```bash
# Create backup with default settings (output to /tmp)
juju run openclaw/0 backup

# Specify custom output path
juju run openclaw/0 backup output-path=/home/ubuntu/backups

# Set custom wait timeout (default 30 seconds)
juju run openclaw/0 backup wait-timeout=60

# Force backup even if processes are active (not recommended)
juju run openclaw/0 backup force=true
```

**What gets backed up:**
- Conversation sessions (`.openclaw/agents/main/sessions/`)
- Memory and workspace files (`.openclaw/workspace/`)
- AI model configurations (`.openclaw/agents/main/agent/`)
- Device pairings (`.openclaw/devices/`)
- OpenClaw configuration (`.openclaw/openclaw.json`)

**Backup process:**
1. Waits for active processes to complete (up to `wait-timeout` seconds)
2. Gracefully stops the OpenClaw service
3. Creates compressed tar.gz archive with timestamp
4. Restarts the service
5. Sets proper permissions (600, owner: ubuntu)

**Example output:**
```
backup-file: /tmp/openclaw-backup-20260202-082607.tar.gz
backup-size: 400K
status: success
```

**Restore from backup:**

```bash
# Stop OpenClaw service
juju ssh openclaw/0 'sudo systemctl stop openclaw.service'

# Extract backup (this will overwrite existing data)
juju ssh openclaw/0 'tar -xzf /tmp/openclaw-backup-TIMESTAMP.tar.gz -C /home/ubuntu'

# Start service
juju ssh openclaw/0 'sudo systemctl start openclaw.service'
```

---

## Configuration

### AI Provider Setup

Configure your preferred AI provider using the following examples:

**Anthropic Claude (Recommended)**

```bash
juju config openclaw \
  ai-provider="anthropic" \
  ai-api-key="sk-ant-xxx" \
  ai-model="claude-opus-4-5"
```

**OpenAI**

```bash
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="sk-xxx" \
  ai-model="gpt-4"
```

**Google Gemini**

```bash
juju config openclaw \
  ai-provider="google" \
  ai-api-key="YOUR-GEMINI-API-KEY" \
  ai-model="gemini-2.5-flash-lite"
```

**Local Models (Ollama)**

```bash
juju config openclaw \
  ai-provider="ollama" \
  ai-model="llama3"
```

**Local Models (LM Studio)**

```bash
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="lm-studio" \
  ai-model="local-model" \
  ai-base-url="http://localhost:1234/v1"
```

**Other OpenAI-compatible Services**

```bash
# vLLM
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="dummy-key" \
  ai-model="meta-llama/Llama-3.3-70B-Instruct" \
  ai-base-url="http://localhost:8000/v1"

# Text Generation WebUI
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="dummy-key" \
  ai-model="local-model" \
  ai-base-url="http://localhost:5000/v1"
```

### Comma-Separated Models for Fallback

Both `ai-model` and `ai[0-9]-model` configurations support comma-separated model lists. The first model becomes the primary, and remaining models are added as fallbacks.

**Multiple Models from Same Provider:**

```bash
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="sk-xxx" \
  ai-model="gpt-4,gpt-3.5-turbo"
```

This sets `gpt-4` as primary with `gpt-3.5-turbo` as fallback.

**Cross-Provider Fallbacks (using provider/ prefix):**

```bash
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="sk-xxx" \
  ai-model="gpt-4,anthropic/claude-sonnet-4,google/gemini-2.5-pro"
```

This enables intelligent fallback across providers:
- Primary: `openai/gpt-4`
- Fallback 1: `anthropic/claude-sonnet-4` 
- Fallback 2: `google/gemini-2.5-pro`

**Note:** Models without `provider/` prefix will use the configured `ai-provider`. When using `provider/` prefixes in comma-separated lists, ensure corresponding auth profiles are configured via additional AI slots (each provider needs its own slot with API key).

**GitHub Copilot as Model Aggregator:**

GitHub Copilot Models API acts as an aggregator, routing requests to multiple backend providers (Anthropic, Google, OpenAI, etc.) through a single GitHub API key:

```bash
juju config openclaw \
  ai-provider="github-copilot" \
  ai-api-key="ghp_your_github_token" \
  ai-model="gemini-3-flash-preview,gemini-3-pro-preview,gemini-2.5-pro,claude-haiku-4.5,claude-sonnet-4.5,claude-sonnet-4"
```

This configures:
- Primary: `github-copilot/gemini-3-flash-preview`
- Fallbacks: All other models via `github-copilot/*` provider

GitHub Copilot handles routing to the appropriate backend provider (Google for Gemini models, Anthropic for Claude models).

### Multi-AI Model Support

OpenClaw Charm supports configuring up to 11 AI models simultaneously (1 primary + 10 additional slots). This enables model switching, fallback, and specialized model usage for different tasks.

**Using Multiple Providers - Requires Multiple Slots:**

To use models from different AI providers (e.g., both Google Gemini and Anthropic Claude), configure each provider in a separate slot with its own API key:

```bash
# Slot 0: Google models
juju config openclaw \
  ai-provider="google" \
  ai-api-key="GOOGLE_API_KEY" \
  ai-model="gemini-3-flash-preview,gemini-3-pro-preview,gemini-2.5-pro"

# Slot 1: Anthropic models
juju config openclaw \
  ai0-provider="anthropic" \
  ai0-api-key="ANTHROPIC_API_KEY" \
  ai0-model="claude-haiku-4.5,claude-sonnet-4.5,claude-sonnet-4"
```

Result:
- Primary: `google/gemini-3-flash-preview`
- Fallbacks: `google/gemini-3-pro-preview`, `google/gemini-2.5-pro`, `anthropic/claude-haiku-4.5`, `anthropic/claude-sonnet-4.5`, `anthropic/claude-sonnet-4`

**Configure Additional AI Models:**

```bash
# Configure primary AI model
juju config openclaw \
  ai-provider="anthropic" \
  ai-api-key="sk-ant-xxx" \
  ai-model="claude-opus-4-5"

# Add additional models in slots 0-9
juju config openclaw \
  ai0-provider="openai" \
  ai0-model="gpt-4" \
  ai0-api-key="sk-xxx"

juju config openclaw \
  ai1-provider="google" \
  ai1-model="gemini-2.5-flash-lite" \
  ai1-api-key="YOUR-GEMINI-API-KEY"

juju config openclaw \
  ai2-provider="anthropic" \
  ai2-model="claude-sonnet-4" \
  ai2-api-key="sk-ant-yyy"

# Slots also support comma-separated models
juju config openclaw \
  ai3-provider="openai" \
  ai3-model="gpt-4,gpt-3.5-turbo,gpt-4o-mini" \
  ai3-api-key="sk-xxx"
```

**All AI Slots:**

- Primary: `ai-provider`, `ai-model`, `ai-api-key`, `ai-base-url` (optional)
- Slot 0: `ai0-provider`, `ai0-model`, `ai0-api-key`, `ai0-base-url` (optional)
- Slot 1: `ai1-provider`, `ai1-model`, `ai1-api-key`, `ai1-base-url` (optional)
- Slot 2: `ai2-provider`, `ai2-model`, `ai2-api-key`, `ai2-base-url` (optional)
- Slot 3: `ai3-provider`, `ai3-model`, `ai3-api-key`, `ai3-base-url` (optional)
- Slot 4: `ai4-provider`, `ai4-model`, `ai4-api-key`, `ai4-base-url` (optional)
- Slot 5: `ai5-provider`, `ai5-model`, `ai5-api-key`, `ai5-base-url` (optional)
- Slot 6: `ai6-provider`, `ai6-model`, `ai6-api-key`, `ai6-base-url` (optional)
- Slot 7: `ai7-provider`, `ai7-model`, `ai7-api-key`, `ai7-base-url` (optional)
- Slot 8: `ai8-provider`, `ai8-model`, `ai8-api-key`, `ai8-base-url` (optional)
- Slot 9: `ai9-provider`, `ai9-model`, `ai9-api-key`, `ai9-base-url` (optional)

**Note:** Each slot requires at minimum the three core parameters (provider, model, api-key). The `base-url` parameter is optional and only needed for custom API endpoints. Partially configured slots will trigger validation errors.

**Using Custom Base URLs with Multiple Models:**

```bash
# Mix cloud and local AI models
juju config openclaw \
  ai-provider="anthropic" \
  ai-api-key="sk-ant-xxx" \
  ai-model="claude-opus-4-5"

# Add LM Studio instance in slot 0
juju config openclaw \
  ai0-provider="openai" \
  ai0-api-key="lm-studio" \
  ai0-model="local-llama3" \
  ai0-base-url="http://localhost:1234/v1"

# Add vLLM instance in slot 1
juju config openclaw \
  ai1-provider="openai" \
  ai1-api-key="vllm-key" \
  ai1-model="meta-llama/Llama-3.3-70B-Instruct" \
  ai1-base-url="http://192.168.1.100:8000/v1"
```

This configuration creates:
- Primary model using Anthropic's cloud API
- Slot 0 using LM Studio running locally
- Slot 1 using a vLLM server on your network

OpenClaw will generate the appropriate `models.providers` configuration in `openclaw.json` with custom baseUrls for each provider that has one specified.

### Messaging Channels

Configure messaging platform integrations:

**Enable Telegram:**

```bash
juju config openclaw telegram-bot-token="123456:ABC-DEF"
```

**Enable Discord:**

```bash
juju config openclaw discord-bot-token="YOUR.DISCORD.TOKEN"
```

**Enable Slack:**

```bash
juju config openclaw \
  slack-bot-token="xoxb-xxx" \
  slack-app-token="xapp-xxx"
```

**Enable LINE:**

```bash
juju config openclaw \
  line-channel-access-token="YOUR-CHANNEL-ACCESS-TOKEN" \
  line-channel-secret="YOUR-CHANNEL-SECRET"
```

**Enable Multiple Platforms Simultaneously:**

```bash
juju config openclaw \
  telegram-bot-token="123456:ABC-DEF" \
  discord-bot-token="YOUR.DISCORD.TOKEN" \
  slack-bot-token="xoxb-xxx" \
  slack-app-token="xapp-xxx" \
  line-channel-access-token="YOUR-CHANNEL-ACCESS-TOKEN" \
  line-channel-secret="YOUR-CHANNEL-SECRET"
```

### Security Configuration

```bash
# Set DM access policy (pairing mode recommended)
juju config openclaw dm-policy="pairing"

# Configure sandbox mode
juju config openclaw sandbox-mode="non-main"

# Disable browser automation if not needed
juju config openclaw enable-browser-tool=false
```

### Gateway Settings

```bash
# Change gateway port
juju config openclaw gateway-port=8080

# Bind to all interfaces (for remote access)
juju config openclaw gateway-bind="lan"

# Set log level
juju config openclaw log-level="debug"

# Enable browser automation (can be set anytime)
juju config openclaw enable-browser-tool=true
```

---

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `gateway-port` | int | 18789 | Gateway WebSocket/HTTP port |
| `gateway-bind` | string | loopback | Bind mode: loopback, lan, or IP |
| `node-version` | string | 24 | Node.js major version (min 22) |
| `ai-provider` | string | - | AI provider: anthropic, openai, google, bedrock, ollama |
| `ai-model` | string | - | AI model name |
| `ai-api-key` | string | - | API key for selected provider |
| `ai-base-url` | string | - | Custom API base URL (for LM Studio, vLLM, etc.) |
| `ai0-provider` ... `ai9-provider` | string | - | Additional AI provider slots (0-9) |
| `ai0-model` ... `ai9-model` | string | - | Additional AI model name slots (0-9) |
| `ai0-api-key` ... `ai9-api-key` | string | - | Additional AI API key slots (0-9) |
| `ai0-base-url` ... `ai9-base-url` | string | - | Custom API base URL for additional slots (0-9) |
| `telegram-bot-token` | string | - | Telegram bot token from @BotFather |
| `discord-bot-token` | string | - | Discord bot token |
| `slack-bot-token` | string | - | Slack bot token (xoxb-...) |
| `slack-app-token` | string | - | Slack app token (xapp-...) |
| `line-channel-access-token` | string | - | LINE channel access token |
| `line-channel-secret` | string | - | LINE channel secret |
| `dm-policy` | string | pairing | DM policy: pairing, open, closed |
| `sandbox-mode` | string | non-main | Sandbox: all, non-main, none |
| `install-method` | string | npm | Install method: npm, pnpm, bun, source |
| `version` | string | latest | Version to install |
| `auto-update` | boolean | false | Auto-update on charm upgrade |
| `enable-browser-tool` | boolean | false | Enable Playwright browser (post-deployment supported) |
| `log-level` | string | info | Log level: debug, info, warn, error |

---

## Advanced Usage

### Scaling with Multiple Units

OpenClaw charm supports horizontal scaling with automatic Gateway-Node architecture:

```bash
# Deploy with 3 units (IMPORTANT: set gateway-bind=lan for multi-unit)
juju deploy openclaw --channel edge -n 3 \
  --config gateway-bind=lan \
  --config ai-provider="anthropic" \
  --config ai-api-key="sk-ant-xxx" \
  --config ai-model="claude-opus-4-5"

# Wait for deployment
juju status --watch 1s

# Nodes will automatically pair with Gateway via peer relation
# (Auto-approval happens within ~15 seconds of node connection)

# Scale up to 5 units
juju add-unit openclaw -n 2

# Scale down to 2 units
juju remove-unit openclaw/2
```

**⚠️ CRITICAL: Multi-Unit Deployment Requirements**

For multi-unit deployments to work properly, you **MUST** set `gateway-bind=lan`:

```bash
juju config openclaw gateway-bind=lan
```

**Why this is required:**
- Default `gateway-bind=loopback` binds Gateway to `127.0.0.1` (localhost only)
- Node units on different machines cannot connect to `127.0.0.1` 
- Setting `gateway-bind=lan` binds Gateway to all network interfaces
- This allows Nodes to connect via the Gateway's private IP address

The charm will automatically **block deployment** if you attempt multi-unit with `gateway-bind=loopback`.

**Status example:**

```
Unit         Workload  Message
openclaw/0*  active    Gateway: http://10.47.232.168:18789
openclaw/1   active    Node - connected to openclaw/0
openclaw/2   active    Node - connected to openclaw/0
```

**How it works:**
- **Leader unit** (elected by Juju) runs the OpenClaw Gateway service
- **Non-leader units** run OpenClaw Node services that connect to the Gateway
- All units automatically coordinate through peer relations
- Nodes authenticate using gateway tokens and device pairing
- Gateway handles all messaging channels and AI processing
- Nodes provide additional compute capacity and system access

**Authentication Flow:**
1. Gateway generates auth token during onboarding
2. Token shared via Juju peer relation (`openclaw-cluster`)
3. Nodes receive token and inject into systemd service via drop-in file
4. Nodes connect with gateway token → Gateway validates
5. Device pairing created → Auto-approved by Gateway
6. Node receives device token → Subsequent connections use device token

**Benefits:**

- **Horizontal scaling**: Add more nodes for increased capacity
- **Load distribution**: Nodes can handle system.run commands across multiple machines
- **Distributed access**: Nodes provide system access across different machines
- **Automatic coordination**: Units discover and connect through peer relations
- **High availability**: Add redundancy across multiple machines

### Multiple Instances

Deploy multiple independent OpenClaw instances (separate applications):

```bash
# Production instance
juju deploy openclaw openclaw-prod \
  --config gateway-port=18789 --channel edge

# Development instance
juju deploy openclaw openclaw-dev \
  --config gateway-port=18790 --channel edge
```

### Custom Installation

Choose your preferred installation method:

**Install using Bun:**

```bash
juju config openclaw install-method="bun"
```

**Install using pnpm:**

```bash
juju config openclaw install-method="pnpm"
```

**Install from source:**

```bash
juju config openclaw \
  install-method="source" \
  version="main"
```

**Pin to specific version:**

```bash
juju config openclaw \
  version="2026.1.29"
```

**Enable auto-updates:**

```bash
juju config openclaw auto-update=true
```

### Scaling Considerations

OpenClaw Gateway is designed to run as a single instance managing multiple channels. For high availability:

1. **Deploy multiple instances** with different channels
2. **Use load balancer** in front of multiple gateways
3. **Share workspace storage** via NFS or similar

---

## Troubleshooting

For detailed troubleshooting and common issues, see the **[FAQ](FAQ.md)**.

### Check Service Status

```bash
# View charm status
juju status openclaw --relations

# SSH into unit
juju ssh openclaw/0

# Check systemd service (Gateway)
juju ssh openclaw/0 'systemctl --user status openclaw-gateway.service'

# Check systemd service (Node)
juju ssh openclaw/1 'systemctl --user status openclaw-node.service'

# View service logs
juju ssh openclaw/0 'journalctl --user -u openclaw-gateway.service -f'
juju ssh openclaw/1 'journalctl --user -u openclaw-node.service -f'
```

### Common Issues

**Service won't start:**

- Verify API keys are configured correctly
- Check logs: `juju debug-log --replay --include openclaw`
- Ensure Node.js 22+ is installed: `juju ssh openclaw/0 'node --version'`

**Cannot access gateway:**

- Check port is open: `juju ssh openclaw/0 'ss -tulpn | grep 18789'`
- Verify gateway-bind setting: `juju config openclaw gateway-bind`
- Check firewall rules on the host

**Messaging channels not working:**

- Verify channel tokens are correct
- Check channel configuration: `juju ssh openclaw/0 'cat /home/ubuntu/.openclaw/openclaw.json'`
- Review OpenClaw logs for connection errors

### Multi-Unit Deployment Issues

**Issue: Node shows "unauthorized: gateway token missing"**

**Symptoms:**
```
juju ssh openclaw/1 'journalctl --user -u openclaw-node.service --no-pager | tail -20'
# Shows: "unauthorized: gateway token missing (provide gateway auth token)"
```

**Causes:**
- Systemd drop-in file not created or token not in peer relation
- Node started before Gateway published token to relation

**Solutions:**
```bash
# Check if token drop-in exists
juju ssh openclaw/1 'cat /home/ubuntu/.config/systemd/user/openclaw-node.service.d/gateway-token.conf'

# Check peer relation data
juju ssh openclaw/0 'relation-get -r $(relation-ids openclaw-cluster | head -1) - openclaw/0'

# Trigger config-changed to recreate drop-in
juju config openclaw log-level=info

# Manual restart if needed
juju ssh openclaw/1 'systemctl --user restart openclaw-node.service'
```

**Issue: Node shows "Waiting for device pairing approval"**

**Symptoms:**
```
juju status openclaw/1
# Shows: waiting - "Waiting for device pairing approval"
```

**Causes:**
- Auto-approve hasn't completed yet (normal delay: ~15 seconds after node connects)
- Auto-approve script failed to run
- Device is in pending list but approval failed

**Solutions:**
```bash
# Check pending devices on Gateway
juju ssh openclaw/0 'sudo su - ubuntu -c ". ~/.nvm/nvm.sh && openclaw devices list"'

# Manually approve all pending nodes
juju run openclaw/leader approve-nodes

# Check auto-approve script logs
juju ssh openclaw/0 'sudo journalctl --user -u openclaw-gateway.service --no-pager | grep auto-approve'
```

**Issue: Node shows "Cannot reach Gateway"**

**Symptoms:**
```
juju status openclaw/1
# Shows: blocked - "Cannot reach Gateway at 10.x.x.x:18789"
```

**Causes:**
- Gateway bound to loopback instead of LAN
- Network connectivity issue between units
- Firewall blocking Gateway port

**Solutions:**
```bash
# Check Gateway binding
juju config openclaw gateway-bind
# Should be "lan" for multi-unit, not "loopback"

# Fix binding
juju config openclaw gateway-bind=lan

# Verify Gateway is listening on network interface
juju ssh openclaw/0 'ss -tulpn | grep 18789'
# Should show: 0.0.0.0:18789 (not 127.0.0.1:18789)

# Test connectivity from Node
juju ssh openclaw/1 'timeout 3 bash -c "echo > /dev/tcp/$(relation-get -r $(relation-ids openclaw-cluster | head -1) gateway-host openclaw/0)/18789" && echo "Gateway reachable" || echo "Gateway unreachable"'
```

**Issue: Multi-unit deployment blocked at start**

**Symptoms:**
```
juju status openclaw/0
# Shows: blocked - "Multi-unit deployment requires gateway-bind=lan (currently: loopback)"
```

**Cause:**
- Attempting multi-unit deployment with `gateway-bind=loopback`

**Solution:**
```bash
# Set gateway-bind to lan
juju config openclaw gateway-bind=lan

# Deployment will proceed automatically
```

**Issue: Node configuration shows wrong display name**

**Symptoms:**
- Device list shows "ip-10-x-x-x" instead of "openclaw/1"

**Cause:**
- Using old charm version without Juju unit name support

**Solution:**
```bash
# Check node.json
juju ssh openclaw/1 'cat /home/ubuntu/.openclaw/node.json'
# Should show: "displayName": "openclaw/1"

# If not, upgrade charm
juju refresh openclaw --channel edge

# Or regenerate config
juju config openclaw log-level=debug  # Triggers config-changed
```

### Debug Mode

```bash
# Enable debug logging
juju config openclaw log-level="debug"

# View detailed logs (Gateway)
juju ssh openclaw/0 'journalctl --user -u openclaw-gateway.service -n 500'

# View detailed logs (Node)
juju ssh openclaw/1 'journalctl --user -u openclaw-node.service -n 500'

# Check all relation data
juju run openclaw/0 relation-get -r $(relation-ids openclaw-cluster | head -1)
```

### Verification Commands for Multi-Unit Deployments

```bash
# 1. Check deployment status
juju status openclaw

# 2. Verify Node config (no token in file - by design)
juju ssh openclaw/1 'cat /home/ubuntu/.openclaw/node.json | jq .'

# 3. Verify systemd drop-in (token should be present)
juju ssh openclaw/1 'cat /home/ubuntu/.config/systemd/user/openclaw-node.service.d/gateway-token.conf'

# 4. Check Gateway devices list
juju ssh openclaw/0 'sudo su - ubuntu -c ". ~/.nvm/nvm.sh && openclaw devices list"'

# 5. Check Node connection logs
juju ssh openclaw/1 'journalctl --user -u openclaw-node.service --since "5 minutes ago" --no-pager | tail -30'

# 6. Verify Gateway listening on network interface
juju ssh openclaw/0 'ss -tulpn | grep 18789'
# Expected: 0.0.0.0:18789 (not 127.0.0.1:18789)

# 7. Test Gateway connectivity from Node
juju ssh openclaw/1 'nc -zv $(relation-get -r $(relation-ids openclaw-cluster | head -1) gateway-host openclaw/0) 18789'
```

---

## Development

### Building the Charm

```bash
# Install charmcraft
sudo snap install charmcraft --classic

# Pack the charm
charmcraft pack

# Deploy locally
juju deploy ./openclaw_ubuntu-24.04-amd64.charm \
  --config anthropic-api-key="test-key"
```

### Running Tests

```bash
# Lint shell scripts
shellcheck hooks/*

# Run full test suite (requires LXD and Juju)
./.github/workflows/test.yaml  # See workflow for test commands
```

### Project Structure

```
openclaw-charm/
├── metadata.yaml           # Charm metadata
├── config.yaml            # Configuration options
├── hooks/                 # Charm hooks
│   ├── common.sh         # Shared functions
│   ├── install           # Installation hook
│   ├── start             # Start hook
│   ├── stop              # Stop hook
│   ├── config-changed    # Config change handler
│   └── upgrade-charm     # Upgrade handler
├── docs/                  # GitHub Pages
│   └── index.html        # Documentation site
├── .github/workflows/     # CI/CD
│   ├── test.yaml         # Automated tests
│   ├── publish.yaml      # CharmHub publishing
│   └── pages.yaml        # GitHub Pages deploy
└── README.md             # This file
```

---

## CI/CD Pipeline

This charm includes comprehensive CI/CD workflows:

### Test Workflow (`test.yaml`)

Runs on every push and PR:

- **Lint**: Validates shell scripts and metadata
- **Install Test**: Deploys charm with both npm and pnpm methods on Noble 24.04
- **Channel Test**: Verifies messaging channel configuration
- **Upgrade Test**: Tests charm upgrade process

### Publish Workflow (`publish.yaml`)

Triggered on version tags:

1. Builds and packs the charm
2. Uploads to CharmHub
3. Releases to appropriate channel:
   - `vX.Y.Z` tags → candidate channel
   - `vX.Y.Z-rc*` tags → beta channel
   - Other tags → edge channel
4. Manual approval required for stable channel
5. Creates GitHub release with charm artifact

### GitHub Pages Workflow (`pages.yaml`)

Automatically deploys documentation site on changes to `docs/`

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

### Reporting Issues

Found a bug? [Open an issue](https://github.com/fourdollars/openclaw-charm/issues) with:

- Juju version (`juju version`)
- Charm version (`juju status openclaw`)
- Steps to reproduce
- Relevant logs

---

## Security

### Reporting Vulnerabilities

Please report security vulnerabilities privately to [fourdollars+security@gmail.com](mailto:fourdollars+security@gmail.com).

### Best Practices

Follow these security best practices:

- **Use pairing mode** for DM access (`dm-policy="pairing"`)
- **Enable sandboxing** for non-main sessions
- **Bind to loopback** unless remote access is required
- **Rotate API keys** regularly
- **Keep charm updated** to latest stable version

---

## License

This charm is licensed under the MIT License. See [LICENSE](LICENSE) for details.

OpenClaw itself is MIT licensed. See [openclaw/openclaw](https://github.com/openclaw/openclaw) for the upstream project.

---

## Resources

- **[FAQ - Frequently Asked Questions](FAQ.md)**: Common issues and solutions
- **OpenClaw Website**: https://openclaw.ai
- **OpenClaw Documentation**: https://docs.openclaw.ai
- **OpenClaw GitHub**: https://github.com/openclaw/openclaw
- **Charm Documentation**: https://fourdollars.github.io/openclaw-charm/
- **CharmHub Page**: https://charmhub.io/openclaw
- **Juju Documentation**: https://juju.is/docs
- **Discord Community**: https://discord.gg/clawd

---

## Acknowledgments

- OpenClaw team for creating an amazing open-source AI assistant
- Canonical for the Juju ecosystem and tooling
- The charm development community for best practices and examples

---

**Happy Deploying!** 🎉

If you find this charm useful, please ⭐ star the repository and share it with others!
