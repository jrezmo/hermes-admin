# Skill: System Administration via hermes-admin

You have access to a restricted privileged helper at `/usr/local/sbin/hermes-admin`. Use it for all system administration tasks that require root privileges.

## Critical rules

- **Never ask the user for a sudo password.** You cannot use interactive sudo through messaging.
- **Never run raw `sudo` commands.** Always use the helper instead.
- **Never use `NOPASSWD: ALL` or suggest adding it to sudoers.**
- If a task requires root privileges that the helper doesn't support, tell the operator it needs to be done via SSH and suggest they add a subcommand to the helper if it's a recurring need.

## How to call it

```bash
sudo -n /usr/local/sbin/hermes-admin <subcommand> [args]
```

The `-n` flag is important — it prevents sudo from prompting for a password (which would hang in messaging).

## Available subcommands

### Diagnostics (safe, read-only)

| Command | What it does |
|---|---|
| `tailscale-status` | Show Tailscale connection status |
| `service-status <name>` | Show systemd status for an allowlisted service |
| `service-logs <name>` | Show last 50 journal lines for an allowlisted service |
| `check-disk` | Filesystem usage and large directories |
| `check-memory` | Memory usage and top processes |
| `need-reboot` | Check if a reboot is pending |
| `update-check` | Run `apt update` and list available upgrades (does NOT install them) |

### Actions (modify state — use with care)

| Command | What it does |
|---|---|
| `install-tailscale` | Install Tailscale package and enable the service |
| `tailscale-up` | Start Tailscale login flow; returns a login URL for the operator |
| `restart-service <name>` | Restart an allowlisted systemd service |

### Allowlisted services

Only these service names work with `restart-service`, `service-status`, and `service-logs`:

- `hermes-gateway`
- `nginx`
- `docker`
- `tailscaled`

Attempting to use any other service name will be denied by the helper.

## When to use each subcommand

- **User reports connectivity issues** → `tailscale-status`, then `service-status tailscaled`
- **User asks you to set up Tailscale** → `install-tailscale`, then `tailscale-up`, then send the login URL back to the user
- **A service seems down or unresponsive** → `service-status <name>`, then `service-logs <name>` to diagnose, then `restart-service <name>` if appropriate
- **User asks about disk or memory** → `check-disk` or `check-memory`
- **User asks about system updates** → `update-check` to see what's available, but do NOT install upgrades automatically — tell the user what's available and let them decide
- **User asks you to do something not in this list** → Explain that it requires SSH access and isn't available through the messaging helper

## Error handling

- If a command fails, share the error output with the user.
- If you get "permission denied" or "sudo: a password is required", the sudoers rule may not be installed correctly. Tell the user to check `/etc/sudoers.d/hermes-admin`.
- If a service name is rejected, tell the user it's not in the allowlist and they can add it by editing the helper script via SSH.
