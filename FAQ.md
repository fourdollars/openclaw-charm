# OpenClaw Charm - Frequently Asked Questions (FAQ)

## Table of Contents

- [Getting Started](#getting-started)
  - [How do I get the gateway token?](#how-do-i-get-the-gateway-token)
- [Remote Access](#remote-access)
  - [How do I access the gateway remotely?](#how-do-i-access-the-gateway-remotely)
  - [Why do I get "disconnected (1008): control ui requires HTTPS or localhost"?](#why-do-i-get-disconnected-1008-control-ui-requires-https-or-localhost)
  - [Why do I get "disconnected (1008): unauthorized: gateway token missing"?](#why-do-i-get-disconnected-1008-unauthorized-gateway-token-missing)
  - [Can I disable the token requirement?](#can-i-disable-the-token-requirement)
  - [Why do I get "disconnected (1008): pairing required"?](#why-do-i-get-disconnected-1008-pairing-required)
- [Configuration](#configuration)
  - [How do I change the gateway port?](#how-do-i-change-the-gateway-port)
  - [How do I bind the gateway to all network interfaces?](#how-do-i-bind-the-gateway-to-all-network-interfaces)
  - [How do I enable a messaging platform?](#how-do-i-enable-a-messaging-platform)
  - [How do I approve pairing requests (Telegram/LINE)?](#how-do-i-approve-pairing-requests-telegramline)
  - [Telegram bot not receiving messages?](#telegram-bot-not-receiving-messages)
  - [How do I use the OpenClaw CLI?](#how-do-i-use-the-openclaw-cli)
  - [How do I change the AI model?](#how-do-i-change-the-ai-model)
  - [How do I configure multiple AI models?](#how-do-i-configure-multiple-ai-models)
- [Troubleshooting](#troubleshooting)
  - [The gateway service won't start](#the-gateway-service-wont-start)
  - [Chat not responding / "No API key found for provider" error](#chat-not-responding--no-api-key-found-for-provider-error)
  - [How do I check if the gateway is accessible?](#how-do-i-check-if-the-gateway-is-accessible)
  - [The gateway is running but I can't connect](#the-gateway-is-running-but-i-cant-connect)
  - [How do I reset the gateway token?](#how-do-i-reset-the-gateway-token)
  - [How do I enable browser automation?](#how-do-i-enable-browser-automation)
  - [How do I view OpenClaw version?](#how-do-i-view-openclaw-version)
  - [How do I upgrade OpenClaw?](#how-do-i-upgrade-openclaw)
- [Advanced](#advanced)
  - [How do I use a different JavaScript runtime?](#how-do-i-use-a-different-javascript-runtime)
  - [How do I access the Canvas host?](#how-do-i-access-the-canvas-host)
  - [Can I deploy multiple units for scaling?](#can-i-deploy-multiple-units-for-scaling)
  - [Can I run multiple OpenClaw instances?](#can-i-run-multiple-openclaw-instances)
  - [How do I backup OpenClaw data?](#how-do-i-backup-openclaw-data)
  - [How do I access OpenClaw logs?](#how-do-i-access-openclaw-logs)
- [Getting Help](#getting-help)
  - [Where can I find more documentation?](#where-can-i-find-more-documentation)
  - [How do I report a bug?](#how-do-i-report-a-bug)
- [Quick Reference](#quick-reference)

---

## Getting Started

### How do I get the gateway token?

Use the `get-gateway-token` action to retrieve your authentication token:

```bash
# Get token only (text format)
juju run openclaw/0 get-gateway-token

# Get structured JSON with all URLs
juju run openclaw/0 get-gateway-token format=json

# Get tokenized dashboard URL (ready to open in browser)
juju run openclaw/0 get-gateway-token format=url
```

**Example output (url format):**
```
http://10.47.232.204:18789/?token=59ec145c7a4666f620854f7242b28c816d1419d6d84314e6
```

---

## Remote Access

### How do I access the gateway remotely?

The OpenClaw Gateway requires either **HTTPS** or **localhost** access for security. For remote access, use an **SSH tunnel**.

#### **Option 1: SSH Tunnel (Recommended)**

Create an SSH tunnel to access the gateway securely:

```bash
# Get the gateway URL
juju status openclaw

# Create SSH tunnel (replace IP with your gateway address)
ssh -L 18789:127.0.0.1:18789 ubuntu@10.47.232.204

# Get the tokenized URL
juju run openclaw/0 get-gateway-token format=url

# Replace the IP with localhost in the URL, then open in browser:
http://localhost:18789/?token=YOUR_TOKEN_HERE
```

**Step-by-step:**

1. **Open terminal and create tunnel:**

   ```bash
   ssh -L 18789:127.0.0.1:18789 ubuntu@<gateway-ip>
   ```
   
   Keep this terminal open while using the gateway.

2. **In another terminal, get the tokenized URL:**

   ```bash
   juju run openclaw/0 get-gateway-token format=url
   ```

3. **Replace the IP with `localhost` and open in browser:**

   ```
   http://localhost:18789/?token=<your-token>
   ```

4. **Access the chat interface:**

   ```
   http://localhost:18789/chat?session=main
   ```

The tunnel must stay active while you're using the gateway. Close the SSH session to close the tunnel.

#### **Option 2: Multiple Port Forwarding**

If you need to access multiple services, forward multiple ports:

```bash
ssh -L 18789:127.0.0.1:18789 \
    -L 18793:127.0.0.1:18793 \
    ubuntu@<gateway-ip>
```

This forwards both the gateway (18789) and canvas host (18793) ports.

#### **Option 3: SSH Config File (Persistent Setup)**

For frequent access, add an entry to `~/.ssh/config`:

```
Host openclaw
    HostName 10.47.232.204
    User ubuntu
    LocalForward 18789 127.0.0.1:18789
    LocalForward 18793 127.0.0.1:18793
```

Then simply connect with:
```bash
ssh openclaw
```

#### **Option 4: Reverse SSH Tunnel (Advanced)**

If you need to access from a machine that can't reach the gateway but the gateway can reach you:

```bash
# From the gateway machine
ssh -R 18789:localhost:18789 user@your-machine

# Then access on your-machine
http://localhost:18789/?token=<token>
```

---

### Why do I get "disconnected (1008): control ui requires HTTPS or localhost"?

This error appears when accessing the gateway via HTTP on a non-localhost address (e.g., `http://10.47.232.204:18789`). The OpenClaw Control UI enforces a **secure context requirement** for WebSocket connections.

**Solution:** Use an SSH tunnel (see above) to access via `localhost`, which satisfies the secure context requirement.

---

### Why do I get "disconnected (1008): unauthorized: gateway token missing"?

The Control UI requires authentication. You need to:

1. **Get your gateway token:**
   ```bash
   juju run openclaw/0 get-gateway-token format=url
   ```

2. **Use the tokenized URL** that includes `?token=...` in the URL, or

3. **Manually paste the token** in the Control UI settings:
   - Open `http://localhost:18789/` (via SSH tunnel)
   - Click Settings → Gateway Token
   - Paste your token
   - Save and reload

---

### Can I disable the token requirement?

No. Token authentication is required for security in OpenClaw 2026.1.29+. The token is automatically generated during installation and stored in `~/.openclaw/openclaw.json`.

---

### Why do I get "disconnected (1008): pairing required"?

This error appears when your browser tries to connect to the OpenClaw Gateway but hasn't been approved as a device yet. OpenClaw requires **device pairing** for security - the first operator device (your browser) must be manually approved.

**Symptoms:**
- WebSocket connection closes immediately after entering gateway token
- Error message: "disconnected (1008): pairing required"
- Gateway logs show: `code=1008 reason=pairing required`

**Solution:**

1. **SSH into the gateway unit:**
   ```bash
   juju ssh openclaw/0
   ```

2. **List pending devices:**
   ```bash
   sudo -u ubuntu bash -l <<EOF
   export NVM_DIR="/home/ubuntu/.nvm"
   [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
   nvm use 24 >/dev/null 2>&1
   openclaw devices list
   EOF
   ```

   You'll see output like:
   ```
   Pending (1)
   ┌──────────────────────────────────────┬──────────────────────┬──────────┬──────────────┐
   │ Request                              │ Device               │ Role     │ IP           │
   ├──────────────────────────────────────┼──────────────────────┼──────────┼──────────────┤
   │ 7b426990-8fbf-491b-92de-655553e99218 │ 82ba7068cbd9d04b...  │ operator │ 10.235.133.1 │
   └──────────────────────────────────────┴──────────────────────┴──────────┴──────────────┘
   ```

3. **Approve the device using the Request ID:**
   ```bash
   sudo -u ubuntu bash -l <<EOF
   export NVM_DIR="/home/ubuntu/.nvm"
   [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
   nvm use 24 >/dev/null 2>&1
   openclaw devices approve 7b426990-8fbf-491b-92de-655553e99218
   EOF
   ```

4. **Refresh your browser** - the dashboard should now connect successfully!

**Alternative (simplified command):**

For convenience with SSH tunnels through Juju, you can also use:

```bash
# If you're accessing via: ssh -L 18789:10.235.133.100:18789 juju-host
# And your Juju host is configured in ~/.ssh/config as 'juju-host'

ssh juju-host -- juju ssh openclaw/1 'sudo -u ubuntu bash -l <<EOF
export NVM_DIR="/home/ubuntu/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
nvm use 24 >/dev/null 2>&1
openclaw devices list
EOF'
```

**Why does this happen?**

OpenClaw Gateway uses device pairing as a security mechanism:
- The first operator must be manually approved (this is you!)
- After approval, you can approve additional devices through the web UI
- This prevents unauthorized access even if someone obtains the gateway token

**Note:** If you're using `gateway-bind=lan` mode, make sure the SSH tunnel forwards to the correct IP. For example:
```bash
# Forward to the LAN IP, not localhost
ssh -L 18789:10.235.133.100:18789 juju-host
```

---

## Configuration

### How do I change the gateway port?

```bash
juju config openclaw gateway-port=8080
```

The service will automatically restart on the new port.

---

### How do I bind the gateway to all network interfaces?

```bash
juju config openclaw gateway-bind="lan"
```

This allows access from other machines on your network (without SSH tunnel). **Note:** You'll still need to use the tokenized URL or paste the token in the UI.

---

### How do I enable a messaging platform?

Configure messaging platform credentials:

**Telegram:**

```bash
juju config openclaw telegram-bot-token="YOUR_TELEGRAM_BOT_TOKEN"
```

**Discord:**

```bash
juju config openclaw discord-bot-token="YOUR_DISCORD_BOT_TOKEN"
```

**Slack:**

```bash
juju config openclaw \
  slack-bot-token="xoxb-YOUR-BOT-TOKEN" \
  slack-app-token="xapp-YOUR-APP-TOKEN"
```

**LINE:**

```bash
juju config openclaw \
  line-channel-access-token="YOUR-CHANNEL-ACCESS-TOKEN" \
  line-channel-secret="YOUR-CHANNEL-SECRET"
```

Get your LINE credentials from the [LINE Developers Console](https://developers.line.biz/console/).

**After configuring LINE credentials, you must also configure the webhook in the LINE Developers Console:**

1. Go to [LINE Developers Console](https://developers.line.biz/console/)
2. Select your channel → Messaging API tab
3. Set **Webhook URL** to: `http://YOUR-SERVER-IP:18789/line/webhook`
   - Replace `YOUR-SERVER-IP` with your unit's IP address (get from `juju status openclaw`)
   - If your server is behind NAT, use a public URL or ngrok tunnel
4. Enable **Use webhook** toggle
5. Click **Verify** to test the webhook connection

**Troubleshooting LINE Bot:**

- **Bot doesn't respond to messages:**
  - Verify webhook is configured and verified in LINE Developers Console
  - Check webhook accessibility: `curl http://YOUR-IP:18789/line/webhook` should return `OK`
  - Ensure `gateway-bind=lan` if accessing from external network
  - LINE uses pairing mode by default - check if pairing approval is needed (see below)

- **"Invalid signature" errors in logs:**
  - LINE webhook requests include HMAC-SHA256 signature validation
  - Ensure `line-channel-secret` matches your LINE channel secret exactly
  - Check logs: `juju ssh openclaw/0 'journalctl -u openclaw.service | grep -i line'`

---

### How do I approve pairing requests (Telegram/LINE)?

When a user sends a message to your bot for the first time, OpenClaw requires pairing approval for security (DM policy is set to "pairing" by default for both Telegram and LINE).

**You'll see a pairing code in the message**, like: `Your pairing code is: U78G2QQE`

**To approve the pairing:**

1. **SSH into the OpenClaw unit:**

   ```bash
   juju ssh openclaw/0
   ```

2. **Approve the pairing using the code:**

   ```bash
   # For Telegram
   openclaw pairing approve telegram U78G2QQE
   
   # For LINE
   openclaw pairing approve line U78G2QQE
   ```

3. **Verify it was approved:**

   ```bash
   # For Telegram
   openclaw pairing list telegram
   
   # For LINE
   openclaw pairing list line
   ```

**Common pairing commands:**

```bash
# List all pending pairing requests
openclaw pairing list telegram
openclaw pairing list line

# Approve a specific pairing request
openclaw pairing approve <channel> <CODE>

# Reject a pairing request
openclaw pairing reject <channel> <CODE>

# List approved/paired users
openclaw pairing status <channel>
```

**Alternative: Approve via Gateway UI**

You can also approve pairing requests through the OpenClaw Gateway dashboard:

1. Access the gateway (via SSH tunnel): `http://localhost:18789/?token=<your-token>`
2. Navigate to **Settings** → **Channels** → **Telegram**
3. View pending pairing requests and approve/reject them

---

### Telegram bot not receiving messages?

If you configure Telegram but don't receive messages, check for webhook conflicts:

**Symptoms:**
- Service logs show: `getUpdates conflict: can't use getUpdates method while webhook is active`
- Bot doesn't respond to messages

**Solution:**

1. **Delete the webhook:**

   ```bash
   # Replace with your bot token
   curl "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/deleteWebhook"
   ```

2. **Restart OpenClaw service:**

   ```bash
   juju ssh openclaw/0 'sudo systemctl restart openclaw.service'
   ```

3. **Verify it's working:**

   ```bash
   juju ssh openclaw/0 'sudo journalctl -u openclaw.service -n 20 | grep telegram'
   ```

**Why does this happen?**

Telegram bots can use either **webhooks** OR **polling** (getUpdates), but not both. If your bot was previously configured with a webhook (from another service), OpenClaw's polling mode will conflict with it.

---

### How do I use the OpenClaw CLI?

Once deployed, you can use the `openclaw` command-line tool directly on the server for various management tasks.

**Accessing the CLI:**

```bash
# SSH into the OpenClaw unit
juju ssh openclaw/0

# Now you can run openclaw commands
openclaw --version
openclaw --help
```

**Common CLI commands:**

```bash
# Pairing management
openclaw pairing list telegram          # List pending pairing requests
openclaw pairing approve telegram CODE  # Approve a pairing
openclaw pairing reject telegram CODE   # Reject a pairing
openclaw pairing status telegram        # Show paired users

# System diagnostics
openclaw doctor                         # Check system health
openclaw doctor --fix                   # Auto-fix common issues

# Session management
openclaw sessions list                  # List active sessions
openclaw sessions clean                 # Clean up old sessions

# Configuration
openclaw config show                    # Show current configuration
openclaw config validate                # Validate configuration
```

**Troubleshooting:**

If you get `/usr/bin/env: 'node': No such file or directory`:

This means the OpenClaw CLI symlink is trying to use Node.js but only Bun is installed (when using `install-method=bun`). This is fixed automatically in newer charm versions, but you can fix it manually:

```bash
# Remove the problematic symlink
sudo rm /home/ubuntu/.bun/bin/openclaw

# Verify the wrapper script works
openclaw --version
```

The wrapper script at `/usr/local/bin/openclaw` properly uses Bun to run OpenClaw.

---

### How do I change the AI model?

```bash
# Switch to OpenAI GPT-4
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="sk-YOUR-OPENAI-KEY" \
  ai-model="gpt-4"

# Switch to Anthropic Claude
juju config openclaw \
  ai-provider="anthropic" \
  ai-api-key="sk-ant-YOUR-KEY" \
  ai-model="claude-opus-4-5"

# Switch to Google Gemini
juju config openclaw \
  ai-provider="google" \
  ai-api-key="YOUR-GEMINI-KEY" \
  ai-model="gemini-2.5-flash-lite"

# Use local Ollama (OpenAI-compatible API)
juju config openclaw \
  ai-provider="openai" \
  ai-api-key="ollama" \
  ai-model="llama3.1" \
  ai-base-url="http://192.168.1.100:11434/v1"
```

The charm will regenerate `openclaw.json` and restart the service automatically. 

**Note:** Existing chat sessions will continue using their original model until you start a new session. See the "Important Note" section below for details on session model persistence.

**Important:** When using Ollama's OpenAI-compatible API, you **must** include the `/v1` path in the base URL:

- ✅ Correct: `http://192.168.1.100:11434/v1`
- ❌ Wrong: `http://192.168.1.100:11434`

The `/v1` path is required because:
- Ollama exposes two APIs: native Ollama API at `/api/*` and OpenAI-compatible API at `/v1/*`
- OpenClaw uses the OpenAI SDK which expects endpoints like `/v1/chat/completions`
- Without `/v1`, the API calls will fail

**Verify your Ollama endpoint:**

```bash
# Test Ollama OpenAI-compatible API
curl http://192.168.1.100:11434/v1/models

# Should return JSON with model list
```

**Example with local Ollama:**

```bash
# If Ollama is running on 203.0.113.50
juju config openclaw \
  ai-provider="openai" \
  ai-model="ministral-3:14b" \
  ai-api-key="ollama" \
  ai-base-url="http://203.0.113.50:11434/v1"
```

---

### How do I configure multiple AI models?

OpenClaw Charm supports up to 11 AI models simultaneously (1 primary + 10 additional slots):

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
  ai1-api-key="YOUR-GEMINI-KEY"
```

**Important:** Each slot requires all three parameters (provider, model, api-key). Partial configuration will fail validation.

**Verify configuration:**
```bash
# Check all configured models
juju ssh openclaw/0 'cat /home/ubuntu/.openclaw/agents/main/agent/auth-profiles.json | jq .'
```

**Important Note:** Existing chat sessions retain their original model configuration even after you change the charm config. To use the new model:

1. **Start a new session/conversation** - New sessions automatically use the updated model from `openclaw.json`
2. **Or clear existing session** - Close your current chat and start fresh

This is by design - OpenClaw sessions maintain their own model settings independently, allowing different conversations to use different models simultaneously.

**Verify which model a session is using:**
```bash
# Check current session model
juju ssh openclaw/0 'cat ~/.openclaw/agents/main/sessions/sessions.json | jq ".\"agent:main:main\".model"'

# Check default model in config
juju ssh openclaw/0 'cat ~/.openclaw/openclaw.json | jq .agents.defaults.model.primary'
```

---

## Troubleshooting

### The gateway service won't start

Follow these troubleshooting steps:

1. **Check service status:**

   ```bash
   juju ssh openclaw/0 'sudo systemctl status openclaw.service'
   ```

2. **View logs:**

   ```bash
   juju ssh openclaw/0 'sudo journalctl -u openclaw.service -n 100'
   ```

3. **Verify configuration:**

   ```bash
   juju ssh openclaw/0 'cat ~/.openclaw/openclaw.json'
   ```

4. **Run OpenClaw doctor:**

   ```bash
   juju ssh openclaw/0 'openclaw doctor --fix'
   ```

---

### Chat not responding / "No API key found for provider" error

If you can access the gateway but chat messages get no response, check the logs:

```bash
juju ssh openclaw/0 'sudo journalctl -u openclaw.service -n 50 | grep -i "error\|api key"'
```

If you see:
```
Error: No API key found for provider "google". Auth store: ~/.openclaw/agents/main/agent/auth-profiles.json
```

**This means the AI provider authentication is not configured properly.**

**Solution:**

The charm should automatically configure this during deployment. If it's missing, you can manually fix it:

```bash
# Get your configured API key
API_KEY=$(juju config openclaw ai-api-key)
PROVIDER=$(juju config openclaw ai-provider)

# SSH into the unit and configure auth
juju ssh openclaw/0

# Create auth profile directory
mkdir -p ~/.openclaw/agents/main/agent

# Create auth-profiles.json
cat > ~/.openclaw/agents/main/agent/auth-profiles.json <<EOF
{
  "version": 1,
  "profiles": {
    "${PROVIDER}:manual": {
      "type": "api_key",
      "provider": "${PROVIDER}",
      "key": "${API_KEY}"
    }
  }
}
EOF

# Set proper permissions
chmod 600 ~/.openclaw/agents/main/agent/auth-profiles.json

# Restart service
sudo systemctl restart openclaw.service

# Verify it works
sudo journalctl -u openclaw.service -f
```

**Note:** This issue occurs in OpenClaw 2026.x which changed authentication from environment variables to auth-profiles.json. The charm has been updated to handle this automatically for new deployments.

---

### How do I check if the gateway is accessible?

```bash
# Get the gateway URL
juju status openclaw

# Test from the unit
juju ssh openclaw/0 'curl -s http://127.0.0.1:18789/ | head -10'

# Check listening ports
juju ssh openclaw/0 'sudo ss -tlnp | grep 18789'
```

---

### The gateway is running but I can't connect

Follow these steps:

1. **Check bind mode:**

   ```bash
   juju config openclaw gateway-bind
   ```
   
   If it's `loopback`, the gateway only accepts local connections. Use SSH tunnel or change to `lan`.

2. **Check firewall:**

   ```bash
   juju ssh openclaw/0 'sudo ufw status'
   ```

3. **Verify token:**

   ```bash
   juju run openclaw/0 get-gateway-token
   ```

---

### How do I reset the gateway token?

The token is auto-generated. To regenerate:

```bash
juju ssh openclaw/0 'sudo systemctl stop openclaw.service'
juju ssh openclaw/0 'openclaw doctor --fix'
juju ssh openclaw/0 'sudo systemctl start openclaw.service'

# Get the new token
juju run openclaw/0 get-gateway-token
```

---

### How do I enable browser automation?

Browser automation (Playwright) is disabled by default to reduce installation time and disk usage.

**Enable browser automation:**

```bash
juju config openclaw enable-browser-tool=true
```

This will automatically install Google Chrome and enable browser automation features.

**Features enabled:**

- Web browsing and navigation
- Screenshot capture
- Form automation
- Web scraping
- Headless browser testing

**Post-deployment configuration:**

You can enable browser automation **at any time** - it works both during initial deployment and after the charm is already running. The charm will automatically install Chrome when you set this option to `true`.

**For multi-unit deployments:**

Chrome will be installed on all units (both Gateway and Nodes) to ensure browser commands can run anywhere.

**Verification:**

```bash
# Check if Chrome is installed
juju ssh openclaw/0 'google-chrome --version'

# Check browser service status
juju ssh openclaw/0 'journalctl -u openclaw.service | grep "browser/service"'
```

You should see: `Browser control service ready (profiles=2)`

**Disable browser automation:**

```bash
juju config openclaw enable-browser-tool=false
```

**Note:** Disabling will not uninstall Chrome, but OpenClaw will stop advertising browser capabilities.

---

### How do I view OpenClaw version?

```bash
juju ssh openclaw/0 'openclaw --version'
```

---

### How do I upgrade OpenClaw?

```bash
# Manual upgrade
juju ssh openclaw/0 'sudo su - ubuntu -c "bun update -g openclaw"'
juju ssh openclaw/0 'sudo systemctl restart openclaw.service'

# Or enable auto-update (upgrades on charm refresh)
juju config openclaw auto-update=true
juju refresh openclaw
```

---

## Advanced

### How do I use a different JavaScript runtime?

The charm supports npm, pnpm, bun, or source installation:

```bash
# Use Bun (default)
juju config openclaw install-method="bun"

# Use npm
juju config openclaw install-method="npm"

# Use pnpm  
juju config openclaw install-method="pnpm"

# Install from source
juju config openclaw install-method="source" version="main"
```

---

### How do I access the Canvas host?

The Canvas host serves files for node WebViews on port 18793:

```bash
# Via SSH tunnel
ssh -L 18793:127.0.0.1:18793 ubuntu@<gateway-ip>

# Then access
http://localhost:18793/__openclaw__/canvas/
```

---

## Can I deploy multiple units for scaling?

Yes! The OpenClaw charm supports horizontal scaling with automatic Gateway-Node architecture:

```bash
# Deploy with 3 units
juju deploy openclaw --channel edge -n 3

# Wait for units to be ready
juju status --watch 1s

# Approve pending Nodes (new in charm v19+)
juju run openclaw/leader approve-nodes

# Scale up
juju add-unit openclaw -n 2
juju run openclaw/leader approve-nodes

# Scale down
juju remove-unit openclaw/4
```

**Status example:**

```
Unit         Workload  Message
openclaw/0*  active    Gateway: http://10.47.232.168:18789
openclaw/1   active    Node - connected to openclaw/0
openclaw/2   active    Node - connected to openclaw/0
```

**How it works:**

- **Leader unit**: Runs OpenClaw Gateway (handles messaging, AI processing, dashboard)
- **Non-leader units**: Run OpenClaw Node (provide compute capacity, system access)
- **Automatic coordination**: Units discover each other via peer relations
- **Device pairing**: Nodes require approval before connecting (use `approve-nodes` action)

**Benefits:**

- Horizontal scaling for increased capacity
- Distributed compute for `system.run` commands
- Multiple Nodes provide system access across machines
- Dynamic scaling with `juju add-unit`

**Monitoring:**

```bash
# Check status of all units
juju status openclaw

# View Gateway token
juju run openclaw/0 get-gateway-token

# Check which devices are connected
juju ssh openclaw/0 'openclaw devices list'

# Check Node service status
juju ssh openclaw/1 'systemctl status openclaw-node.service'

# View Node logs
juju ssh openclaw/1 'journalctl -u openclaw-node.service -n 50'
```

**Troubleshooting Nodes:**

If Nodes show as "pending" and not connected:

```bash
# List pending devices
juju ssh openclaw/0 'openclaw devices list'

# Approve all pending Nodes
juju run openclaw/leader approve-nodes

# Or manually approve a specific device
juju ssh openclaw/0 'openclaw devices approve <request-id>'
```

---

### Can I run multiple OpenClaw instances?

Yes! Deploy multiple independent applications with different configurations:

```bash
# Production instance
juju deploy openclaw openclaw-prod \
  --config gateway-port=18789 --channel edge

# Development instance  
juju deploy openclaw openclaw-dev \
  --config gateway-port=18790 --channel edge
```

Each instance has its own isolated configuration and workspace.

---

### How do I backup OpenClaw data?

**Recommended: Use the backup action**

The backup action provides a safe, automated way to backup your data:

```bash
# Create backup with default settings
juju run openclaw/0 backup

# Specify custom output directory
juju run openclaw/0 backup output-path=/home/ubuntu/backups

# Set custom wait timeout for active processes
juju run openclaw/0 backup wait-timeout=60
```

The backup action will:

- ✅ Wait for active processes to complete (graceful)
- ✅ Stop the service safely
- ✅ Create a timestamped compressed archive
- ✅ Automatically restart the service
- ✅ Set proper file permissions

**What gets backed up:**

- Conversation sessions and history
- Memory and workspace files
- AI model configurations
- Device pairings
- OpenClaw configuration

**Download the backup:**

```bash
# Copy backup to your local machine
juju scp openclaw/0:/tmp/openclaw-backup-TIMESTAMP.tar.gz .
```

**Manual backup (alternative method):**

```bash
# Stop service first
juju ssh openclaw/0 'sudo systemctl stop openclaw.service'

# Create backup
juju ssh openclaw/0 'tar -czf ~/openclaw-backup.tar.gz ~/.openclaw/'

# Restart service
juju ssh openclaw/0 'sudo systemctl start openclaw.service'

# Download backup
juju scp openclaw/0:~/openclaw-backup.tar.gz .
```

**Restore from backup:**

```bash
# Upload backup to unit
juju scp openclaw-backup-TIMESTAMP.tar.gz openclaw/0:/tmp/

# Stop service
juju ssh openclaw/0 'sudo systemctl stop openclaw.service'

# Extract backup (overwrites existing data)
juju ssh openclaw/0 'tar -xzf /tmp/openclaw-backup-TIMESTAMP.tar.gz -C /home/ubuntu'

# Fix permissions
juju ssh openclaw/0 'chown -R ubuntu:ubuntu /home/ubuntu/.openclaw'

# Start service
juju ssh openclaw/0 'sudo systemctl start openclaw.service'
```

**Automated backups:**

Set up a cron job for regular backups:
```bash
juju ssh openclaw/0 'cat > /tmp/backup-cron.sh << "EOF"
#!/bin/bash
# Run backup action via juju
/snap/bin/juju run openclaw/0 backup output-path=/home/ubuntu/backups
# Clean up old backups (keep last 7 days)
find /home/ubuntu/backups -name "openclaw-backup-*.tar.gz" -mtime +7 -delete
EOF'

juju ssh openclaw/0 'chmod +x /tmp/backup-cron.sh'
juju ssh openclaw/0 'crontab -l | { cat; echo "0 2 * * * /tmp/backup-cron.sh >> /tmp/backup-cron.log 2>&1"; } | crontab -'
```

---

### How do I access OpenClaw logs?

```bash
# Service logs
juju ssh openclaw/0 'sudo journalctl -u openclaw.service -f'

# OpenClaw application logs
juju ssh openclaw/0 'tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log'

# Charm logs
juju debug-log --replay --include openclaw
```

---

## Getting Help

### Where can I find more documentation?

Official documentation resources:

- **OpenClaw Official Docs:** https://docs.openclaw.ai
- **OpenClaw GitHub:** https://github.com/openclaw/openclaw
- **Charm Repository:** https://github.com/fourdollars/openclaw-charm
- **CharmHub:** https://charmhub.io/openclaw

### How do I report a bug?

Report charm-related issues:

Please report charm-related issues at:
https://github.com/fourdollars/openclaw-charm/issues

For OpenClaw core issues:
https://github.com/openclaw/openclaw/issues

---

## Quick Reference

### Common Commands

```bash
# Get status
juju status openclaw

# Get gateway token
juju run openclaw/0 get-gateway-token format=url

# View logs
juju ssh openclaw/0 'sudo journalctl -u openclaw.service -n 50'

# Restart service
juju ssh openclaw/0 'sudo systemctl restart openclaw.service'

# Update configuration
juju config openclaw ai-model="claude-opus-4-5"

# SSH tunnel for remote access
ssh -L 18789:127.0.0.1:18789 ubuntu@<gateway-ip>
```

### Configuration Cheat Sheet

| Setting | Default | Description |
|---------|---------|-------------|
| `gateway-port` | 18789 | Gateway WebSocket/HTTP port |
| `gateway-bind` | loopback | Bind mode: loopback, lan, or IP |
| `ai-provider` | (required) | anthropic, openai, google |
| `ai-model` | (required) | Model name for selected provider |
| `ai-api-key` | (required) | API key for AI provider |
| `telegram-bot-token` | - | Telegram bot token from @BotFather |
| `discord-bot-token` | - | Discord bot token |
| `slack-bot-token` | - | Slack bot token (xoxb-...) |
| `slack-app-token` | - | Slack app token (xapp-...) |
| `line-channel-access-token` | - | LINE channel access token |
| `line-channel-secret` | - | LINE channel secret |
| `install-method` | npm | npm, pnpm, bun, or source |
| `version` | latest | OpenClaw version to install |
| `enable-browser-tool` | false | Enable Playwright browser |
| `log-level` | info | debug, info, warn, or error |

---

**Happy Clawing!** 🦞
