---
name: Bug Report
about: Report a bug in the OpenClaw Juju Charm
title: '[BUG] '
labels: bug
assignees: ''
---

## Describe the Bug

A clear and concise description of what the bug is.

## To Reproduce

Steps to reproduce the behavior:
1. Deploy charm with '...'
2. Configure with '...'
3. See error

## Expected Behavior

A clear description of what you expected to happen.

## Actual Behavior

What actually happened.

## Environment

- **Juju Version**: [e.g., 3.4.0]
- **Ubuntu Version**: [e.g., 22.04, 24.04]
- **Charm Revision**: [e.g., revision 5 from stable channel]
- **Install Method**: [npm/pnpm/source]
- **OpenClaw Version**: [if known]

## Logs

```
# juju status output
juju status openclaw

# Charm logs
juju debug-log --replay --include openclaw | tail -100

# Service logs
juju ssh openclaw/0 'journalctl -u openclaw.service -n 100'
```

## Configuration

```yaml
# juju config openclaw (redact sensitive values)
```

## Additional Context

Add any other context about the problem here.
