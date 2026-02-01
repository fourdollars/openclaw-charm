# OpenClaw Charm - Frequently Asked Questions (FAQ)

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

---

#### **Option 2: Multiple Port Forwarding**

If you need to access multiple services, forward multiple ports:

```bash
ssh -L 18789:127.0.0.1:18789 \
    -L 18793:127.0.0.1:18793 \
    ubuntu@<gateway-ip>
```

This forwards both the gateway (18789) and canvas host (18793) ports.

---

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

---

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

---

### How do I approve Telegram pairing requests?

When a user sends a message to your Telegram bot for the first time, OpenClaw requires pairing approval for security (DM policy is set to "pairing" by default).

**You'll see a pairing code in the Telegram message**, like: `Your pairing code is: U78G2QQE`

**To approve the pairing:**

1. **SSH into the OpenClaw unit:**
   ```bash
   juju ssh openclaw/0
   ```

2. **Approve the pairing using the code:**
   ```bash
   openclaw pairing approve telegram U78G2QQE
   ```

3. **Verify it was approved:**
   ```bash
   openclaw pairing list telegram
   ```

**Common pairing commands:**

```bash
# List all pending pairing requests for Telegram
openclaw pairing list telegram

# Approve a specific pairing request
openclaw pairing approve telegram <CODE>

# Reject a pairing request
openclaw pairing reject telegram <CODE>

# List approved/paired users
openclaw pairing status telegram
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

You should see `[telegram] [default] starting provider (@YourBotName)` without any errors.

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
  ai-model="gemini-2.0-flash"
```

---

## Troubleshooting

### The gateway service won't start

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

To enable:
```bash
juju config openclaw enable-browser-tool=true
```

This will install Chrome and enable browser automation features.

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

### Can I run multiple OpenClaw instances?

Yes! Deploy multiple units with different configurations:

```bash
# Production instance
juju deploy openclaw openclaw-prod \
  --config gateway-port=18789

# Development instance  
juju deploy openclaw openclaw-dev \
  --config gateway-port=18790
```

Each instance has its own isolated configuration and workspace.

---

### How do I backup OpenClaw data?

```bash
# Backup configuration and sessions
juju ssh openclaw/0 'tar -czf ~/openclaw-backup.tar.gz ~/.openclaw/'

# Download backup
juju scp openclaw/0:~/openclaw-backup.tar.gz .
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

- **OpenClaw Official Docs:** https://docs.openclaw.ai
- **OpenClaw GitHub:** https://github.com/openclaw/openclaw
- **Charm Repository:** https://github.com/fourdollars/openclaw-charm
- **CharmHub:** https://charmhub.io/openclaw

### How do I report a bug?

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
| `install-method` | npm | npm, pnpm, bun, or source |
| `version` | latest | OpenClaw version to install |
| `enable-browser-tool` | false | Enable Playwright browser |
| `log-level` | info | debug, info, warn, or error |

---

**Happy Clawing!** 🦞
