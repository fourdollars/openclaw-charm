# Contributing to OpenClaw Juju Charm

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the OpenClaw Juju Charm project.

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## How to Contribute

### Reporting Bugs

1. Check if the bug is already reported in [Issues](https://github.com/fourdollars/openclaw-charm/issues)
2. Create a new issue with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (Juju version, OS, etc.)
   - Relevant logs

### Suggesting Enhancements

1. Open an issue with the "enhancement" label
2. Describe the feature and use case
3. Explain why it would be useful

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Test thoroughly
5. Commit with clear messages
6. Push to your fork
7. Open a pull request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/fourdollars/openclaw-charm.git
cd openclaw-charm

# Install dependencies
sudo snap install charmcraft --classic
sudo snap install juju --classic

# Make changes to hooks or configuration
vim hooks/install

# Test locally
charmcraft pack
juju deploy ./openclaw_*.charm --config test-config.yaml
```

### Testing Guidelines

- Test all hooks (install, start, stop, config-changed, upgrade-charm)
- Verify configuration changes work correctly
- Test on both Jammy (22.04) and Noble (24.04)
- Check logs for errors
- Ensure service starts correctly

### Code Style

**Shell Scripts (Bash)**
- Use shellcheck for linting
- Follow Google Shell Style Guide
- Add comments for complex logic
- Use meaningful variable names
- Handle errors properly (set -e)

**YAML Files**
- 2-space indentation
- Clear descriptions for all options
- Follow Juju charm metadata standards

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add support for multiple AI providers
fix: resolve port binding issue on Noble
docs: update configuration examples
test: add upgrade test workflow
chore: update dependencies
```

### Pull Request Process

1. Update README.md if needed
2. Update CHANGELOG.md
3. Ensure all tests pass
4. Request review from maintainers
5. Address review feedback
6. Squash commits if requested

## Project Structure

```
openclaw-charm/
├── metadata.yaml       # Charm metadata and relations
├── config.yaml        # Configuration options
├── charmcraft.yaml    # Build configuration
├── hooks/             # Charm lifecycle hooks
│   ├── common.sh     # Shared functions
│   ├── install       # Installation logic
│   ├── start         # Start logic
│   ├── stop          # Stop logic
│   ├── config-changed # Config update logic
│   └── upgrade-charm  # Upgrade logic
├── .github/workflows/ # CI/CD pipelines
├── docs/             # GitHub Pages documentation
└── README.md         # Main documentation
```

## Testing

### Local Testing

```bash
# Lint shell scripts
shellcheck hooks/*

# Pack charm
charmcraft pack

# Deploy to LXD
juju bootstrap localhost test
juju add-model test-openclaw
juju deploy ./openclaw_*.charm --config anthropic-api-key="test"

# Test configuration changes
juju config openclaw gateway-port=8080

# Check status
juju status openclaw
juju ssh openclaw/0 'systemctl status openclaw'

# Clean up
juju destroy-model test-openclaw -y
```

### CI Testing

All PRs automatically run:
- Shell script linting
- Metadata validation
- Installation tests (npm/pnpm methods)
- Configuration tests
- Upgrade tests

## Release Process

1. Update version in metadata
2. Update CHANGELOG.md
3. Create PR for release
4. After merge, create tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
5. Push tag: `git push origin v1.0.0`
6. GitHub Actions will automatically:
   - Run tests
   - Build charm
   - Publish to CharmHub (candidate channel)
   - Create GitHub release

### Version Tags

- `vX.Y.Z` → candidate channel
- `vX.Y.Z-rc.N` → beta channel
- `vX.Y.Z-alpha.N` → edge channel
- Stable channel requires manual approval

## Getting Help

- **Documentation**: https://fourdollars.github.io/openclaw-charm/
- **Issues**: https://github.com/fourdollars/openclaw-charm/issues
- **Discussions**: https://github.com/fourdollars/openclaw-charm/discussions
- **Juju Docs**: https://juju.is/docs
- **OpenClaw Discord**: https://discord.gg/clawd

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
