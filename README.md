# hermes-admin

A restricted privileged helper for managing a Linux server through [Hermes Agent](https://github.com/NousResearch/hermes-agent) messaging gateways (Telegram, Discord) without transmitting sudo passwords through chat.

## The problem

Hermes Agent can drive multi-step server administration workflows from a messaging interface. But when a task requires `sudo`, the flow breaks:

- **Messaging gateways can't do interactive password prompts.** There's no TTY. Commands that trigger a sudo password prompt just fail with timeout or auth errors.
- **The common workaround is `NOPASSWD: ALL`.** This gives the LLM unrestricted root access — any prompt injection or Telegram session compromise becomes a full host takeover.
- **Sending a sudo password through chat is worse.** Telegram messages are durable, sync across devices, appear in notifications, client caches, and transcripts. A sudo password in chat collapses the entire trust boundary.

There is currently no built-in mechanism in the Hermes Agent or OpenClaw ecosystems that provides a scoped, root-owned privileged helper for messaging-driven administration.

## The solution

A **narrow, root-owned shell script** at `/usr/local/sbin/hermes-admin` with an explicit subcommand allowlist, paired with a **single sudoers rule** that lets the bot user run only this helper without a password.

No password in chat. No `NOPASSWD: ALL`. Only the operations you explicitly permit.

## What's in this repo

```
hermes-admin.sh          # The privileged helper script
hermes-admin.sudoers     # Drop-in sudoers rule
SKILL.md                 # Hermes skill file — teaches the agent when/how to use the helper
```

## Quick start

### 1. Install the helper

```bash
# Copy the script (review it first)
sudo cp hermes-admin.sh /usr/local/sbin/hermes-admin
sudo chown root:root /usr/local/sbin/hermes-admin
sudo chmod 0755 /usr/local/sbin/hermes-admin
```

### 2. Add the sudoers rule

```bash
# Edit the file first — replace <your-bot-user> with the Linux user your agent runs as
nano hermes-admin.sudoers   # or any editor you prefer

# Then copy, lock permissions, and validate
sudo cp hermes-admin.sudoers /etc/sudoers.d/hermes-admin
sudo chmod 0440 /etc/sudoers.d/hermes-admin

# Validate syntax — if this errors, fix before logging out
sudo visudo -cf /etc/sudoers.d/hermes-admin
```

### 3. Test from your shell

```bash
# Should work without a password prompt
sudo -n /usr/local/sbin/hermes-admin tailscale-status
sudo -n /usr/local/sbin/hermes-admin check-disk
sudo -n /usr/local/sbin/hermes-admin service-status nginx

# Should fail (unknown subcommand)
sudo -n /usr/local/sbin/hermes-admin do-something-evil
```

### 4. Install the Hermes skill

```bash
mkdir -p ~/.hermes/skills/sysadmin
cp SKILL.md ~/.hermes/skills/sysadmin/SKILL.md
```

### 5. Test from Telegram/Discord

Ask Hermes to check disk usage or restart a service. It should use the helper automatically.

## Threat model

### What this protects

- **Host root access** — no broad privilege escalation path from chat
- **Sudo password** — never transmitted, never cached by the bot
- **Service integrity** — only allowlisted services can be restarted
- **Auditability** — every invocation logged to syslog

### What this does NOT protect against

- A compromised Telegram/Discord account can still invoke any allowlisted subcommand. Scope your allowlist to operations you're comfortable with an attacker running (diagnostics are safe; `ufw-allow` probably isn't).
- The helper trusts the Hermes process. If Hermes itself is compromised at the application level, the attacker has access to whatever the helper permits.
- This is defense-in-depth, not a complete security boundary. It dramatically narrows the blast radius compared to `NOPASSWD: ALL`, but it is not a substitute for securing your Telegram account and Hermes deployment.

## Design principles

1. **No sudo password in chat.** Ever.
2. **No `NOPASSWD: ALL`.** The helper is the only thing that runs without a password.
3. **Explicit allowlist only.** Unknown subcommands are denied.
4. **Root-owned, not user-writable.** The bot user cannot modify the helper.
5. **Logged.** Every invocation hits syslog with the subcommand and arguments.
6. **Safe defaults.** Deny first. Fail closed.

## Customizing the allowlist

Edit `/usr/local/sbin/hermes-admin` to add or remove subcommands. The script uses a simple case statement — adding a new operation means adding a new block. The `ALLOWED_SERVICES` array controls which systemd units can be targeted by `restart-service`, `service-status`, and `service-logs`.

After editing, re-test from CLI before relying on it from messaging.

## Why not just use...

| Approach | Problem |
|---|---|
| `NOPASSWD: ALL` | Unrestricted root from chat. Any exploit = full host compromise. |
| Sudo password in chat | Credential exposure in message history, notifications, caches. |
| Sudo auth caching (`sudo -v`) | Requires manual SSH login first; expires in minutes. |
| Docker/Tailscale group membership | Only solves specific services, not general admin tasks. |
| Manual SSH for everything | Defeats the purpose of a 24/7 autonomous agent. |

## Extending this pattern

This is a reference implementation, not a framework. Fork it, gut it, reshape it for your setup. The valuable thing here is the *pattern* — root-owned helper, narrow sudoers rule, agent skill file — not the specific subcommands.

If you're running a different set of services, swap out the allowlist. If you want stricter controls (rate limiting, IP allowlisting, approval workflows), layer them on top. The helper is just a shell script; it's easy to extend and easy to audit.

## License

MIT. Do whatever you want with it.
