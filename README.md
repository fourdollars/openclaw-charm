# OpenClaw Juju Charm

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
juju deploy openclaw

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

---

## Configuration

### AI Provider Setup

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
  ai-model="gemini-2.0-flash"
```

**Local Models (Ollama)**
```bash
juju config openclaw \
  ai-provider="ollama" \
  ai-model="llama3"
```

### Multi-AI Model Support

OpenClaw Charm supports configuring up to 11 AI models simultaneously (1 primary + 10 additional slots). This enables model switching, fallback, and specialized model usage for different tasks.

**Configure Additional AI Models**
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
  ai1-model="gemini-2.0-flash" \
  ai1-api-key="YOUR-GEMINI-API-KEY"

juju config openclaw \
  ai2-provider="anthropic" \
  ai2-model="claude-sonnet-4" \
  ai2-api-key="sk-ant-yyy"
```

**All AI Slots**
- Primary: `ai-provider`, `ai-model`, `ai-api-key`
- Slot 0: `ai0-provider`, `ai0-model`, `ai0-api-key`
- Slot 1: `ai1-provider`, `ai1-model`, `ai1-api-key`
- Slot 2: `ai2-provider`, `ai2-model`, `ai2-api-key`
- Slot 3: `ai3-provider`, `ai3-model`, `ai3-api-key`
- Slot 4: `ai4-provider`, `ai4-model`, `ai4-api-key`
- Slot 5: `ai5-provider`, `ai5-model`, `ai5-api-key`
- Slot 6: `ai6-provider`, `ai6-model`, `ai6-api-key`
- Slot 7: `ai7-provider`, `ai7-model`, `ai7-api-key`
- Slot 8: `ai8-provider`, `ai8-model`, `ai8-api-key`
- Slot 9: `ai9-provider`, `ai9-model`, `ai9-api-key`

Each slot requires all three parameters (provider, model, api-key) to be configured. Partially configured slots will trigger validation errors.

### Messaging Channels

**Enable Telegram**
```bash
juju config openclaw telegram-bot-token="123456:ABC-DEF"
```

**Enable Discord**
```bash
juju config openclaw discord-bot-token="YOUR.DISCORD.TOKEN"
```

**Enable Slack**
```bash
juju config openclaw \
  slack-bot-token="xoxb-xxx" \
  slack-app-token="xapp-xxx"
```

**Enable Multiple Platforms Simultaneously**
```bash
juju config openclaw \
  telegram-bot-token="123456:ABC-DEF" \
  discord-bot-token="YOUR.DISCORD.TOKEN" \
  slack-bot-token="xoxb-xxx" \
  slack-app-token="xapp-xxx"
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
| `ai0-provider` ... `ai9-provider` | string | - | Additional AI provider slots (0-9) |
| `ai0-model` ... `ai9-model` | string | - | Additional AI model name slots (0-9) |
| `ai0-api-key` ... `ai9-api-key` | string | - | Additional AI API key slots (0-9) |
| `telegram-bot-token` | string | - | Telegram bot token from @BotFather |
| `discord-bot-token` | string | - | Discord bot token |
| `slack-bot-token` | string | - | Slack bot token (xoxb-...) |
| `slack-app-token` | string | - | Slack app token (xapp-...) |
| `dm-policy` | string | pairing | DM policy: pairing, open, closed |
| `sandbox-mode` | string | non-main | Sandbox: all, non-main, none |
| `install-method` | string | npm | Install method: npm, pnpm, bun, source |
| `version` | string | latest | Version to install |
| `auto-update` | boolean | false | Auto-update on charm upgrade |
| `enable-browser-tool` | boolean | true | Enable Playwright browser |
| `log-level` | string | info | Log level: debug, info, warn, error |

---

## Advanced Usage

### Multiple Instances

Deploy multiple OpenClaw instances for different teams or environments:

```bash
# Production instance
juju deploy openclaw openclaw-prod \
  --config gateway-port=18789

# Development instance
juju deploy openclaw openclaw-dev \
  --config gateway-port=18790
```

### Custom Installation

**Install using Bun**
```bash
juju config openclaw install-method="bun"
```

**Install using pnpm**
```bash
juju config openclaw install-method="pnpm"
```

**Install from source**
```bash
juju config openclaw \
  install-method="source" \
  version="main"
```

**Pin to specific version**
```bash
juju config openclaw \
  version="2026.1.29"
```

**Enable auto-updates**
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

# Check systemd service
juju ssh openclaw/0 'systemctl status openclaw.service'

# View service logs
juju ssh openclaw/0 'journalctl -u openclaw.service -f'
```

### Common Issues

**Service won't start**
- Verify API keys are configured correctly
- Check logs: `juju debug-log --replay --include openclaw`
- Ensure Node.js 22+ is installed: `juju ssh openclaw/0 'node --version'`

**Cannot access gateway**
- Check port is open: `juju ssh openclaw/0 'ss -tulpn | grep 18789'`
- Verify gateway-bind setting: `juju config openclaw gateway-bind`
- Check firewall rules on the host

**Messaging channels not working**
- Verify channel tokens are correct
- Check channel configuration: `juju ssh openclaw/0 'cat /home/openclaw/.openclaw/openclaw.json'`
- Review OpenClaw logs for connection errors

### Debug Mode

```bash
# Enable debug logging
juju config openclaw log-level="debug"

# View detailed logs
juju ssh openclaw/0 'journalctl -u openclaw.service -n 500'
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
