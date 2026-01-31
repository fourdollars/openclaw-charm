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
  anthropic-api-key="sk-ant-xxx" \
  ai-model="claude-opus-4-5"

# Wait for deployment
juju status --watch 1s

# Get the gateway URL
juju status openclaw
```

Access the OpenClaw Gateway at `http://<unit-ip>:18789`

---

## Configuration

### AI Provider Setup

**Anthropic Claude (Recommended)**
```bash
juju config openclaw \
  ai-provider="anthropic" \
  anthropic-api-key="sk-ant-xxx" \
  ai-model="claude-opus-4-5"
```

**OpenAI**
```bash
juju config openclaw \
  ai-provider="openai" \
  openai-api-key="sk-xxx" \
  ai-model="gpt-4"
```

**Local Models (Ollama)**
```bash
juju config openclaw \
  ai-provider="ollama" \
  ai-model="llama3"
```

### Messaging Channels

**Enable Telegram**
```bash
juju config openclaw \
  enable-telegram=true \
  telegram-bot-token="123456:ABC-DEF"
```

**Enable Discord**
```bash
juju config openclaw \
  enable-discord=true \
  discord-bot-token="YOUR.DISCORD.TOKEN"
```

**Enable Slack**
```bash
juju config openclaw \
  enable-slack=true \
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
| `node-version` | string | 22 | Node.js major version (min 22) |
| `ai-provider` | string | anthropic | AI provider: anthropic, openai, bedrock, ollama |
| `ai-model` | string | claude-opus-4-5 | AI model name |
| `anthropic-api-key` | string | - | Anthropic API key |
| `openai-api-key` | string | - | OpenAI API key |
| `enable-telegram` | boolean | false | Enable Telegram integration |
| `telegram-bot-token` | string | - | Telegram bot token |
| `enable-discord` | boolean | false | Enable Discord integration |
| `discord-bot-token` | string | - | Discord bot token |
| `enable-slack` | boolean | false | Enable Slack integration |
| `slack-bot-token` | string | - | Slack bot token |
| `slack-app-token` | string | - | Slack app token |
| `dm-policy` | string | pairing | DM policy: pairing, open, closed |
| `sandbox-mode` | string | non-main | Sandbox: all, non-main, none |
| `install-method` | string | npm | Install method: npm, pnpm, source |
| `openclaw-version` | string | latest | Version to install |
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

**Install from source**
```bash
juju config openclaw \
  install-method="source" \
  openclaw-version="main"
```

**Pin to specific version**
```bash
juju config openclaw \
  openclaw-version="2026.1.29"
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
