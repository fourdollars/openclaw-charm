# OpenClaw Charm: Multi-Unit Gateway-Node Implementation

## Overview

This implementation enables the OpenClaw Juju charm to support horizontal scaling with automatic Gateway-Node architecture. When deployed with multiple units, the leader unit runs as the OpenClaw Gateway while non-leader units run as OpenClaw Nodes that connect to the Gateway.

## Architecture

### Single-Unit Deployment
- **Unit 0 (Leader)**: Runs OpenClaw Gateway
  - Handles all messaging channels (Telegram, Discord, Slack, etc.)
  - Processes AI models and agent commands
  - Serves web dashboard
  - Manages sessions and workspaces

### Multi-Unit Deployment
- **Leader Unit**: Runs OpenClaw Gateway (as above)
  - Publishes connection info via peer relation
  - Opens gateway port for Node connections
  
- **Non-Leader Units**: Run OpenClaw Node
  - Connect to leader's Gateway WebSocket
  - Provide distributed compute capacity
  - Expose `system.run` and `system.which` capabilities
  - Scale horizontally for increased capacity

## Implementation Details

### 1. Metadata Changes (`metadata.yaml`)
Added peer relation for unit coordination:
```yaml
peers:
  openclaw-cluster:
    interface: openclaw-cluster
    description: Peer relation for OpenClaw units to coordinate Gateway and Node roles
```

### 2. Common Functions (`hooks/common.sh`)
Added role detection and node management functions:
- `is_leader()`: Checks if current unit is the leader
- `get_unit_role()`: Returns "gateway" or "node" based on leader status
- `generate_node_config()`: Creates node configuration with Gateway connection info
- `create_node_systemd_service()`: Creates systemd service for Node
- `start_openclaw_node()`: Starts Node service
- `stop_openclaw_node()`: Stops Node service
- `restart_openclaw_node()`: Restarts Node service

### 3. Modified Hooks

#### `hooks/start`
- Detects unit role using `get_unit_role()`
- **Gateway mode** (leader):
  - Validates configuration
  - Generates Gateway config
  - Opens ports
  - Starts Gateway service
  - Publishes connection info via `relation-set`
- **Node mode** (non-leader):
  - Waits for Gateway connection info
  - Generates Node config
  - Creates Node systemd service
  - Starts Node service

#### `hooks/stop`
- Stops appropriate service based on role
- Gateway: stops openclaw.service and closes ports
- Node: stops openclaw-node.service

#### `hooks/config-changed`
- Handles configuration changes with role awareness
- Gateway: updates Gateway config and restarts Gateway service
- Node: updates Node config and restarts Node service

#### `hooks/update-status`
- Reports status based on role
- Gateway: shows Gateway URL and port
- Node: shows connected Gateway host and port

### 4. New Peer Relation Hooks

#### `hooks/openclaw-cluster-relation-joined`
- Leader publishes Gateway connection info:
  - `gateway-host`: IP address of Gateway
  - `gateway-port`: Gateway WebSocket port
  - `gateway-token`: Authentication token

#### `hooks/openclaw-cluster-relation-changed`
- Non-leaders receive Gateway connection info
- Generates Node configuration
- Creates Node systemd service if not exists
- Restarts Node if already running

#### `hooks/openclaw-cluster-relation-departed`
- Handles unit departure
- Logs warning for Nodes losing Gateway connection

### 5. Systemd Services

#### Gateway Service (`openclaw.service`)
```ini
ExecStart=/usr/bin/env openclaw gateway --verbose
```

#### Node Service (`openclaw-node.service`)
```ini
ExecStart=/usr/bin/env openclaw node run --host ${gateway_host} --port ${gateway_port}
```

## Usage

### Deploy with Multiple Units
```bash
# Deploy with 3 units
juju deploy openclaw --channel edge -n 3 \
  --config ai-provider="anthropic" \
  --config ai-api-key="sk-ant-xxx" \
  --config ai-model="claude-opus-4-5"

# Result:
# - openclaw/0: Gateway (leader)
# - openclaw/1: Node (connected to openclaw/0)
# - openclaw/2: Node (connected to openclaw/0)
```

### Scale Up
```bash
# Add 2 more Node units
juju add-unit openclaw -n 2
```

### Scale Down
```bash
# Remove a specific unit
juju remove-unit openclaw/4
```

### Check Status
```bash
# View all units
juju status openclaw

# Expected output:
# openclaw/0*  active  idle   10.0.0.1  Gateway: http://10.0.0.1:18789
# openclaw/1   active  idle   10.0.0.2  Node connected to 10.0.0.1:18789
# openclaw/2   active  idle   10.0.0.3  Node connected to 10.0.0.1:18789
```

### Access Gateway
```bash
# Get Gateway token
juju run openclaw/leader get-gateway-token

# SSH to Gateway unit
juju ssh openclaw/0

# Check Gateway logs
juju ssh openclaw/0 'journalctl -u openclaw.service -f'
```

### Check Node Status
```bash
# SSH to Node unit
juju ssh openclaw/1

# Check Node service
juju ssh openclaw/1 'systemctl status openclaw-node.service'

# View Node logs
juju ssh openclaw/1 'journalctl -u openclaw-node.service -f'
```

## Benefits

### High Availability
- Juju handles leader election automatically
- If Gateway unit fails, Juju elects a new leader
- New leader starts Gateway service
- Nodes reconnect to new Gateway

### Horizontal Scaling
- Add more Node units for increased compute capacity
- Nodes can handle `system.run` commands in parallel
- Scale up during high load, scale down during low load

### Automatic Configuration
- No manual configuration required
- Peer relations handle all coordination
- Units auto-discover Gateway connection info
- Role assignment is automatic based on leadership

### Separation of Concerns
- Gateway focuses on messaging and AI processing
- Nodes focus on system access and compute
- Clear architectural boundaries

## Technical Notes

### Leader Election
- Juju's leader election is used (built-in)
- `is-leader` command determines current leader
- Leader status can change during deployment lifecycle
- Hooks react to leader changes appropriately

### Peer Relation Data Flow
1. Leader unit starts Gateway service
2. Leader publishes `gateway-host`, `gateway-port`, `gateway-token` via `relation-set`
3. Non-leader units receive data via `relation-get`
4. Non-leaders use data to configure Node connection
5. Nodes connect to Gateway WebSocket

### Service Management
- Gateway: managed by `openclaw.service` (systemd)
- Node: managed by `openclaw-node.service` (systemd)
- Both services auto-restart on failure
- Logs available via `journalctl`

### Port Management
- Gateway opens configured port (default: 18789)
- Nodes don't open any ports (connect outbound to Gateway)
- Only leader unit needs port opened

## Testing

### Manual Testing
```bash
# 1. Deploy with multiple units
juju deploy openclaw --channel edge -n 3 --config <your-config>

# 2. Wait for deployment
juju status --watch 1s

# 3. Verify Gateway is running
juju ssh openclaw/0 'systemctl status openclaw.service'

# 4. Verify Nodes are connected
juju ssh openclaw/1 'systemctl status openclaw-node.service'
juju ssh openclaw/2 'systemctl status openclaw-node.service'

# 5. Check peer relation data
juju run openclaw/1 'relation-get -r openclaw-cluster:0 gateway-host'
juju run openclaw/1 'relation-get -r openclaw-cluster:0 gateway-port'

# 6. Test failover (kill Gateway unit, observe new leader election)
juju remove-unit openclaw/0 --force
juju status --watch 1s
```

### Automated Testing
Future work: Add CI/CD tests for multi-unit deployment in `.github/workflows/test.yaml`

## Future Enhancements

1. **Node Health Monitoring**: Implement health checks between Gateway and Nodes
2. **Load Balancing**: Distribute `system.run` commands across available Nodes
3. **Node Capabilities**: Allow Nodes to advertise specific capabilities (GPU, storage, etc.)
4. **Gateway Redundancy**: Support multiple Gateway units with load balancing
5. **Metrics & Monitoring**: Add Prometheus metrics for Gateway-Node connections

## Troubleshooting

### Node Can't Connect to Gateway
```bash
# Check if Gateway info is published
juju run openclaw/1 'relation-get -r openclaw-cluster:0 gateway-host'

# Check network connectivity
juju ssh openclaw/1 'curl -v http://<gateway-host>:<gateway-port>'

# Check Gateway logs
juju ssh openclaw/0 'journalctl -u openclaw.service | grep node'
```

### Leader Election Issues
```bash
# Check current leader
juju status openclaw | grep "*"

# Force leader election (remove and re-add leader unit)
juju remove-unit openclaw/0 --force
```

### Service Not Starting
```bash
# Check service status
juju ssh openclaw/N 'systemctl status openclaw.service'
juju ssh openclaw/N 'systemctl status openclaw-node.service'

# View logs
juju ssh openclaw/N 'journalctl -u openclaw.service -n 100'
juju ssh openclaw/N 'journalctl -u openclaw-node.service -n 100'
```

## Files Modified

- `metadata.yaml`: Added peer relation
- `hooks/common.sh`: Added role detection and node functions
- `hooks/start`: Role-aware startup logic
- `hooks/stop`: Role-aware shutdown logic
- `hooks/config-changed`: Role-aware configuration updates
- `hooks/update-status`: Role-aware status reporting
- `hooks/openclaw-cluster-relation-joined`: New peer relation hook
- `hooks/openclaw-cluster-relation-changed`: New peer relation hook
- `hooks/openclaw-cluster-relation-departed`: New peer relation hook
- `README.md`: Added multi-unit scaling documentation
- `PROJECT_SUMMARY.md`: Updated architecture section
- `FAQ.md`: Added multi-unit deployment FAQ

## Conclusion

This implementation enables the OpenClaw charm to scale horizontally with automatic Gateway-Node architecture, providing high availability and increased compute capacity without requiring manual configuration. The design follows Juju best practices for leader election and peer relations, ensuring robust and reliable multi-unit deployments.
